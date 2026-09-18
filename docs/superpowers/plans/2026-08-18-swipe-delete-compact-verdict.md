# Swipe Delete and Compact Verdict Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe swipe-to-reveal deletion for inactive accounts and implement the approved compact verdict/footer layout without removing information.

**Architecture:** Put gesture math, exact deletion arguments, single-open-row behavior, and layout metrics in pure testable policies. Add one AppKit row container that owns interaction/animation only; `AccountPanelView` owns transient reveal identity, and `AppDelegate` keeps process execution in the existing maintenance path. Re-layout the existing verdict and footer from centralized metrics.

**Tech Stack:** Swift 5, AppKit, SwiftUI/Charts, Foundation, `codex-auth 0.2.10`, shell verification scripts.

## Global Constraints

- Target macOS 14+ and dark appearance only.
- Active accounts cannot reveal or execute deletion.
- Swipe deletion calls only `codex-auth remove <account.selector>` as separate arguments.
- Never construct or pass `--all` from the swipe-deletion path.
- Delete immediately after the revealed button is pressed; no third confirmation.
- Keep every current verdict datum.
- Verdict height: `108 pt`; gap before reset chance: `12 pt`.
- Refresh/Quit sizes: `68 × 26 pt` and `50 × 26 pt`.
- New copy must be typed and localized in Russian and English.
- Do not perform final visual judgment; reinstall and open the dark app for the user.
- Each implementation commit must pass tests and the full macOS build.

---

## File Structure

- `Sources/AppInfrastructure.swift`: pure swipe, reveal-selection, removal-argument, and layout policies.
- `Sources/Localization.swift`: RU/EN Delete copy.
- `Sources/PanelComponents.swift`: reusable swipe-reveal container and exact badge centering.
- `Sources/main.swift`: account-row wiring, transient state, maintenance callback, compact positions, footer widths.
- `Tests/InfrastructureTests.swift`: deterministic policy and localization tests.
- `CHANGELOG.md`: concise user-facing notes.

---

### Task 1: Pure Safety and Layout Contracts

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Sources/Localization.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `SwipeAxisIntent`, `SwipeRevealSettleState`, `SwipeRevealPolicy`.
- Produces: `AccountRowRevealPolicy.next(current:requested:canReveal:)`.
- Produces: `AccountRemovalPolicy.arguments(selector:isActive:)`.
- Produces: `UsagePanelLayoutMetrics`.
- Produces: `.deleteAccountButton` and `.deleteAccountTooltip` localization keys.

- [ ] **Step 1: Write failing localization and policy tests**

Register four new tests in `InfrastructureTests.run()`:

```swift
testSwipeRevealPolicy()
testAccountRowRevealPolicy()
testAccountRemovalPolicy()
testUsagePanelLayoutMetrics()
```

Extend localization assertions:

```swift
expect(LocalizedText.value(.deleteAccountButton, language: .russian) == "Удалить", "Russian delete title")
expect(LocalizedText.value(.deleteAccountButton, language: .english) == "Delete", "English delete title")
expect(LocalizedText.value(.deleteAccountTooltip, language: .russian) == "Удалить аккаунт", "Russian delete tooltip")
expect(LocalizedText.value(.deleteAccountTooltip, language: .english) == "Delete account", "English delete tooltip")
```

Add exact pure tests:

