package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"
)

func newTestServer(t *testing.T) (*Server, int64) {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "test.db")
	srv, err := NewServer(Config{
		LegacyToken: "test-token",
		Port:        8080,
		DBPath:      dbPath,
	})
	if err != nil {
		t.Fatalf("NewServer: %v", err)
	}
	t.Cleanup(func() { srv.store.db.Close() })
	return srv, 1
}

func item(uid string, updatedAt int64, progression float64) ProgressItem {
	return ProgressItem{
		BookUID:     uid,
		Locator:     `{"href":"chap.xhtml"}`,
		Progression: progression,
		UpdatedAt:   updatedAt,
		DeviceID:    "dev1",
	}
}

// doAPI 通过真实路由发请求(支持 {uid} 路径参数)。
func doAPI(t *testing.T, srv *Server, method, path, token string, body any) *httptest.ResponseRecorder {
	t.Helper()
	req := newRequest(t, method, path, token, body)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	return rec
}

func newRequest(t *testing.T, method, path, token string, body any) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	switch b := body.(type) {
	case nil:
	case string:
		buf.WriteString(b) // 原始文本体
	case []byte:
		buf.Write(b) // 原始字节体(文件/二进制上传测试用)
	default:
		_ = json.NewEncoder(&buf).Encode(b)
	}
	req := httptest.NewRequest(method, path, &buf)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	return req
}

func TestAuthRejectsMissingToken(t *testing.T) {
	srv, _ := newTestServer(t)
	rec := doAPI(t, srv, "POST", "/api/sync/push", "", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d", rec.Code)
	}
}

func TestUnknownTokenRejected(t *testing.T) {
	srv, _ := newTestServer(t)
	rec := doAPI(t, srv, "GET", "/api/sync/pull?deviceId=dev1", "no-such-token", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401 for unknown token, got %d", rec.Code)
	}
}

func TestPushPullRoundTrip(t *testing.T) {
	srv, _ := newTestServer(t)
	pushBody := map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.42)},
	}
	rec := doAPI(t, srv, "POST", "/api/sync/push", "test-token", pushBody)
	if rec.Code != http.StatusOK {
		t.Fatalf("push: want 200, got %d: %s", rec.Code, rec.Body.String())
	}

	rec = doAPI(t, srv, "GET", "/api/sync/pull?deviceId=dev1&after=1970-01-01T00:00:00Z", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("pull: want 200, got %d", rec.Code)
	}
	var result PullResult
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(result.Items) != 1 || result.Items[0].BookUID != "book-a" || result.Items[0].Progression != 0.42 {
		t.Fatalf("unexpected pull result: %+v", result.Items)
	}
}

func TestUsersAreIsolated(t *testing.T) {
	srv, uid := newTestServer(t)
	other, err := srv.store.createUser("other", "other-token", time.Now().UnixMilli())
	if err != nil {
		t.Fatal(err)
	}

	push := func(token string) *httptest.ResponseRecorder {
		return doAPI(t, srv, "POST", "/api/sync/push", token, map[string]any{
			"deviceId": "dev1",
			"items":    []ProgressItem{item("book-a", 100, 0.5)},
		})
	}
	if rec := push("test-token"); rec.Code != http.StatusOK {
		t.Fatalf("user1 push failed: %s", rec.Body.String())
	}
	if rec := push("other-token"); rec.Code != http.StatusOK {
		t.Fatalf("user2 push failed: %s", rec.Body.String())
	}

	// 各自只能看到自己的书。
	items, err := srv.store.pullByBook(uid, "book-a")
	if err != nil || len(items) != 1 {
		t.Fatalf("user1 should see book-a: %v %v", items, err)
	}
	items, err = srv.store.pullByBook(other.ID, "book-a")
	if err != nil || len(items) != 1 {
		t.Fatalf("user2 should see its own book-a: %v %v", items, err)
	}

	// 删除 user2 不影响 user1。
	if err := srv.store.deleteUser(other.ID); err != nil {
		t.Fatal(err)
	}
	if _, ok := srv.store.userByToken("other-token"); ok {
		t.Fatal("deleted user token must be rejected")
	}
	items, err = srv.store.pullByBook(uid, "book-a")
	if err != nil || len(items) != 1 {
		t.Fatalf("user1 data must survive user2 deletion: %v %v", items, err)
	}
}

func TestArrivalOrderWins(t *testing.T) {
	srv, uid := newTestServer(t)
	// 旧的先写入
	rec := doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.1)},
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("first push failed: %d", rec.Code)
	}
	// 旧 updatedAt 重推不覆盖
	doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.99)},
	})
	// 新 updatedAt 覆盖
	rec = doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000009000, 0.9)},
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("newer push failed: %d", rec.Code)
	}

	items, err := srv.store.pullByBook(uid, "book-a")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].UpdatedAt != 1725000009000 || items[0].Progression != 0.9 {
		t.Fatalf("want newest record, got %+v", items)
	}
	// 即使客户端时间更旧,后到达的内容仍然胜出。
	rec = doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1, 0.2)},
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("older timestamp push failed: %d", rec.Code)
	}
	items, err = srv.store.pullByBook(uid, "book-a")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].UpdatedAt != 1 || items[0].Progression != 0.2 {
		t.Fatalf("want arrival-order record, got %+v", items)
	}
}

