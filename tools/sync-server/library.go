package main

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// ---- 书库云备份:书单(manifest)与原始文件仓库(vault),按用户隔离 ----

type LibraryManifestEntry struct {
	BookUID     string `json:"bookUid"`
	Fingerprint string `json:"fingerprint"`
	Title       string `json:"title"`
	AuthorsJSON string `json:"authorsJson"`
	Format      string `json:"format"`
	SizeBytes   int64  `json:"sizeBytes"`
	CoverExt    string `json:"coverExt,omitempty"`
	ImportedAt  int64  `json:"importedAt"`
	UpdatedAt   int64  `json:"updatedAt"`
	DeletedAt   *int64 `json:"deletedAt,omitempty"`
}

var (
	bookUIDPattern = regexp.MustCompile(`^[0-9a-f]{32}$`)
	fileExtPattern = regexp.MustCompile(`^[a-z0-9]{1,8}$`)
)

func validBookUID(uid string) bool { return bookUIDPattern.MatchString(uid) }

func validFileExt(ext string) bool { return fileExtPattern.MatchString(ext) }

func (s *Store) upsertManifestEntry(userID int64, entry LibraryManifestEntry) error {
	if entry.AuthorsJSON == "" {
		entry.AuthorsJSON = "[]"
	}
	_, err := s.db.Exec(
		`INSERT INTO library_manifest
		 (user_id, book_uid, fingerprint, title, authors_json, format, size_bytes, cover_ext, imported_at, updated_at, deleted_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
		 ON CONFLICT(user_id, book_uid) DO UPDATE SET
		   fingerprint  = excluded.fingerprint,
		   title        = excluded.title,
		   authors_json = excluded.authors_json,
		   format       = excluded.format,
		   size_bytes   = excluded.size_bytes,
		   cover_ext    = excluded.cover_ext,
		   imported_at  = MIN(imported_at, excluded.imported_at),
		   updated_at   = excluded.updated_at,
		   deleted_at   = NULL`,
		userID, entry.BookUID, entry.Fingerprint, entry.Title, entry.AuthorsJSON, entry.Format,
		entry.SizeBytes, entry.CoverExt, entry.ImportedAt, entry.UpdatedAt,
	)
	return err
}

func (s *Store) markLibraryDeleted(userID int64, bookUID string, now int64) error {
	_, err := s.db.Exec(
		`INSERT INTO library_manifest
		 (user_id, book_uid, fingerprint, title, authors_json, format, size_bytes, cover_ext, imported_at, updated_at, deleted_at)
		 VALUES (?, ?, '', '', '[]', '', 0, '', ?, ?, ?)
		 ON CONFLICT(user_id, book_uid) DO UPDATE SET
		   deleted_at = excluded.deleted_at,
		   updated_at = excluded.updated_at`,
		userID, bookUID, now, now, now,
	)
	return err
}

// listManifest 返回 updated_at > since 的条目(含墓碑);since=0 返回全量。
func (s *Store) listManifest(userID int64, since int64) ([]LibraryManifestEntry, error) {
	rows, err := s.db.Query(
		`SELECT book_uid, fingerprint, title, authors_json, format, size_bytes, cover_ext, imported_at, updated_at, deleted_at
		 FROM library_manifest WHERE user_id = ? AND updated_at > ? ORDER BY updated_at ASC`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var entries []LibraryManifestEntry
	for rows.Next() {
		var e LibraryManifestEntry
		if err := rows.Scan(
			&e.BookUID, &e.Fingerprint, &e.Title, &e.AuthorsJSON, &e.Format, &e.SizeBytes,
			&e.CoverExt, &e.ImportedAt, &e.UpdatedAt, &e.DeletedAt,
		); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, rows.Err()
}

func (s *Store) manifestCoverExt(userID int64, bookUID string) (string, error) {
	var coverExt string
	err := s.db.QueryRow(
		`SELECT cover_ext FROM library_manifest WHERE user_id = ? AND book_uid = ?`,
		userID, bookUID,
	).Scan(&coverExt)
	if err != nil {
		return "", err
	}
	return coverExt, nil
}

func (s *Store) userVaultDir(userID int64) string {
	return filepath.Join(s.vaultDir, strconv.FormatInt(userID, 10))
}

func (s *Store) bookVaultDir(userID int64, bookUID string) string {
	return filepath.Join(s.userVaultDir(userID), bookUID)
}

// writeVaultFile 先写临时文件再改名,避免半写文件被下载。
func writeVaultFile(path string, data io.Reader, maxBytes int64) (int64, error) {
	tmp := path + ".tmp"
	f, err := os.Create(tmp)
	if err != nil {
		return 0, err
	}
	n, err := io.Copy(f, io.LimitReader(data, maxBytes+1))
	if closeErr := f.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		_ = os.Remove(tmp)
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			return n, errFileTooLarge
		}
		return n, err
	}
	if n > maxBytes {
		_ = os.Remove(tmp)
		return n, errFileTooLarge
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return n, err
	}
	return n, nil
}

var errFileTooLarge = errors.New("file too large")

// ---- Handlers ----

