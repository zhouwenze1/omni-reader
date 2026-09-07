// sync-server: 阅读进度同步 + 书库云备份服务器(omni-reader 配套)。
//
// 单二进制 + SQLite,无框架依赖。多用户:管理员在 /admin 网页生成 token 分发,
// 所有数据按 token(用户)隔离。API:
//
//	GET    /health
//	POST   /api/sync/push               批量推送进度(内容变化才写入)
//	GET    /api/sync/pull?cursor=&deviceId=&bookUid=
//	                                    按服务端序号拉取增量;bookUid 指定时返回该书最新
//	GET    /api/library/manifest?since= 书单(含墓碑),since 为 updated_at 毫秒增量
//	POST   /api/library/announce        上报书目元数据(含封面 base64)
//	PUT    /api/books/{uid}/file?ext=   上传原始书文件
//	GET    /api/books/{uid}/file        下载原始书文件(支持 Range)
//	GET    /api/books/{uid}/cover       下载封面
//	DELETE /api/library/{uid}           删除云端书目(墓碑)+文件
//	GET    /admin                       管理页(登录后可生成/删除用户 token)
//
// 除 /health 与 /admin 登录外均需 Authorization: Bearer <用户token>。
package main

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

// serverVersion 由构建注入:-ldflags "-X main.serverVersion=20260905b"。
var serverVersion = "dev"

// startedAt 在进程启动时记录,管理页展示运行时长。
var startedAt = time.Now()

// ---- 配置 ----

type Config struct {
	Port                int    `json:"port"`
	DBPath              string `json:"db_path"`
	AdminPassword       string `json:"admin_password"`        // 管理页登录密码,必填
	LegacyToken         string `json:"token"`                 // 兼容旧配置:首次启动用该 token 建 default 用户
	DeviceInactiveDays  int    `json:"device_inactive_days"`  // 设备闲置清理阈值,默认 180
	DeviceCleanupMinute int    `json:"device_cleanup_minute"` // 每日清理时刻(本地时区小时,0-23),默认 4
	BookVaultMaxFileMB  int    `json:"book_vault_max_file_mb"`
	UpdatePath          string `json:"update_path"` // 热更新二进制落点;容器内默认 /data/sync-server
}

func defaultConfig() Config {
	return Config{
		Port:                8080,
		DBPath:              "sync.db",
		DeviceInactiveDays:  180,
		DeviceCleanupMinute: 4,
		BookVaultMaxFileMB:  200,
	}
}

// envOverrides 用环境变量覆盖配置(Docker 部署优先用环境变量,不依赖挂载 config.json)。
func envOverrides(cfg *Config) {
	if v := os.Getenv("SYNC_PORT"); v != "" {
		if p, err := strconv.Atoi(v); err == nil && p > 0 {
			cfg.Port = p
		}
	}
	if v := os.Getenv("SYNC_DB_PATH"); v != "" {
		cfg.DBPath = v
	}
	if v := os.Getenv("ADMIN_PASSWORD"); v != "" {
		cfg.AdminPassword = v
	}
	if v := os.Getenv("SYNC_TOKEN"); v != "" {
		cfg.LegacyToken = v
	}
	if v := os.Getenv("SYNC_DEVICE_INACTIVE_DAYS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.DeviceInactiveDays = n
		}
	}
	if v := os.Getenv("SYNC_BOOK_MAX_FILE_MB"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			cfg.BookVaultMaxFileMB = n
		}
	}
	if v := os.Getenv("SYNC_UPDATE_PATH"); v != "" {
		cfg.UpdatePath = v
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
	if cfg.AdminPassword == "" {
		return cfg, errors.New("config.json: admin_password must not be empty (or set ADMIN_PASSWORD)")
	}
	if cfg.DeviceInactiveDays <= 0 {
		cfg.DeviceInactiveDays = 180
	}
	if cfg.BookVaultMaxFileMB <= 0 {
		cfg.BookVaultMaxFileMB = 200
	}
	return cfg, nil
}

