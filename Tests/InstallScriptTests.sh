#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"

grep -Fq 'was_running=false' "$INSTALL_SCRIPT"
grep -Fq 'was_running=true' "$INSTALL_SCRIPT"
grep -Fq '/usr/bin/open "$DEST_APP"' "$INSTALL_SCRIPT"

echo "Install script restart test passed."
