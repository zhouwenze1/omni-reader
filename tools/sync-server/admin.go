package main

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// ---- 管理员网页与 API:登录 → 概览/用户/图书/活动/系统 五个分区 ----

const adminSessionCookie = "admin_session"

func (s *Server) registerAdmin(mux *http.ServeMux) {
	mux.HandleFunc("GET /admin", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(adminPageHTML))
	})
	mux.HandleFunc("POST /admin/api/login", s.handleAdminLogin)
	mux.HandleFunc("POST /admin/api/logout", s.handleAdminLogout)
	mux.HandleFunc("GET /admin/api/overview", s.adminGuard(s.handleAdminOverview))
	mux.HandleFunc("GET /admin/api/users", s.adminGuard(s.handleAdminListUsers))
	mux.HandleFunc("POST /admin/api/users", s.adminGuard(s.handleAdminCreateUser))
	mux.HandleFunc("PATCH /admin/api/users/{id}", s.adminGuard(s.handleAdminPatchUser))
	mux.HandleFunc("POST /admin/api/users/{id}/token", s.adminGuard(s.handleAdminResetToken))
	mux.HandleFunc("DELETE /admin/api/users/{id}", s.adminGuard(s.handleAdminDeleteUser))
	mux.HandleFunc("GET /admin/api/users/{id}/books", s.adminGuard(s.handleAdminUserBooks))
	mux.HandleFunc("GET /admin/api/users/{id}/books/{uid}/cover", s.adminGuard(s.handleAdminBookCover))
	mux.HandleFunc("DELETE /admin/api/users/{id}/books/{uid}", s.adminGuard(s.handleAdminDeleteUserBook))
	mux.HandleFunc("GET /admin/api/users/{id}/devices", s.adminGuard(s.handleAdminUserDevices))
	mux.HandleFunc("DELETE /admin/api/users/{id}/devices/{deviceID}", s.adminGuard(s.handleAdminDeleteUserDevice))
	mux.HandleFunc("GET /admin/api/books", s.adminGuard(s.handleAdminAllBooks))
	mux.HandleFunc("GET /admin/api/activity", s.adminGuard(s.handleAdminActivity))
	mux.HandleFunc("POST /admin/api/activity/clear", s.adminGuard(s.handleAdminActivityClear))
	mux.HandleFunc("POST /admin/api/maintenance/cleanup", s.adminGuard(s.handleAdminCleanup))
	mux.HandleFunc("POST /admin/api/maintenance/vacuum", s.adminGuard(s.handleAdminVacuum))
	mux.HandleFunc("GET /admin/api/version", s.adminGuard(s.handleAdminVersion))
	mux.HandleFunc("POST /admin/api/update", s.adminGuard(s.handleAdminUpdate))
	mux.HandleFunc("POST /admin/api/update/rollback", s.adminGuard(s.handleAdminUpdateRollback))
}

// adminGuard 校验管理员会话 cookie。
func (s *Server) adminGuard(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie(adminSessionCookie)
		if err != nil || !s.validSession(cookie.Value) {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "admin login required"})
			return
		}
		next(w, r)
	}
}

func (s *Server) validSession(token string) bool {
	s.adminMu.Lock()
	defer s.adminMu.Unlock()
	expiry, ok := s.adminSessions[token]
	if !ok {
		return false
	}
	if time.Now().After(expiry) {
		delete(s.adminSessions, token)
		return false
	}
	return true
}

func newSessionToken() string {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		panic(err) // crypto/rand 不可用属致命环境问题
	}
	return hex.EncodeToString(buf)
}