func (s *Server) handleLibraryManifest(w http.ResponseWriter, r *http.Request, user User) {
	var since int64
	if raw := r.URL.Query().Get("since"); raw != "" {
		value, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || value < 0 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid since"})
			return
		}
		since = value
	}
	entries, err := s.store.listManifest(user.ID, since)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"books":      entries,
		"serverTime": time.Now().UnixMilli(),
	})
}

type announceRequest struct {
	BookUID     string `json:"bookUid"`
	Fingerprint string `json:"fingerprint"`
	Title       string `json:"title"`
	AuthorsJSON string `json:"authorsJson"`
	Format      string `json:"format"`
	SizeBytes   int64  `json:"sizeBytes"`
	CoverExt    string `json:"coverExt"`
	CoverBase64 string `json:"coverBase64"`
	ImportedAt  int64  `json:"importedAt"`
}

func (s *Server) handleLibraryAnnounce(w http.ResponseWriter, r *http.Request, user User) {
	var body announceRequest
	if err := jsonDecodeLimited(w, r, 8<<20, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if !validBookUID(body.BookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	now := time.Now().UnixMilli()

	if body.CoverBase64 != "" {
		ext := body.CoverExt
		if !validFileExt(ext) {
			ext = "jpg"
		}
		decoder := base64.NewDecoder(base64.StdEncoding, strings.NewReader(body.CoverBase64))
		path := filepath.Join(s.store.bookVaultDir(user.ID, body.BookUID), "cover."+ext)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		// 封面上限 2MB。
		if _, err := writeVaultFile(path, decoder, 2<<20); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cover too large"})
			return
		}
		body.CoverExt = ext
	}

	entry := LibraryManifestEntry{
		BookUID:     body.BookUID,
		Fingerprint: body.Fingerprint,
		Title:       body.Title,
		AuthorsJSON: body.AuthorsJSON,
		Format:      body.Format,
		SizeBytes:   body.SizeBytes,
		CoverExt:    body.CoverExt,
		ImportedAt:  body.ImportedAt,
		UpdatedAt:   now,
	}
	if err := s.store.upsertManifestEntry(user.ID, entry); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	title := body.Title
	if title == "" {
		title = shortUID(body.BookUID)
	}
	s.recordActivity("library.announce", user.Name, "上报书目《"+title+"》")
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleBookFilePut(w http.ResponseWriter, r *http.Request, user User) {
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	ext := r.URL.Query().Get("ext")
	if !validFileExt(ext) {
		ext = "epub"
	}
	maxBytes := int64(s.cfg.BookVaultMaxFileMB) << 20
	if r.ContentLength > maxBytes {
		writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{"error": "file too large"})
		return
	}
	dir := s.store.bookVaultDir(user.ID, bookUID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	path := filepath.Join(dir, "original."+ext)
	body := http.MaxBytesReader(w, r.Body, maxBytes)
	size, err := writeVaultFile(path, body, maxBytes)
	if err != nil {
		if errors.Is(err, errFileTooLarge) {
			writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{"error": "file too large"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("library.upload", user.Name,
		"上传书文件 "+shortUID(bookUID)+" · "+humanBytes(size))
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "sizeBytes": size})
}

func (s *Server) handleBookFileGet(w http.ResponseWriter, r *http.Request, user User) {
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	matches, err := filepath.Glob(filepath.Join(s.store.bookVaultDir(user.ID, bookUID), "original.*"))
	if err != nil || len(matches) == 0 {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "book file not found"})
		return
	}
	s.recordActivity("library.download", user.Name, "取回书文件 "+shortUID(bookUID))
	serveVaultFile(w, r, matches[0], "application/octet-stream")
}

var coverContentTypes = map[string]string{
	"jpg":  "image/jpeg",
	"jpeg": "image/jpeg",
	"png":  "image/png",
	"webp": "image/webp",
	"gif":  "image/gif",
}

func (s *Server) handleBookCoverGet(w http.ResponseWriter, r *http.Request, user User) {
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	coverExt, err := s.store.manifestCoverExt(user.ID, bookUID)
	if err != nil || coverExt == "" || !validFileExt(coverExt) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "cover not found"})
		return
	}
	path := filepath.Join(s.store.bookVaultDir(user.ID, bookUID), "cover."+coverExt)
	contentType := coverContentTypes[coverExt]
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	serveVaultFile(w, r, path, contentType)
}

func serveVaultFile(w http.ResponseWriter, r *http.Request, path, contentType string) {
	f, err := os.Open(path)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "file not found"})
		return
	}
	defer f.Close()
	stat, err := f.Stat()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.Header().Set("Content-Type", contentType)
	http.ServeContent(w, r, "", stat.ModTime(), f)
}

func (s *Server) handleLibraryDelete(w http.ResponseWriter, r *http.Request, user User) {
	bookUID := r.PathValue("uid")
	if !validBookUID(bookUID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid bookUid"})
		return
	}
	now := time.Now().UnixMilli()
	if err := s.store.markLibraryDeleted(user.ID, bookUID, now); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if err := os.RemoveAll(s.store.bookVaultDir(user.ID, bookUID)); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.recordActivity("library.delete", user.Name, "删除云端书 "+shortUID(bookUID))
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// jsonDecodeLimited 解析限制大小的 JSON body。
func jsonDecodeLimited(w http.ResponseWriter, r *http.Request, maxBytes int64, v any) error {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBytes))
	return decoder.Decode(v)
}
