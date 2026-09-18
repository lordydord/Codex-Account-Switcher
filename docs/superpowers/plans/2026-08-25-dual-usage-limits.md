# Dual Usage Limits Account Row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display the five-hour and weekly remaining Codex limits together in each compact account row, with five-hour usage visually dominant.

**Architecture:** Add a pure formatting policy for the ordered percentage pair, localize the compact meter labels and accessibility description, and compose two independently colored progress lines inside the existing SwiftUI row. Preserve all AppKit table behavior and panel geometry.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, the repository's executable Swift test harness, macOS 14+.

## Global Constraints

- Keep the normal account row at `39 pt` and the inter-row gap at `4 pt`.
- The top `4 pt` track represents five-hour remaining capacity.
- The bottom `3 pt` track represents weekly remaining capacity at reduced opacity.
- Display the trailing pair in `five-hour / weekly` order, including mixed unknown values.
- Use independent existing semantic quota palettes for the two limits.
- Localize new visible and accessibility text in Russian and English.
- Do not change confirmation, scrolling, swipe, or switching behavior.
- Do not commit or push until the user approves the installed visual result.

---

### Task 1: Testable usage-pair presentation and localization

**Files:**
- Modify: `Sources/AppInfrastructure.swift:17`
- Modify: `Sources/Localization.swift:42-166`
- Modify: `Tests/InfrastructureTests.swift:25-90,480-525`

**Interfaces:**
- Produces: `AccountUsagePairText` with `fiveHour` and `weekly` strings.
- Produces: `AccountUsagePresentationPolicy.pair(fiveHourRemaining:weeklyRemaining:) -> AccountUsagePairText`.
- Produces: localized `.fiveHourShort` and `.weeklyShort` labels.
- Produces: `LocalizedText.accountUsageAccessibility(fiveHour:weekly:weeklyReset:language:) -> String`.

- [ ] **Step 1: Write the failing policy and localization assertions**

Add `testAccountUsagePresentationPolicy()` to the test runner and assert:

```swift
expect(
    AccountUsagePresentationPolicy.pair(fiveHourRemaining: 10, weeklyRemaining: 80)
        == AccountUsagePairText(fiveHour: "10%", weekly: "80%"),
    "usage pair should preserve five-hour then weekly order"
)
expect(
    AccountUsagePresentationPolicy.pair(fiveHourRemaining: nil, weeklyRemaining: 120)
        == AccountUsagePairText(fiveHour: "--", weekly: "100%"),
    "usage pair should preserve unknown values and clamp known values"
)
expect(
    AccountUsagePresentationPolicy.pair(fiveHourRemaining: -5, weeklyRemaining: nil)
        == AccountUsagePairText(fiveHour: "0%", weekly: "--"),
    "usage pair should clamp low values and preserve unknown weekly usage"
)
expect(LocalizedText.value(.fiveHourShort, language: .russian) == "5 Ч", "Russian five-hour label should be compact")
expect(LocalizedText.value(.weeklyShort, language: .english) == "WK", "English weekly label should be compact")
expect(UsagePanelLayoutMetrics.accountPrimaryTrackHeight == 4, "five-hour track should remain primary")
expect(UsagePanelLayoutMetrics.accountSecondaryTrackHeight == 3, "weekly track should be visually quieter")
expect(UsagePanelLayoutMetrics.accountSecondaryOpacity == 0.55, "weekly track should keep the approved subdued treatment")
```

- [ ] **Step 2: Run the tests and verify the new assertions fail to compile**

Run: `./run-tests.sh`

Expected: FAIL because `AccountUsagePresentationPolicy`, `AccountUsagePairText`, and the new localization keys do not exist.

- [ ] **Step 3: Add the minimal pure presentation types and localized strings**

Add to `AppInfrastructure.swift`:

```swift
struct AccountUsagePairText: Equatable {
    let fiveHour: String
    let weekly: String
}

enum AccountUsagePresentationPolicy {
    static func pair(fiveHourRemaining: Int?, weeklyRemaining: Int?) -> AccountUsagePairText {
        AccountUsagePairText(
            fiveHour: percentText(fiveHourRemaining),
            weekly: percentText(weeklyRemaining)
        )
    }

    private static func percentText(_ remaining: Int?) -> String {
        guard let remaining else { return "--" }
        return "\(min(100, max(0, remaining)))%"
    }
}
```

Add `.fiveHourShort` and `.weeklyShort` to `LocalizedTextKey`, map them to `5 Ч`/`НЕД` and `5H`/`WK`, and add this complete-sentence accessibility formatter:

