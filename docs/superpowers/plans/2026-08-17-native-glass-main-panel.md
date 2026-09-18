# Native Glass Main Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the split account-card UI with one numbered Native Glass account list, semantic remaining-capacity gradients, inline manual-switch confirmation, and fixed aggregate sections for every account count.

**Architecture:** Keep server data, history, forecasts, and the switch transaction unchanged. Add small pure presentation policies to `AppInfrastructure.swift` for testable thresholds, row capacity, and confirmation transitions; adapt the existing AppKit components and `AccountSwitcherPanelView` to consume those policies. The list alone lives in an `NSScrollView`, while the pool chart, reset chance, and toolbar remain fixed.

**Tech Stack:** Swift 6, AppKit, SwiftUI Charts, macOS 14 fallback materials, macOS 26 `NSGlassEffectView`, custom shell-based Swift infrastructure tests.

## Global Constraints

- Target panel width is `520 pt` with an `8 pt` minimum visible-screen margin.
- Use one compact layout for `1…N` accounts and remove five-hour UI from the main panel only.
- Show up to ten normal rows without scrolling when screen height permits; scroll only the account list.
- Numbers are visual top-to-bottom positions and have no persistence or keyboard shortcuts.
- Manual panel switches always require four-second Inline Buttons confirmation.
- Weekly remaining bands are `0–10`, `11–25`, and `26–100` percent.
- Preserve current account ordering, data fetching, pool history schema, forecast math, reset-credit behavior, automatic-switch behavior, and plugin synchronization.
- Keep macOS 14 as the deployment floor and introduce no dependencies.
- Make surgical changes and keep existing tests green after every task.

---

### Task 1: Weekly remaining presentation policy

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `enum WeeklyRemainingBand: Equatable { case unknown, healthy, warning, critical }`
- Produces: `WeeklyRemainingBand.classify(_ remainingPercent: Int?) -> WeeklyRemainingBand`
- Consumed later by: Native Glass color mapping and pool-chart tint mapping.

- [ ] **Step 1: Register and write the failing boundary test**

Add `testWeeklyRemainingBand()` to `InfrastructureTests.main()` and add:

```swift
private static func testWeeklyRemainingBand() {
    expect(WeeklyRemainingBand.classify(nil) == .unknown, "missing remaining usage should be neutral")
    expect(WeeklyRemainingBand.classify(-1) == .critical, "negative remaining usage should clamp into critical")
    expect(WeeklyRemainingBand.classify(0) == .critical, "zero remaining should be critical")
    expect(WeeklyRemainingBand.classify(10) == .critical, "ten percent remaining should be critical")
    expect(WeeklyRemainingBand.classify(11) == .warning, "eleven percent remaining should be warning")
    expect(WeeklyRemainingBand.classify(25) == .warning, "twenty-five percent remaining should be warning")
    expect(WeeklyRemainingBand.classify(26) == .healthy, "twenty-six percent remaining should be healthy")
    expect(WeeklyRemainingBand.classify(100) == .healthy, "full remaining usage should be healthy")
    expect(WeeklyRemainingBand.classify(101) == .healthy, "over-reported remaining usage should clamp into healthy")
}
```

- [ ] **Step 2: Run the test suite and verify the new type is missing**

Run: `./run-tests.sh`
Expected: Swift compilation fails because `WeeklyRemainingBand` is not defined.

- [ ] **Step 3: Implement the minimal pure policy**

Add to `Sources/AppInfrastructure.swift`:

```swift
enum WeeklyRemainingBand: Equatable {
    case unknown
    case healthy
    case warning
    case critical

    static func classify(_ remainingPercent: Int?) -> WeeklyRemainingBand {
        guard let remainingPercent else { return .unknown }
        let clamped = min(100, max(0, remainingPercent))
        if clamped <= 10 { return .critical }
        if clamped <= 25 { return .warning }
        return .healthy
    }
}
```

- [ ] **Step 4: Run tests and verify the policy passes**

