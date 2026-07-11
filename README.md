<p align="center">
  <img src="assets/social-preview.png" alt="Codex Account Switcher modern preview" width="100%">
</p>

<h1 align="center">Codex Account Switcher</h1>

<p align="center">
  <strong>A tiny native macOS menu-bar app for switching Codex / ChatGPT accounts, watching usage, and keeping the active account obvious.</strong>
</p>

<p align="center">
  <a href="https://developer.apple.com/swift/"><img alt="Swift" src="https://img.shields.io/badge/Swift-5.9+-f97316?style=flat-square"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14+-111827?style=flat-square">
  <img alt="Native AppKit" src="https://img.shields.io/badge/Native-AppKit-2563eb?style=flat-square">
  <img alt="Current version 1.8.2" src="https://img.shields.io/badge/Current-v1.8.2-16a34a?style=flat-square">
  <a href="./LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-16a34a?style=flat-square"></a>
</p>

<p align="center">
  <a href="https://github.com/lordydord/Codex-Account-Switcher/releases/download/v1.8.2/Codex-Account-Switcher-v1.8.2.zip"><strong>Download v1.8.2</strong></a>
  ·
  <a href="#install"><strong>Install from source</strong></a>
  ·
  <a href="#how-switching-works"><strong>How switching works</strong></a>
</p>

## Why

If you use the Codex Desktop app heavily, swapping between personal and work ChatGPT accounts can be clunky. Codex Account Switcher puts the useful bits in your menu bar:

- active account usage in the menu bar
- 5-hour and weekly usage in a compact account panel
- reset-credit tracking across saved accounts, including expiry urgency colours
- clearer active and inactive account styling without extra panel badges
- safer switch previews before relaunching Codex
- health checks for `codex-auth`, ChatGPT/Codex, notifications, refresh freshness, and updates
- optional automatic switching and resume prompts when quota gets tight