```swift
static func accountUsageAccessibility(
    pair: AccountUsagePairText,
    weeklyReset: String,
    language: AppLanguage
) -> String {
    switch language {
    case .russian:
        return "Остаток на 5 часов: \(pair.fiveHour). Недельный остаток: \(pair.weekly). \(weeklyReset)"
    case .english:
        return "Five-hour remaining: \(pair.fiveHour). Weekly remaining: \(pair.weekly). \(weeklyReset)"
    }
}
```

Add these executable visual-hierarchy tokens to `UsagePanelLayoutMetrics`:

```swift
static let accountPrimaryTrackHeight = 4.0
static let accountSecondaryTrackHeight = 3.0
static let accountSecondaryOpacity = 0.55
```

- [ ] **Step 4: Run the targeted suite and verify it passes**

Run: `./run-tests.sh`

Expected: all infrastructure, AppKit interaction, reset logic, and install-script tests pass.

### Task 2: Render the dual-limit hierarchy in the account row

**Files:**
- Modify: `Sources/AccountRowView.swift:1-190`

**Interfaces:**
- Consumes: `AccountUsagePresentationPolicy.pair(fiveHourRemaining:weeklyRemaining:)`.
- Consumes: `.fiveHourShort`, `.weeklyShort`, and `LocalizedText.accountUsageAccessibility(...)`.
- Produces: `AccountUsageMetersView`, a private SwiftUI view with two labelled tracks.

- [ ] **Step 1: Run the presentation tests before changing the view**

Run: `./run-tests.sh`

Expected: PASS, establishing that the formatting, localization, hierarchy metrics, table behavior, and compact geometry are ready before the SwiftUI composition changes.

- [ ] **Step 2: Replace the single weekly line with two independently styled lines**

In `AccountRowView`:

```swift
private var fiveHourPalette: AccountRowPalette {
    AccountRowPalette.make(remainingPercent: account.fiveHourUsedPercent, theme: theme)
}

private var weeklyPalette: AccountRowPalette {
    AccountRowPalette.make(remainingPercent: account.weeklyUsedPercent, theme: theme)
}
```

Use `fiveHourPalette` for the active badge, border, and confirmation accent. Replace the single progress line with `AccountUsageMetersView` that renders:

```swift
VStack(spacing: 4) {
    labelledProgress(
        label: LocalizedText.value(.fiveHourShort, language: language),
        percent: account.fiveHourUsedPercent,
        palette: fiveHourPalette,
        height: CGFloat(UsagePanelLayoutMetrics.accountPrimaryTrackHeight),
        opacity: 1
    )
    labelledProgress(
        label: LocalizedText.value(.weeklyShort, language: language),
        percent: account.weeklyUsedPercent,
        palette: weeklyPalette,
        height: CGFloat(UsagePanelLayoutMetrics.accountSecondaryTrackHeight),
        opacity: UsagePanelLayoutMetrics.accountSecondaryOpacity
    )
}
```

Render the trailing pair as separately styled five-hour text, neutral slash, and subdued weekly text in a fixed trailing region. Set the row accessibility value to the localized complete description.

- [ ] **Step 3: Run tests and build the app**

Run: `./run-tests.sh`

Expected: all tests pass.

Run: `./build.sh`

Expected: prints the built `.app` path and exits successfully.

### Task 3: Align product documentation and install for user review

**Files:**
- Modify: `docs/design-system.md:268-300`
- Review: `docs/superpowers/specs/2026-08-25-dual-usage-limits-design.md`
- Review: `docs/superpowers/plans/2026-08-25-dual-usage-limits.md`

**Interfaces:**
- Consumes: the implemented account-row behavior.
- Produces: accurate design-system guidance and an installed build for manual review.

- [ ] **Step 1: Update the account-row documentation**

Describe the two labelled progress lines, five-hour-first percentage pair, independent semantic palettes, subdued weekly treatment, and the unchanged compact row geometry. Remove the weekly-only wording.

- [ ] **Step 2: Run final repository verification**

Run: `./run-tests.sh`

Expected: all tests pass.

Run: `./build.sh`

Expected: build succeeds.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 3: Install and relaunch the application**

Run: `./install.sh`

Expected: `/Applications/Codex Account Switcher.app` is replaced with the new signed build.

If the app was not already running, launch it with:

```bash
open "/Applications/Codex Account Switcher.app"
```

Run: `./verify-install.sh`

Expected: installed bundle, ad-hoc signature, and lifecycle monitor all verify.

- [ ] **Step 4: Hand off for visual approval without committing**

Report the modified files, verification results, and installed app path. Wait for the user's visual approval before staging, committing, or pushing `feat/dual-usage-limits` to `main`.
