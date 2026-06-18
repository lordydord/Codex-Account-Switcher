---
name: codex-account-switcher
description: Maintain and publish the macOS Codex Account Switcher app. Use when Graham asks to tweak, build, package, sanitize, or publish the menu-bar account switcher.
---

# Codex Account Switcher Skill

Use this skill for the local/public Codex Account Switcher project.

## Project Location

Work from the root of this repository.

## Important Public-Safety Rules

- Never commit `~/.codex/auth.json`, `~/.codex/accounts/`, `registry.json`, tokens, account IDs, real account emails, or usage snapshots.
- Never commit `build/` or module caches.
- Public account initials must be generic: use the first alphanumeric character from each account email unless the app user sets a custom label.
- Switch commands should use email queries, not numeric selectors like `01` or `02`.

## Build

```bash
./build.sh
```

## Install Locally

```bash
./install.sh
```

## Behavior Summary

- Current local update is v1.33 / build 133.
- Menu bar defaults to large weekly usage with percent signs, with a compact number-only option.
- Active account is bright; inactive accounts are dimmed.
- Dropdown shows 5-hour usage for all accounts.
- The main panel supports three/four saved accounts with a compact 2x2 card grid and an empty slot.
- Live usage values that come back as 400/401 should be treated as expired login, not healthy unknown usage. Ask Graham to remove/re-add or re-login that labelled account.
- The relaunch path may see leftover Codex helper PIDs; if Codex can still open, do not treat helper survivors alone as a failed relaunch.
- Low-usage auto-switch is notification/action based: the user clicks `Switch Now`.
- Launch-at-login is handled via a user LaunchAgent.

## Troubleshooting Notes

- If the menu-bar title gets stuck on `Adding account` after a manual login, quit `CodexAccountSwitcher` and reopen `/Applications/Codex Account Switcher.app`, then run `codex-auth list` to confirm the registry.
- If the device-code button crashes or fails, inspect the Terminal/AppleScript helper path first. Do not assume the account registry is broken if `codex-auth list` already shows the re-added account with live usage.
- After every local tweak, run `./build.sh`, `./install.sh`, quit `CodexAccountSwitcher`, reopen `/Applications/Codex Account Switcher.app`, and verify the running process path.