```swift
private static func testSwipeRevealPolicy() {
    expect(SwipeRevealPolicy.intent(deltaX: 3, deltaY: 2) == .undecided, "small motion preserves click")
    expect(SwipeRevealPolicy.intent(deltaX: -12, deltaY: 3) == .horizontal, "left motion reveals")
    expect(SwipeRevealPolicy.intent(deltaX: 4, deltaY: 13) == .vertical, "vertical motion scrolls")
    expect(SwipeRevealPolicy.clampedOffset(-120) == -84, "offset clamps at action width")
    expect(SwipeRevealPolicy.clampedOffset(20) == 0, "right motion from rest stays closed")
    expect(SwipeRevealPolicy.settledState(offset: -50, velocityX: 0) == .revealed, "majority reveal stays open")
    expect(SwipeRevealPolicy.settledState(offset: -20, velocityX: 0) == .closed, "short reveal closes")
    expect(SwipeRevealPolicy.settledState(offset: -15, velocityX: -500) == .revealed, "fast left release reveals")
}

private static func testAccountRowRevealPolicy() {
    expect(AccountRowRevealPolicy.next(current: nil, requested: "a", canReveal: true) == "a", "eligible row reveals")
    expect(AccountRowRevealPolicy.next(current: "a", requested: "b", canReveal: true) == "b", "new row replaces old")
    expect(AccountRowRevealPolicy.next(current: "a", requested: nil, canReveal: true) == nil, "outside interaction closes")
    expect(AccountRowRevealPolicy.next(current: nil, requested: "active", canReveal: false) == nil, "active row cannot reveal")
}

private static func testAccountRemovalPolicy() {
    expect(AccountRemovalPolicy.arguments(selector: "02", isActive: false) == ["remove", "02"], "exact selector arguments")
    expect(AccountRemovalPolicy.arguments(selector: " 02 ", isActive: false) == ["remove", "02"], "trim selector")
    expect(AccountRemovalPolicy.arguments(selector: "", isActive: false) == nil, "reject empty selector")
    expect(AccountRemovalPolicy.arguments(selector: "01", isActive: true) == nil, "reject active account")
    expect(AccountRemovalPolicy.arguments(selector: "--all", isActive: false) == nil, "reject remove-all flag")
    expect(AccountRemovalPolicy.arguments(selector: "--api", isActive: false) == nil, "reject every flag-like selector")
    expect(!(AccountRemovalPolicy.arguments(selector: "02", isActive: false) ?? []).contains("--all"), "never remove all")
}

private static func testUsagePanelLayoutMetrics() {
    expect(UsagePanelLayoutMetrics.verdictCardHeight == 108, "exact compact verdict height")
    expect(UsagePanelLayoutMetrics.verdictResetGap == 12, "exact inter-card gap")
    expect(UsagePanelLayoutMetrics.refreshButtonWidth == 68, "Refresh width")
    expect(UsagePanelLayoutMetrics.quitButtonWidth == 50, "Quit width")
    expect(UsagePanelLayoutMetrics.footerButtonHeight == 26, "stable footer height")
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
```

Expected: compiler errors for the missing types and localization keys.

- [ ] **Step 3: Add typed localization**

Add `deleteAccountButton` and `deleteAccountTooltip` to `LocalizedTextKey`, with these exact values:

```swift
// Russian
case .deleteAccountButton: return "Удалить"
case .deleteAccountTooltip: return "Удалить аккаунт"

// English
case .deleteAccountButton: return "Delete"
case .deleteAccountTooltip: return "Delete account"
```

- [ ] **Step 4: Implement minimal pure policies**

Add beside the current account-list policies:

```swift
enum SwipeAxisIntent: Equatable { case undecided, horizontal, vertical }
enum SwipeRevealSettleState: Equatable { case closed, revealed }

enum SwipeRevealPolicy {
    static let revealWidth = 84.0
    static let intentThreshold = 6.0
    static let velocityRevealThreshold = -420.0

    static func intent(deltaX: Double, deltaY: Double) -> SwipeAxisIntent {
        guard max(abs(deltaX), abs(deltaY)) >= intentThreshold else { return .undecided }
        return abs(deltaX) > abs(deltaY) ? .horizontal : .vertical
    }

    static func clampedOffset(_ proposed: Double) -> Double {
        min(0, max(-revealWidth, proposed))
    }

    static func settledState(offset: Double, velocityX: Double) -> SwipeRevealSettleState {
        if velocityX <= velocityRevealThreshold { return .revealed }
        return offset <= -(revealWidth / 2) ? .revealed : .closed
    }
}

enum AccountRowRevealPolicy {
    static func next(current: String?, requested: String?, canReveal: Bool) -> String? {
        guard let requested else { return nil }
        guard canReveal else { return current == requested ? nil : current }
        return requested
    }
}

enum AccountRemovalPolicy {
    static func arguments(selector: String, isActive: Bool) -> [String]? {
        guard !isActive else { return nil }
        let selector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty, !selector.hasPrefix("-") else { return nil }
        return ["remove", selector]
    }
}

enum UsagePanelLayoutMetrics {
    static let verdictCardHeight = 108.0
    static let verdictResetGap = 12.0
    static let refreshButtonWidth = 68.0
    static let quitButtonWidth = 50.0
    static let footerButtonHeight = 26.0
}
```

- [ ] **Step 5: Run GREEN, build, and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
git diff --check
git add Sources/AppInfrastructure.swift Sources/Localization.swift Tests/InfrastructureTests.swift
git commit -m "feat: define safe account swipe deletion"
```

Expected: suite, reset self-test, build, signing, and whitespace checks pass.

---

### Task 2: AppKit Swipe-Reveal Row and Exact Removal

**Files:**
- Modify: `Sources/PanelComponents.swift`
- Modify: `Sources/main.swift`
- Test: `Tests/InfrastructureTests.swift` (Task 1 policies cover interaction decisions)

**Interfaces:**
- Consumes: Task 1 policies and localized Delete copy.
- Produces: `SwipeRevealRowView` with `setRevealed(_:animated:)`, `onRevealRequested`, `onDelete`, and `onPrimaryAction`.
- Produces: one `revealedDeleteEmail` identity and an AppDelegate removal callback.

- [ ] **Step 1: Add `SwipeRevealRowView`**

Create a focused container in `PanelComponents.swift`:

```swift
final class SwipeRevealRowView: NSView {
    let contentView: NSView
    var onRevealRequested: ((Bool) -> Void)?
    var onDelete: (() -> Void)?
    var onPrimaryAction: (() -> Void)?

