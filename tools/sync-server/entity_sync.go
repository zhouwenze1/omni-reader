package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// ---- 实体同步 v2:标注/设置/统计。多实体变更日志 + 按实体游标拉取 ----
//
// 与 v1 progress 同构:push 按内容指纹去重(幂等),写入状态表+只追加日志表;
// pull 按日志 seq 游标增量回放,首次 cursor=0 即全量。冲突在客户端解决:
// annotation 按 updatedAt LWW + 墓碑删除,setting per-key LWW,stat 按 (deviceId, startedAt) 并集。

var syncEntities = map[string]bool{"annotation": true, "setting": true, "stat": true}

// EntityPushItem push/pull 的通用条目。payload 对服务端不透明(原样存储/回传)。
type EntityPushItem struct {
	Key       string          `json:"key"`
	Payload   json.RawMessage `json:"payload,omitempty"`
	UpdatedAt int64           `json:"updatedAt"`
	Deleted   bool            `json:"deleted,omitempty"`
}

func (s *Store) ensureEntityTables() error {
	_, err := s.db.Exec(`
CREATE TABLE IF NOT EXISTS entity_state (
  user_id      INTEGER NOT NULL,
  entity       TEXT NOT NULL,
  item_key     TEXT NOT NULL,
  payload      TEXT NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER,
  content_hash TEXT NOT NULL,
  PRIMARY KEY (user_id, entity, item_key)
);
CREATE TABLE IF NOT EXISTS entity_changes (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  entity       TEXT NOT NULL,
  item_key     TEXT NOT NULL,
  payload      TEXT NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER,
  content_hash TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entity_changes ON entity_changes(user_id, entity, seq);
`)
	return err
}

// validEntityKey 条目键:非空、无控制字符、长度受限。
func validEntityKey(key string) bool {
	if key == "" || len(key) > 200 {
		return false
	}
	return !strings.ContainsFunc(key, func(r rune) bool { return r < 0x20 })
}

func entityContentHash(payload string, deleted bool) (string, error) {
	var decoded any
	decoder := json.NewDecoder(strings.NewReader(payload))
	decoder.UseNumber()
	if err := decoder.Decode(&decoded); err != nil {
		return "", err
	}
	canonical, err := marshalCanonicalJSON(map[string]any{
		"payload": decoded,
		"deleted": deleted,
	})
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(canonical)
	return hex.EncodeToString(digest[:]), nil
}

// applyEntityItem 指纹未变化时跳过(幂等),否则追加日志并更新状态。返回是否新增。
func (s *Store) applyEntityItem(tx *sql.Tx, userID int64, entity string, item EntityPushItem) (bool, error) {
	payload := "{}"
	if !item.Deleted && len(item.Payload) > 0 {
		payload = string(item.Payload)
	}
	hash, err := entityContentHash(payload, item.Deleted)
	if err != nil {
		return false, err
	}

	var currentHash string
	err = tx.QueryRow(
		`SELECT content_hash FROM entity_state WHERE user_id = ? AND entity = ? AND item_key = ?`,
		userID, entity, item.Key,
	).Scan(&currentHash)
	if err == nil && currentHash == hash {
		return false, nil
	}
	if err != nil && err != sql.ErrNoRows {
		return false, err
	}

	var deletedAt any
	if item.Deleted {
		deletedAt = item.UpdatedAt
	}
	if _, err := tx.Exec(
		`INSERT INTO entity_state (user_id, entity, item_key, payload, updated_at, deleted_at, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(user_id, entity, item_key) DO UPDATE SET
		   payload = excluded.payload, updated_at = excluded.updated_at,
		   deleted_at = excluded.deleted_at, content_hash = excluded.content_hash`,
		userID, entity, item.Key, payload, item.UpdatedAt, deletedAt, hash,
	); err != nil {
		return false, err
	}
	if _, err := tx.Exec(
		`INSERT INTO entity_changes (user_id, entity, item_key, payload, updated_at, deleted_at, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		userID, entity, item.Key, payload, item.UpdatedAt, deletedAt, hash,
	); err != nil {
		return false, err
	}
	return true, nil
}

// pullEntityByCursor 在读事务内固定快照,返回变更条目与该实体日志的新游标。
func (s *Store) pullEntityByCursor(userID int64, entity string, after int64) ([]EntityPushItem, int64, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, 0, err
	}
	defer tx.Rollback()

	var cursor int64
	if err := tx.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM entity_changes WHERE user_id = ? AND entity = ?`,
		userID, entity,
	).Scan(&cursor); err != nil {
		return nil, 0, err
	}
	rows, err := tx.Query(
		`SELECT item_key, payload, updated_at, deleted_at
		 FROM entity_changes WHERE user_id = ? AND entity = ? AND seq > ? AND seq <= ?
		 ORDER BY seq ASC`,
		userID, entity, after, cursor,
	)
	if err != nil {
		return nil, 0, err
	}
	items := make([]EntityPushItem, 0, 16)
	for rows.Next() {
		var it EntityPushItem
		var payload string
		var deletedAt *int64
		if err := rows.Scan(&it.Key, &payload, &it.UpdatedAt, &deletedAt); err != nil {
			rows.Close()
			return nil, 0, err
		}
		it.Payload = json.RawMessage(payload)
		it.Deleted = deletedAt != nil
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, 0, err
	}
	rows.Close()
	if err := tx.Commit(); err != nil {
		return nil, 0, err
	}
	return items, cursor, nil
}

// ---- HTTP ----

func (s *Server) handleEntityPush(w http.ResponseWriter, r *http.Request, user User) {
	entity := r.PathValue("entity")
	if !syncEntities[entity] {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "unknown entity"})
		return
	}
	var body struct {
		DeviceID string           `json:"deviceId"`
		Items    []EntityPushItem `json:"items"`
	}
	if err := jsonDecodeLimited(w, r, 8<<20, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	tx, err := s.store.db.Begin()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	accepted := 0
	changed := 0
	for _, item := range body.Items {
		if !validEntityKey(item.Key) {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid key"})
			return
		}
		if item.UpdatedAt <= 0 {
			item.UpdatedAt = time.Now().UnixMilli()
		}
		itemChanged, err := s.store.applyEntityItem(tx, user.ID, entity, item)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		accepted++
		if itemChanged {
			changed++
		}
	}
	if err := tx.Commit(); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if changed > 0 {
		s.recordActivity("sync."+entity, user.Name,
			"推送 "+strconv.Itoa(changed)+" 条变化")
	}
	writeJSON(w, http.StatusOK, map[string]int{"accepted": accepted, "changed": changed})
}

func (s *Server) handleEntityPull(w http.ResponseWriter, r *http.Request, user User) {
	entity := r.PathValue("entity")
	if !syncEntities[entity] {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "unknown entity"})
		return
	}
	var after int64
	if raw := r.URL.Query().Get("cursor"); raw != "" {
		value, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || value < 0 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid cursor"})
			return
		}
		after = value
	}
	items, cursor, err := s.store.pullEntityByCursor(user.ID, entity, after)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if len(items) > 0 {
		s.recordActivity("sync."+entity, user.Name,
			"拉取 "+strconv.Itoa(len(items))+" 条")
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"items":      items,
		"cursor":     cursor,
		"serverTime": time.Now().UnixMilli(),
	})
}

var errUnknownEntity = errors.New("unknown entity")
