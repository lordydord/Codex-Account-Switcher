#!/bin/sh

# Keep the menu-bar switcher coupled to the Codex desktop surface without
# mistaking its intentional restart during an account switch for a real quit.
APP_PATH="/Applications/Codex Account Switcher.app"
GRACE_SECONDS=5
POLL_SECONDS=2
missing_since=""

target_is_running() {
  /usr/bin/osascript -e 'application "ChatGPT" is running' 2>/dev/null | /usr/bin/grep -qx 'true' ||
    /usr/bin/osascript -e 'application "Codex" is running' 2>/dev/null | /usr/bin/grep -qx 'true'
}

switcher_is_running() {
  /usr/bin/osascript -e 'application id "com.mohamedfuad.codexaccountswitcher" is running' 2>/dev/null | /usr/bin/grep -qx 'true'
}

while true; do
  if target_is_running; then
    missing_since=""
    if ! switcher_is_running && [ -d "$APP_PATH" ]; then
      /usr/bin/open -g "$APP_PATH" >/dev/null 2>&1
    fi
  else
    now=$(/bin/date +%s)
    if [ -z "$missing_since" ]; then
      missing_since="$now"
    elif [ $((now - missing_since)) -ge "$GRACE_SECONDS" ]; then
      if switcher_is_running; then
        /usr/bin/osascript -e 'tell application id "com.mohamedfuad.codexaccountswitcher" to quit' >/dev/null 2>&1
      fi
    fi
  fi

  /bin/sleep "$POLL_SECONDS"
done
