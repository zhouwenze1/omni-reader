package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"testing"
	"time"
)

func adminLogin(t *testing.T, srv *Server, password string) *httptest.ResponseRecorder {
	t.Helper()
	return doAPI(t, srv, "POST", "/admin/api/login", "", map[string]any{"password": password})
}

func sessionCookie(t *testing.T, rec *httptest.ResponseRecorder) *http.Cookie {
	t.Helper()
	for _, c := range rec.Result().Cookies() {
		if c.Name == adminSessionCookie {
			return c
		}
	}
	t.Fatal("missing session cookie")
	return nil
}

func TestAdminLoginRequiresPassword(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.AdminPassword = "pw"
	if rec := adminLogin(t, srv, "wrong"); rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d", rec.Code)
	}
	rec := adminLogin(t, srv, "pw")
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d", rec.Code)
	}
	if sessionCookie(t, rec).Value == "" {
		t.Fatal("login should set session cookie")
	}
}

func TestAdminAPIRequiresSession(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.AdminPassword = "pw"
	req := newRequest(t, "GET", "/admin/api/users", "", nil)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401 without session, got %d", rec.Code)
	}
}

func TestAdminCreateListDeleteUser(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.AdminPassword = "pw"
	cookie := sessionCookie(t, adminLogin(t, srv, "pw"))

	adminReq := func(method, path, body string) *httptest.ResponseRecorder {
		req := newRequest(t, method, path, "", body)
		req.AddCookie(cookie)
		rec := httptest.NewRecorder()
		srv.routes().ServeHTTP(rec, req)
		return rec
	}

	// 创建
	rec := adminReq("POST", "/admin/api/users", `{"name":"测试用户"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("create failed: %d %s", rec.Code, rec.Body.String())
	}
	var created struct {
		ID    int64  `json:"id"`
		Token string `json:"token"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	if created.Token == "" {
		t.Fatal("created user must return token")
	}

	// 新 token 立即可用于用户 API。
	pushRec := doAPI(t, srv, "POST", "/api/sync/push", created.Token, map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1, 0.1)},
	})
	if pushRec.Code != http.StatusOK {
		t.Fatalf("new token should work: %d", pushRec.Code)
	}

	// 列表
	rec = adminReq("GET", "/admin/api/users", "")
	var list struct {
		Users []adminUserView `json:"users"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Users) != 2 { // default + 新用户
		t.Fatalf("want 2 users, got %d", len(list.Users))
	}

	// 删除后 token 失效。
	rec = adminReq("DELETE", "/admin/api/users/"+strconv.FormatInt(created.ID, 10), "")
	if rec.Code != http.StatusOK {
		t.Fatalf("delete failed: %d", rec.Code)
	}
	if _, ok := srv.store.userByToken(created.Token); ok {
		t.Fatal("deleted user token must be rejected")
	}
}

func adminSessionFor(t *testing.T, srv *Server) *http.Cookie {
	t.Helper()
	srv.cfg.AdminPassword = "pw"
	rec := doAPI(t, srv, "POST", "/admin/api/login", "", map[string]any{"password": "pw"})
	for _, c := range rec.Result().Cookies() {
		if c.Name == adminSessionCookie {
			return c
		}
	}
	t.Fatal("missing session cookie")
	return nil
}

func TestAdminUserBooksListAndDelete(t *testing.T) {
	srv, uid := newTestServer(t)
	cookie := adminSessionFor(t, srv)

	if err := srv.store.upsertManifestEntry(uid, LibraryManifestEntry{
		BookUID: testBookUID, Fingerprint: "fp", Title: "书", Format: "epub",
		SizeBytes: 10, ImportedAt: 1, UpdatedAt: 2,
	}); err != nil {
		t.Fatal(err)
	}
	dir := srv.store.bookVaultDir(uid, testBookUID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}

	// 列表
	req := newRequest(t, "GET", "/admin/api/users/1/books", "", nil)
	req.AddCookie(cookie)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("books list failed: %d", rec.Code)
	}
	var list struct {
		Books []adminBookView `json:"books"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Books) != 1 || list.Books[0].Title != "书" {
		t.Fatalf("unexpected books: %+v", list.Books)
	}

	// 删除
	req = newRequest(t, "DELETE", "/admin/api/users/1/books/"+testBookUID, "", nil)
	req.AddCookie(cookie)
	rec = httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("book delete failed: %d", rec.Code)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("vault dir should be removed, err=%v", err)
	}
	entries, _ := srv.store.listManifest(uid, 0)
	if len(entries) != 1 || entries[0].DeletedAt == nil {
		t.Fatalf("book should be tombstoned: %+v", entries)
	}
}

