//go:build unix

// bootstrap:容器入口。优先执行 /data/sync-server(管理页上传的热更新版本),
// 不存在则回退到镜像内置 /sync-server——热更新因此能跨容器重启持久。
package main

import (
	"log"
	"os"
	"syscall"
)

const updatedBin = "/data/sync-server"
const builtinBin = "/sync-server"

func main() {
	target := builtinBin
	if _, err := os.Stat(updatedBin); err == nil {
		target = updatedBin
	}
	if err := syscall.Exec(target, []string{"sync-server"}, os.Environ()); err != nil {
		// 热更新二进制无法执行(架构不符/损坏):回退镜像版本,避免容器卡死。
		log.Printf("[bootstrap] exec %s failed: %v, falling back to %s", target, err, builtinBin)
		if err := syscall.Exec(builtinBin, []string{"sync-server"}, os.Environ()); err != nil {
			log.Fatalf("[bootstrap] fallback exec failed: %v", err)
		}
	}
}
