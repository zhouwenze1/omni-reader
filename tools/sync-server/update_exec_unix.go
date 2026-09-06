//go:build unix

package main

import (
	"os"
	"syscall"
)

// execIntoSelf 用新二进制替换当前进程(同 PID,监听端口随 CLOEXEC 关闭)。
// 仅在 Linux 容器/主机上有意义;失败时容器按 restart 策略拉起镜像内版本。
func execIntoSelf(path string) error {
	return syscall.Exec(path, []string{"sync-server"}, os.Environ())
}