Run: `./run-tests.sh`
Expected: all infrastructure assertions and the reset self-test pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "test: define weekly remaining bands"
```

---

### Task 2: Account-list capacity policy

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `AccountListPresentationPolicy.maximumRowsWithoutScrolling == 10`
- Produces: `visibleRowCount(accountCount:availableRowCapacity:) -> Int`
- Produces: `requiresScrolling(accountCount:availableRowCapacity:) -> Bool`
- Consumed later by: `AccountSwitcherPanelView.preferredSize` and the account-list scroll view.

- [ ] **Step 1: Write failing capacity tests**

Register `testAccountListPresentationPolicy()` and add:

```swift
private static func testAccountListPresentationPolicy() {
    expect(AccountListPresentationPolicy.visibleRowCount(accountCount: 0, availableRowCapacity: 10) == 0, "empty accounts should have no rows")
    expect(AccountListPresentationPolicy.visibleRowCount(accountCount: 2, availableRowCapacity: 10) == 2, "two accounts should show two rows")
    expect(AccountListPresentationPolicy.visibleRowCount(accountCount: 10, availableRowCapacity: 10) == 10, "ten accounts should fit without scrolling")
    expect(AccountListPresentationPolicy.visibleRowCount(accountCount: 11, availableRowCapacity: 10) == 10, "eleven accounts should cap the viewport at ten rows")
    expect(AccountListPresentationPolicy.visibleRowCount(accountCount: 10, availableRowCapacity: 6) == 6, "short screens should lower visible capacity")
    expect(!AccountListPresentationPolicy.requiresScrolling(accountCount: 10, availableRowCapacity: 10), "ten rows should not scroll on a tall screen")
    expect(AccountListPresentationPolicy.requiresScrolling(accountCount: 11, availableRowCapacity: 10), "eleven rows should scroll")
    expect(AccountListPresentationPolicy.requiresScrolling(accountCount: 10, availableRowCapacity: 6), "short screens should scroll earlier")
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `./run-tests.sh`
Expected: compilation fails because `AccountListPresentationPolicy` is missing.

- [ ] **Step 3: Implement the layout policy**

Add:

```swift
enum AccountListPresentationPolicy {
    static let maximumRowsWithoutScrolling = 10

    static func visibleRowCount(accountCount: Int, availableRowCapacity: Int) -> Int {
        min(max(0, accountCount), min(maximumRowsWithoutScrolling, max(0, availableRowCapacity)))
    }

    static func requiresScrolling(accountCount: Int, availableRowCapacity: Int) -> Bool {
        accountCount > visibleRowCount(accountCount: accountCount, availableRowCapacity: availableRowCapacity)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `./run-tests.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "test: define account list capacity"
```

---

### Task 3: Native semantic gradients

**Files:**
- Modify: `Sources/Models.swift`
- Modify: `Sources/PanelComponents.swift`
- Modify: `Sources/main.swift`

**Interfaces:**
- Produces: `struct MeterGradient { let start: NSColor; let end: NSColor; let label: NSColor }`
- Produces: `meterGradient(for remainingPercent: Int?) -> MeterGradient`
- Extends: `ProgressLineView.init(frame:startColor:endColor:trackColor:percent:)`
- Consumes: `WeeklyRemainingBand.classify(_:)` from Task 1.

- [ ] **Step 1: Add exact Native palette constants**

Add these colors to the existing `NSColor` extension in `Sources/Models.swift`:

```swift
static let nativeMint = NSColor(red: CGFloat(0x47) / 255.0, green: CGFloat(0xD7) / 255.0, blue: CGFloat(0xA5) / 255.0, alpha: 1)
static let nativeBlue = NSColor(red: CGFloat(0x64) / 255.0, green: CGFloat(0xB9) / 255.0, blue: CGFloat(0xFF) / 255.0, alpha: 1)
static let nativeGold = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0xD1) / 255.0, blue: CGFloat(0x66) / 255.0, alpha: 1)
static let nativeOrange = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0x8F) / 255.0, blue: CGFloat(0x3F) / 255.0, alpha: 1)
static let nativeCoral = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0x8A) / 255.0, blue: CGFloat(0x7A) / 255.0, alpha: 1)
static let nativeRed = NSColor(red: CGFloat(0xE8) / 255.0, green: CGFloat(0x3F) / 255.0, blue: CGFloat(0x54) / 255.0, alpha: 1)
```

- [ ] **Step 2: Extend `ProgressLineView` with two-color drawing**

Replace the single stored `color` with `startColor` and `endColor`. Preserve the existing initializer as a convenience initializer for solid call sites, and add:

```swift
init(
    frame: NSRect,
    startColor: NSColor,
    endColor: NSColor,
    trackColor: NSColor = NSColor.white.withAlphaComponent(0.11),
    percent: CGFloat
) {
    self.startColor = startColor
    self.endColor = endColor
    self.trackColor = trackColor
    self.percent = max(0, min(1, percent))
    super.init(frame: frame)
    wantsLayer = true
}
```

Draw every non-empty fill through an `NSGradient(starting:ending:)` clipped to the rounded fill path. Keep the track and percent clamping unchanged.

- [ ] **Step 3: Add the UI mapping and replace weekly row color selection**

In `AccountSwitcherPanelView`, add:

```swift
private struct MeterGradient {
    let start: NSColor
    let end: NSColor
    let label: NSColor
}

