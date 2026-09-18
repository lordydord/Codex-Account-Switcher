# Codex Account Switcher Project Notes

This project is a sanitized public version of Graham's local Codex Account Switcher menu-bar app.

## Current project baseline (August 2026)

- Work from the current `main` branch and preserve the existing dual-language SwiftUI/AppKit implementation. The app supports English and Russian through the Settings language switcher; every new user-facing string must be added to both localization paths.
- The account panel must keep both usage windows visible: the five-hour limit and the weekly limit. These are remaining percentages, not consumed percentages. Do not replace the two bars with a single limit indicator or change the existing layout metrics without an explicit UI request.
- The unused API Mode feature was removed. Do not reintroduce API Mode, provider-mode toggles, or related production symbols unless explicitly requested. The current app switches Codex accounts through the existing `codex-auth` flow.
- `AppDelegate` is `@MainActor`-isolated. AppKit objects, panel state, timers, menu state, and UI settings stay on the main actor. Command execution, file/auth reads, parsing, process/plugin maintenance, and other pure I/O helpers are explicitly `nonisolated`; background results must cross back to the main actor as value data.
- Refreshes are generation-guarded (`refreshGeneration`) so an older asynchronous result cannot overwrite a newer refresh. Preserve this protection when changing account refresh or usage-fetch code.
- The MainActor refactor is documented in `docs/superpowers/specs/2026-08-26-mainactor-refactor-spec.md` and `docs/superpowers/plans/2026-08-26-mainactor-refactor.md`. Read those before changing concurrency boundaries.
- The latest verified MainActor refactor was pushed to `main` as commit `878f505`; this hash is a historical baseline, not a reason to reset or discard later user work.

Rules for future work:

- Do not commit local Codex auth files, account registries, tokens, account IDs, email addresses, or build artifacts.
- Read and follow `docs/design-system.md` before creating or redesigning any screen or reusable UI component. The product direction is dark-only, warm Native Glass, and SwiftUI-first for new content.
- Keep `build/`, `.swiftpm/`, `.build/`, and module caches ignored.
- The public toolbar account label must remain generic: use the first alphanumeric character from the email address unless the user sets a custom label in the app.
- Keep switching based on account email queries, not padded numeric selectors such as `01` or `02`.
- The app depends on `codex-auth`; do not vendor or copy private `~/.codex/accounts` data into the repository.
- Resolve saved auth files by the registry `account_key` (base64 without padding), never by `chatgpt_account_id` alone: workspace IDs can be shared by different users. Preserve the exact key through token refresh and require an exact active-key match before mirroring tokens into active auth.
- Build verification is `./build.sh`.
- Install verification is `./install.sh`, then confirm the app runs from `/Applications/Codex Account Switcher.app`.
- Current local app update is v1.8.5 / build 185 with a numbered Native Glass account list, native account-row swipe actions, both five-hour and weekly remaining-limit bars, semantic weekly-remaining gradients, four-second inline manual-switch confirmation, and a pool-wide usage pace forecast backed by current usage plus a local 56-day history, plus OAuth token auto-refresh, reset-credit expiry notifications, all-account live usage refresh, last-known-good usage retention, post-reset missing-window handling, extended reset verification, compact generation-safe switch/reset status animations, cached concurrent reset-credit refreshes, bounded async networking, command timeouts, dynamic Computer Use discovery, automated infrastructure tests, backup pruning, verified reset-credit redemption, transactional verified switching, rollback, best-account scoring, a native lifecycle monitor, privacy-safe diagnostics, clipboard restoration, local ad-hoc signing, and the current MainActor isolation. API Mode and the Route B/provider prototype are not part of the active production surface.

## Development workflow

- Do UI work in a git worktree under `.worktrees/<branch>` (gitignored); keep the main checkout clean.
- UI change cycle: edit in worktree → `./build.sh` → `./install.sh` (copies the app into `/Applications` and re-signs) → **kill the running `CodexAccountSwitcher` process and relaunch via `open`** — the running app keeps the old binary in memory, so overwriting the bundle alone never updates the visible UI.
- `./verify-install.sh` checks the installed bundle, ad-hoc signature, and native lifecycle monitor.
- `./run-tests.sh` runs the infrastructure suite, AppKit/SwiftUI interaction tests, and the built app's `--self-test-reset-logic`. Pure business rules belong outside views so they remain independently testable.

## Language & percent semantics (confusion source)

- On the current toolchain (Swift 6.3.3, swift-driver 1.148.6) **unqualified access to `static` members from an instance context is a compile error** (`static member ... cannot be used on instance of type ...`) — verified even on plain classes. Always qualify: `AccountPanelLayout.rowHeight` or `Self.member`. Never convert `let`/`var` instance constants to `static` and keep calling them bare.
- Screen-level geometry lives in `private enum AccountPanelLayout` (top of `main.swift`): usage width/insets, normal and confirmation row heights, row gap, pace/reset sections, and bottom bar. `preferredSize(mode:accountCount:showsPace:maximumHeight:)` is the single source of panel sizing; the account region alone scrolls after ten rows or earlier on short screens. Reusable SwiftUI content must use relative layout rather than adding construction-time coordinates to this enum.
- `AccountSwitcherPanelView` is flipped (isFlipped = true, y grows downward); the panel is a borderless `NSPanel`, live-refreshed by rebuilding the view controller (`refreshAccountPanelContent()`), which must be followed by `positionAccountPanel()` while visible so size/anchoring follow account changes.
- **`fiveHourUsedPercent` / `weeklyUsedPercent` on `CodexAccount` are REMAINING percents** (parsed from `remainingPercent`, displayed as "X% left"); they are NOT used amounts. The main account-list fill uses the remaining value directly and maps `26…100%` to mint→blue, `11…25%` to gold→orange, and `0…10%` to coral→red.

Potential v2.5 idea:

- Consider a separate "Cheap Agent" / Route B mode instead of trying to make a third-party model fully replace Codex Desktop.
- The app could store provider profiles in Keychain and launch a local helper that exposes only a limited, tested tool set: selected MCP calls, simple file/folder checks, Ego Browser or Chrome browser reads/clicks, page scraping, and harmless draft/check workflows.
- Treat each third-party model as capability-tested rather than trusted by default. Show capability states such as chat only, MCP-safe, browser-safe, and live-ops unsafe.
- Require smoke tests before enabling browser or MCP use: open/read a page, perform a harmless click/type, call one selected MCP, process the tool result, and continue coherently.
- Keep native Codex as the fallback and default for public, irreversible, account-sensitive, or upload/send tasks such as Traxsource, Kit, Prime, SoundCloud, Bandcamp, invoices, and account switching.
- Keep all provider keys, local routing files, account emails, and actual auth state out of the public repository.
- The minimal prototype now implements profile selection only. It stores a public profile ID in `UserDefaults`; provider execution, key entry, and tool enablement remain disabled.
