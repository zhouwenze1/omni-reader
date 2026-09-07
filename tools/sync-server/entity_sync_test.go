package main

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"
)

func TestEntityPushPullRoundTrip(t *testing.T) {
	srv, _ := newTestServer(t)

	push := func(body string) map[string]int {
		rec := doAPI(t, srv, "POST", "/api/v2/sync/annotation/push", "test-token", body)
		if rec.Code != http.StatusOK {
			t.Fatalf("push failed: %d %s", rec.Code, rec.Body.String())
		}
		var result map[string]int
		if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		return result
	}

	a1 := `{"deviceId":"dev1","items":[
		{"key":"11111111111111111111111111111111","payload":{"bookUid":"book-a","id":"11111111111111111111111111111111","locator":{"href":"c1.xhtml"},"text":"划线内容","note":"","color":"yellow","updatedAt":1000},"updatedAt":1000},
		{"key":"22222222222222222222222222222222","payload":{"bookUid":"book-a","id":"22222222222222222222222222222222","locator":{"href":"c2.xhtml"},"text":"","note":"笔记","color":"green","updatedAt":2000},"updatedAt":2000}]}`
	if r := push(a1); r["accepted"] != 2 || r["changed"] != 2 {
		t.Fatalf("first push: %+v", r)
	}
	// 同内容重推幂等。
	if r := push(a1); r["accepted"] != 2 || r["changed"] != 0 {
		t.Fatalf("repeat push should be idempotent: %+v", r)
	}

	// cursor=0 全量回放。
	rec := doAPI(t, srv, "GET", "/api/v2/sync/annotation/pull?cursor=0", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("pull failed: %d", rec.Code)
	}
	var pull struct {
		Items  []EntityPushItem `json:"items"`
		Cursor int64            `json:"cursor"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &pull); err != nil {
		t.Fatal(err)
	}
	if len(pull.Items) != 2 || pull.Cursor != 2 {
		t.Fatalf("unexpected pull: %d items cursor=%d", len(pull.Items), pull.Cursor)
	}

	// 内容变化 → 增量 1 条。
	push(`{"deviceId":"dev1","items":[{"key":"11111111111111111111111111111111","payload":{"bookUid":"book-a","id":"11111111111111111111111111111111","note":"修改后的笔记","updatedAt":3000},"updatedAt":3000}]}`)
	rec = doAPI(t, srv, "GET", "/api/v2/sync/annotation/pull?cursor=2", "test-token", nil)
	pull.Items = nil
	if err := json.Unmarshal(rec.Body.Bytes(), &pull); err != nil {
		t.Fatal(err)
	}
	if len(pull.Items) != 1 || pull.Items[0].Key != "11111111111111111111111111111111" {
		t.Fatalf("incremental pull: %+v", pull.Items)
	}
}

func TestAnnotationTombstone(t *testing.T) {
	srv, _ := newTestServer(t)
	push := func(body string) {
		rec := doAPI(t, srv, "POST", "/api/v2/sync/annotation/push", "test-token", body)
		if rec.Code != http.StatusOK {
			t.Fatalf("push failed: %d %s", rec.Code, rec.Body.String())
		}
	}
	push(`{"deviceId":"dev1","items":[{"key":"abc","payload":{"id":"abc","text":"x"},"updatedAt":1000}]}`)
	// 删除 = 墓碑条目,日志里必须保留 deleted 标记。
	push(`{"deviceId":"dev1","items":[{"key":"abc","deleted":true,"updatedAt":2000}]}`)

	rec := doAPI(t, srv, "GET", "/api/v2/sync/annotation/pull?cursor=0", "test-token", nil)
	var pull struct {
		Items []EntityPushItem `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &pull); err != nil {
		t.Fatal(err)
	}
	if len(pull.Items) != 2 || !pull.Items[1].Deleted {
		t.Fatalf("tombstone missing: %+v", pull.Items)
	}
	// 相同墓碑重推幂等。
	push(`{"deviceId":"dev1","items":[{"key":"abc","deleted":true,"updatedAt":2000}]}`)
	rec = doAPI(t, srv, "GET", "/api/v2/sync/annotation/pull?cursor=2", "test-token", nil)
	pull.Items = nil
	if err := json.Unmarshal(rec.Body.Bytes(), &pull); err != nil {
		t.Fatal(err)
	}
	if len(pull.Items) != 0 {
		t.Fatalf("tombstone repeat should not append: %+v", pull.Items)
	}
}

func TestEntityIsolationAndValidation(t *testing.T) {
	srv, _ := newTestServer(t)
	if _, err := srv.store.createUser("other", "other-token", time.Now().UnixMilli()); err != nil {
		t.Fatal(err)
	}

	rec := doAPI(t, srv, "POST", "/api/v2/sync/setting/push", "test-token",
		`{"deviceId":"dev1","items":[{"key":"reader_style","payload":{"fontSize":18},"updatedAt":1000}]}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("setting push failed: %d %s", rec.Code, rec.Body.String())
	}

	// 其他用户拉不到。
	rec = doAPI(t, srv, "GET", "/api/v2/sync/setting/pull?cursor=0", "other-token", nil)
	var pull struct {
		Items []EntityPushItem `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &pull); err != nil {
		t.Fatal(err)
	}
	if len(pull.Items) != 0 {
		t.Fatalf("user isolation broken: %+v", pull.Items)
	}

	// 未知实体 404;空 key 400;超大/控制字符 key 400。
	if rec := doAPI(t, srv, "GET", "/api/v2/sync/bogus/pull", "test-token", nil); rec.Code != http.StatusNotFound {
		t.Fatalf("unknown entity should 404, got %d", rec.Code)
	}
	if rec := doAPI(t, srv, "POST", "/api/v2/sync/stat/push", "test-token",
		`{"deviceId":"dev1","items":[{"key":"","payload":{},"updatedAt":1}]}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("empty key should 400, got %d", rec.Code)
	}
	if rec := doAPI(t, srv, "POST", "/api/v2/sync/stat/push", "test-token",
		`{"deviceId":"dev1","items":[{"key":"a\nb","payload":{},"updatedAt":1}]}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("control-char key should 400, got %d", rec.Code)
	}

	// 缺 cursor 默认 0(全量)。
	rec = doAPI(t, srv, "GET", "/api/v2/sync/setting/pull", "test-token", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("pull without cursor failed: %d", rec.Code)
	}
}

func TestEntityPushActivityLogged(t *testing.T) {
	srv, _ := newTestServer(t)
	doAPI(t, srv, "POST", "/api/v2/sync/stat/push", "test-token",
		`{"deviceId":"dev1","items":[{"key":"dev1:1000","payload":{"seconds":60},"updatedAt":1000}]}`)
	found := false
	for _, e := range srv.recentActivity(50) {
		if e.Type == "sync.stat" {
			found = true
		}
	}
	if !found {
		t.Fatal("stat push should be recorded in activity log")
	}
}
