#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$(/bin/bash "$ROOT_DIR/build.sh")"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/Codex Account Switcher.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
cp -R "$APP_PATH" "$DEST_APP"

if command -v xattr >/dev/null 2>&1; then
  /usr/bin/xattr -cr "$DEST_APP"
fi

if command -v codesign >/dev/null 2>&1; then
  /usr/bin/codesign --force --deep --sign - "$DEST_APP" >/dev/null
fi

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

echo "$DEST_APP"