// defaultUpdatePath 与 bootstrap 的探测路径保持一致。
func defaultUpdatePath() string { return "/data/sync-server" }

// ---- 用户 ----

type User struct {
	ID         int64
	Name       string
	Token      string
	CreatedAt  int64
	LastSeenAt *int64
	Enabled    bool
}

func (s *Store) createUser(name, token string, now int64) (User, error) {
	res, err := s.db.Exec(
		`INSERT INTO users (name, token, created_at, enabled) VALUES (?, ?, ?, 1)`,
		name, token, now,
	)
	if err != nil {
		return User{}, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return User{}, err
	}
	return User{ID: id, Name: name, Token: token, CreatedAt: now, Enabled: true}, nil
}

func (s *Store) listUsers() ([]User, error) {
	rows, err := s.db.Query(
		`SELECT id, name, token, created_at, last_seen_at, enabled FROM users ORDER BY id ASC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanUsers(rows)
}

func scanUsers(rows *sql.Rows) ([]User, error) {
	var users []User
	for rows.Next() {
		var u User
		var enabled int
		if err := rows.Scan(&u.ID, &u.Name, &u.Token, &u.CreatedAt, &u.LastSeenAt, &enabled); err != nil {
			return nil, err
		}
		u.Enabled = enabled == 1
		users = append(users, u)
	}
	return users, rows.Err()
}

func (s *Store) userByToken(token string) (User, bool) {
	var u User
	var enabled int
	err := s.db.QueryRow(
		`SELECT id, name, token, created_at, last_seen_at, enabled FROM users WHERE token = ?`,
		token,
	).Scan(&u.ID, &u.Name, &u.Token, &u.CreatedAt, &u.LastSeenAt, &enabled)
	if err != nil {
		return User{}, false
	}
	u.Enabled = enabled == 1
	return u, u.Enabled
}

func (s *Store) touchUser(userID int64, now int64) {
	_, _ = s.db.Exec(`UPDATE users SET last_seen_at = ? WHERE id = ?`, now, userID)
}

// deleteUser 级联删除该用户全部数据(进度/变更/设备/书单),书文件目录由调用方删除。
func (s *Store) deleteUser(userID int64) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, table := range []string{"progress_sync", "sync_changes", "sync_devices", "library_manifest"} {
		if _, err := tx.Exec(`DELETE FROM `+table+` WHERE user_id = ?`, userID); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(`DELETE FROM users WHERE id = ?`, userID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) countUserBooks(userID int64) (int, error) {
	var count int
	err := s.db.QueryRow(
		`SELECT COUNT(*) FROM library_manifest WHERE user_id = ? AND deleted_at IS NULL`,
		userID,
	).Scan(&count)
	return count, err
}

func (s *Store) getUserByID(id int64) (User, error) {
	var u User
	var enabled int
	err := s.db.QueryRow(
		`SELECT id, name, token, created_at, last_seen_at, enabled FROM users WHERE id = ?`, id,
	).Scan(&u.ID, &u.Name, &u.Token, &u.CreatedAt, &u.LastSeenAt, &enabled)
	if err != nil {
		return User{}, err
	}
	u.Enabled = enabled == 1
	return u, nil
}

func (s *Store) renameUser(id int64, name string) error {
	_, err := s.db.Exec(`UPDATE users SET name = ? WHERE id = ?`, name, id)
	return err
}

func (s *Store) setUserEnabled(id int64, enabled bool) error {
	value := 0
	if enabled {
		value = 1
	}
	_, err := s.db.Exec(`UPDATE users SET enabled = ? WHERE id = ?`, value, id)
	return err
}

func (s *Store) resetUserToken(id int64, token string) error {
	_, err := s.db.Exec(`UPDATE users SET token = ? WHERE id = ?`, token, id)
	return err
}

// ---- 设备 ----

type DeviceView struct {
	DeviceID    string `json:"deviceId"`
	LastSeenAt  int64  `json:"lastSeenAt"`
	BooksSynced int    `json:"booksSynced"`
}

func (s *Store) countUserDevices(userID int64) (int, error) {
	var count int
	err := s.db.QueryRow(
		`SELECT COUNT(*) FROM sync_devices WHERE user_id = ?`, userID,
	).Scan(&count)
	return count, err
}

func (s *Store) listUserDevices(userID int64) ([]DeviceView, error) {
	rows, err := s.db.Query(
		`SELECT d.device_id, d.last_seen_at,
		        (SELECT COUNT(*) FROM progress_sync p WHERE p.user_id = d.user_id AND p.device_id = d.device_id)
		 FROM sync_devices d WHERE d.user_id = ? ORDER BY d.last_seen_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var devices []DeviceView
	for rows.Next() {
		var d DeviceView
		if err := rows.Scan(&d.DeviceID, &d.LastSeenAt, &d.BooksSynced); err != nil {
			return nil, err
		}
		devices = append(devices, d)
	}
	return devices, rows.Err()
}

func (s *Store) deleteUserDevice(userID int64, deviceID string) error {
	_, err := s.db.Exec(`DELETE FROM sync_devices WHERE user_id = ? AND device_id = ?`, userID, deviceID)
	return err
}

func (s *Store) vacuum() error {
	_, err := s.db.Exec(`VACUUM`)
	return err
}

// ---- 数据模型(进度同步) ----

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
	db       *sql.DB
	vaultDir string
}

