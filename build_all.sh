#!/usr/bin/env bash
# ============================================================
# Omni Reader 双端构建脚本 (Windows / Git Bash)
#
# 用法:
#   ./build_all.sh            # 构建桌面端 + 移动端 APK
#   ./build_all.sh desktop    # 只构建桌面端 (Windows Release)
#   ./build_all.sh mobile     # 只构建移动端 (APK)
#   ./build_all.sh --no-kill  # 不强制结束正在运行的桌面端进程
#
# 产物:
#   桌面端: apps/desktop/build/windows/x64/runner/Release/reader_desktop.exe
#   移动端: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
#           (另复制一份到桌面 Omni-Reader-<version>.apk)
# ============================================================
set -euo pipefail

# 定位项目根目录 (脚本所在目录)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_APP="$ROOT_DIR/apps/desktop"
MOBILE_APP="$ROOT_DIR/apps/mobile"

KILL_RUNNING=true
TARGET="both"
for arg in "$@"; do
  case "$arg" in
    --no-kill) KILL_RUNNING=false ;;
    desktop|mobile|both) TARGET="$arg" ;;
    -h|--help)
      grep -E '^#' "$0" | head -20
      exit 0
      ;;
  esac
done

echo "==> 项目根目录: $ROOT_DIR"
echo "==> 目标: $TARGET"

# 读 app 的 pubspec 版本号,用于 APK 命名 (0.6.0+2007 -> 0.6.0)
VERSION="$(grep -E '^version:' "$MOBILE_APP/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
if [ -z "$VERSION" ]; then
  VERSION="$(grep -E '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
fi
echo "==> 版本: $VERSION"

# 桌面端: 结束正在运行的实例,避免 WebView2Loader.dll 被占用导致 MSB3027
kill_desktop() {
  if [ "$KILL_RUNNING" = true ]; then
    if tasklist 2>/dev/null | grep -qi 'reader_desktop.exe'; then
      echo "==> 结束运行中的桌面端进程..."
      taskkill //IM reader_desktop.exe //F >/dev/null 2>&1 || true
      sleep 1
    fi
  else
    echo "==> 跳过结束桌面端进程 (--no-kill)"
  fi
}

build_desktop() {
  echo ""
  echo "===== 构建桌面端 (Windows Release) ====="
  kill_desktop
  cd "$DESKTOP_APP"
  if flutter build windows --release; then
    EXE="$DESKTOP_APP/build/windows/x64/runner/Release/reader_desktop.exe"
    echo ""
    echo "✅ 桌面端构建成功:"
    echo "   $EXE"
  else
    echo "❌ 桌面端构建失败" >&2
    exit 1
  fi
}

build_mobile() {
  echo ""
  echo "===== 构建移动端 (APK Release) ====="
  cd "$MOBILE_APP"
  if flutter build apk --release; then
    APK="$MOBILE_APP/build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "✅ 移动端 APK 构建成功:"
    echo "   $APK"
    # 复制到桌面
    DESKTOP_DIR="${USERPROFILE:-$HOME}/Desktop"
    if [ -d "$DESKTOP_DIR" ]; then
      DEST="$DESKTOP_DIR/Omni-Reader-v$VERSION.apk"
      cp "$APK" "$DEST"
      echo "   已复制到桌面: $DEST"
    else
      echo "   (未找到桌面目录,跳过复制)"
    fi
  else
    echo "❌ 移动端构建失败" >&2
    exit 1
  fi
}

case "$TARGET" in
  desktop) build_desktop ;;
  mobile)  build_mobile ;;
  both)    build_desktop; build_mobile ;;
esac

echo ""
echo "===== 全部完成 ====="
