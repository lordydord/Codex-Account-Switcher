<p align="center">
  <a href="https://lordydord.github.io/Codex-Account-Switcher/">
    <img src="docs/assets/readme-hero.png" alt="Codex Account Switcher product website showing the macOS account panel" width="100%">
  </a>
</p>

<p align="center">
  <a href="https://lordydord.github.io/Codex-Account-Switcher/"><strong>Product site</strong></a>
  &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="https://github.com/lordydord/Codex-Account-Switcher/releases/latest"><strong>Download</strong></a>
  &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#build-from-source"><strong>Build from source</strong></a>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111827?style=flat-square&logo=apple&logoColor=white">
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/Swift-5.9%2B-f97316?style=flat-square&logo=swift&logoColor=white">
  <img alt="Native AppKit" src="https://img.shields.io/badge/Native-AppKit-1f2937?style=flat-square">
  <img alt="Current release 1.8.5" src="https://img.shields.io/badge/release-v1.8.5-16a34a?style=flat-square">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-1f2937?style=flat-square">
</p>

# Codex Account Switcher

Codex Account Switcher is a native macOS menu bar companion for people who use more than one ChatGPT account with Codex. It shows live account limits, makes the active account obvious, verifies switches, and can help continue work when a quota runs out.

## The useful parts, immediately

- **Live account limits** for five-hour and weekly usage windows.
- **Fast account switching** from a compact numbered Native Glass list that scales from one account to many.
- **Weekly capacity at a glance** with semantic gradients and inline switch confirmation.
- **Verified changes** with target checks and automatic rollback on failure.
- **Reset-credit tracking** across saved accounts, grouped by expiry urgency.
- **Optional auto-switching** when the active account reaches a chosen threshold.
- **Optional task continuation** after a successful automatic switch.
- **Desktop companion auto-launch** when Codex or ChatGPT opens. The switcher stays running when the desktop app closes, including during account switching and plugin repair.
- **Local diagnostics** that omit credentials, account IDs, and private usage snapshots.

<p align="center">
  <img src="assets/screenshot-menubar.png" alt="Codex Account Switcher menu bar status with privacy-safe demo labels" width="760">
</p>

<table>
  <tr>
    <td width="50%"><img src="assets/screenshot-panel.png" alt="Account panel showing four privacy-safe demo accounts"></td>
    <td width="50%"><img src="assets/screenshot-settings.png" alt="Settings screen showing display, automation, and health controls"></td>
  </tr>
</table>

<p align="center">
  <img src="assets/screenshot-resets.png" alt="Reset credits grouped by privacy-safe demo account with expiry colours" width="390">
</p>

## Install v1.8.5

1. Download `Codex-Account-Switcher-v1.8.5.zip` from the [latest release](https://github.com/lordydord/Codex-Account-Switcher/releases/latest).
2. Extract the archive and move `Codex Account Switcher.app` to Applications.
3. Right-click the app and choose **Open** on first launch if macOS asks.
4. Install and configure [`codex-auth`](https://www.npmjs.com/package/@loongphy/codex-auth):

```bash
npm install -g @loongphy/codex-auth
codex-auth login
```

Repeat `codex-auth login` for each account you want to use.

The release is ad-hoc signed and includes a SHA-256 checksum. It is not Apple-notarized, so macOS may show the standard warning for independently distributed software.

## Requirements

- macOS 14 or later
- ChatGPT Desktop in `/Applications/ChatGPT.app`
- `codex-auth` with at least one saved ChatGPT account
- Xcode command line tools only when building from source

## How switching stays safe

Codex Desktop must relaunch after an account change. The switcher asks `codex-auth` to change accounts, verifies that the requested target became active, then relaunches ChatGPT. If verification fails, it restores the previous account and reports the failure.

Automatic selection considers both usage windows, login health, reset credits, and a cooldown that prevents rapid switching between accounts.

## Reset credits

The reset-credit screen reads available credits for every saved account, groups them by account, and highlights expiry urgency. Spending a credit always requires confirmation. The switcher does not automatically retry a spending request and only reports success after the credit and refreshed usage state agree.

## Build from source

```bash
git clone https://github.com/lordydord/Codex-Account-Switcher.git
cd Codex-Account-Switcher
./run-tests.sh
./build.sh
./install.sh
./verify-install.sh
```

The built app is written to `build/Codex Account Switcher.app` and the install script copies it to `/Applications`.

Create a checked release archive with:

```bash
./package-release.sh
```

## Privacy

This repository does not contain ChatGPT credentials, auth tokens, account IDs, account registries, real email addresses, or private usage snapshots. Public screenshots use demo accounts and placeholder labels.

The switcher works with local `codex-auth` sessions. It does not add analytics, advertising, or a separate cloud account.

## Version 1.8.5

Version 1.8.5 forecasts how long the pooled five-hour quota lasts: it samples the remaining pool into a local history, draws a CodexBar-style utilization chart in the panel, and tells you whether the pool will survive until the weekly reset.

Read the full [1.8.5 release notes](docs/release-notes/v1.8.5.md), or see every published build on the [Releases page](https://github.com/lordydord/Codex-Account-Switcher/releases).

## Project map

```text
Sources/main.swift             AppKit application and account workflows
Sources/Models.swift           Shared app models and visual theme
Sources/PanelComponents.swift  Account panel views and controls
Sources/AccountRowView.swift   Adaptive SwiftUI account-row content
Sources/AppInfrastructure.swift  Networking, commands, and shared infrastructure
Sources/LifecycleMonitor.swift Native ChatGPT lifecycle companion
Tests                         Infrastructure and reset-logic regression checks
docs/design-system.md         Canonical UI tokens, components, and redesign rules
docs                          GitHub Pages product site
assets                        Privacy-safe app screenshots and repository artwork
```

## License

MIT. See [LICENSE](LICENSE).

### Start limits (MVP)

The account panel's **Start limits** button sends one short `gpt-5.6-luna` request with `low` reasoning effort per saved account, in batches of four. OMP is not required. Each row shows waiting, sending, refreshing token, completed, or failed; usage refreshes after the batch. Results remain inline for 12 seconds after completion, then the reset date returns. No result dialog is shown. A new run cancels the previous status-clear timer. Closing and reopening the panel retains the current run. The button is disabled while running.

“Request completed” confirms a completed inference response; the server controls whether a new five-hour window starts. An already running window is not reset. Requests consume a small amount of usage. Network failures are not automatically replayed because the server may already have accepted the request. The Codex endpoint does not accept `max_output_tokens`; the prompt requests only “OK”. No response text or tokens are persisted.

Business/Team accounts with a weekly-only API limit show the weekly remaining percentage in the menu bar and `--` for the unavailable five-hour limit. Accounts with both windows keep the five-hour menu-bar percentage.