func (s *Server) handleAdminLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if body.Password != s.cfg.AdminPassword {
		time.Sleep(time.Second) // 降低爆破效率
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "wrong password"})
		return
	}
	token := newSessionToken()
	s.adminMu.Lock()
	s.adminSessions[token] = time.Now().Add(7 * 24 * time.Hour)
	s.adminMu.Unlock()
	s.recordActivity("admin.login", "admin", "管理员登录成功")
	http.SetCookie(w, &http.Cookie{
		Name: adminSessionCookie, Value: token, Path: "/",
		HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: 7 * 24 * 3600,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleAdminLogout(w http.ResponseWriter, r *http.Request) {
	if cookie, err := r.Cookie(adminSessionCookie); err == nil {
		s.adminMu.Lock()
		delete(s.adminSessions, cookie.Value)
		s.adminMu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{
		Name: adminSessionCookie, Value: "", Path: "/", MaxAge: -1,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ---- 用户管理 ----

type adminUserView struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	Token      string `json:"token"`
	CreatedAt  int64  `json:"createdAt"`
	LastSeenAt *int64 `json:"lastSeenAt"`
	Enabled    bool   `json:"enabled"`
	Books      int    `json:"books"`
	Devices    int    `json:"devices"`
	VaultBytes int64  `json:"vaultBytes"`
}

func (s *Server) buildUserViews() ([]adminUserView, int, int64) {
	users, err := s.store.listUsers()
	if err != nil {
		return nil, 0, 0
	}
	views := make([]adminUserView, 0, len(users))
	var totalBooks int
	var totalBytes int64
	for _, u := range users {
		view := adminUserView{
			ID: u.ID, Name: u.Name, Token: u.Token,
			CreatedAt: u.CreatedAt, LastSeenAt: u.LastSeenAt, Enabled: u.Enabled,
		}
		view.Books, _ = s.store.countUserBooks(u.ID)
		view.Devices, _ = s.store.countUserDevices(u.ID)
		view.VaultBytes = dirSize(s.store.userVaultDir(u.ID))
		totalBooks += view.Books
		totalBytes += view.VaultBytes
		views = append(views, view)
	}
	return views, totalBooks, totalBytes
}

func (s *Server) handleAdminListUsers(w http.ResponseWriter, r *http.Request) {
	views, totalBooks, totalBytes := s.buildUserViews()
	writeJSON(w, http.StatusOK, map[string]any{
		"users": views,
		"totals": map[string]any{
			"users": len(views), "books": totalBooks, "vaultBytes": totalBytes,
		},
	})
}

func dirSize(path string) int64 {
	var total int64
	_ = filepath.WalkDir(path, func(_ string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if info, infoErr := entry.Info(); infoErr == nil && !info.IsDir() {
			total += info.Size()
		}
		return nil
	})
	return total
}

func fileSize(path string) int64 {
	info, err := os.Stat(path)
	if err != nil {
		return 0
	}
	return info.Size()
}

func humanBytes(n int64) string {
	const unit = 1024
	if n < unit {
		return strconv.FormatInt(n, 10) + " B"
	}
	div, exp := int64(unit), 0
	for m := n / unit; m >= unit; m /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(n)/float64(div), "KMGTPE"[exp])
}

func shortUID(uid string) string {
	if len(uid) > 12 {
		return uid[:12] + "…"
	}
	return uid
}

func (s *Server) handleAdminCreateUser(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name required"})
		return
	}
	user, err := s.store.createUser(name, newSessionToken(), time.Now().UnixMilli())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("admin.user.create", "admin", "创建用户 "+name+" 并生成 token")
	writeJSON(w, http.StatusOK, adminUserView{
		ID: user.ID, Name: user.Name, Token: user.Token,
		CreatedAt: user.CreatedAt, Enabled: true,
	})
}

// handleAdminPatchUser 改名 / 启用 / 禁用。
func (s *Server) handleAdminPatchUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	var body struct {
		Name    *string `json:"name"`
		Enabled *bool   `json:"enabled"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	user, err := s.store.getUserByID(id)
	if err == sql.ErrNoRows {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if body.Name != nil {
		name := strings.TrimSpace(*body.Name)
		if name == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name required"})
			return
		}
		if err := s.store.renameUser(id, name); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		s.recordActivity("admin.user.rename", "admin", "用户 "+user.Name+" 改名为 "+name)
		user.Name = name
	}
	if body.Enabled != nil {
		if err := s.store.setUserEnabled(id, *body.Enabled); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		if *body.Enabled {
			s.recordActivity("admin.user.enable", "admin", "启用用户 "+user.Name)
		} else {
			s.recordActivity("admin.user.disable", "admin", "禁用用户 "+user.Name+"(token 立即失效)")
		}
		user.Enabled = *body.Enabled
	}
	view := adminUserView{
		ID: user.ID, Name: user.Name, Token: user.Token,
		CreatedAt: user.CreatedAt, LastSeenAt: user.LastSeenAt, Enabled: user.Enabled,
	}
	view.Books, _ = s.store.countUserBooks(id)
	view.Devices, _ = s.store.countUserDevices(id)
	view.VaultBytes = dirSize(s.store.userVaultDir(id))
	writeJSON(w, http.StatusOK, view)
}

// handleAdminResetToken 重新生成 token,旧 token 立即失效。
func (s *Server) handleAdminResetToken(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	user, err := s.store.getUserByID(id)
	if err == sql.ErrNoRows {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	token := newSessionToken()
	if err := s.store.resetUserToken(id, token); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("admin.user.token", "admin", "重置用户 "+user.Name+" 的 token(旧 token 失效)")
	writeJSON(w, http.StatusOK, map[string]string{"token": token})
}

func (s *Server) handleAdminDeleteUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	user, err := s.store.getUserByID(id)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if err := s.store.deleteUser(id); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	_ = os.RemoveAll(s.store.userVaultDir(id))
	s.recordActivity("admin.user.delete", "admin", "删除用户 "+user.Name+" 及其全部数据")
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ---- 图书管理 ----

type adminBookView struct {
	BookUID    string `json:"bookUid"`
	Title      string `json:"title"`
	Format     string `json:"format"`
	SizeBytes  int64  `json:"sizeBytes"`
	ImportedAt int64  `json:"importedAt"`
	UpdatedAt  int64  `json:"updatedAt"`
	CoverExt   string `json:"coverExt,omitempty"`
	Deleted    bool   `json:"deleted"`
}

func (s *Server) handleAdminUserBooks(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || userID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	entries, err := s.store.listManifest(userID, 0)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	books := make([]adminBookView, 0, len(entries))
	for _, e := range entries {
		books = append(books, adminBookView{
			BookUID:    e.BookUID,
			Title:      e.Title,
			Format:     e.Format,
			SizeBytes:  e.SizeBytes,
			ImportedAt: e.ImportedAt,
			UpdatedAt:  e.UpdatedAt,
			CoverExt:   e.CoverExt,
			Deleted:    e.DeletedAt != nil,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"books": books})
}

func (s *Server) handleAdminDeleteUserBook(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || userID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	if err := s.store.markLibraryDeleted(userID, bookUID, time.Now().UnixMilli()); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if err := os.RemoveAll(s.store.bookVaultDir(userID, bookUID)); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("admin.book.delete", "admin", "删除云端书 "+shortUID(bookUID))
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// handleAdminBookCover 管理端封面缩略图(供书库表格展示)。
func (s *Server) handleAdminBookCover(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || userID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	coverExt, err := s.store.manifestCoverExt(userID, bookUID)
	if err != nil || coverExt == "" || !validFileExt(coverExt) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "cover not found"})
		return
	}
	path := filepath.Join(s.store.bookVaultDir(userID, bookUID), "cover."+coverExt)
	contentType := coverContentTypes[coverExt]
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	serveVaultFile(w, r, path, contentType)
}

type adminGlobalBookView struct {
	UserID     int64    `json:"userId"`
	UserName   string   `json:"userName"`
	BookUID    string   `json:"bookUid"`
	Title      string   `json:"title"`
	Authors    []string `json:"authors"`
	Format     string   `json:"format"`
	SizeBytes  int64    `json:"sizeBytes"`
	CoverExt   string   `json:"coverExt,omitempty"`
	ImportedAt int64    `json:"importedAt"`
	UpdatedAt  int64    `json:"updatedAt"`
	Deleted    bool     `json:"deleted"`
}

func (s *Store) listAllManifestEntries(includeDeleted bool, limit int) ([]adminGlobalBookView, error) {
	query := `SELECT m.user_id, u.name, m.book_uid, m.title, m.authors_json, m.format,
	                 m.size_bytes, m.cover_ext, m.imported_at, m.updated_at, m.deleted_at
	          FROM library_manifest m JOIN users u ON u.id = m.user_id`
	if !includeDeleted {
		query += ` WHERE m.deleted_at IS NULL`
	}
	query += ` ORDER BY m.updated_at DESC LIMIT ?`
	rows, err := s.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	books := make([]adminGlobalBookView, 0, limit)
	for rows.Next() {
		var b adminGlobalBookView
		var authorsJSON string
		var deletedAt *int64
		if err := rows.Scan(&b.UserID, &b.UserName, &b.BookUID, &b.Title, &authorsJSON,
			&b.Format, &b.SizeBytes, &b.CoverExt, &b.ImportedAt, &b.UpdatedAt, &deletedAt); err != nil {
			return nil, err
		}
		_ = json.Unmarshal([]byte(authorsJSON), &b.Authors)
		b.Deleted = deletedAt != nil
		books = append(books, b)
	}
	return books, rows.Err()
}

// handleAdminAllBooks 跨用户书库总表。
func (s *Server) handleAdminAllBooks(w http.ResponseWriter, r *http.Request) {
	limit := 200
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 && n <= 1000 {
			limit = n
		}
	}
	includeDeleted := r.URL.Query().Get("includeDeleted") == "1"
	books, err := s.store.listAllManifestEntries(includeDeleted, limit)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"books": books})
}

// ---- 设备管理 ----

func (s *Server) handleAdminUserDevices(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || userID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	devices, err := s.store.listUserDevices(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"devices": devices})
}

func (s *Server) handleAdminDeleteUserDevice(w http.ResponseWriter, r *http.Request) {
	userID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || userID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	deviceID := r.PathValue("deviceID")
	if deviceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid deviceId"})
		return
	}
	if err := s.store.deleteUserDevice(userID, deviceID); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("admin.device.delete", "admin", "移除设备 "+deviceID)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ---- 概览统计 ----

func (s *Server) activityCountsSince(sinceMs int64) map[string]int {
	s.actMu.Lock()
	defer s.actMu.Unlock()
	counts := map[string]int{}
	for _, e := range s.activity {
		if e.TS < sinceMs {
			continue
		}
		counts[e.Type]++
	}
	return counts
}

func (s *Server) handleAdminOverview(w http.ResponseWriter, r *http.Request) {
	var userTotal, userEnabled int64
	_ = s.store.db.QueryRow(`SELECT COUNT(*), COALESCE(SUM(enabled), 0) FROM users`).
		Scan(&userTotal, &userEnabled)
	var bookActive, bookDeleted int64
	_ = s.store.db.QueryRow(`SELECT COUNT(*), COALESCE(SUM(deleted_at IS NOT NULL), 0) FROM library_manifest`).
		Scan(&bookActive, &bookDeleted)
	var progressCount, changeCount, deviceCount int64
	_ = s.store.db.QueryRow(`SELECT COUNT(*) FROM progress_sync`).Scan(&progressCount)
	_ = s.store.db.QueryRow(`SELECT COUNT(*) FROM sync_changes`).Scan(&changeCount)
	_ = s.store.db.QueryRow(`SELECT COUNT(*) FROM sync_devices`).Scan(&deviceCount)

	dbBytes := fileSize(s.cfg.DBPath) + fileSize(s.cfg.DBPath+"-wal")
	vaultBytes := dirSize(s.store.vaultDir)
	views, _, totalVault := s.buildUserViews()
	_ = totalVault

	type topBook struct {
		BookUID   string `json:"bookUid"`
		Title     string `json:"title"`
		UserName  string `json:"userName"`
		SizeBytes int64  `json:"sizeBytes"`
	}
	topBooks := make([]topBook, 0, 8)
	rows, err := s.store.db.Query(
		`SELECT m.book_uid, m.title, m.size_bytes, u.name
		 FROM library_manifest m JOIN users u ON u.id = m.user_id
		 WHERE m.deleted_at IS NULL ORDER BY m.size_bytes DESC LIMIT 8`)
	if err == nil {
		for rows.Next() {
			var b topBook
			if err := rows.Scan(&b.BookUID, &b.Title, &b.SizeBytes, &b.UserName); err == nil {
				topBooks = append(topBooks, b)
			}
		}
		rows.Close()
	}

	todayStart := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day(),
		0, 0, 0, 0, time.Local).UnixMilli()
	counts := s.activityCountsSince(todayStart)

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	_, updateReady := os.Stat(s.cfg.UpdatePath)

	writeJSON(w, http.StatusOK, map[string]any{
		"totals": map[string]any{
			"users":         userTotal,
			"enabledUsers":  userEnabled,
			"books":         bookActive,
			"deletedBooks":  bookDeleted,
			"progressItems": progressCount,
			"changeLog":     changeCount,
			"devices":       deviceCount,
			"dbBytes":       dbBytes,
			"vaultBytes":    vaultBytes,
		},
		"runtime": map[string]any{
			"version":            serverVersion,
			"goVersion":          runtime.Version(),
			"os":                 runtime.GOOS,
			"arch":               runtime.GOARCH,
			"goroutines":         runtime.NumGoroutine(),
			"heapAlloc":          int64(mem.HeapAlloc),
			"sysBytes":           int64(mem.Sys),
			"startedAt":          startedAt.UnixMilli(),
			"uptimeMs":           time.Since(startedAt).Milliseconds(),
			"maxFileMB":          s.cfg.BookVaultMaxFileMB,
			"deviceInactiveDays": s.cfg.DeviceInactiveDays,
			"updateReady":        updateReady == nil,
		},
		"perUser":        views,
		"topBooks":       topBooks,
		"recentActivity": s.recentActivity(12),
		"today": map[string]any{
			"push": counts["sync.push"], "pull": counts["sync.pull"],
			"upload": counts["library.upload"], "download": counts["library.download"],
		},
	})
}

// ---- 活动日志 ----

func (s *Server) handleAdminActivity(w http.ResponseWriter, r *http.Request) {
	limit := 100
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 && n <= activityCap {
			limit = n
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"events":   s.recentActivity(limit),
		"capacity": activityCap,
	})
}

func (s *Server) handleAdminActivityClear(w http.ResponseWriter, r *http.Request) {
	s.actMu.Lock()
	s.activity = nil
	s.actMu.Unlock()
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ---- 运维:孤儿清理 / 数据库压缩 ----

type orphanTarget struct {
	path  string
	bytes int64
}

// scanVaultOrphans 找出 vault 里没有对应在架书目的目录;
// 1 小时宽限期避免误删"文件已传、announce 未到"的上传中的书。
func (s *Server) scanVaultOrphans() ([]orphanTarget, error) {
	users, err := s.store.listUsers()
	if err != nil {
		return nil, err
	}
	active := map[int64]map[string]bool{}
	for _, u := range users {
		set := map[string]bool{}
		entries, err := s.store.listManifest(u.ID, 0)
		if err != nil {
			return nil, err
		}
		for _, e := range entries {
			if e.DeletedAt == nil {
				set[e.BookUID] = true
			}
		}
		active[u.ID] = set
	}
	var targets []orphanTarget
	userDirs, err := os.ReadDir(s.store.vaultDir)
	if err != nil {
		return nil, err
	}
	for _, ud := range userDirs {
		if !ud.IsDir() {
			continue
		}
		userID, perr := strconv.ParseInt(ud.Name(), 10, 64)
		if perr != nil {
			continue // 非用户目录不碰
		}
		activeSet := active[userID]
		bookDirs, err := os.ReadDir(s.store.userVaultDir(userID))
		if err != nil {
			continue
		}
		for _, bd := range bookDirs {
			if !bd.IsDir() {
				continue
			}
			if activeSet[bd.Name()] {
				continue
			}
			if info, ierr := bd.Info(); ierr == nil && time.Since(info.ModTime()) < time.Hour {
				continue
			}
			full := filepath.Join(s.store.userVaultDir(userID), bd.Name())
			targets = append(targets, orphanTarget{path: full, bytes: dirSize(full)})
		}
	}
	return targets, nil
}

func (s *Server) handleAdminCleanup(w http.ResponseWriter, r *http.Request) {
	targets, err := s.scanVaultOrphans()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	var freed int64
	for _, t := range targets {
		if err := os.RemoveAll(t.path); err == nil {
			freed += t.bytes
		}
	}
	s.recordActivity("admin.maintenance", "admin",
		fmt.Sprintf("清理孤儿书目录 %d 个,释放 %s", len(targets), humanBytes(freed)))
	writeJSON(w, http.StatusOK, map[string]any{
		"removed": len(targets), "freedBytes": freed,
	})
}

func (s *Server) handleAdminVacuum(w http.ResponseWriter, r *http.Request) {
	before := fileSize(s.cfg.DBPath)
	if err := s.store.vacuum(); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	after := fileSize(s.cfg.DBPath)
	s.recordActivity("admin.maintenance", "admin",
		fmt.Sprintf("VACUUM 数据库: %s → %s", humanBytes(before), humanBytes(after)))
	writeJSON(w, http.StatusOK, map[string]any{
		"beforeBytes": before, "afterBytes": after,
	})
}

// ---- 版本 / 热更新 ----

func (s *Server) handleAdminVersion(w http.ResponseWriter, r *http.Request) {
	_, diskUpdated := os.Stat(s.cfg.UpdatePath)
	writeJSON(w, http.StatusOK, map[string]any{
		"version":     serverVersion,
		"startedAt":   startedAt.UnixMilli(),
		"updateReady": diskUpdated == nil,
	})
}

// handleAdminUpdate 接收新版本二进制:校验大小/可选 sha256/ELF 魔数,
// 原子落盘到 cfg.UpdatePath 后自替换进程;容器重启由 bootstrap 保持新版本。
func (s *Server) handleAdminUpdate(w http.ResponseWriter, r *http.Request) {
	if s.cfg.UpdatePath == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "update not configured"})
		return
	}
	s.updateMu.Lock()
	defer s.updateMu.Unlock()

	maxBytes := int64(256) << 20
	if r.ContentLength > maxBytes {
		writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{"error": "too large"})
		return
	}
	tmp := s.cfg.UpdatePath + ".upload"
	body := http.MaxBytesReader(w, r.Body, maxBytes)
	f, err := os.Create(tmp)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	hasher := sha256.New()
	size, copyErr := io.Copy(io.MultiWriter(f, hasher), body)
	if closeErr := f.Close(); copyErr == nil {
		copyErr = closeErr
	}
	if copyErr != nil {
		_ = os.Remove(tmp)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": copyErr.Error()})
		return
	}
	// 可选 sha256 校验:提供时强制匹配,防止传错文件。
	if expected := r.URL.Query().Get("sha256"); expected != "" {
		if !strings.EqualFold(hex.EncodeToString(hasher.Sum(nil)), expected) {
			_ = os.Remove(tmp)
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "sha256 mismatch"})
			return
		}
	}
	// ELF 魔数检查,防止误传配置/文档导致重启后起不来。
	magic := make([]byte, 4)
	mf, err := os.Open(tmp)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	_, readErr := mf.Read(magic)
	_ = mf.Close()
	if readErr != nil || magic[0] != 0x7f || magic[1] != 'E' || magic[2] != 'L' || magic[3] != 'F' {
		_ = os.Remove(tmp)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "not a linux ELF binary"})
		return
	}
	// exec 需要可执行位;os.Create 默认 0666。
	if err := os.Chmod(tmp, 0o755); err != nil {
		_ = os.Remove(tmp)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if err := os.Rename(tmp, s.cfg.UpdatePath); err != nil {
		_ = os.Remove(tmp)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	log.Printf("[update] new binary installed at %s (%d bytes), restarting", s.cfg.UpdatePath, size)
	s.recordActivity("admin.update", "admin",
		fmt.Sprintf("上传新版本(%s)并重启", humanBytes(size)))
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "sizeBytes": size, "restarting": true})
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	hook := s.execHook
	go func() {
		time.Sleep(500 * time.Millisecond) // 让响应先送达客户端
		if err := hook(s.cfg.UpdatePath); err != nil {
			log.Printf("[update] exec failed: %v", err)
		}
	}()
}

// handleAdminUpdateRollback 删除磁盘上的热更新版本并回到镜像内置版本。
// 与 handleAdminUpdate 互斥,避免与上传交错写临时文件/并发 exec。
func (s *Server) handleAdminUpdateRollback(w http.ResponseWriter, r *http.Request) {
	s.updateMu.Lock()
	defer s.updateMu.Unlock()
	_ = os.Remove(s.cfg.UpdatePath)
	_ = os.Remove(s.cfg.UpdatePath + ".upload")
	_ = os.Remove(s.cfg.UpdatePath + ".sha256")
	s.recordActivity("admin.update", "admin", "回滚到镜像内置版本并重启")
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "restarting": true})
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	hook := s.execHook
	go func() {
		time.Sleep(500 * time.Millisecond)
		if err := hook("/sync-server"); err != nil {
			log.Printf("[update] rollback exec failed: %v", err)
		}
	}()
}
