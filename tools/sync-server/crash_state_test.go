//go:build unix

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCrashStateBumpAndThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sync-server.crash")

	if n, err := readCrashState(path); err != nil || n != 0 {
		t.Fatalf("missing file should read 0, got %d err=%v", n, err)
	}
	for i := 1; i <= 4; i++ {
		n, err := bumpCrashState(path)
		if err != nil {
			t.Fatalf("bump %d: %v", i, err)
		}
		if n != i {
			t.Fatalf("bump %d: want %d, got %d", i, i, n)
		}
	}
	clearCrashState(path)
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("clearCrashState should remove the file")
	}
	if n, _ := readCrashState(path); n != 0 {
		t.Fatalf("after clear should read 0, got %d", n)
	}
}
