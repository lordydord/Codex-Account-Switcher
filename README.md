# Codex Account Switcher

A small native macOS menu-bar app for switching between saved Codex / ChatGPT accounts with [`codex-auth`](https://www.npmjs.com/package/@loongphy/codex-auth).

The app shows compact weekly usage for saved accounts in the menu bar, shows 5-hour usage in the dropdown, and can prompt you to switch accounts when the active account gets low.

## Features

- Compact menu-bar usage such as `A93 B84`.
- Active account shown bright, inactive accounts dimmed.
- Dropdown with both accounts' 5-hour remaining usage.
- One-click account switching with Codex relaunch.
- Configurable usage notifications.
- Optional "Switch Now" notification flow for low 5-hour usage.
- Configurable refresh intervals.
- Launch-at-login toggle.
- Account backup cleanup.
- Generic account initials: by default, each account uses the first letter or number of its email address. You can override labels from the app menu.

## Requirements

- macOS 14 or later.
- Swift compiler / Xcode command line tools.
- Codex desktop app installed at `/Applications/Codex.app`.
- `codex-auth` installed and configured with at least one account.

Install `codex-auth`:

```bash
npm install -g @loongphy/codex-auth
```

Add accounts:

```bash
codex-auth login
```

## Build

```bash
./build.sh
```

The app bundle is created at:

```text
build/Codex Account Switcher.app
```

## Install

```bash
./install.sh
```

This installs to:

```text
~/Applications/Codex Account Switcher.app
```

## Run Without Installing

```bash
./run.sh
```

## Notes

Codex Desktop needs to be relaunched after an account switch before the newly active account takes effect. This app performs that relaunch as part of switching.

Usage refresh depends on `codex-auth`. When `codex-auth` is in API mode, it fetches usage from ChatGPT backend endpoints using the saved account token. Review the `codex-auth` documentation and decide whether that tradeoff is right for you.

No account credentials, tokens, usage registry, or local auth files are included in this repository.

## License

MIT. See [LICENSE](./LICENSE).
