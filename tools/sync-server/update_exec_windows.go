//go:build !unix

package main

import "errors"

// execIntoSelf 在非 Unix 平台(如 Windows 开发机)不支持进程自替换。
func execIntoSelf(path string) error {
	return errors.New("hot update is only supported inside the linux container")
}