func openStore(dbPath, seedToken string) (*Store, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1) // modernc/sqlite 单写者,避免锁竞争
	store := &Store{db: db}
	if err := store.ensureUsersTable(); err != nil {
		db.Close()
		return nil, err
	}
	defaultUserID, err := store.seedDefaultUser(seedToken, time.Now().UnixMilli())
	if err != nil {
		db.Close()
		return nil, err
	}
	if err := store.migrate(defaultUserID); err != nil {
		db.Close()
		return nil, err
	}
	if err := store.ensureEntityTables(); err != nil {
		db.Close()
		return nil, err
	}
	store.vaultDir = filepath.Join(filepath.Dir(dbPath), "book-vault")
	if err := os.MkdirAll(store.vaultDir, 0o755); err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

func (s *Store) ensureUsersTable() error {
	_, err := s.db.Exec(`
CREATE TABLE IF NOT EXISTS users (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,
  token        TEXT NOT NULL UNIQUE,
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER,
  enabled      INTEGER NOT NULL DEFAULT 1
)`)
	return err
}

// seedDefaultUser 在 users 为空且给了种子 token 时建 default 用户;返回迁移用的默认用户 id。
func (s *Store) seedDefaultUser(seedToken string, now int64) (int64, error) {
	var count int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&count); err != nil {
		return 0, err
	}
	if count == 0 && seedToken != "" {
		if _, err := s.createUser("default", seedToken, now); err != nil {
			return 0, err
		}
	}
	var id int64
	err := s.db.QueryRow(`SELECT id FROM users ORDER BY id ASC LIMIT 1`).Scan(&id)
	if err == sql.ErrNoRows {
		return 0, nil
	}
	return id, err
}

