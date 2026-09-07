# 发布流程

> 补齐于 2026-09-07（此前为空占位）。当前版本：apps `0.6.2+2007`。

## 1. 版本号约定

- **唯一来源**：`apps/mobile/pubspec.yaml` 与 `apps/desktop/pubspec.yaml` 的 `version:`（两文件必须一致）。`versionCode`/`versionName`（APK）、exe VERSIONINFO 都从它派生——**不再用 `--build-number` 传版本**。
- `+` 后为构建号（如 `0.6.2+2007`）；升版即改 pubspec。
- Android 侧 `apps/mobile/android/local.properties` 的 `flutter.versionName/versionCode` 为构建快照，发布构建会随之刷新（保持与 pubspec 一致）。
- 版本展示（关于页/设置）读取 pubspec 版本。

## 2. 渲染器资产重同步（改渲染器后必做）

```bash
cd omni-reader
node tools/sync_renderer.mjs       # 重建 ../vue-book-renderer → 拷入 engines/epub/assets/renderer → 重写 pubspec 资产清单 + SHA-256 manifest
node tools/check_renderer_assets.mjs  # 发布/CI 前校验:index/资产/manifest/pubspec 一致
```

- `RENDERER_PATH=<path>` 可指定渲染器位置。
- manifest 记录 `rendererCommit` + `rendererDirty`；**发布前渲染器须已提交、dirty=false**。
- 渲染器 `public/` 书 fixture 不嵌入——实际内容由 App 的 `LocalReaderHttpServer` 按活动书伺服。

## 3. 质量门槛（发布前）

- omni-reader：`dart analyze` 零问题（基线 4 条既有 deprecation info 除外）→ 跑 CI 覆盖的包测试 + 本次改动相关测试。
- sync-server：`go vet ./...` + `go test ./...`（如涉 Go 改动）。
- vue-book-renderer：`pnpm type-check` + `pnpm test:unit` + `pnpm lint`。
- 桌面/移动端在改动 UI 时本地跑一次 `flutter build windows|apk` 冒烟。
- CI：omni-reader `.github/workflows/ci.yml`（资产校验 → analyze → 5 包测试）；渲染器 `.github/workflows/ci.yml`（type-check → lint → format → 单测 → e2e）。**注意 CI 用 stable Flutter 未 pin 版本，本地与 CI 间可能有 lint 差异。**

## 4. 发布清单（按序）

1. 渲染器改动提交（vue-book-renderer）→ 跑 `sync_renderer.mjs` → `check_renderer_assets.mjs` 通过。
2. omni-reader 全部改动提交 → analyze/测试绿 → 打版本（改双 pubspec version）→ 提交。
3. 构建桌面 Release：`flutter build windows --release` → 产物 `apps/desktop/build/windows/x64/runner/Release/reader_desktop.exe`（桌面快捷方式直指此路径，勿改名）。注意构建前先 `taskkill //IM reader_desktop.exe //F`（用户常驻运行会锁 WebView2Loader.dll）。
4. 构建移动 APK：`flutter build apk --release`（app.so 产物、icon-cache/aapt 校验见 Windows 构建备忘）。
5. sync-server：如服务端有改动，交叉编译 linux 二进制并经 /admin 热更新页上传（免 Docker 重建，见 `同步服务器部署与使用指南.md`）。
6. 更新 `开发状态与路线图.md` 的版本/状态行与已交付清单。

## 5. 版本历史

| 版本 | 内容 |
| --- | --- |
| 0.6.2+2007（2026-09-07） | 云同步客户端+冷热备份+epub-repair 集成+sync-server entity/library/admin（f4836ca）；LWW 进度/游标/热更新安全/云删可见/桥接超时+ok:false（9e3a46e，渲染器 f22a6a5）；翻页锚点索引（渲染器 218cf34） |
| 0.6.0+2007 | 品牌 "Omni Reader"、8 项 UX 批、统计中心、标注/搜索/合集等（历史） |
