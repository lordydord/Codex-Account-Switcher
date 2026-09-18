# Modern Settings Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy AppKit Settings screen with a compact SwiftUI root/Advanced flow using native macOS controls, remove misleading menu-bar usage percentages, and persist editable notification settings.

**Architecture:** Keep `AppDelegate` responsible for UserDefaults, notifications, refresh scheduling, update checks, maintenance commands, and panel lifecycle. Add a small SwiftUI Settings surface hosted inside the existing `AccountSwitcherPanelView`; pass values and explicit callbacks into the view. Put pure validation/presentation helpers in `AppInfrastructure.swift` so they can be tested without launching AppKit.

**Tech Stack:** Swift 5, SwiftUI, AppKit/`NSHostingView`, UserDefaults, existing infrastructure and AppKit test harness, macOS 14+ deployment target.

## Global Constraints

- Use the existing `PanelTheme` semantic colors and design-system spacing; do not introduce a parallel styling framework.
- Boolean controls must use genuine SwiftUI `Toggle` with the platform switch style; do not recreate the track or thumb.
- All tappable rows use `Button`; all numeric fields use intrinsic localized layout and preserve a valid saved value on invalid input.
- Remove the `Weekly / 5H` Settings selector and the usage percentage from the status item; account rows remain the source of both limits.
- Keep update checks and release links scoped to `smashlight/Codex-Account-Switcher`.
- Preserve existing callback behavior for auto-switch, plugin capture, diagnostics, and account operations unless this plan explicitly changes their surface.
- Respect Reduce Motion and never add perpetual decorative animations.
- Do not commit or push implementation until the user visually approves the installed app.

## File Map