private func meterGradient(for remainingPercent: Int?) -> MeterGradient {
    switch WeeklyRemainingBand.classify(remainingPercent) {
    case .healthy:
        return MeterGradient(start: .nativeMint, end: .nativeBlue, label: .nativeMint)
    case .warning:
        return MeterGradient(start: .nativeGold, end: .nativeOrange, label: .nativeOrange)
    case .critical:
        return MeterGradient(start: .nativeCoral, end: .nativeRed, label: .nativeRed)
    case .unknown:
        let neutral = theme.secondaryText.withAlphaComponent(0.65)
        return MeterGradient(start: neutral, end: neutral, label: neutral)
    }
}
```

Pass `weeklyPercent / 100` as the fill amount so bar width represents remaining capacity. Use `gradient.label` for the numeric percentage.

- [ ] **Step 4: Build and run tests**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: infrastructure tests, reset self-test, full app compilation, and ad-hoc signing pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Models.swift Sources/PanelComponents.swift Sources/main.swift
git commit -m "feat: add native usage gradients"
```

---

### Task 4: Unified numbered list and scroll-only account region

**Files:**
- Modify: `Sources/main.swift`

**Interfaces:**
- Changes: `AccountSwitcherPanelView.preferredSize(mode:accountCount:showsPace:maximumHeight:) -> NSSize`
- Changes: `accountListRow(_:displayIndex:frame:) -> NSView`
- Produces: account-list `NSScrollView` with fixed aggregate sections below it.
- Consumes: `AccountListPresentationPolicy` from Task 2 and `MeterGradient` from Task 3.

- [ ] **Step 1: Replace split usage layout with one ordered list path**

In `buildUsageContent()` remove the `accounts.count >= 3` and one/two-card branches. Build `orderedAccounts` once, pass it to a new `accountListSection(_:frame:)`, and keep the empty state only for zero accounts.

Delete the main-panel-only large-card construction methods and constants that become unused: `accountCard`, `accountCardHeight`, five-hour ring placement, and five-hour reset rows. Do not delete five-hour fields from `CodexAccount`, usage parsing, reset workflows, or diagnostics.

- [ ] **Step 2: Build the scroll view and numbered rows**

Create an `NSScrollView` with a flipped document view. For every ordered account:

```swift
let row = accountListRow(
    account,
    displayIndex: index + 1,
    frame: NSRect(x: 0, y: y, width: listWidth, height: AccountPanelLayout.rowHeight)
)
```

Set `hasVerticalScroller` from `AccountListPresentationPolicy.requiresScrolling`. Do not add the old `+N more in menu` caption.

- [ ] **Step 3: Render the approved normal row**

Each row must render the number badge, email, active state, weekly remaining percentage, weekly reset text, and semantic remaining-capacity gradient. Remove `ACTIVE` and `SWITCH` pills. Keep the existing email tooltip and click the whole non-active surface through `RoundedPanelView.clickAction`.

- [ ] **Step 4: Make sizing screen-aware**

Change preferred sizing to accept whether pace history exists and a maximum available height. Compute fixed section height first, then row capacity from the remainder:

```swift
let availableListHeight = max(0, maximumHeight - fixedSectionHeight)
let rowCapacity = max(1, Int((availableListHeight + AccountPanelLayout.rowGap) / (AccountPanelLayout.rowHeight + AccountPanelLayout.rowGap)))
let visibleRows = AccountListPresentationPolicy.visibleRowCount(
    accountCount: accountCount,
    availableRowCapacity: rowCapacity
)
```

Return width `520` for usage mode. Update `currentAccountPanelSize()` and view construction to use the current screen's visible height minus `16 pt` total margin.

- [ ] **Step 5: Show aggregate sections for every account count**

Remove the `accounts.count >= 3` condition around `paceSection`. Show it whenever `pace != nil`, including one or two accounts. Keep reset chance and bottom toolbar fixed below the scroll view.

Extend demo fixtures with an optional `CODEX_ACCOUNT_SWITCHER_DEMO_COUNT` environment value clamped to `1...20`. Default remains three accounts. Generate deterministic emails and weekly remaining values so 1, 2, 10, and 11-row layouts can be launched without editing source.