// migrate 建最终 schema;旧库缺 user_id 的表整体重建,历史数据归属默认用户。
func (s *Store) migrate(defaultUserID int64) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 旧表重建(带 user_id 的新主键);新库无这些表则跳过。
	if err := rebuildProgressSync(tx, defaultUserID); err != nil {
		return err
	}
	if err := rebuildSimple(tx, "sync_devices",
		`CREATE TABLE sync_devices__v2 (
		   user_id      INTEGER NOT NULL,
		   device_id    TEXT NOT NULL,
		   last_seen_at INTEGER NOT NULL,
		   PRIMARY KEY (user_id, device_id)
		 )`,
		[]string{"device_id", "last_seen_at"}, defaultUserID,
	); err != nil {
		return err
	}
	if err := rebuildChanges(tx, defaultUserID); err != nil {
		return err
	}

	const schema = `
CREATE TABLE IF NOT EXISTS progress_sync (
  user_id      INTEGER NOT NULL,
  book_uid     TEXT NOT NULL,
  locator      TEXT NOT NULL,
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (user_id, book_uid)
);
CREATE INDEX IF NOT EXISTS idx_progress_updated ON progress_sync(updated_at);
CREATE TABLE IF NOT EXISTS sync_devices (
  user_id      INTEGER NOT NULL,
  device_id    TEXT NOT NULL,
  last_seen_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, device_id)
);
CREATE INDEX IF NOT EXISTS idx_devices_seen ON sync_devices(last_seen_at);
CREATE TABLE IF NOT EXISTS sync_changes (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  book_uid     TEXT NOT NULL,
  locator      TEXT NOT NULL,
  progression  REAL NOT NULL,
  updated_at   INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sync_changes_user_seq ON sync_changes(user_id, seq);
CREATE INDEX IF NOT EXISTS idx_sync_changes_book ON sync_changes(book_uid);
CREATE TABLE IF NOT EXISTS library_manifest (
  user_id      INTEGER NOT NULL,
  book_uid     TEXT NOT NULL,
  fingerprint  TEXT NOT NULL DEFAULT '',
  title        TEXT NOT NULL,
  authors_json TEXT NOT NULL DEFAULT '[]',
  format       TEXT NOT NULL DEFAULT '',
  size_bytes   INTEGER NOT NULL DEFAULT 0,
  cover_ext    TEXT NOT NULL DEFAULT '',
  imported_at  INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER,
  PRIMARY KEY (user_id, book_uid)
);
CREATE INDEX IF NOT EXISTS idx_manifest_user_updated ON library_manifest(user_id, updated_at);
CREATE TABLE IF NOT EXISTS sync_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
`
	if _, err := tx.Exec(schema); err != nil {
		return err
	}

	if err := s.backfillContentHashes(tx); err != nil {
		return err
	}
	if err := s.backfillChangeLog(tx); err != nil {
		return err
	}
	return tx.Commit()
}

// tableColumns 返回表现有列名集合;表不存在返回 nil。
func tableColumns(tx *sql.Tx, table string) (map[string]bool, error) {
	var name string
	err := tx.QueryRow(
		`SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?`, table,
	).Scan(&name)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	rows, err := tx.Query(`SELECT name FROM pragma_table_info(?)`, table)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	cols := map[string]bool{}
	for rows.Next() {
		var column string
		if err := rows.Scan(&column); err != nil {
			return nil, err
		}
		cols[column] = true
	}
	return cols, rows.Err()
}

// rebuildSimple 重建只有普通列、无可选列的表。
func rebuildSimple(tx *sql.Tx, table, createV2 string, cols []string, defaultUserID int64) error {
	existing, err := tableColumns(tx, table)
	if err != nil {
		return err
	}
	if existing == nil || existing["user_id"] {
		return nil // 新库,或已是新 schema
	}
	if _, err := tx.Exec(createV2); err != nil {
		return err
	}
	if err := copyRows(tx, table+"__v2", cols, cols, existing, defaultUserID); err != nil {
		return err
	}
	if _, err := tx.Exec(`DROP TABLE ` + table); err != nil {
		return err
	}
	_, err = tx.Exec(`ALTER TABLE ` + table + `__v2 RENAME TO ` + table)
	return err
}

// copyRows 把旧表数据拷入新表;可选列缺失时用 fallback 填充。
func copyRows(tx *sql.Tx, destTable string, destCols, srcCols []string, existing map[string]bool, defaultUserID int64) error {
	selects := make([]string, 0, len(srcCols)+1)
	for _, col := range srcCols {
		if existing[col] {
			selects = append(selects, `"`+col+`"`)
		} else {
			selects = append(selects, fmt.Sprintf("%s AS %q", colFallback(col), col))
		}
	}
	query := fmt.Sprintf(`INSERT INTO %s (%s, "user_id") SELECT %s, ? FROM %s`,
		destTable, quoteJoin(destCols), strings.Join(selects, ", "), legacyTableName(destTable))
	_, err := tx.Exec(query, defaultUserID)
	return err
}

