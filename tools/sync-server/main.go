// sync-server: 阅读进度同步服务器(omni-reader 配套)。
//
// 单二进制 + SQLite,无框架依赖。API:
//
//	GET  /health
//	POST /api/sync/push         批量推送进度(updatedAt 后写赢)
//	GET  /api/sync/pull?after=&deviceId=&bookUid=
//	                           拉取增量;bookUid 指定时返回该书最新(不受 after 限制)
//
// 除 /health 外均需 Authorization: Bearer <token>(config.json 配置)。
package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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

func loadConfig(path string) (Config, error) {
	cfg := defaultConfig()
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return cfg, nil // 缺配置用默认值
		}
		return cfg, err
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return cfg, err
	}
	if cfg.Token == "" {
		return cfg, errors.New("config.json: token must not be empty")
	}
	if cfg.DeviceInactiveDays <= 0 {
		cfg.DeviceInactiveDays = 180
	}
	return cfg, nil
}

// ---- 数据模型 ----

type ProgressItem struct {
	BookUID    string  `json:"bookUid"`
	Locator    string  `json:"locator"`
	Progression float64 `json:"progression"`
	UpdatedAt  int64   `json:"updatedAt"` // epoch ms UTC
	LastReadAt *int64  `json:"lastReadAt"`
	DeviceID   string  `json:"deviceId,omitempty"` // push 时从 body 顶层取,不逐条带
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
  device_id    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_progress_updated ON progress_sync(updated_at);
CREATE TABLE IF NOT EXISTS sync_devices (
  device_id    TEXT PRIMARY KEY,
  last_seen_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_devices_seen ON sync_devices(last_seen_at);
`
	_, err := s.db.Exec(schema)
	return err
}

// upsertItem 按 book_uid 合并,updated_at 新者覆盖(后写赢)。
func (s *Store) upsertItem(item ProgressItem) error {
	res, err := s.db.Exec(
		`INSERT INTO progress_sync (book_uid, locator, progression, updated_at, last_read_at, device_id)
		 VALUES (?, ?, ?, ?, ?, ?)
		 ON CONFLICT(book_uid) DO UPDATE SET
		   locator      = excluded.locator,
		   progression  = excluded.progression,
		   updated_at   = excluded.updated_at,
		   last_read_at = excluded.last_read_at,
		   device_id    = excluded.device_id
		 WHERE excluded.updated_at > progress_sync.updated_at`,
		item.BookUID, item.Locator, item.Progression, item.UpdatedAt, item.LastReadAt, item.DeviceID,
	)
	if err != nil {
		return err
	}
	_ = res // 行数仅用于调试
	return nil
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
}

// pullIncremental 返回 updated_at > after 的记录(按 after 过滤)。
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
		DeviceID string          `json:"deviceId"`
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
	now := time.Now().UnixMilli()
	if err := s.store.touchDevice(body.DeviceID, now); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	accepted := 0
	for _, item := range body.Items {
		if item.BookUID == "" || item.Locator == "" {
			continue
		}
		item.DeviceID = body.DeviceID
		if err := s.store.upsertItem(item); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		accepted++
	}
	writeJSON(w, http.StatusOK, map[string]int{"accepted": accepted})
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
	if bookUID := q.Get("bookUid"); bookUID != "" {
		items, err = s.store.pullByBook(bookUID)
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
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, PullResult{Items: items, ServerTime: now})
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