- [ ] **Step 6: Run tests and build**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: all tests and the full app build pass with no five-hour labels in the usage-panel construction path.

Run: `rg -n '5H REMAINING|accountCard\(' Sources/main.swift`
Expected: no main-panel card construction or five-hour label remains.

- [ ] **Step 7: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: unify numbered account list"
```

---

### Task 5: Always-on inline manual-switch confirmation

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Sources/Models.swift`
- Modify: `Sources/main.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `enum InlineSwitchDecision: Equatable { case ignore, arm, confirm }`
- Produces: `InlineSwitchConfirmationPolicy.decision(armedEmail:requestedEmail:isActive:isSwitching:) -> InlineSwitchDecision`
- Consumes: existing `armedSwitchEmail`, `armedSwitchClearWorkItem`, and four-second timer.

- [ ] **Step 1: Write failing decision-policy tests**

Register `testInlineSwitchConfirmationPolicy()` and add:

```swift
private static func testInlineSwitchConfirmationPolicy() {
    expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "two@example.com", isActive: false, isSwitching: false) == .arm, "first click should arm confirmation")
    expect(InlineSwitchConfirmationPolicy.decision(armedEmail: "two@example.com", requestedEmail: "two@example.com", isActive: false, isSwitching: false) == .confirm, "confirmed target should switch")
    expect(InlineSwitchConfirmationPolicy.decision(armedEmail: "two@example.com", requestedEmail: "three@example.com", isActive: false, isSwitching: false) == .arm, "different target should replace confirmation")
    expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "one@example.com", isActive: true, isSwitching: false) == .ignore, "active account should not arm")
    expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "two@example.com", isActive: false, isSwitching: true) == .ignore, "switching state should ignore clicks")
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `./run-tests.sh`
Expected: compilation fails because the confirmation policy is missing.

- [ ] **Step 3: Implement the pure decision policy**

Add:

```swift
enum InlineSwitchDecision: Equatable {
    case ignore
    case arm
    case confirm
}

enum InlineSwitchConfirmationPolicy {
    static func decision(
        armedEmail: String?,
        requestedEmail: String,
        isActive: Bool,
        isSwitching: Bool
    ) -> InlineSwitchDecision {
        if isActive || isSwitching { return .ignore }
        return armedEmail == requestedEmail ? .confirm : .arm
    }
}
```

- [ ] **Step 4: Render Inline Buttons state in the armed row**

When `armedSwitchEmail == account.email`, replace the normal metrics area with:

- `Switch to account #N?`;
- target email;
- `Codex will relaunch`;
- `Cancel` and `Switch` text buttons;
- `Closes in 4 seconds` hint.

The cancel button calls a new `cancelSwitchConfirmation` closure. The switch button calls the existing switch closure a second time. The expanded row uses an amber-tinted Native Glass border and remains inside the list document view.

- [ ] **Step 5: Make every panel switch use the inline policy**

Update `handlePanelSwitchRequest` to resolve the target account, call `InlineSwitchConfirmationPolicy.decision`, and either ignore, arm, or close the panel and call `switchTo(query:)`. Keep `armSwitchConfirmation` and its four-second timer.

Remove `confirmBeforeSwitching` from `AccountSwitcherPanelView`, `AppDelegate`, settings construction, menu construction, and `UserDefaults`. Remove `confirmSwitchPreview(for:)`, `toggleConfirmBeforeSwitching`, and `SettingsPanelAction.toggleConfirmSwitch`. Manual panel switching must no longer open `NSAlert`.

- [ ] **Step 6: Run tests and search for obsolete confirmation code**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: all tests and the full app build pass.

Run: `rg -n 'confirmBeforeSwitching|Confirm Panel Switches|confirmSwitchPreview|toggleConfirmSwitch' Sources`
Expected: no matches.

- [ ] **Step 7: Commit**

```bash
git add Sources/AppInfrastructure.swift Sources/Models.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "feat: add inline switch confirmation"
```

---

### Task 6: Native Glass surfaces and larger toolbar controls

**Files:**
- Modify: `Sources/Models.swift`
- Modify: `Sources/PanelComponents.swift`
- Modify: `Sources/main.swift`

**Interfaces:**
- Refines: `PanelTheme` Native Glass surface, border, hover, divider, and icon colors.
- Refines: bottom toolbar SF Symbols to `20–22 pt` visual size with at least `34 × 32 pt` hit targets.
- Preserves: `DashboardBackgroundView` macOS 26 and older-macOS branches.

