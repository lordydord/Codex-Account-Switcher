#!/usr/bin/env bash
set -euo pipefail
APP="/Applications/Codex Account Switcher.app"
[[ -d "$APP" ]]
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
/bin/launchctl print "gui/$(/usr/bin/id -u)/com.mohamedfuad.codexaccountswitcher" >/dev/null
/usr/bin/pgrep -f "$APP/Contents/Resources/CodexLifecycleMonitor" >/dev/null
echo "Installed app, ad-hoc signature, and native lifecycle monitor verified."
