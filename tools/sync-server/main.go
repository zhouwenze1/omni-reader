// sync-server: 阅读进度同步服务器(omni-reader 配套)。
//
// 单二进制 + SQLite,无框架依赖。API:
//
//	GET  /health
//	POST /api/sync/push         批量推送进度(内容变化才写入)
//	GET  /api/sync/pull?cursor=&deviceId=&bookUid=
//	                           按服务端序号拉取增量;bookUid 指定时返回该书最新
//
// 除 /health 外均需 Authorization: Bearer <token>(config.json 配置)。
package main

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// ---- 配置 ----

type Config struct {
	Token               string `json:"token"`
	Port                int    `json:"port"`
	DBPath              string `json:"db_path"`
	DeviceInactiveDays  int    `json:"device_inactive_days"`  // 设备闲置清理阈值,默认 180
	DeviceCleanupMinute int    `json:"device_cleanup_minute"` // 每日清理时刻(本地时区小时,0-23),默认 4
}

func defaultConfig() Config {
	return Config{Port: 8080, DBPath: "sync.db", DeviceInactiveDays: 180, DeviceCleanupMinute: 4}
}

// envOverrides 用环境变量覆盖配置(Docker 部署优先用环境变量,不依赖挂载 config.json)。
func envOverrides(cfg *Config) {
	if v := os.Getenv("SYNC_TOKEN"); v != "" {
		cfg.Token = v
	}
	if v := os.Getenv("SYNC_PORT"); v != "" {
		if p, err := strconv.Atoi(v); err == nil && p > 0 {
			cfg.Port = p
		}
	}
	if v := os.Getenv("SYNC_DB_PATH"); v != "" {
		cfg.DBPath = v
	}
	if v := os.Getenv("SYNC_DEVICE_INACTIVE_DAYS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.DeviceInactiveDays = n
		}
	}
}

func loadConfig(path string) (Config, error) {
	cfg := defaultConfig()
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			envOverrides(&cfg)
			return cfg, nil // 缺配置用默认值+环境变量
		}
		return cfg, err
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return cfg, err
	}
	envOverrides(&cfg)
	if cfg.Token == "" {
		return cfg, errors.New("config.json: token must not be empty (or set SYNC_TOKEN)")
	}
	if cfg.DeviceInactiveDays <= 0 {
		cfg.DeviceInactiveDays = 180
	}
	return cfg, nil
}

// ---- 数据模型 ----

type ProgressItem struct {
	BookUID     string  `json:"bookUid"`
	Locator     string  `json:"locator"`
	Progression float64 `json:"progression"`
	UpdatedAt   int64   `json:"updatedAt"` // epoch ms UTC
	LastReadAt  *int64  `json:"lastReadAt"`
	DeviceID    string  `json:"deviceId,omitempty"` // push 时从 body 顶层取,不逐条带
	ContentHash string  `json:"-"`
	Seq         int64   `json:"-"`
}

// ---- 存储 ----

type Store struct {
	db *sql.DB
}

func openStore(dbPath string) (*Store, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1) // modernc/sqlite 单写者,避免锁竞争
	store := &Store{db: db}
	if err := store.migrate(); err != nil {
		return nil, err
	}
	return store, nil
}

