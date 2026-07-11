#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_BUILD_DIR="${TMPDIR:-/tmp}/codex-account-switcher-tests"
TEST_BINARY="$TEST_BUILD_DIR/InfrastructureTests"

mkdir -p "$TEST_BUILD_DIR"
/usr/bin/xcrun swiftc \
  "$ROOT_DIR/Sources/AppInfrastructure.swift" \
  "$ROOT_DIR/Tests/InfrastructureTests.swift" \
  -target arm64-apple-macosx14.0 \
  -o "$TEST_BINARY"

"$TEST_BINARY"

APP_BINARY="$ROOT_DIR/build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
if [[ ! -x "$APP_BINARY" ]]; then
  /bin/bash "$ROOT_DIR/build.sh" >/dev/null
fi
RESET_RESULT="$("$APP_BINARY" --self-test-reset-logic)"
if [[ "$RESET_RESULT" != "Reset logic self-test passed" ]]; then
  echo "$RESET_RESULT" >&2
  exit 1
fi
echo "$RESET_RESULT"