- **Create:** `Sources/SettingsView.swift` — SwiftUI root and Advanced screen, section/row components, native controls, transitions, accessibility.
- **Modify:** `Sources/AppInfrastructure.swift` — pure validation and presentation helpers for numeric settings and Advanced summaries.
- **Modify:** `Sources/Models.swift` — remove obsolete Settings actions/display mode cases and add narrow Settings callback/value types only if needed by the hosted view.
- **Modify:** `Sources/Localization.swift` — Russian/English Settings and validation strings.
- **Modify:** `Sources/main.swift` — host SwiftUI Settings, remove legacy Settings construction, wire callbacks/UserDefaults, remove status usage presentation and old Settings-only dialogs/menu actions, parameterize reset-credit expiry, point update checks at `smashlight`.
- **Modify:** `Tests/InfrastructureTests.swift` — pure policy, localization, update URL, expiry-window, and status-presentation tests.
- **Modify:** `Tests/AppKitInteractionTests.swift` (or the repository's current AppKit test file) — Settings action routing and hosted-content lifecycle checks where existing harness permits.
- **Modify:** `docs/design-system.md` — record the migrated Settings composition and native control rules.
- **Modify:** `CHANGELOG.md` — add an Unreleased entry after implementation is verified.

---

### Task 1: Define tested settings value policies

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produce `SettingsNumericPolicy` (or an equivalently narrow existing-style helper) with `reminderThresholdRange = 1...99`, `creditExpiryLeadDaysRange = 1...30`, defaults `10` and `3`, and a function that accepts a draft string plus a range and returns either a normalized integer or a validation failure.
- Produce a pure expiry interval helper that converts lead days to `TimeInterval`.
- Produce pure Advanced/root summary text helpers only if the SwiftUI view would otherwise duplicate localization/formatting logic.

- [ ] **Step 1: Write failing tests** for `1`, `99`, `0`, `100`, blank, whitespace, non-numeric reminder drafts; the same cases for `1`, `30`, `0`, `31` credit-expiry days; and `3` days → `259200` seconds.
- [ ] **Step 2: Run the infrastructure suite** with `./run-tests.sh`; confirm the new assertions fail for missing symbols or incorrect behavior.
- [ ] **Step 3: Implement the smallest pure policy** with no UserDefaults or AppKit dependency. Do not silently coerce invalid text into a valid value; return a failure so the field can preserve its draft.
- [ ] **Step 4: Re-run `./run-tests.sh`** and confirm all existing and new assertions pass.
- [ ] **Step 5: Commit** `test: define settings value policies`.

### Task 2: Add localized SwiftUI Settings components

**Files:**
- Create: `Sources/SettingsView.swift`
- Modify: `Sources/Localization.swift`
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- `SettingsScreenView` receives `language`, `settings` values, and explicit callbacks for root navigation, Advanced navigation, language, toggles, threshold/lead-day commits, refresh interval changes, update/plugin/diagnostics actions, and auto-switch editing.
- `AdvancedSettingsView` receives the same injected values needed for its fields and callbacks.
- Components: `SettingsHeader`, `SettingsSection`, `SettingsToggleRow`, `SettingsNavigationRow`, `SettingsNumericFieldRow`.

- [ ] **Step 1: Add localization keys/tests** for both languages: Settings/Advanced titles, section names, row titles/subtitles, Done/Back, `%`/days suffixes, validation messages, refresh labels, maintenance actions, and accessibility descriptions. Assert no newly visible Settings string is English-only.
- [ ] **Step 2: Add the root view** using a single `ScrollView` only when needed, existing theme colors, intrinsic-width layout, and section cards. The root contains language, four automation rows, and Advanced navigation; it contains no `5H / Weekly` selector, Health section, Add Account, or footer grid.
- [ ] **Step 3: Use native controls**: `Toggle` with `.toggleStyle(.switch)` and native segmented `Picker`. Do not use `MiniSwitchButton` or custom switch drawing in the SwiftUI path.
- [ ] **Step 4: Add Advanced view** with right-aligned numeric fields, suffixes, active/idle refresh pickers, and maintenance action rows. Commit on Return/focus loss, restore on Escape, and show an inline validation message without changing the saved value on failure.
- [ ] **Step 5: Add navigation/motion** with a short directional transition, smooth panel-size animation hook, hover surface emphasis, and `accessibilityReduceMotion` fallback to opacity-only movement.
- [ ] **Step 6: Add accessibility grouping and labels** for every row, field, switch, and maintenance action. Keep keyboard order equal to visual order.
- [ ] **Step 7: Build the app** with `./build.sh` to catch SwiftUI type and localization integration errors before AppDelegate wiring.
- [ ] **Step 8: Commit** `feat: add native SwiftUI settings screens`.

### Task 3: Persist advanced notification settings

**Files:**
- Modify: `Sources/main.swift`
- Modify: `Sources/AppInfrastructure.swift` if the existing policy needs a shared call site
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Add `creditExpiryLeadDaysDefaultsKey` and `creditExpiryLeadDays` with default `3`, clamped only when reading a stored integer; setters use the tested policy range.
- Replace the fixed `creditExpiryWindow` property with a computed `TimeInterval` derived from `creditExpiryLeadDays`.
- Provide callbacks from `AccountSwitcherPanelView`/`SettingsScreenView` that update `reminderThreshold` and `creditExpiryLeadDays`, then refresh visible panel content.

- [ ] **Step 1: Add failing persistence/expiry tests** for absent lead days (3), stored 1/30, invalid stored values, and notification candidate selection at just inside/outside the configured window.
- [ ] **Step 2: Run targeted infrastructure tests** and confirm the fixed three-day implementation fails the configurable cases.
- [ ] **Step 3: Implement the UserDefaults property and replace all notification calculations** that currently use `3 * 24 * 60 * 60`.
- [ ] **Step 4: Route valid SwiftUI field commits into these properties**; use the existing reminder threshold setter for `1...99`.
- [ ] **Step 5: Re-run the full infrastructure suite** and confirm no notification behavior outside the requested window changed.
- [ ] **Step 6: Commit** `feat: persist configurable notification lead time`.

### Task 4: Host SwiftUI Settings inside the existing panel

**Files:**
- Modify: `Sources/main.swift`
- Modify: `Sources/Models.swift` if obsolete Settings action cases are removed
- Test: `Tests/AppKitInteractionTests.swift` (or current AppKit test harness)

**Interfaces:**
- `AccountSwitcherPanelView` receives Settings values/callbacks and hosts `SettingsScreenView` in an `NSHostingView` for `.settings` mode.
- AppKit remains the owner of the panel frame, background, activation, and mode lifecycle.

- [ ] **Step 1: Add an AppKit interaction test** that creates the Settings panel path and asserts the hosted SwiftUI content is installed, the root/Advanced callbacks change `AccountPanelMode`, and Done returns to usage.
- [ ] **Step 2: Run the AppKit test suite** and confirm it fails while `buildSettingsContent()` still owns the screen.
- [ ] **Step 3: Add the hosting method** with a stable frame/autoresizing behavior and injected callbacks; preserve dark/light theme values and localized content.
- [ ] **Step 4: Replace the fixed-coordinate `buildSettingsContent()` path** with the hosted view. Adjust Settings preferred height/width to the adaptive root and Advanced requirements while keeping the existing usage/reset/API sizes intact.
- [ ] **Step 5: Remove only Settings-specific legacy builders** (`settingsHeader`, `settingsSection`, `segmentedRow`, `settingToggleRow`, `settingsFooter`, `healthSection`) after confirming no other mode uses them.
- [ ] **Step 6: Re-run AppKit tests and `./build.sh`**.
- [ ] **Step 7: Commit** `refactor: host settings with SwiftUI`.

### Task 5: Remove misleading menu-bar usage mode and legacy Settings actions

**Files:**
- Modify: `Sources/main.swift`
- Modify: `Sources/Models.swift`
- Modify: `Sources/Localization.swift` only if old menu strings become unused
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Status item presentation becomes a compact icon-only state with existing reset/switching/error states preserved where they carry operational meaning.
- `UsageDisplayMode`, `usageMode`, `usageWeekly`, and `usageFiveHour` no longer participate in Settings or status-title calculation.

- [ ] **Step 1: Add failing tests** asserting the normal status-item presentation contains no usage percentage, no `UsageDisplayMode` dependency, and that Settings action decoding no longer exposes the two mode actions.
- [ ] **Step 2: Run targeted tests** and confirm the old status title/mode path fails those assertions.
- [ ] **Step 3: Remove the normal account usage title construction** from `statusAttributedTitle`, `statusTitleKey`, `toolbarStatusText`, and related status-length calculations. Keep reset-status and switching/error presentation intact if currently visible.
- [ ] **Step 4: Remove Settings/menu actions and old mode dialogs** (`showMenuBarDisplayDialog`, `setUsageMode`, mode menu items, and obsolete `UsageDisplayMode` code) only after checking references with `rg`.
- [ ] **Step 5: Rebuild the menu** so it contains account actions and maintenance commands but no Weekly/5H mode choice.
- [ ] **Step 6: Update the tests and run both suites**.
- [ ] **Step 7: Commit** `remove: retire menu-bar usage mode`.

### Task 6: Correct update repository and Advanced maintenance wiring

**Files:**
- Modify: `Sources/main.swift`
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Centralize the owner/release constants as `https://api.github.com/repos/smashlight/Codex-Account-Switcher/releases/latest` and `https://github.com/smashlight/Codex-Account-Switcher/releases`.
- Advanced update action uses the existing async comparison flow and opens only the returned `smashlight` release URL or the owner releases page.

- [ ] **Step 1: Add failing URL tests** for API endpoint owner, fallback releases page, and rejection of the old `lordydord` owner.
- [ ] **Step 2: Run targeted tests** and confirm the current endpoint fails because it uses `lordydord`.
- [ ] **Step 3: Replace the endpoint/fallback constants** and preserve existing version comparison/error reporting.
- [ ] **Step 4: Wire Advanced rows** for refresh settings, updates, plugin capture, and diagnostics. Remove the old Settings footer actions and old reminder/refresh dialog entry points from this screen; keep menu commands only if they remain intentionally supported.
- [ ] **Step 5: Run tests and build**.
- [ ] **Step 6: Commit** `fix: scope updates to project repository`.

### Task 7: Documentation, full verification, and install for visual review

**Files:**
- Modify: `docs/design-system.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update the design-system Settings section** with the SwiftUI screen/section composition, native switch rule, Advanced field behavior, and icon-only menu-bar rule. Do not rewrite unrelated design guidance.
- [ ] **Step 2: Add one Unreleased changelog entry** describing the modern Settings screen, configurable notification values, and removal of misleading menu-bar usage percentages.
- [ ] **Step 3: Run `./run-tests.sh`** and record the passing assertion count.
- [ ] **Step 4: Run the AppKit interaction suite** and record the passing assertion count.
- [ ] **Step 5: Run `./build.sh`** and confirm the signed app bundle builds.
- [ ] **Step 6: Run `./install.sh`** to replace `/Applications/Codex Account Switcher.app`, terminate any stale process if required by the script, and relaunch the installed app.
- [ ] **Step 7: Run `./verify-install.sh`** and compare the installed executable hash with the build output.
- [ ] **Step 8: Report the installed path, test/build results, and visual-review checklist to the user. Do not commit or push implementation changes yet; wait for visual approval.

## Self-review

- Every approved spec decision maps to Tasks 1–7: native SwiftUI controls (2), root/Advanced IA (2/4), configurable values (1/3), icon-only menu bar (5), repository ownership (6), localization/accessibility/motion (2), documentation and install (7).
- No new external dependency or speculative architecture layer is introduced.
- Invalid numeric drafts preserve the last valid value; stored integers are normalized through explicit ranges.
- The status-item removal is scoped to normal usage display; reset/switching/error states remain available when operationally meaningful.
- No task depends on a placeholder or an undefined helper; each newly introduced interface is named in its task.