func TestAdminUpdateRejectsNonElf(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.UpdatePath = filepath.Join(t.TempDir(), "sync-server")
	cookie := adminSessionFor(t, srv)
	called := false
	srv.execHook = func(path string) error { called = true; return nil }

	req := newRequest(t, "POST", "/admin/api/update", "", "this is not elf")
	req.AddCookie(cookie)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("want 400 for non-ELF, got %d", rec.Code)
	}
	if called {
		t.Fatal("must not restart on rejected upload")
	}
	if _, err := os.Stat(srv.cfg.UpdatePath + ".upload"); !os.IsNotExist(err) {
		t.Fatal("temp file must be cleaned up")
	}
}

func TestAdminUpdateAcceptsElf(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.UpdatePath = filepath.Join(t.TempDir(), "sync-server")
	cookie := adminSessionFor(t, srv)
	srv.execHook = func(path string) error { return nil }

	payload := append([]byte{0x7f, 'E', 'L', 'F'}, []byte("fake-binary")...)
	req := newRequest(t, "POST", "/admin/api/update", "", payload)
	req.AddCookie(cookie)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d %s", rec.Code, rec.Body.String())
	}
	if _, err := os.Stat(srv.cfg.UpdatePath); err != nil {
		t.Fatalf("update binary must be installed: %v", err)
	}
}

