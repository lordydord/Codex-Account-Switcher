#!/usr/bin/env bash
set -euo pipefail

APP_PATH="$(/bin/bash "$(dirname "${BASH_SOURCE[0]}")/build.sh")"
/usr/bin/open "$APP_PATH"
