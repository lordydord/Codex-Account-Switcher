# Changelog

## 3.0 - 2026-09-28

A full redesign in the macOS 27 Liquid Glass design language.

- Rebuild the panel as a single Liquid Glass sheet (native `NSGlassEffectView` on macOS 26 and later, which follows the system transparency setting) with standard corner radius and a uniform toolbar.
- Replace the scattered back buttons with an Accounts / Resets / Settings tab control, with a live reset-credit count.
- Show the active account with Activity-style rings for the 5-hour and weekly windows, and list other accounts as compact rows with usage meters, a "Best next" hint and a single Switch button.
- Move switch confirmation inline ("Relaunch ChatGPT as B?" with Cancel and Confirm) and show signed-out accounts with a Sign In action.
- Redesign the menu bar item as a small usage ring plus a monochrome label, turning red only when usage is nearly exhausted, with a spinner while switching or applying a reset.
- Rebuild Settings as grouped lists with native switches and pop-up buttons, a live menu bar preview, per-account Rename and Log Out, and a compact health summary.
- Rebuild Resets with a summary of available credits, next expiry and urgency breakdown, then per-account credits with colour-coded days left.
- Size the panel from its content and scroll long views instead of clipping them.
- Add a More menu for account and maintenance actions, and support light and dark appearances throughout.
- Remove roughly 1,600 lines of legacy panel drawing code, plus the retired API-mode and hidden legacy menu code (about 2,400 lines in total).

Performance:

- Resolve `codex-auth` once and cache it. Previously every command first launched `codex-auth --version`, including on the main thread each time the panel was drawn.
- Only rebuild the open panel when something it shows has changed, instead of recreating every view on each background refresh.
- Stop rebuilding a hidden menu on every refresh.
- Relaunch ChatGPT by watching for the real process state instead of fixed waits, so switches finish several seconds sooner.
- Skip reset-credit re-downloads when opening the panel or after a switch; they refresh on their normal five-minute schedule or when you press Refresh.
- Wait for helper commands with an exit notification instead of polling every 20 ms.
- Use a dedicated, cache-free network session so usage data is always fresh and no token-bearing responses are written to disk.
- Index saved sign-ins once instead of re-reading every auth file for each lookup, and keep account labels in memory.
- Allow macOS to coalesce timer wake-ups, and reuse spinner frames while switching.

## 1.8.3.3 - 2026-08-25

- Make five-hour usage the menu-bar default again.
- Migrate existing weekly menu-bar preferences once, while preserving the option to switch back manually afterward.

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
