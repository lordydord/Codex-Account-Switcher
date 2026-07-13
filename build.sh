#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="Codex Account Switcher"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BIN_PATH="$MACOS_DIR/CodexAccountSwitcher"
MODULE_CACHE_DIR="${CODEX_SWITCHER_MODULE_CACHE_DIR:-$HOME/Library/Caches/CodexAccountSwitcher/ModuleCache}"
ICON_SOURCE="$ROOT_DIR/Sources/icon.png"
TOOLBAR_ICON_SOURCE="$ROOT_DIR/Sources/toolbar-icon.png"
LIFECYCLE_MONITOR_SOURCE="$ROOT_DIR/Sources/LifecycleMonitor.swift"

rm -rf "$APP_DIR" "$BUILD_DIR/ModuleCache" "$BUILD_DIR/Codex Account Switcher 2.app" "$BUILD_DIR/Codex Account Switcher 3.app"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AccountSwitcherIcon.png"
elif [[ -f "/Applications/ChatGPT.app/Contents/Resources/icon.icns" ]]; then
  cp "/Applications/ChatGPT.app/Contents/Resources/icon.icns" "$RESOURCES_DIR/AccountSwitcherIcon.icns"
elif [[ -f "/Applications/Codex.app/Contents/Resources/icon.icns" ]]; then
  cp "/Applications/Codex.app/Contents/Resources/icon.icns" "$RESOURCES_DIR/AccountSwitcherIcon.icns"
fi

if [[ -f "$TOOLBAR_ICON_SOURCE" ]]; then
  cp "$TOOLBAR_ICON_SOURCE" "$RESOURCES_DIR/ToolbarIcon.png"
fi

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swiftc "$LIFECYCLE_MONITOR_SOURCE" \
  -target arm64-apple-macosx14.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -o "$RESOURCES_DIR/CodexLifecycleMonitor"

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swiftc \
  "$ROOT_DIR/Sources/AppInfrastructure.swift" \
  "$ROOT_DIR/Sources/main.swift" \
  -target arm64-apple-macosx14.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework UserNotifications \
  -o "$BIN_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexAccountSwitcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.mohamedfuad.codexaccountswitcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Account Switcher</string>
  <key>CFBundleDisplayName</key>
  <string>Codex Account Switcher</string>
  <key>CFBundleIconFile</key>
  <string>AccountSwitcherIcon.png</string>
  <key>NSUserNotificationUsageDescription</key>
  <string>Codex Account Switcher sends low-usage reminders when your active account is near the configured threshold.</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.8.3.1</string>
  <key>CFBundleVersion</key>
  <string>1831</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null 2>&1; then
  /usr/bin/xattr -cr "$APP_DIR"
  /usr/bin/xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
  /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
fi
if command -v codesign >/dev/null 2>&1; then
  signed=0
  for _ in 1 2 3 4 5; do
    /usr/bin/xattr -cr "$APP_DIR" 2>/dev/null || true
    /usr/bin/xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
    /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
    if /usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1; then
      signed=1
      break
    fi
  done
  if [[ "$signed" != "1" ]]; then
    echo "Could not ad-hoc sign the build bundle after five metadata-cleanup attempts." >&2
    exit 1
  fi
fi

echo "$APP_DIR"