It is deliberately small: a single Swift/AppKit menu-bar app for Codex Desktop that talks to [`codex-auth`](https://www.npmjs.com/package/@loongphy/codex-auth).

## What It Looks Like

<p align="center">
  <img src="assets/screenshot-menubar.png" alt="Codex Account Switcher menu-bar status with placeholder account labels" width="720">
</p>

<table>
  <tr>
    <td width="50%">
      <img src="assets/screenshot-panel.png" alt="Codex Account Switcher account panel with placeholder accounts">
    </td>
    <td width="50%">
      <img src="assets/screenshot-settings.png" alt="Codex Account Switcher settings panel with placeholder accounts">
    </td>
  </tr>
</table>

<p align="center">
  <img src="assets/screenshot-resets.png" alt="Codex Account Switcher reset credits screen with placeholder accounts and color-coded expiry urgency" width="360">
</p>

The reset-credit view is one of the main reasons to use the switcher: it can show available Codex reset credits across saved accounts, group them by account, color-code expiry urgency, and keep each reset behind an explicit confirmation before anything is spent.

By default, each account uses the first letter or number from its email address. For example:

- `alice@example.com` becomes `A`
- `builds@example.com` becomes `B`

You can switch the menu bar to a smaller `A93 B84` style, or override account labels from the menu if you prefer custom initials.

## Features

- Menu-bar usage display with weekly or 5-hour usage, active account color, large percentage and small compact styles.
- Click-to-open account panel with 5-hour rings, weekly progress, refresh, settings, and close controls.
- In-window reset-credit screen grouped by account, with color-coded expiry urgency and guarded redemption.
- Verified reset redemption that checks both the spent credit and the refreshed live usage windows before reporting success.
- Five-minute reset-credit caching, while the active account's usage display can still refresh every five seconds.
- Bounded concurrent reset checks and non-blocking async networking, with safe GET retries and no automatic retry of credit-spending POST requests.
- Compact 2x2 account panel layout for three or four saved accounts.
- Bright active account card and dim inactive accounts, with green, orange, and red status colours retained across cards.
- Dropdown showing 5-hour usage for all saved accounts.
- Email-based switching, avoiding brittle numeric selectors.
- Optional panel-card confirmation plus switch previews showing target 5-hour and weekly usage.
- Codex relaunch after switching so Desktop picks up the new account.
- Optional **Follow Codex / ChatGPT** lifecycle mode: opens the switcher when either desktop surface opens, then closes it only after both have been absent for 5 seconds. The grace period keeps the switcher alive during its own account-change relaunch.
- Configurable notification and auto-switch thresholds.
- Optional auto-switching from a low-usage active account to another saved account.
- Transactional switching with verification and automatic rollback on failure.
- Best-account scoring using both usage windows, reset credits, login health, and an anti-bounce cooldown.
- Event-driven native lifecycle monitoring without a two-second polling loop.
- Privacy-safe local switch history and copyable diagnostics.
- Clipboard restoration after automatic continuation.
- `Switch Now` notification action for low usage.
- Refresh interval controls for active and idle states.
- In-panel settings for display mode, launch-at-login, usage reminders, card confirmation, auto-switching, auto-resume, account actions, health checks, update checks, and maintenance.
- A safe Route B prototype with selectable OpenRouter text and visual helper profiles plus explicit ready, test-required, and blocked capability labels.
- Account backup cleanup.
- Automatic retention of the ten newest authentication backups per account.
- Dynamic Computer Use plugin discovery instead of a hard-coded plugin version.
- Helper-command timeouts so a stalled dependency cannot leave the menu bar permanently refreshing.
- No bundled credentials, tokens, account registry, or usage snapshots.

## Route B Prototype

Open **Settings → OpenRouter** to inspect and switch the selected secondary-lane profile.

This first prototype deliberately stops at profile selection:

- `Text Helper` uses the public model identifier `z-ai/glm-5.2`.
- `Visual Helper` uses the public model identifier `z-ai/glm-5v-turbo`.
- Green labels are ready for the profile's narrow purpose.
- Orange labels require a smoke test before they can be enabled.
- Red labels are blocked.
- Selecting a profile stores only its public profile ID in macOS preferences.

Route B does not make provider requests, accept or store provider keys, change Codex configuration, or replace normal Codex Desktop account switching. Native Codex remains the default for sends, uploads, account changes, invoices, and other live operations.

## Requirements

- macOS 14 or later.
- Xcode command line tools / Swift compiler.
- ChatGPT Desktop installed at `/Applications/ChatGPT.app`; legacy `/Applications/Codex.app` remains supported.
- [`codex-auth`](https://www.npmjs.com/package/@loongphy/codex-auth) installed and configured.

Install `codex-auth`:

```bash
npm install -g @loongphy/codex-auth
```

Add accounts:

```bash
codex-auth login
```

Repeat login for each account you want to switch between.

## Build

```bash
./build.sh
```

The app bundle is created at:

```text
build/Codex Account Switcher.app
```

Run the infrastructure and reset-logic regression checks with:

```bash
./run-tests.sh
```

## Install

```bash
./install.sh
```

This installs to:

```text
/Applications/Codex Account Switcher.app
```

## Run Without Installing

```bash
./run.sh
```

## How Switching Works

Codex Desktop needs to be relaunched after an account switch before the newly active account takes effect. This app handles that relaunch as part of switching.

The app uses `codex-auth switch <email-query>` internally, so it does not depend on account numbers such as `01` or `02`.

## Privacy Notes

This repository does not contain account credentials, tokens, account IDs, local auth files, usage registries, or personal account data.

Screenshots are generated from demo account data and should stay that way for future releases.

Usage refresh depends on `codex-auth` and normal saved ChatGPT account sessions. API token mode is disabled in the current local build.

## Versions

- [v1.8.2](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.8.2)
- [v1.7](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.7)
- [v1.6.1](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.6.1)
- [v1.5](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.5)
- [v1.4](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.4)
- [v1.34](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.34)
- [v1.33](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.33)
- [v1.32](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.32)
- [v1.31](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.31)
- [v1.3](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.3)
- [v1.2.2](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.2.2)
- [v1.2.1](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.2.1)
- [v1.2](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.2)
- [v1.1](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.1)
- [v1.0](https://github.com/lordydord/Codex-Account-Switcher/releases/tag/v1.0)

## Unsigned Distribution

Version 1.8.2 uses ad-hoc code signing and SHA-256 checksums. This improves local bundle integrity without a paid Apple Developer account, but it cannot provide Apple notarization or remove every first-launch Gatekeeper warning. Build a checked package with `./package-release.sh` and verify an installation with `./verify-install.sh`.

## Roadmap Ideas

- Developer ID signing and notarization if the project later gains an Apple Developer account.
- Homebrew cask.
- Preferences window if the menu grows too large.
- Optional sound or banner style settings for switch prompts.

## License

MIT. See [LICENSE](./LICENSE).
