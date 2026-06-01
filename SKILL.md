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

- Menu bar shows compact weekly usage for saved accounts.
- Active account is bright; inactive accounts are dimmed.
- Dropdown shows 5-hour usage for all accounts.
- Low-usage auto-switch is notification/action based: the user clicks `Switch Now`.
- Launch-at-login is handled via a user LaunchAgent.