    private let actionButton: SettingsActionButton
    private var offset: CGFloat = 0
    private var downPoint: NSPoint?
    private var dragIntent: SwipeAxisIntent = .undecided

    init(frame: NSRect, contentView: NSView, deleteTitle: String, deleteTooltip: String) {
        self.contentView = contentView
        actionButton = SettingsActionButton(
            frame: NSRect(x: frame.width - CGFloat(SwipeRevealPolicy.revealWidth), y: 0, width: CGFloat(SwipeRevealPolicy.revealWidth), height: frame.height),
            title: deleteTitle,
            color: NSColor.systemRed.withAlphaComponent(0.78),
            textColor: .white
        )
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        actionButton.target = self
        actionButton.action = #selector(deletePressed)
        actionButton.toolTip = deleteTooltip
        actionButton.setAccessibilityLabel(deleteTooltip)
        addSubview(actionButton)
        addSubview(contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func deletePressed() { onDelete?() }
}
```

Complete it with these rules:

- `mouseDown` records position and never switches immediately.
- `mouseDragged` asks `SwipeRevealPolicy.intent`; horizontal motion updates the clamped foreground offset, vertical motion continues through the scroll responder chain.
- `mouseUp` invokes `onPrimaryAction` only for `.undecided`; horizontal interaction settles through `settledState` and reports `onRevealRequested`.
- `scrollWheel` handles dominant horizontal precision scrolling and forwards dominant vertical scrolling unchanged.
- `setRevealed` animates the foreground to `0` or `-84` over `0.16 s`.
- the action button stays behind content and is accessible only when revealed.

- [ ] **Step 2: Thread one revealed identity through the panel**

Add to AppDelegate:

```swift
private var revealedDeleteEmail: String?
```

Extend the panel initializer with immutable state and callbacks:

```swift
revealedDeleteEmail: String?,
revealDeleteRow: @escaping (String?) -> Void,
removeAccountRequested: @escaping (String) -> Void
```

Use `AccountRowRevealPolicy.next(...)` before rebuilding the visible usage content. Clear this state on mode changes, switch arming, maintenance start/end, and panel close.

- [ ] **Step 3: Wrap only eligible rows**

Extract the existing visuals into `accountListRowContent` with `clickAction: nil`. Wrap only inactive, non-armed, non-maintenance rows:

```swift
let swipe = SwipeRevealRowView(
    frame: frame,
    contentView: content,
    deleteTitle: LocalizedText.value(.deleteAccountButton, language: language),
    deleteTooltip: LocalizedText.value(.deleteAccountTooltip, language: language)
)
swipe.setRevealed(revealedDeleteEmail == account.email, animated: false)
swipe.onRevealRequested = { [revealDeleteRow] revealed in
    revealDeleteRow(revealed ? account.email : nil)
}
swipe.onPrimaryAction = { [weak self] in self?.switchAccount(account.email) }
swipe.onDelete = { [removeAccountRequested] in removeAccountRequested(account.email) }
```

Active rows remain plain content views and have no Delete control.

- [ ] **Step 4: Run exact selector deletion**

Add:

```swift
private func removeAccountFromSwipe(email: String) {
    guard
        let account = accounts.first(where: { $0.email == email }),
        let args = AccountRemovalPolicy.arguments(selector: account.selector, isActive: account.isActive)
    else { return }
    revealedDeleteEmail = nil
    runAccountMaintenance(title: "Removing account", args: args)
}
```

Do not call the picker, pass an email query, or introduce `--all`. Existing `runAccountMaintenance` keeps the account on failure and refreshes from disk on success.

- [ ] **Step 5: Verify and commit Task 2**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
git diff --check
git add Sources/PanelComponents.swift Sources/main.swift
git commit -m "feat: swipe to delete inactive accounts"
```

---

### Task 3: Compact Verdict, Gap, Badge, and Footer

**Files:**
- Modify: `Sources/PanelComponents.swift`
- Modify: `Sources/main.swift`
- Test: `Tests/InfrastructureTests.swift` (Task 1 metrics are the regression contract)

**Interfaces:**
- Consumes: `UsagePanelLayoutMetrics` and `PoolVerdictPresentation`.
- Produces: approved layout B with exact geometry.

- [ ] **Step 1: Route panel constants through tested metrics**

```swift
static let verdictCardHeight = CGFloat(UsagePanelLayoutMetrics.verdictCardHeight)
static let verdictResetGap = CGFloat(UsagePanelLayoutMetrics.verdictResetGap)
static var verdictSectionHeight: CGFloat {
    verdictTopGap + verdictCardHeight + verdictResetGap
}
```

Place the card so its bottom is exactly 12 pt above `resetChanceY`, and calculate chart/list position from the top of the complete verdict section. Keep the outer panel height unchanged.

- [ ] **Step 2: Fit every verdict element into 108 pt**

Use exact frames in `PoolVerdictCardView`:

```swift
let symbolFrame = NSRect(x: 14, y: 12, width: 32, height: 32)
let titleFrame = NSRect(x: 56, y: 10, width: bounds.width - 56 - textTrailingInset, height: 19)
let detailFrame = NSRect(x: 56, y: 31, width: bounds.width - 56 - textTrailingInset, height: 16)
let badgeFrame = NSRect(x: bounds.width - 98, y: 12, width: 84, height: 28)
let pointY: CGFloat = 69
let eventTitleY: CGFloat = 76
let eventIntervalY: CGFloat = 92
```

Preserve three equal event columns and all presentation strings. For `.collecting`, center the symbol/title/detail group and continue omitting badge and scale.

- [ ] **Step 3: Center the margin badge exactly**

Replace its baseline-dependent `NSTextField` with a draw-based centered view (reuse `CenteredTextView` if accessible from this file, otherwise add a small private equivalent). Keep monospaced digits, `.center`, 14 pt corner radius, current fill/accent, and the accessibility value.

- [ ] **Step 4: Widen footer actions**

```swift
let quitWidth = CGFloat(UsagePanelLayoutMetrics.quitButtonWidth)
let refreshWidth = CGFloat(UsagePanelLayoutMetrics.refreshButtonWidth)
let footerButtonHeight = CGFloat(UsagePanelLayoutMetrics.footerButtonHeight)
```

Use the tested height for both buttons, preserve the 8 pt gap and dividers, and let the existing `updatedWidth = max(46, ...)` absorb the extra width.

- [ ] **Step 5: Verify and commit Task 3**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
codesign --verify --deep --strict "build/Codex Account Switcher.app"
git diff --check
git add Sources/PanelComponents.swift Sources/main.swift
git commit -m "style: compact the pool verdict panel"
```

---

### Task 4: Release Note, Final Regression, and Installation

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- No new runtime interfaces.

- [ ] **Step 1: Add concise release notes**

Add under the current version without changing version numbers:

```markdown
- Add swipe-to-reveal deletion for inactive accounts using exact `codex-auth` selectors.
- Compact the pool verdict card, center its margin badge, and improve adjacent spacing.
```

- [ ] **Step 2: Run final verification**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
codesign --verify --deep --strict "build/Codex Account Switcher.app"
git diff --check
rg -n 'remove.*--all|--all.*remove' Sources Tests
```

Expected: tests, reset self-test, build, signing, and whitespace checks pass; no swipe builder contains `--all`.

- [ ] **Step 3: Check docs and commit**

```bash
rg -n 'swipe|remove|verdict|pool' README.md CHANGELOG.md docs/superpowers/specs/2026-08-18-swipe-delete-compact-verdict-design.md
git add CHANGELOG.md
git commit -m "docs: describe swipe account deletion"
```

- [ ] **Step 4: Reinstall and verify**

Run outside the filesystem sandbox:

```bash
./install.sh
./verify-install.sh
```

Expected: installed version 1.8.5, signature, and lifecycle monitor pass.

- [ ] **Step 5: Open for user-led inspection**

Terminate only the installed executable, then open the usage panel:

```bash
pkill -f '^/Applications/Codex Account Switcher\.app/Contents/MacOS/CodexAccountSwitcher$' || true
CODEX_ACCOUNT_SWITCHER_SHOW_PANEL=1 "/Applications/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
```

Do not capture or judge a new screenshot. Report commit and automated evidence; the user performs visual review.

---

## Final Acceptance

- [ ] Full infrastructure suite and reset self-test pass.
- [ ] Full build and strict ad-hoc signature pass.
- [ ] Inactive swipe reveals exactly one localized red Delete control.
- [ ] Active rows cannot reveal or remove.
- [ ] Delete invokes `["remove", account.selector]` and never `--all`.
- [ ] Failure preserves the account and exposes CLI output.
- [ ] Verdict stays complete at 108 pt with a 12 pt gap below it.
- [ ] Margin badge uses exact two-axis centering.
- [ ] Refresh/Quit are 68/50 pt wide and 26 pt high.
- [ ] Installed 1.8.5 and lifecycle monitor verify.
- [ ] Dark app opens for user-led visual review.
