# Changelog

## Unreleased

- Redesign Settings as a compact SwiftUI root and Advanced screen with native macOS-style switches, inline notification thresholds, and a menu-bar five-hour percentage for the active account; update checks now use the smashlight repository.
- Show five-hour and weekly remaining limits together in every account row, with a primary labelled five-hour meter, a subdued weekly meter, and the ordered `five-hour / weekly` percentage pair.
- Replace the daily minimum-remaining pool chart with dynamic daily-spend bars normalized across the weekly account pool, including a 14.3% pace reference, semantic spend colors, selected-bar emphasis, and localized compact hover details.
- Add swipe-to-delete for inactive saved accounts, using the selected account's full email and never the remove-all command; keep trailing percentages and confirmation buttons inside compact rows, and tint the reset-chance bolt yellow.
- Tighten the pool verdict card while preserving its full forecast timeline, add separation from reset chance, center the margin badge, and give the Refresh and Quit buttons more horizontal padding.
- Use native `NSTableView` row actions so clicks and destructive swipes map to the exact account, keep the verdict available from current usage even before history accumulates, and fall back to a bounded HTTP/1.1 forecast request when URLSession is blocked by a local proxy route.

## 1.8.5 - 2026-08-15

- Add a pool-wide usage pace forecast for the weekly window: the app samples the remaining weekly pool of all saved accounts every 30 minutes into a local 56-day JSONL history, then draws a CodexBar-style utilization chart at the bottom of the account panel.
- Replace raw pool/burn forecast text with an ordered Enough / Not Enough / Collecting verdict card.
- Add immediate Russian/English switching for the main panel, defaulting to Russian for new installations.
- Persist the weekly reset timestamps captured from live usage snapshots so the forecast can compare EOL against the actual reset date.

## 1.8.4 - 2026-08-15

- Auto-refresh expired or aging Codex OAuth tokens: proactive refresh when the token is older than 3 days, plus an automatic one-shot retry after a 400/401 usage response. Updated tokens are written back to the account auth file and mirrored into the active `~/.codex/auth.json` when the active account refreshes.
- Notify when auto token refresh finally fails (per-account 6-hour cooldown) so a dead account is re-logged in with `codex-auth login` instead of silently going stale.
- Add an optional "Credit expiry" automation toggle that alerts 3 days before saved reset credits expire, deduplicated per credit inventory.

## 1.8.3.1 - 2026-07-13

- Treat an absent, not-yet-started post-reset usage window as 100% available instead of retaining a stale 0% value.
- Make manual refresh query the direct live usage endpoint for the active account.
- Continue pending reset verification for several minutes while ChatGPT applies the new limits.
- Close the status-level account panel and present reset-spending confirmation centrally so it cannot appear underneath the switcher.

## 1.8.3 - 2026-07-12

- Keep switch, reset, and verification progress in a compact single-line menu bar state.
- Use generation checks so an older delayed callback cannot clear a newer status animation.
- Restore the normal active-account display cleanly after switch or reset verification.
- Add a full GitHub Pages product site and refresh the repository presentation.

## 1.8.2 - 2026-07-11

- Add cached concurrent reset-credit refreshes and bounded asynchronous networking.
- Add command timeouts, dynamic Computer Use discovery, regression tests, and backup pruning.
- Improve verified reset redemption and direct live usage refresh.
- Ship the graphite control-deck interface and the non-executing Route B profile prototype.

## 1.7 - 2026-07-10

- Add transactional account switching with verification and rollback.
- Add best-account scoring, a native lifecycle monitor, privacy-safe diagnostics, and clipboard restoration.
- Harden ad-hoc signing, packaging, and extracted-archive verification.

Earlier builds remain available on the [GitHub Releases page](https://github.com/lordydord/Codex-Account-Switcher/releases).
