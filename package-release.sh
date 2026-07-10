#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$(/bin/bash "$ROOT_DIR/build.sh")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ARCHIVE="$ROOT_DIR/build/Codex-Account-Switcher-v$VERSION.zip"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP_PATH" "$ARCHIVE"
/usr/bin/shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
VERIFY_DIR="$(/usr/bin/mktemp -d /tmp/codex-switcher-verify.XXXXXX)"
trap '/bin/rm -rf "$VERIFY_DIR"' EXIT
/usr/bin/ditto -x -k "$ARCHIVE" "$VERIFY_DIR"
/usr/bin/codesign --verify --deep --strict "$VERIFY_DIR/Codex Account Switcher.app"
echo "$ARCHIVE"
echo "$ARCHIVE.sha256"