func (s *Store) migrate() error {
	const schema = `
CREATE TABLE IF NOT EXISTS progress_sync (
  book_uid     TEXT PRIMARY KEY,
  locator      TEXT NOT NULL,
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_progress_updated ON progress_sync(updated_at);
CREATE TABLE IF NOT EXISTS sync_devices (
  device_id    TEXT PRIMARY KEY,
  last_seen_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_devices_seen ON sync_devices(last_seen_at);
CREATE TABLE IF NOT EXISTS sync_changes (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  book_uid     TEXT NOT NULL,
  locator      TEXT NOT NULL,
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sync_changes_book ON sync_changes(book_uid);
CREATE TABLE IF NOT EXISTS sync_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
`
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(schema); err != nil {
		return err
	}

	var hasContentHash bool
	rows, err := tx.Query(`PRAGMA table_info(progress_sync)`)
	if err != nil {
		return err
	}
	for rows.Next() {
		var cid, notNull, primaryKey int
		var name, dataType string
		var defaultValue any
		if err := rows.Scan(
			&cid,
			&name,
			&dataType,
			&notNull,
			&defaultValue,
			&primaryKey,
		); err != nil {
			rows.Close()
			return err
		}
		if name == "content_hash" {
			hasContentHash = true
		}
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	rows.Close()
	if !hasContentHash {
		if _, err := tx.Exec(
			`ALTER TABLE progress_sync ADD COLUMN content_hash TEXT NOT NULL DEFAULT ''`,
		); err != nil {
			return err
		}
	}
	if err := s.backfillContentHashes(tx); err != nil {
		return err
	}
	if err := s.backfillChangeLog(tx); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) backfillContentHashes(tx *sql.Tx) error {
	rows, err := tx.Query(
		`SELECT book_uid, locator, progression
		 FROM progress_sync WHERE content_hash = '' OR content_hash IS NULL`,
	)
	if err != nil {
		return err
	}
	type row struct {
		bookUID     string
		locator     string
		progression float64
	}
	var pending []row
	for rows.Next() {
		var value row
		if err := rows.Scan(&value.bookUID, &value.locator, &value.progression); err != nil {
			rows.Close()
			return err
		}
		pending = append(pending, value)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	rows.Close()
	for _, value := range pending {
		hash, err := progressContentHash(value.locator, value.progression)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(
			`UPDATE progress_sync SET content_hash = ? WHERE book_uid = ?`,
			hash, value.bookUID,
		); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) backfillChangeLog(tx *sql.Tx) error {
	var marker string
	err := tx.QueryRow(
		`SELECT value FROM sync_meta WHERE key = 'legacy_backfill_v1'`,
	).Scan(&marker)
	if err == nil {
		return nil
	}
	if err != sql.ErrNoRows {
		return err
	}

	rows, err := tx.Query(
		`SELECT book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash
		 FROM progress_sync ORDER BY book_uid ASC`,
	)
	if err != nil {
		return err
	}
	type row struct {
		bookUID     string
		locator     string
		progression float64
		updatedAt   int64
		lastReadAt  *int64
		deviceID    string
		contentHash string
	}
	var pending []row
	for rows.Next() {
		var value row
		if err := rows.Scan(
			&value.bookUID,
			&value.locator,
			&value.progression,
			&value.updatedAt,
			&value.lastReadAt,
			&value.deviceID,
			&value.contentHash,
		); err != nil {
			rows.Close()
			return err
		}
		pending = append(pending, value)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	rows.Close()
	for _, value := range pending {
		if _, err := tx.Exec(
			`INSERT INTO sync_changes
			 (book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
			 VALUES (?, ?, ?, ?, ?, ?, ?)`,
			value.bookUID,
			value.locator,
			value.progression,
			value.updatedAt,
			value.lastReadAt,
			value.deviceID,
			value.contentHash,
		); err != nil {
			return err
		}
	}
	_, err = tx.Exec(
		`INSERT INTO sync_meta (key, value) VALUES ('legacy_backfill_v1', 'done')`,
	)
	return err
}

// progressContentHash 只根据阅读位置计算哈希,不使用设备时间。
func progressContentHash(locator string, progression float64) (string, error) {
	var locatorValue any
	decoder := json.NewDecoder(strings.NewReader(locator))
	decoder.UseNumber()
	if err := decoder.Decode(&locatorValue); err != nil {
		locatorValue = locator
	}
	payload := map[string]any{
		"locator":     locatorValue,
		"progression": progression,
	}
	canonical, err := marshalCanonicalJSON(payload)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(canonical)
	return hex.EncodeToString(digest[:]), nil
}

func marshalCanonicalJSON(value any) ([]byte, error) {
	var buffer bytes.Buffer
	if err := writeCanonicalJSON(&buffer, value); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func writeCanonicalJSON(buffer *bytes.Buffer, value any) error {
	switch value := value.(type) {
	case nil:
		buffer.WriteString("null")
	case string:
		encoded, err := json.Marshal(value)
		if err != nil {
			return err
		}
		buffer.Write(encoded)
	case bool:
		if value {
			buffer.WriteString("true")
		} else {
			buffer.WriteString("false")
		}
	case json.Number:
		number, err := canonicalNumber(value.String())
		if err != nil {
			return err
		}
		buffer.WriteString(number)
	case float64:
		buffer.WriteString(strconv.FormatFloat(value, 'g', -1, 64))
	case map[string]any:
		keys := make([]string, 0, len(value))
		for key := range value {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		buffer.WriteByte('{')
		for index, key := range keys {
			if index > 0 {
				buffer.WriteByte(',')
			}
			if err := writeCanonicalJSON(buffer, key); err != nil {
				return err
			}
			buffer.WriteByte(':')
			if err := writeCanonicalJSON(buffer, value[key]); err != nil {
				return err
			}
		}
		buffer.WriteByte('}')
	case []any:
		buffer.WriteByte('[')
		for index, item := range value {
			if index > 0 {
				buffer.WriteByte(',')
			}
			if err := writeCanonicalJSON(buffer, item); err != nil {
				return err
			}
		}
		buffer.WriteByte(']')
	default:
		encoded, err := json.Marshal(value)
		if err != nil {
			return err
		}
		buffer.Write(encoded)
	}
	return nil
}

func canonicalNumber(raw string) (string, error) {
	if integer, err := strconv.ParseInt(raw, 10, 64); err == nil {
		return strconv.FormatInt(integer, 10), nil
	}
	value, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return "", err
	}
	return strconv.FormatFloat(value, 'g', -1, 64), nil
}

func touchDeviceTx(tx *sql.Tx, deviceID string, now int64) error {
	_, err := tx.Exec(
		`INSERT INTO sync_devices (device_id, last_seen_at) VALUES (?, ?)
		 ON CONFLICT(device_id) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
		deviceID, now,
	)
	return err
}

// applyItemTx 按内容变化写入当前状态和变更日志,不比较客户端时间。
func (s *Store) applyItemTx(tx *sql.Tx, item ProgressItem) (bool, error) {
	hash, err := progressContentHash(item.Locator, item.Progression)
	if err != nil {
		return false, err
	}

	var currentHash string
	err = tx.QueryRow(
		`SELECT content_hash FROM progress_sync WHERE book_uid = ?`,
		item.BookUID,
	).Scan(&currentHash)
	if err == nil && currentHash == hash {
		return false, nil
	}
	if err != nil && err != sql.ErrNoRows {
		return false, err
	}

	if _, err := tx.Exec(
		`INSERT INTO sync_changes
		 (book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		item.BookUID,
		item.Locator,
		item.Progression,
		item.UpdatedAt,
		item.LastReadAt,
		item.DeviceID,
		hash,
	); err != nil {
		return false, err
	}
	if _, err := tx.Exec(
		`INSERT INTO progress_sync
		 (book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(book_uid) DO UPDATE SET
		   locator      = excluded.locator,
		   progression  = excluded.progression,
		   updated_at   = excluded.updated_at,
		   last_read_at = excluded.last_read_at,
		   device_id    = excluded.device_id,
		   content_hash = excluded.content_hash`,
		item.BookUID,
		item.Locator,
		item.Progression,
		item.UpdatedAt,
		item.LastReadAt,
		item.DeviceID,
		hash,
	); err != nil {
		return false, err
	}
	return true, nil
}

func (s *Store) touchDevice(deviceID string, now int64) error {
	_, err := s.db.Exec(
		`INSERT INTO sync_devices (device_id, last_seen_at) VALUES (?, ?)
		 ON CONFLICT(device_id) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
		deviceID, now,
	)
	return err
}

type PullResult struct {
	Items      []ProgressItem `json:"items"`
	ServerTime int64          `json:"serverTime"`
	Cursor     int64          `json:"cursor"`
}

// pullIncremental 保留给旧客户端,按旧版 after 时间过滤。
func (s *Store) pullIncremental(after int64) ([]ProgressItem, error) {
	rows, err := s.db.Query(
		`SELECT book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM progress_sync WHERE updated_at > ? ORDER BY updated_at ASC`, after,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanItems(rows)
}

// pullByCursor 在一个读事务内固定快照,保证返回的 cursor 不会跳过并发写入。
func (s *Store) pullByCursor(after int64) ([]ProgressItem, int64, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, 0, err
	}
	defer tx.Rollback()

	var cursor int64
	if err := tx.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM sync_changes`,
	).Scan(&cursor); err != nil {
		return nil, 0, err
	}
	rows, err := tx.Query(
		`SELECT seq, book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM sync_changes WHERE seq > ? AND seq <= ? ORDER BY seq ASC`,
		after, cursor,
	)
	if err != nil {
		return nil, 0, err
	}
	items, err := scanChangeItems(rows)
	rows.Close()
	if err != nil {
		return nil, 0, err
	}
	if err := tx.Commit(); err != nil {
		return nil, 0, err
	}
	return items, cursor, nil
}

func (s *Store) currentCursor() (int64, error) {
	var cursor int64
	err := s.db.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM sync_changes`,
	).Scan(&cursor)
	return cursor, err
}

// pullByBook 返回指定书的记录(不受 after 限制,用于打开图书时按需拉取)。
func (s *Store) pullByBook(bookUID string) ([]ProgressItem, error) {
	rows, err := s.db.Query(
		`SELECT book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM progress_sync WHERE book_uid = ?`, bookUID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanItems(rows)
}

func scanItems(rows *sql.Rows) ([]ProgressItem, error) {
	var items []ProgressItem
	for rows.Next() {
		var it ProgressItem
		if err := rows.Scan(&it.BookUID, &it.Locator, &it.Progression, &it.UpdatedAt, &it.LastReadAt, &it.DeviceID); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func scanChangeItems(rows *sql.Rows) ([]ProgressItem, error) {
	var items []ProgressItem
	for rows.Next() {
		var it ProgressItem
		if err := rows.Scan(
			&it.Seq,
			&it.BookUID,
			&it.Locator,
			&it.Progression,
			&it.UpdatedAt,
			&it.LastReadAt,
			&it.DeviceID,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

// cleanupInactiveDevices 删除 last_seen_at 早于阈值的设备记录。
func (s *Store) cleanupInactiveDevices(inactiveDays int, now int64) (int64, error) {
	threshold := now - int64(inactiveDays)*24*3600*1000
	res, err := s.db.Exec(`DELETE FROM sync_devices WHERE last_seen_at < ?`, threshold)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// ---- HTTP 服务 ----

type Server struct {
	cfg   Config
	store *Store
}

func (s *Server) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		if auth != "Bearer "+s.cfg.Token {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		next(w, r)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handlePush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var body struct {
		DeviceID string         `json:"deviceId"`
		Items    []ProgressItem `json:"items"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<20)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if body.DeviceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "deviceId required"})
		return
	}
	tx, err := s.store.db.Begin()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	if err := touchDeviceTx(tx, body.DeviceID, time.Now().UnixMilli()); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	accepted := 0
	changed := 0
	for _, item := range body.Items {
		if item.BookUID == "" || item.Locator == "" {
			continue
		}
		item.DeviceID = body.DeviceID
		itemChanged, err := s.store.applyItemTx(tx, item)
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
	writeJSON(w, http.StatusOK, map[string]int{
		"accepted": accepted,
		"changed":  changed,
	})
}

func (s *Server) handlePull(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	q := r.URL.Query()
	deviceID := q.Get("deviceId")
	if deviceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "deviceId required"})
		return
	}
	now := time.Now().UnixMilli()
	_ = s.store.touchDevice(deviceID, now) // 拉取也计入设备活跃

	var items []ProgressItem
	var err error
	var cursor int64
	if bookUID := q.Get("bookUid"); bookUID != "" {
		items, err = s.store.pullByBook(bookUID)
		if err == nil {
			cursor, err = s.store.currentCursor()
		}
	} else {
		if raw := q.Get("cursor"); raw != "" {
			after, perr := strconv.ParseInt(raw, 10, 64)
			if perr != nil || after < 0 {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid cursor"})
				return
			}
			items, cursor, err = s.store.pullByCursor(after)
		} else {
			var after int64
			if raw := q.Get("after"); raw != "" {
				t, perr := time.Parse(time.RFC3339Nano, raw)
				if perr != nil {
					writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid after, expect ISO-8601"})
					return
				}
				after = t.UnixMilli()
			}
			items, err = s.store.pullIncremental(after)
			cursor, _ = s.store.currentCursor()
		}
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, PullResult{
		Items:      items,
		ServerTime: now,
		Cursor:     cursor,
	})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// ---- 设备闲置清理 ----

func (s *Server) runDailyCleanup() {
	for {
		now := time.Now()
		next := time.Date(now.Year(), now.Month(), now.Day(), s.cfg.DeviceCleanupMinute, 0, 0, 0, now.Location())
		if !next.After(now) {
			next = next.Add(24 * time.Hour)
		}
		time.Sleep(time.Until(next))
		removed, err := s.store.cleanupInactiveDevices(s.cfg.DeviceInactiveDays, time.Now().UnixMilli())
		if err != nil {
			log.Printf("[cleanup] failed: %v", err)
			continue
		}
		if removed > 0 {
			log.Printf("[cleanup] removed %d inactive device(s)", removed)
		}
	}
}

func main() {
	exeDir, err := os.Executable()
	if err != nil {
		exeDir = "."
	} else {
		exeDir = filepath.Dir(exeDir)
	}
	cfgPath := filepath.Join(exeDir, "config.json")
	cfg, err := loadConfig(cfgPath)
	if err != nil {
		log.Fatalf("config error: %v", err)
	}
	store, err := openStore(cfg.DBPath)
	if err != nil {
		log.Fatalf("db error: %v", err)
	}

	srv := &Server{cfg: cfg, store: store}
	mux := http.NewServeMux()
	mux.HandleFunc("/health", srv.handleHealth)
	mux.HandleFunc("/api/sync/push", srv.auth(srv.handlePush))
	mux.HandleFunc("/api/sync/pull", srv.auth(srv.handlePull))

	// 启动时先清一次,再走每日定时。
	if removed, err := store.cleanupInactiveDevices(cfg.DeviceInactiveDays, time.Now().UnixMilli()); err == nil && removed > 0 {
		log.Printf("[cleanup] removed %d inactive device(s) at startup", removed)
	}
	go srv.runDailyCleanup()

	log.Printf("sync-server listening on :%d (db=%s)", cfg.Port, cfg.DBPath)
	if err := http.ListenAndServe(":"+strconv.Itoa(cfg.Port), mux); err != nil {
		log.Fatal(err)
	}
}
