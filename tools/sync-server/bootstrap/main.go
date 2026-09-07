//go:build unix

// bootstrap:容器入口。优先执行 /data/sync-server(管理页上传的热更新版本),
// 不存在则回退到镜像内置 /sync-server——热更新因此能跨容器重启持久。
//
// 崩溃回退:更新版本若反复崩溃(exec 成功但进程随即退出),bootstrap 依据
// .crash 计数文件在连续崩溃达到阈值后删除损坏的更新二进制并回退内置版本,
// 避免坏版本把容器钉死在 crash-loop 且管理页不可用。
package main

import (
	"log"
	"os"
	"strconv"
	"syscall"
)

const updatedBin = "/data/sync-server"
const builtinBin = "/sync-server"
const crashThreshold = 3

func crashPath() string { return updatedBin + ".crash" }

func readCrash() int {
	raw, err := os.ReadFile(crashPath())
	if err != nil {
		return 0
	}
	n := 0
	for _, c := range raw {
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
		if n > crashThreshold {
			break
		}
	}
	return n
}

func main() {
	target := builtinBin
	if _, err := os.Stat(updatedBin); err == nil {
		target = updatedBin
	}

	if target == updatedBin {
		// 用坏版本 exec 前先递增崩溃计数;进程健康启动会清空该文件。
		n := readCrash()
		if n >= crashThreshold {
			log.Printf("[bootstrap] updated binary crashed %d times, removing %s and falling back to builtin", n, updatedBin)
			_ = os.Remove(updatedBin)
			_ = os.Remove(crashPath())
			target = builtinBin
		} else {
			// 递增崩溃计数(写入 n+1),健康启动后由主进程清空。
			if err := os.WriteFile(crashPath(), []byte(strconv.Itoa(n+1)), 0o644); err != nil {
				log.Printf("[bootstrap] write crash state failed: %v", err)
			}
		}
	}

	env := os.Environ()
	if target == updatedBin {
		// 标记本次 exec 的是更新版本;主进程健康启动后据此清空崩溃计数。
		env = append(env, "SYNC_UPDATED_BIN="+updatedBin)
	}
	if err := syscall.Exec(target, []string{"sync-server"}, env); err != nil {
		// 更新二进制无法执行(架构不符/损坏):回退镜像版本,避免容器卡死。
		log.Printf("[bootstrap] exec %s failed: %v, falling back to %s", target, err, builtinBin)
		if err := syscall.Exec(builtinBin, []string{"sync-server"}, os.Environ()); err != nil {
			log.Fatalf("[bootstrap] fallback exec failed: %v", err)
		}
	}
}
