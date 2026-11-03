#!/bin/bash
# 编译并组装成可运行的 .app（ad-hoc 签名）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="BatterySentry"
DISPLAY_NAME="电量哨兵"
BUNDLE_ID="com.ray.batterysentry"
CONFIGURATION="${1:-release}"
SIGNING_IDENTITY="${BATTERYSENTRY_SIGNING_IDENTITY:--}"

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

echo "==> [4/4] 签名"
if [ "$SIGNING_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP" >/dev/null
  echo "   ad-hoc 签名：系统通知使用普通级别，全屏浮窗仍可用"
else
  codesign --force --deep --sign "$SIGNING_IDENTITY" --entitlements "$ROOT/Resources/BatterySentry.entitlements" "$APP" >/dev/null
fi
codesign --verify "$APP"
if [ "$SIGNING_IDENTITY" != "-" ]; then
  if ! codesign -d --entitlements :- "$APP" 2>/dev/null | python3 -c 'import plistlib,sys; sys.exit(0 if plistlib.loads(sys.stdin.buffer.read()).get("com.apple.developer.usernotifications.time-sensitive") is True else 1)'; then
    echo "✗ 签名中未找到时间敏感通知能力"
    exit 1
  fi
fi
if ! SELFTEST_OUTPUT=$("$APP/Contents/MacOS/$APP_NAME" --selftest 2>&1); then
  echo "✗ 签名后的应用无法启动：$SELFTEST_OUTPUT"
  exit 1
fi
if [ "$SIGNING_IDENTITY" != "-" ] && ! grep -q '进程时间敏感能力: true' <<< "$SELFTEST_OUTPUT"; then
  echo "✗ 运行进程没有获得时间敏感通知能力"
  exit 1
fi

echo ""
echo "✅ 构建完成: $APP"
echo "   运行: open \"$APP\""
echo "   自检: \"$APP/Contents/MacOS/$APP_NAME\" --selftest --sound --speak"
