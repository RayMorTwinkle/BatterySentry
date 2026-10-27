#!/bin/bash
# 编译并组装成可运行的 .app（ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="BatterySentry"
DISPLAY_NAME="电量哨兵"
BUNDLE_ID="com.ray.batterysentry"
CONFIGURATION="${1:-release}"

ROOT="$(pwd)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
ICONSET_DIR="$ROOT/Resources/AppIcon.iconset"
ICON_FILE="$ROOT/Resources/AppIcon.icns"

echo "==> [1/4] 准备应用图标"
if [ ! -f "$ICON_FILE" ]; then
  rm -rf "$ICONSET_DIR"
  swift "$ROOT/scripts/make-icon.swift" "$ICONSET_DIR"
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
fi

echo "==> [2/4] 编译 Swift 源码 ($CONFIGURATION)"
swift build --disable-sandbox -c "$CONFIGURATION" --product "$APP_NAME"
BIN_PATH="$(swift build --disable-sandbox -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"
if [ ! -x "$BIN_PATH" ]; then
  echo "✗ 编译产物不存在: $BIN_PATH"
  exit 1
fi

echo "==> [3/4] 组装 .app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON_FILE" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> [4/4] ad-hoc 签名"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
codesign --verify "$APP"

echo ""
echo "✅ 构建完成: $APP"
echo "   运行: open \"$APP\""
echo "   自检: \"$APP/Contents/MacOS/$APP_NAME\" --selftest --sound --speak"