func legacyTableName(destTable string) string {
	return strings.TrimSuffix(destTable, "__v2")
}

// colFallback 旧表缺失列的填充值。
func colFallback(col string) string {
	if col == "content_hash" {
		return "''"
	}
	return "NULL"
}

func quoteJoin(cols []string) string {
	quoted := make([]string, len(cols))
	for i, col := range cols {
		quoted[i] = `"` + col + `"`
	}
	return strings.Join(quoted, ", ")
}

func rebuildProgressSync(tx *sql.Tx, defaultUserID int64) error {
	existing, err := tableColumns(tx, "progress_sync")
	if err != nil {
		return err
	}
	if existing == nil || existing["user_id"] {
		return nil
	}
	const createV2 = `CREATE TABLE progress_sync__v2 (
	  user_id      INTEGER NOT NULL,
	  book_uid     TEXT NOT NULL,
	  locator      TEXT NOT NULL,
	  progression  REAL NOT NULL,
	  updated_at   INTEGER NOT NULL,
	  last_read_at INTEGER,
	  device_id    TEXT NOT NULL,
	  content_hash TEXT NOT NULL DEFAULT '',
	  PRIMARY KEY (user_id, book_uid)
	)`
	if _, err := tx.Exec(createV2); err != nil {
		return err
	}
	cols := []string{"book_uid", "locator", "progression", "updated_at", "last_read_at", "device_id", "content_hash"}
	if err := copyRows(tx, "progress_sync__v2", cols, cols, existing, defaultUserID); err != nil {
		return err
	}
	if _, err := tx.Exec(`DROP TABLE progress_sync`); err != nil {
		return err
	}
	_, err = tx.Exec(`ALTER TABLE progress_sync__v2 RENAME TO progress_sync`)
	return err
}

func rebuildChanges(tx *sql.Tx, defaultUserID int64) error {
	existing, err := tableColumns(tx, "sync_changes")
	if err != nil {
		return err
	}
	if existing == nil || existing["user_id"] {
		return nil
	}
	const createV2 = `CREATE TABLE sync_changes__v2 (
	  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
	  user_id      INTEGER NOT NULL,
	  book_uid     TEXT NOT NULL,
	  locator      TEXT NOT NULL,
	  progression  REAL NOT NULL,
	  updated_at   INTEGER NOT NULL,
	  last_read_at INTEGER,
	  device_id    TEXT NOT NULL,
	  content_hash TEXT NOT NULL
	)`
	if _, err := tx.Exec(createV2); err != nil {
		return err
	}
	cols := []string{"book_uid", "locator", "progression", "updated_at", "last_read_at", "device_id", "content_hash"}
	if err := copyRows(tx, "sync_changes__v2", cols, cols, existing, defaultUserID); err != nil {
		return err
	}
	if _, err := tx.Exec(`DROP TABLE sync_changes`); err != nil {
		return err
	}
	_, err = tx.Exec(`ALTER TABLE sync_changes__v2 RENAME TO sync_changes`)
	return err
}

