#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$(/bin/bash "$ROOT_DIR/build.sh")"
DEST_DIR="/Applications"
DEST_APP="$DEST_DIR/Codex Account Switcher.app"
DEST_EXECUTABLE="$DEST_APP/Contents/MacOS/CodexAccountSwitcher"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

was_running=false
if /usr/bin/pgrep -f -x "$DEST_EXECUTABLE" >/dev/null 2>&1; then
  was_running=true
  /usr/bin/pkill -f -x "$DEST_EXECUTABLE" || true
fi

mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
cp -R "$APP_PATH" "$DEST_APP"

if command -v xattr >/dev/null 2>&1; then
  /usr/bin/xattr -cr "$DEST_APP"
  /usr/bin/xattr -d com.apple.FinderInfo "$DEST_APP" 2>/dev/null || true
  /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$DEST_APP" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
  /usr/bin/codesign --force --deep --sign - "$DEST_APP" >/dev/null
fi

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

"$DEST_APP/Contents/MacOS/CodexAccountSwitcher" --install-lifecycle-monitor >/dev/null

if "$was_running"; then
  /usr/bin/open "$DEST_APP"
fi

echo "$DEST_APP"
