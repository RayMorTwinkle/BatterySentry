#!/bin/bash
# 构建并安装到 /Applications（登录项用 SMAppService 时更可靠）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="BatterySentry"
DEST="/Applications/${APP_NAME}.app"

bash build.sh

if [ ! -w "/Applications" ]; then
  echo "✗ 没有写入 /Applications 的权限，请手动把 dist/${APP_NAME}.app 拖进「应用程序」文件夹。"
  exit 1
fi

echo "==> 退出正在运行的实例"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

echo "==> 安装到 $DEST"
rm -rf "$DEST"
cp -R "dist/${APP_NAME}.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

echo "==> 启动"
open "$DEST"

echo ""
echo "✅ 已安装并启动: $DEST"
echo "   菜单栏右上角应该出现了电池图标（电量 XX%）。"