func (s *Store) backfillContentHashes(tx *sql.Tx) error {
	rows, err := tx.Query(
		`SELECT user_id, book_uid, locator, progression
		 FROM progress_sync WHERE content_hash = '' OR content_hash IS NULL`,
	)
	if err != nil {
		return err
	}
	type row struct {
		userID      int64
		bookUID     string
		locator     string
		progression float64
	}
	var pending []row
	for rows.Next() {
		var value row
		if err := rows.Scan(&value.userID, &value.bookUID, &value.locator, &value.progression); err != nil {
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
			`UPDATE progress_sync SET content_hash = ? WHERE user_id = ? AND book_uid = ?`,
			hash, value.userID, value.bookUID,
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
		`SELECT user_id, book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash
		 FROM progress_sync ORDER BY user_id ASC, book_uid ASC`,
	)
	if err != nil {
		return err
	}
	type row struct {
		userID      int64
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
			&value.userID,
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
			 (user_id, book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			value.userID,
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

func touchDeviceTx(tx *sql.Tx, userID int64, deviceID string, now int64) error {
	_, err := tx.Exec(
		`INSERT INTO sync_devices (user_id, device_id, last_seen_at) VALUES (?, ?, ?)
		 ON CONFLICT(user_id, device_id) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
		userID, deviceID, now,
	)
	return err
}

// applyItemTx 按 updated_at 做 LWW:内容变化且时间戳不旧于当前行才写入状态与
// 变更日志。时间戳更旧的迟到写入被跳过,避免慢设备/断线重推回滚较新进度
// (与 entity 同步的客户端 LWW 语义一致:严格新于才覆盖,等值保留现有行)。
func (s *Store) applyItemTx(tx *sql.Tx, userID int64, item ProgressItem) (bool, error) {
	hash, err := progressContentHash(item.Locator, item.Progression)
	if err != nil {
		return false, err
	}

	var currentHash string
	var currentUpdatedAt int64
	err = tx.QueryRow(
		`SELECT content_hash, updated_at FROM progress_sync WHERE user_id = ? AND book_uid = ?`,
		userID, item.BookUID,
	).Scan(&currentHash, &currentUpdatedAt)
	if err == nil {
		if currentHash == hash {
			return false, nil
		}
		if item.UpdatedAt <= currentUpdatedAt {
			return false, nil
		}
	}
	if err != nil && err != sql.ErrNoRows {
		return false, err
	}

	if _, err := tx.Exec(
		`INSERT INTO sync_changes
		 (user_id, book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		userID,
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
		 (user_id, book_uid, locator, progression, updated_at, last_read_at, device_id, content_hash)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(user_id, book_uid) DO UPDATE SET
		   locator      = excluded.locator,
		   progression  = excluded.progression,
		   updated_at   = excluded.updated_at,
		   last_read_at = excluded.last_read_at,
		   device_id    = excluded.device_id,
		   content_hash = excluded.content_hash`,
		userID,
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

func (s *Store) touchDevice(userID int64, deviceID string, now int64) error {
	_, err := s.db.Exec(
		`INSERT INTO sync_devices (user_id, device_id, last_seen_at) VALUES (?, ?, ?)
		 ON CONFLICT(user_id, device_id) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
		userID, deviceID, now,
	)
	return err
}

type PullResult struct {
	Items      []ProgressItem `json:"items"`
	ServerTime int64          `json:"serverTime"`
	Cursor     int64          `json:"cursor"`
}

// pullIncremental 保留给旧客户端,按旧版 after 时间过滤。
func (s *Store) pullIncremental(userID int64, after int64) ([]ProgressItem, error) {
	rows, err := s.db.Query(
		`SELECT book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM progress_sync WHERE user_id = ? AND updated_at > ? ORDER BY updated_at ASC`,
		userID, after,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanItems(rows)
}

// pullByCursor 在一个读事务内固定快照,保证返回的 cursor 不会跳过并发写入。
// cursor 是"该用户"的 max seq(非全局),避免把其他用户的写入进度带进本用户游标。
func (s *Store) pullByCursor(userID int64, after int64) ([]ProgressItem, int64, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, 0, err
	}
	defer tx.Rollback()

	var cursor int64
	if err := tx.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM sync_changes WHERE user_id = ?`,
		userID,
	).Scan(&cursor); err != nil {
		return nil, 0, err
	}
	rows, err := tx.Query(
		`SELECT seq, book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM sync_changes WHERE user_id = ? AND seq > ? AND seq <= ? ORDER BY seq ASC`,
		userID, after, cursor,
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

// currentCursor 返回该用户的 max seq;seq 是全局单调递增,按 user 过滤避免把
// 其他用户的写入进度暴露给本用户。
func (s *Store) currentCursor(userID int64) (int64, error) {
	var cursor int64
	err := s.db.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM sync_changes WHERE user_id = ?`,
		userID,
	).Scan(&cursor)
	return cursor, err
}

// bookCursor 返回指定书在该用户的 max seq。bookUid 拉取模式下返回的游标仅对
// 该书有效,不得用作全量增量拉取的起点。
func (s *Store) bookCursor(userID int64, bookUID string) (int64, error) {
	var cursor int64
	err := s.db.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) FROM sync_changes WHERE user_id = ? AND book_uid = ?`,
		userID, bookUID,
	).Scan(&cursor)
	return cursor, err
}

// pullByBook 返回指定书的记录(不受 after 限制,用于打开图书时按需拉取)。
func (s *Store) pullByBook(userID int64, bookUID string) ([]ProgressItem, error) {
	rows, err := s.db.Query(
		`SELECT book_uid, locator, progression, updated_at, last_read_at, device_id
		 FROM progress_sync WHERE user_id = ? AND book_uid = ?`, userID, bookUID,
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

// ActivityEvent 管理页活动日志条目,仅存内存(ring buffer),重启即清空。
type ActivityEvent struct {
	TS     int64  `json:"ts"`
	Type   string `json:"type"`
	User   string `json:"user"`
	Detail string `json:"detail"`
}

const activityCap = 400

type Server struct {
	cfg           Config
	store         *Store
	adminMu       sync.Mutex
	adminSessions map[string]time.Time

	actMu    sync.Mutex
	activity []ActivityEvent

	// updateMu 串行化热更新与回滚:并发上传/回滚会交错写同一 .upload 临时路径
	// 并可能并发 exec 替换进程。
	updateMu sync.Mutex

	// execHook 热更新时替换当前进程;测试可注入空实现。
	execHook func(path string) error
}

// recordActivity 追加一条活动记录,超过上限丢最旧的。
func (s *Server) recordActivity(typ, user, detail string) {
	s.actMu.Lock()
	defer s.actMu.Unlock()
	s.activity = append(s.activity, ActivityEvent{
		TS: time.Now().UnixMilli(), Type: typ, User: user, Detail: detail,
	})
	if len(s.activity) > activityCap {
		s.activity = s.activity[len(s.activity)-activityCap:]
	}
}

// recentActivity 返回最新的 n 条活动(新→旧)。
func (s *Server) recentActivity(n int) []ActivityEvent {
	s.actMu.Lock()
	defer s.actMu.Unlock()
	out := make([]ActivityEvent, 0, n)
	for i := len(s.activity) - 1; i >= 0 && len(out) < n; i-- {
		out = append(out, s.activity[i])
	}
	return out
}

// userAuth 校验 Bearer 用户 token,通过后把用户传入 handler。
func (s *Server) userAuth(next func(http.ResponseWriter, *http.Request, User)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		token, ok := strings.CutPrefix(auth, "Bearer ")
		if !ok || token == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		user, valid := s.store.userByToken(token)
		if !valid {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		s.store.touchUser(user.ID, time.Now().UnixMilli())
		next(w, r, user)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handlePush(w http.ResponseWriter, r *http.Request, user User) {
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
	if err := touchDeviceTx(tx, user.ID, body.DeviceID, time.Now().UnixMilli()); err != nil {
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
		itemChanged, err := s.store.applyItemTx(tx, user.ID, item)
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
	s.recordActivity("sync.push", user.Name,
		fmt.Sprintf("推送 %d 条进度,变化 %d · %s", accepted, changed, body.DeviceID))
	writeJSON(w, http.StatusOK, map[string]int{
		"accepted": accepted,
		"changed":  changed,
	})
}

func (s *Server) handlePull(w http.ResponseWriter, r *http.Request, user User) {
	q := r.URL.Query()
	deviceID := q.Get("deviceId")
	if deviceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "deviceId required"})
		return
	}
	now := time.Now().UnixMilli()
	_ = s.store.touchDevice(user.ID, deviceID, now) // 拉取也计入设备活跃

	var items []ProgressItem
	var err error
	var cursor int64
	if bookUID := q.Get("bookUid"); bookUID != "" {
		items, err = s.store.pullByBook(user.ID, bookUID)
		if err == nil {
			// 注意:bookUid 模式返回的游标只对该书有效,不能作为全量增量拉取起点。
			cursor, err = s.store.bookCursor(user.ID, bookUID)
		}
	} else {
		if raw := q.Get("cursor"); raw != "" {
			after, perr := strconv.ParseInt(raw, 10, 64)
			if perr != nil || after < 0 {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid cursor"})
				return
			}
			items, cursor, err = s.store.pullByCursor(user.ID, after)
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
			items, err = s.store.pullIncremental(user.ID, after)
			cursor, _ = s.store.currentCursor(user.ID)
		}
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if len(items) > 0 { // 空拉取(无新变化)是常态轮询,不记日志
		s.recordActivity("sync.pull", user.Name,
			fmt.Sprintf("拉取 %d 条进度 · %s", len(items), deviceID))
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

// NewServer 打开存储并返回可用服务实例。
func NewServer(cfg Config) (*Server, error) {
	if cfg.BookVaultMaxFileMB <= 0 {
		cfg.BookVaultMaxFileMB = defaultConfig().BookVaultMaxFileMB
	}
	if cfg.UpdatePath == "" {
		cfg.UpdatePath = defaultUpdatePath()
	}
	store, err := openStore(cfg.DBPath, cfg.LegacyToken)
	if err != nil {
		return nil, err
	}
	return &Server{
		cfg:           cfg,
		store:         store,
		adminSessions: map[string]time.Time{},
		execHook:      execIntoSelf,
	}, nil
}

// routes 组装全部路由,main 与测试共用。
func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("POST /api/sync/push", s.userAuth(s.handlePush))
	mux.HandleFunc("GET /api/sync/pull", s.userAuth(s.handlePull))
	mux.HandleFunc("POST /api/v2/sync/{entity}/push", s.userAuth(s.handleEntityPush))
	mux.HandleFunc("GET /api/v2/sync/{entity}/pull", s.userAuth(s.handleEntityPull))
	mux.HandleFunc("GET /api/library/manifest", s.userAuth(s.handleLibraryManifest))
	mux.HandleFunc("POST /api/library/announce", s.userAuth(s.handleLibraryAnnounce))
	mux.HandleFunc("PUT /api/books/{uid}/file", s.userAuth(s.handleBookFilePut))
	mux.HandleFunc("GET /api/books/{uid}/file", s.userAuth(s.handleBookFileGet))
	mux.HandleFunc("GET /api/books/{uid}/cover", s.userAuth(s.handleBookCoverGet))
	mux.HandleFunc("DELETE /api/library/{uid}", s.userAuth(s.handleLibraryDelete))
	s.registerAdmin(mux)
	return mux
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
	srv, err := NewServer(cfg)
	if err != nil {
		log.Fatalf("db error: %v", err)
	}

	// 健康启动:若运行的是热更新二进制,清空崩溃计数(bootstrap 据此判定
	// 更新版本是否反复崩溃并回退)。仅当 env 由 bootstrap 注入时清理,避免
	// 测试/本地直接运行时误删。
	if os.Getenv("SYNC_UPDATED_BIN") != "" {
		clearCrashState(srv.cfg.UpdatePath)
	}

	// 启动时先清一次,再走每日定时。
	if removed, err := srv.store.cleanupInactiveDevices(cfg.DeviceInactiveDays, time.Now().UnixMilli()); err == nil && removed > 0 {
		log.Printf("[cleanup] removed %d inactive device(s) at startup", removed)
	}
	go srv.runDailyCleanup()

	log.Printf("sync-server listening on :%d (db=%s, admin page at /admin)", cfg.Port, cfg.DBPath)
	if err := http.ListenAndServe(":"+strconv.Itoa(cfg.Port), srv.routes()); err != nil {
		log.Fatal(err)
	}
}
