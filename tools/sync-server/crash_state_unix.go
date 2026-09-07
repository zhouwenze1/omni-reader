//go:build unix

// 热更新崩溃回退的状态记录。容器由 bootstrap 启动:若更新后的二进制反复
// 崩溃(Exec 本身成功但进程随后退出),bootstrap 会看到累积的崩溃计数并回退
// 到镜像内置版本,避免"坏版本永久 crash-loop、管理页不可用"。

package main

import (
	"os"
	"strconv"
)

// CrashStatePath 返回崩溃计数文件路径(与更新二进制同目录)。
func CrashStatePath(updatePath string) string {
	return updatePath + ".crash"
}

// crashThreshold 连续崩溃超过该次数即判定更新版本不可用,回退内置版本。
const crashThreshold = 3

// readCrashState 读取当前崩溃计数;文件缺失视为 0。
func readCrashState(path string) (int, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return 0, nil
		}
		return 0, err
	}
	n, err := strconv.Atoi(string(raw))
	if err != nil || n < 0 {
		return 0, nil
	}
	return n, nil
}

// bumpCrashState 在 exec 新版本前递增崩溃计数并返回递增后的值。
func bumpCrashState(path string) (int, error) {
	n, err := readCrashState(path)
	if err != nil {
		return 0, err
	}
	n++
	if err := os.WriteFile(path, []byte(strconv.Itoa(n)), 0o644); err != nil {
		return 0, err
	}
	return n, nil
}

// clearCrashState 进程健康启动后清零崩溃计数。
func clearCrashState(path string) {
	_ = os.Remove(path)
}