func TestAdminUpdateConcurrentSerialized(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.UpdatePath = filepath.Join(t.TempDir(), "sync-server")
	cookie := adminSessionFor(t, srv)
	var mu sync.Mutex
	execs := 0
	srv.execHook = func(path string) error { mu.Lock(); execs++; mu.Unlock(); return nil }

	elfA := append([]byte{0x7f, 'E', 'L', 'F'}, bytes.Repeat([]byte{'A'}, 4096)...)
	elfB := append([]byte{0x7f, 'E', 'L', 'F'}, bytes.Repeat([]byte{'B'}, 4096)...)
	var wg sync.WaitGroup
	for _, payload := range [][]byte{elfA, elfB} {
		wg.Add(1)
		go func(p []byte) {
			defer wg.Done()
			req := newRequest(t, "POST", "/admin/api/update", "", p)
			req.AddCookie(cookie)
			rec := httptest.NewRecorder()
			srv.routes().ServeHTTP(rec, req)
			if rec.Code != http.StatusOK {
				t.Errorf("concurrent update failed: %d %s", rec.Code, rec.Body.String())
			}
		}(payload)
	}
	wg.Wait()

	// 两个请求都成功(串行化),落盘文件必须是其中一份的完整内容而非交错。
	got, err := os.ReadFile(srv.cfg.UpdatePath)
	if err != nil {
		t.Fatalf("read installed binary: %v", err)
	}
	if !bytes.Equal(got, elfA) && !bytes.Equal(got, elfB) {
		t.Fatalf("installed file is torn/corrupt (%d bytes)", len(got))
	}
	// exec 钩子在响应 flush 后延迟 ~500ms 触发,轮询等待两个都执行完。
	deadline := time.Now().Add(2 * time.Second)
	for {
		mu.Lock()
		n := execs
		mu.Unlock()
		if n >= 2 || time.Now().After(deadline) {
			if n != 2 {
				t.Fatalf("want 2 restarts (one per successful update), got %d", n)
			}
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func TestAdminVersionEndpoint(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)
	req := newRequest(t, "GET", "/admin/api/version", "", nil)
	req.AddCookie(cookie)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("version failed: %d", rec.Code)
	}
	var v struct {
		Version     string `json:"version"`
		StartedAt   int64  `json:"startedAt"`
		UpdateReady bool   `json:"updateReady"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &v); err != nil {
		t.Fatal(err)
	}
	if v.Version == "" || v.StartedAt == 0 {
		t.Fatalf("unexpected version payload: %+v", v)
	}
}

func adminAPI(t *testing.T, srv *Server, cookie *http.Cookie, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := newRequest(t, method, path, "", body)
	if cookie != nil {
		req.AddCookie(cookie)
	}
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	return rec
}

func TestAdminPatchUserRenameAndDisable(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)

	rec := adminAPI(t, srv, cookie, "POST", "/admin/api/users", `{"name":"临时用户"}`)
	var created struct {
		ID    int64  `json:"id"`
		Token string `json:"token"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}

	// 改名
	rec = adminAPI(t, srv, cookie, "PATCH", "/admin/api/users/2", `{"name":"改名用户"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("rename failed: %d %s", rec.Code, rec.Body.String())
	}
	user, err := srv.store.getUserByID(created.ID)
	if err != nil || user.Name != "改名用户" {
		t.Fatalf("rename not applied: %+v %v", user, err)
	}

	// 禁用后原 token 立即失效
	rec = adminAPI(t, srv, cookie, "PATCH", "/admin/api/users/2", `{"enabled":false}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("disable failed: %d %s", rec.Code, rec.Body.String())
	}
	if _, ok := srv.store.userByToken(created.Token); ok {
		t.Fatal("disabled user token must be rejected")
	}

	// 空名字被拒绝
	rec = adminAPI(t, srv, cookie, "PATCH", "/admin/api/users/2", `{"name":"  "}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("empty rename should 400, got %d", rec.Code)
	}
}

func TestAdminResetToken(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)
	rec := adminAPI(t, srv, cookie, "POST", "/admin/api/users/1/token", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("reset failed: %d %s", rec.Code, rec.Body.String())
	}
	var result struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Token == "" || result.Token == "test-token" {
		t.Fatalf("want fresh token, got %q", result.Token)
	}
	// 新 token 可用,旧 token 失效。
	if _, ok := srv.store.userByToken(result.Token); !ok {
		t.Fatal("new token should authenticate")
	}
	if _, ok := srv.store.userByToken("test-token"); ok {
		t.Fatal("old token must be rejected after reset")
	}
}

func TestAdminOverviewAndActivity(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)

	// 产生同步活动 + 书目。
	if rec := doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev1",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.4)},
	}); rec.Code != http.StatusOK {
		t.Fatalf("push failed: %s", rec.Body.String())
	}
	if err := srv.store.upsertManifestEntry(1, LibraryManifestEntry{
		BookUID: testBookUID, Title: "大书", Format: "epub",
		SizeBytes: 1000, ImportedAt: 1, UpdatedAt: 2,
	}); err != nil {
		t.Fatal(err)
	}

	rec := adminAPI(t, srv, cookie, "GET", "/admin/api/overview", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("overview failed: %d %s", rec.Code, rec.Body.String())
	}
	var view struct {
		Totals   map[string]int64 `json:"totals"`
		Today    map[string]int   `json:"today"`
		Runtime  map[string]any   `json:"runtime"`
		PerUser  []adminUserView  `json:"perUser"`
		TopBooks []map[string]any `json:"topBooks"`
		Recent   []ActivityEvent  `json:"recentActivity"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &view); err != nil {
		t.Fatal(err)
	}
	if view.Totals["users"] != 1 || view.Totals["books"] != 1 || view.Totals["progressItems"] != 1 {
		t.Fatalf("unexpected totals: %+v", view.Totals)
	}
	if view.Today["push"] != 1 {
		t.Fatalf("today push should be 1, got %+v", view.Today)
	}
	if len(view.PerUser) != 1 || len(view.TopBooks) != 1 {
		t.Fatalf("unexpected overview lists: perUser=%d topBooks=%d", len(view.PerUser), len(view.TopBooks))
	}
	if view.Runtime["version"] == "" {
		t.Fatal("runtime.version missing")
	}

	// 活动日志:push 已被记录,且 admin 登录也在。
	rec = adminAPI(t, srv, cookie, "GET", "/admin/api/activity", "")
	var acts struct {
		Events   []ActivityEvent `json:"events"`
		Capacity int             `json:"capacity"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &acts); err != nil {
		t.Fatal(err)
	}
	if len(acts.Events) < 2 {
		t.Fatalf("want push + login events, got %+v", acts.Events)
	}
	found := map[string]bool{}
	for _, e := range acts.Events {
		found[e.Type] = true
	}
	if !found["sync.push"] || !found["admin.login"] {
		t.Fatalf("missing expected events: %v", found)
	}

	// 清空。
	rec = adminAPI(t, srv, cookie, "POST", "/admin/api/activity/clear", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("clear failed: %d", rec.Code)
	}
	rec = adminAPI(t, srv, cookie, "GET", "/admin/api/activity", "")
	acts = struct {
		Events   []ActivityEvent `json:"events"`
		Capacity int             `json:"capacity"`
	}{}
	if err := json.Unmarshal(rec.Body.Bytes(), &acts); err != nil {
		t.Fatal(err)
	}
	if len(acts.Events) != 0 {
		t.Fatalf("activity should be empty after clear, got %+v", acts.Events)
	}
}

func TestAdminAllBooksAndCover(t *testing.T) {
	srv, uid := newTestServer(t)
	cookie := adminSessionFor(t, srv)

	coverB64 := "aGVsbG8gcG5n" // 任意字节,仅回读校验
	if rec := doAPI(t, srv, "POST", "/api/library/announce", "test-token", map[string]any{
		"bookUid": testBookUID, "title": "云端书", "format": "epub",
		"sizeBytes": 123, "coverExt": "png", "coverBase64": coverB64,
		"importedAt": 5,
	}); rec.Code != http.StatusOK {
		t.Fatalf("announce failed: %s", rec.Body.String())
	}

	rec := adminAPI(t, srv, cookie, "GET", "/admin/api/books", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("books failed: %d %s", rec.Code, rec.Body.String())
	}
	var list struct {
		Books []adminGlobalBookView `json:"books"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Books) != 1 || list.Books[0].Title != "云端书" || list.Books[0].UserName != "default" {
		t.Fatalf("unexpected books: %+v", list.Books)
	}

	// 管理端封面。
	rec = adminAPI(t, srv, cookie, "GET", "/admin/api/users/1/books/"+testBookUID+"/cover", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("cover failed: %d", rec.Code)
	}
	if body := rec.Body.String(); body != "hello png" {
		t.Fatalf("unexpected cover body: %q", body)
	}

	// includeDeleted=1 才显示墓碑。
	if err := srv.store.markLibraryDeleted(uid, testBookUID, 99); err != nil {
		t.Fatal(err)
	}
	rec = adminAPI(t, srv, cookie, "GET", "/admin/api/books", "")
	list.Books = nil
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Books) != 0 {
		t.Fatal("deleted books should be hidden by default")
	}
	rec = adminAPI(t, srv, cookie, "GET", "/admin/api/books?includeDeleted=1", "")
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Books) != 1 || !list.Books[0].Deleted {
		t.Fatalf("tombstone should show with includeDeleted=1: %+v", list.Books)
	}
}

