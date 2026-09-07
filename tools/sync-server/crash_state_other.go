//go:build !unix

// 非 unix 平台没有 bootstrap/热更新自替换,崩溃回退状态为空操作。

package main

func clearCrashState(path string) {}