- [ ] **Step 1: Update theme surfaces without changing semantic colors**

Change `PanelTheme` card and toolbar surfaces from warm opaque graphite to neutral translucent values. Use theme-dependent alpha for light and dark appearance, keep low-opacity white borders, and retain readable theme-derived text colors.

- [ ] **Step 2: Add pressed feedback to whole-row glass surfaces**

Extend `RoundedPanelView` to retain the approved hover fill and temporarily apply a pressed fill in `mouseDown`, restoring hover or normal fill after the click. Do not translate or resize the row.

- [ ] **Step 3: Enlarge toolbar controls**

Set toolbar icon hit frames to at least `36 × 34 pt`, configure SF Symbol point size near `21 pt`, keep existing tooltips, and preserve button actions. Increase toolbar height and spacing only as needed to avoid clipping at `520 pt` width.

- [ ] **Step 4: Build for user-owned visual verification**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: tests, full compilation, and ad-hoc signing pass. Do not launch or visually inspect the panel; the user owns visual acceptance to avoid spending agent time and credits.

- [ ] **Step 5: Commit**

```bash
git add Sources/Models.swift Sources/PanelComponents.swift Sources/main.swift
git commit -m "style: apply native glass main panel"
```

---

### Task 7: End-to-end verification and documentation consistency

**Files:**
- Verify: `docs/superpowers/specs/2026-08-17-native-glass-main-panel-design.md`
- Verify: `AGENTS.md`
- Verify: `README.md`
- Modify only if inconsistent: `README.md`

**Interfaces:**
- Produces: a clean, reviewable feature branch with passing tests and verified runtime behavior.

- [ ] **Step 1: Run static checks**

Run:

```bash
git diff --check feat/reference-plugin-set...HEAD
rg -n '5H REMAINING|Confirm Panel Switches|confirmBeforeSwitching|confirmSwitchPreview' Sources
```

Expected: diff check is clean and obsolete main-panel/confirmation strings have no matches.

- [ ] **Step 2: Run the full automated suite**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: all infrastructure assertions pass, reset logic self-test passes, and the app bundle builds and signs successfully.

- [ ] **Step 3: Prepare the user visual-verification checklist**

Hand off these checks to the user after automated verification:

- 1, 2, 10, and 11+ rows;
- short-screen list scrolling without moving aggregate sections;
- visual numbering after current sorting;
- healthy, warning, and critical gradients;
- hover and pressed feedback;
- inline cancel, four-second timeout, and confirmed switch;
- disabled rows while switching;
- chart and forecast with one and two accounts when history exists;
- reset chance, reset credits, refresh, Settings, Add Account, and close actions;
- dark appearance, light appearance, and the pre-macOS-26 material fallback where available.

Provide these exact optional demo launches for user-run row-count coverage:

```bash
CODEX_ACCOUNT_SWITCHER_DEMO=1 CODEX_ACCOUNT_SWITCHER_DEMO_COUNT=1 CODEX_ACCOUNT_SWITCHER_SHOW_PANEL=1 "build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
CODEX_ACCOUNT_SWITCHER_DEMO=1 CODEX_ACCOUNT_SWITCHER_DEMO_COUNT=2 CODEX_ACCOUNT_SWITCHER_SHOW_PANEL=1 "build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
CODEX_ACCOUNT_SWITCHER_DEMO=1 CODEX_ACCOUNT_SWITCHER_DEMO_COUNT=10 CODEX_ACCOUNT_SWITCHER_SHOW_PANEL=1 "build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
CODEX_ACCOUNT_SWITCHER_DEMO=1 CODEX_ACCOUNT_SWITCHER_DEMO_COUNT=11 CODEX_ACCOUNT_SWITCHER_SHOW_PANEL=1 "build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
```

- [ ] **Step 4: Check documentation consistency**

Read `README.md`, `AGENTS.md`, and the approved design spec. Update `README.md` only if it explicitly describes the removed five-hour main-panel cards or configurable manual confirmation. Do not alter unrelated documentation.

- [ ] **Step 5: Commit any necessary documentation correction**

If `README.md` required a correction:

```bash
git add README.md
git commit -m "docs: update main panel behavior"
```

If no correction was needed, record that result in the final verification report and create no empty commit.

- [ ] **Step 6: Review branch scope**

Run:

```bash
git status --short
git log --oneline feat/reference-plugin-set..HEAD
git diff --stat feat/reference-plugin-set...HEAD
```

Expected: the worktree is clean and every changed file traces to the Native Glass main-panel specification.