func TestAdminUserDevices(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)
	doAPI(t, srv, "POST", "/api/sync/push", "test-token", map[string]any{
		"deviceId": "dev-abc",
		"items":    []ProgressItem{item("book-a", 1725000000000, 0.4)},
	})

	rec := adminAPI(t, srv, cookie, "GET", "/admin/api/users/1/devices", "")
	var list struct {
		Devices []DeviceView `json:"devices"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Devices) != 1 || list.Devices[0].DeviceID != "dev-abc" || list.Devices[0].BooksSynced != 1 {
		t.Fatalf("unexpected devices: %+v", list.Devices)
	}

	rec = adminAPI(t, srv, cookie, "DELETE", "/admin/api/users/1/devices/dev-abc", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("device delete failed: %d", rec.Code)
	}
	var count int
	if err := srv.store.db.QueryRow(`SELECT COUNT(*) FROM sync_devices`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("device should be removed, count=%d", count)
	}
}

func TestAdminCleanupOrphans(t *testing.T) {
	srv, uid := newTestServer(t)
	cookie := adminSessionFor(t, srv)

	// 在架书目录:保留。
	live := srv.store.bookVaultDir(uid, testBookUID)
	if err := srv.store.upsertManifestEntry(uid, LibraryManifestEntry{
		BookUID: testBookUID, Title: "在架书", SizeBytes: 5, ImportedAt: 1, UpdatedAt: 2,
	}); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(live, 0o755); err != nil {
		t.Fatal(err)
	}

	// 孤儿目录(2 小时前):删除。
	orphan := filepath.Join(srv.store.userVaultDir(uid), "deadbeefdeadbeefdeadbeefdeadbeef")
	if err := os.MkdirAll(orphan, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := time.Now().Add(-2 * time.Hour)
	if err := os.Chtimes(orphan, stale, stale); err != nil {
		t.Fatal(err)
	}

	// 刚上传还没 announce 的目录(1 小时宽限内):保留。
	fresh := filepath.Join(srv.store.userVaultDir(uid), "cafecafecafecafecafecafecafe0001")
	if err := os.MkdirAll(fresh, 0o755); err != nil {
		t.Fatal(err)
	}

	rec := adminAPI(t, srv, cookie, "POST", "/admin/api/maintenance/cleanup", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("cleanup failed: %d %s", rec.Code, rec.Body.String())
	}
	var result struct {
		Removed int `json:"removed"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Removed != 1 {
		t.Fatalf("want 1 orphan removed, got %d", result.Removed)
	}
	if _, err := os.Stat(orphan); !os.IsNotExist(err) {
		t.Fatal("orphan dir should be removed")
	}
	if _, err := os.Stat(live); err != nil {
		t.Fatalf("live dir must survive: %v", err)
	}
	if _, err := os.Stat(fresh); err != nil {
		t.Fatalf("fresh dir must survive grace window: %v", err)
	}
}

func TestAdminVacuum(t *testing.T) {
	srv, _ := newTestServer(t)
	cookie := adminSessionFor(t, srv)
	rec := adminAPI(t, srv, cookie, "POST", "/admin/api/maintenance/vacuum", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("vacuum failed: %d %s", rec.Code, rec.Body.String())
	}
	var result struct {
		BeforeBytes int64 `json:"beforeBytes"`
		AfterBytes  int64 `json:"afterBytes"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.BeforeBytes <= 0 || result.AfterBytes <= 0 {
		t.Fatalf("unexpected vacuum sizes: %+v", result)
	}
}
