package main

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const testBookUID = "0123456789abcdef0123456789abcdef"

func TestLibraryManifestAnnounceAndIncrement(t *testing.T) {
	srv, uid := newTestServer(t)
	announce := func(title string) *httptest.ResponseRecorder {
		return doAPI(t, srv, "POST", "/api/library/announce", "test-token", map[string]any{
			"bookUid":     testBookUID,
			"fingerprint": "fp-test-123",
			"title":       title,
			"authorsJson": "[\"作者\"]",
			"format":      "epub",
			"sizeBytes":   1024,
			"importedAt":  111,
		})
	}
	if rec := announce("书名一"); rec.Code != http.StatusOK {
		t.Fatalf("announce failed: %s", rec.Body.String())
	}

	rec := doAPI(t, srv, "GET", "/api/library/manifest", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("manifest failed: %d", rec.Code)
	}
	var result struct {
		Books []LibraryManifestEntry `json:"books"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if len(result.Books) != 1 || result.Books[0].Title != "书名一" || result.Books[0].DeletedAt != nil {
		t.Fatalf("unexpected manifest: %+v", result.Books)
	}
	if result.Books[0].Fingerprint != "fp-test-123" {
		t.Fatalf("fingerprint must round trip, got %q", result.Books[0].Fingerprint)
	}

	// 重新 announce 覆盖标题,不产生重复条目。
	if rec := announce("书名二"); rec.Code != http.StatusOK {
		t.Fatalf("re-announce failed: %s", rec.Body.String())
	}
	entries, err := srv.store.listManifest(uid, 0)
	if err != nil || len(entries) != 1 || entries[0].Title != "书名二" {
		t.Fatalf("re-announce should upsert: %+v %v", entries, err)
	}
}

func TestLibraryManifestTombstoneOnDelete(t *testing.T) {
	srv, uid := newTestServer(t)
	if err := srv.store.upsertManifestEntry(uid, LibraryManifestEntry{
		BookUID: testBookUID, Title: "书", ImportedAt: 1, UpdatedAt: 1,
	}); err != nil {
		t.Fatal(err)
	}
	rec := doAPI(t, srv, "DELETE", "/api/library/"+testBookUID, "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("delete failed: %d", rec.Code)
	}
	entries, err := srv.store.listManifest(uid, 0)
	if err != nil || len(entries) != 1 || entries[0].DeletedAt == nil {
		t.Fatalf("delete should leave tombstone: %+v %v", entries, err)
	}
	books, err := srv.store.countUserBooks(uid)
	if err != nil || books != 0 {
		t.Fatalf("tombstoned book must not count: %d %v", books, err)
	}
}

func TestLibraryManifestInvalidUIDRejected(t *testing.T) {
	srv, _ := newTestServer(t)
	rec := doAPI(t, srv, "POST", "/api/library/announce", "test-token", map[string]any{
		"bookUid": "../escape",
	})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("want 400 for invalid uid, got %d", rec.Code)
	}
}

func TestBookFileUploadDownloadRoundTrip(t *testing.T) {
	srv, _ := newTestServer(t)
	payload := strings.Repeat("EPUB-DATA-", 1000)

	rec := doAPI(t, srv, "PUT", "/api/books/"+testBookUID+"/file?ext=epub", "test-token", payload)
	if rec.Code != http.StatusOK {
		t.Fatalf("upload failed: %d %s", rec.Code, rec.Body.String())
	}

	rec = doAPI(t, srv, "GET", "/api/books/"+testBookUID+"/file", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("download failed: %d", rec.Code)
	}
	got, err := io.ReadAll(rec.Body)
	if err != nil || string(got) != payload {
		t.Fatalf("round trip mismatch: len=%d err=%v", len(got), err)
	}
}

func TestBookFileUploadRejectsUnknownUser(t *testing.T) {
	srv, _ := newTestServer(t)
	rec := doAPI(t, srv, "PUT", "/api/books/"+testBookUID+"/file?ext=epub", "wrong-token", "x")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d", rec.Code)
	}
}

func TestBookFileUploadRejectsOversize(t *testing.T) {
	srv, _ := newTestServer(t)
	srv.cfg.BookVaultMaxFileMB = 1
	payload := strings.Repeat("a", 2<<20) // 2MB > 1MB
	rec := doAPI(t, srv, "PUT", "/api/books/"+testBookUID+"/file?ext=epub", "test-token", payload)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("want 413, got %d", rec.Code)
	}
}

func TestBookFileIsolatedPerUser(t *testing.T) {
	srv, _ := newTestServer(t)
	if _, err := srv.store.createUser("other", "other-token", time.Now().UnixMilli()); err != nil {
		t.Fatal(err)
	}
	rec := doAPI(t, srv, "PUT", "/api/books/"+testBookUID+"/file?ext=epub", "test-token", "data")
	if rec.Code != http.StatusOK {
		t.Fatalf("upload failed: %d", rec.Code)
	}

	// 另一个用户下载不到该文件。
	rec = doAPI(t, srv, "GET", "/api/books/"+testBookUID+"/file", "other-token", nil)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("other user must not see the file, got %d", rec.Code)
	}
}

func TestBookCoverUploadAndFetch(t *testing.T) {
	srv, _ := newTestServer(t)
	coverBytes := []byte("fake-jpeg-bytes")
	rec := doAPI(t, srv, "POST", "/api/library/announce", "test-token", map[string]any{
		"bookUid":     testBookUID,
		"title":       "书",
		"coverExt":    "jpg",
		"coverBase64": base64.StdEncoding.EncodeToString(coverBytes),
		"importedAt":  5,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("announce with cover failed: %s", rec.Body.String())
	}

	rec = doAPI(t, srv, "GET", "/api/books/"+testBookUID+"/cover", "test-token", nil)
	if rec.Code != http.StatusOK || rec.Header().Get("Content-Type") != "image/jpeg" {
		t.Fatalf("cover fetch failed: %d %s", rec.Code, rec.Header().Get("Content-Type"))
	}
	got, _ := io.ReadAll(rec.Body)
	if string(got) != string(coverBytes) {
		t.Fatal("cover bytes mismatch")
	}
}

func TestDeleteRemovesVaultFiles(t *testing.T) {
	srv, uid := newTestServer(t)
	dir := srv.store.bookVaultDir(uid, testBookUID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "original.epub"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	rec := doAPI(t, srv, "DELETE", "/api/library/"+testBookUID, "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("delete failed: %d", rec.Code)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("vault dir should be removed, err=%v", err)
	}
}