func TestPushSameContentIsIdempotent(t *testing.T) {
	srv, _ := newTestServer(t)
	body := map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 100, 0.4)},
	}
	rec := doAPI(t, srv, "POST", "/api/sync/push", "test-token", body)
	if rec.Code != http.StatusOK {
		t.Fatalf("first push failed: %d", rec.Code)
	}
	body["items"] = []ProgressItem{item("book-a", 1, 0.4)}
	rec = doAPI(t, srv, "POST", "/api/sync/push", "test-token", body)
	if rec.Code != http.StatusOK {
		t.Fatalf("repeat push failed: %d", rec.Code)
	}
	var result map[string]int
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatalf("unmarshal push response: %v", err)
	}
	if result["accepted"] != 1 || result["changed"] != 0 {
		t.Fatalf("want accepted=1 changed=0, got %+v", result)
	}
	var changes int
	if err := srv.store.db.QueryRow(`SELECT COUNT(*) FROM sync_changes`).Scan(&changes); err != nil {
		t.Fatal(err)
	}
	if changes != 1 {
		t.Fatalf("same content should create one change, got %d", changes)
	}
}

func TestCursorPullIgnoresClientTime(t *testing.T) {
	srv, _ := newTestServer(t)
	rec := doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 9999999999999, 0.1)},
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("first push failed: %d", rec.Code)
	}
	rec = doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev2",
		"items":    []ProgressItem{item("book-b", 1, 0.2)},
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("second push failed: %d", rec.Code)
	}

	rec = doAPI(t, srv, "GET", "/api/sync/pull?deviceId=dev1&cursor=1", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("cursor pull failed: %d", rec.Code)
	}
	var result PullResult
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatalf("unmarshal cursor pull: %v", err)
	}
	if result.Cursor != 2 || len(result.Items) != 1 || result.Items[0].BookUID != "book-b" {
		t.Fatalf("unexpected cursor result: cursor=%d items=%+v", result.Cursor, result.Items)
	}
}

func TestLegacyDatabaseMigrationBackfillsCursorChanges(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "legacy.db")
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`
CREATE TABLE progress_sync (
  book_uid TEXT PRIMARY KEY,
  locator TEXT NOT NULL,
  progression REAL NOT NULL,
  updated_at INTEGER NOT NULL,
  last_read_at INTEGER,
  device_id TEXT NOT NULL
);
INSERT INTO progress_sync (book_uid, locator, progression, updated_at, device_id)
VALUES ('book-a', '{"href":"chap.xhtml"}', 0.3, 100, 'dev1');
`)
	if err != nil {
		db.Close()
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	srv, err := NewServer(Config{LegacyToken: "test-token", DBPath: dbPath})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { srv.store.db.Close() })
	items, cursor, err := srv.store.pullByCursor(1, 0)
	if err != nil {
		t.Fatal(err)
	}
	if cursor != 1 || len(items) != 1 || items[0].BookUID != "book-a" {
		t.Fatalf("unexpected migrated changes: cursor=%d items=%+v", cursor, items)
	}
}

func TestPullIncrementalFiltersByAfter(t *testing.T) {
	srv, uid := newTestServer(t)
	doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items": []ProgressItem{
			item("book-a", 1725000000000, 0.1),
			item("book-b", 1725000010000, 0.2),
		},
	})
	// after 卡在两条之间:只应返回 book-b
	items, err := srv.store.pullIncremental(uid, 1725000005000)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].BookUID != "book-b" {
		t.Fatalf("want only book-b, got %+v", items)
	}
}

func TestCleanupInactiveDevices(t *testing.T) {
	srv, uid := newTestServer(t)
	doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.1)},
	})
	now := time.Now().UnixMilli()
	// 把 last_seen 改到 200 天前
	if _, err := srv.store.db.Exec(`UPDATE sync_devices SET last_seen_at = ?`, now-200*24*3600*1000); err != nil {
		t.Fatal(err)
	}
	removed, err := srv.store.cleanupInactiveDevices(180, now)
	if err != nil {
		t.Fatal(err)
	}
	if removed != 1 {
		t.Fatalf("want 1 removed, got %d", removed)
	}
	// 清理后再 touch 重新注册
	if err := srv.store.touchDevice(uid, "dev1", now); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := srv.store.db.QueryRow(`SELECT COUNT(*) FROM sync_devices`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("device should re-register, count=%d", count)
	}
}
