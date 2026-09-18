# Proportional Pool Verdict Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the pool verdict line into a proportional time scale and replace the truncating signed capsule with a two-line localized margin summary.

**Architecture:** Keep forecast evaluation unchanged. Extend the pure presentation layer with timeline geometry and semantic margin text, then make the existing AppKit `PoolVerdictCardView` render only those display-ready values. Keep event labels in collision-safe columns while drawing the first-event point at its true proportional position.

**Tech Stack:** Swift 6 toolchain, Foundation, AppKit, existing shell-driven infrastructure tests, macOS 14 deployment target

## Global Constraints

- Do not change burn, exhaustion, reset, margin, history sampling, or reset calculations.
- Do not animate continuously between data refreshes.
- Do not migrate the card to SwiftUI.
- Keep `UsagePanelLayoutMetrics.verdictCardHeight == 108` and the surrounding panel layout unchanged.
- Keep Russian and English localization exhaustive and preserve correct clock-time plural forms.
- Do not launch the app, use browser automation, capture screenshots, or perform visual inspection.
- Do not stage the existing `.agents/skills/swiftui-expert-skill` deletions or the pre-existing untracked `docs/plans/` directory.

---

## File Map

- `Sources/Localization.swift`: localized summary keys, pure timeline fraction helper, and display-ready verdict presentation fields.
- `Tests/InfrastructureTests.swift`: regression coverage for geometry, summary semantics, Collecting behavior, and existing event ordering.
- `Sources/PanelComponents.swift`: AppKit header summary and proportional track/point drawing; removal of the orphaned fixed badge view.
- `docs/superpowers/specs/2026-08-19-proportional-pool-verdict-timeline-design.md`: approved behavior contract; no further edits expected.

### Task 1: Add proportional geometry and margin-summary presentation

**Files:**
- Modify: `Sources/Localization.swift:52-153`
- Modify: `Sources/Localization.swift:360-445`
- Test: `Tests/InfrastructureTests.swift:250-295`

**Interfaces:**
- Produces: `PoolVerdictTimelineGeometry.firstEventFraction(firstInterval:lastInterval:) -> Double?`
- Produces: `PoolVerdictPresentation.firstEventFraction: Double?`
- Produces: `PoolVerdictPresentation.marginSummaryLabel: String?`
- Produces: `PoolVerdictPresentation.marginSummaryValue: String?`
- Preserves temporarily: `PoolVerdictPresentation.marginBadge` until Task 2 updates the AppKit consumer.

- [ ] **Step 1: Write failing presentation and geometry assertions**

Update `testPoolVerdictPresentation()` so the existing Enough and Not Enough fixtures assert the new fields:

```swift
expect(abs((enoughRU.firstEventFraction ?? -1) - (2.0 / 2.9)) < 0.000_001, "Enough should place reset proportionally before exhaustion")
expect(enoughRU.marginSummaryLabel == "Запас после сброса", "Enough should explain the positive margin")
expect(enoughRU.marginSummaryValue == "21 час 36 минут", "Enough should show the absolute localized margin")

expect(abs((notEnoughEN.firstEventFraction ?? -1) - (1.3 / 2.0)) < 0.000_001, "Not Enough should place exhaustion proportionally before reset")
expect(notEnoughEN.marginSummaryLabel == "Deficit", "Not Enough should explain the negative margin")
expect(notEnoughEN.marginSummaryValue == "16 hours 48 minutes", "Not Enough should show the absolute localized margin")

expect(collecting.firstEventFraction == nil, "Collecting should not expose timeline geometry")
expect(collecting.marginSummaryLabel == nil, "Collecting should not show a margin label")
expect(collecting.marginSummaryValue == nil, "Collecting should not show a margin value")
```

Add direct helper assertions to the same test:

```swift
expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 5, lastInterval: 10) == 0.5, "timeline geometry should preserve ratios")
expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: -1, lastInterval: 10) == 0, "timeline geometry should clamp the lower endpoint")
expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 12, lastInterval: 10) == 1, "timeline geometry should clamp the upper endpoint")
expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 1, lastInterval: 0) == nil, "timeline geometry should reject an empty horizon")
expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: .infinity, lastInterval: 10) == nil, "timeline geometry should reject non-finite intervals")
```

- [ ] **Step 2: Run the pure infrastructure compile to verify RED**

Run:

```bash
TEST_DIR="${TMPDIR:-/tmp}/codex-verdict-plan-red"
mkdir -p "$TEST_DIR"
/usr/bin/xcrun swiftc Sources/Models.swift Sources/Localization.swift Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift -target arm64-apple-macosx14.0 -o "$TEST_DIR/InfrastructureTests"
```

Expected: compilation fails because `firstEventFraction`, `marginSummaryLabel`, `marginSummaryValue`, and `PoolVerdictTimelineGeometry` do not exist.

- [ ] **Step 3: Add exhaustive localized summary keys**

Add these cases to `LocalizedTextKey`:

```swift
case verdictDeficitSummary
case verdictAfterResetSummary
```

Add values to both exhaustive language switches:

```swift
// Russian
case .verdictDeficitSummary: return "Дефицит"
case .verdictAfterResetSummary: return "Запас после сброса"

// English
case .verdictDeficitSummary: return "Deficit"
case .verdictAfterResetSummary: return "After reset"
```

- [ ] **Step 4: Add the pure geometry helper**

Place this beside the presentation types in `Sources/Localization.swift`:

```swift
enum PoolVerdictTimelineGeometry {
    static func firstEventFraction(
        firstInterval: TimeInterval,
        lastInterval: TimeInterval
    ) -> Double? {
        guard firstInterval.isFinite, lastInterval.isFinite, lastInterval > 0 else { return nil }
        return max(0, min(1, firstInterval / lastInterval))
    }
}
```

- [ ] **Step 5: Populate the new presentation fields**

Add the three optional properties to `PoolVerdictPresentation`. Set all three to `nil` in Collecting. In the Enough/Not Enough branch, derive the first and last intervals from the same event order already used for labels:

```swift
let firstInterval = verdict.kind == .enough ? reset : exhaustion
let lastInterval = verdict.kind == .enough ? exhaustion : reset
guard let firstEventFraction = PoolVerdictTimelineGeometry.firstEventFraction(
    firstInterval: firstInterval,
    lastInterval: lastInterval
) else {
    return make(verdict: .collecting, language: language)
}
let marginSummaryKey: LocalizedTextKey = verdict.kind == .enough
    ? .verdictAfterResetSummary
    : .verdictDeficitSummary
```

Populate the presentation:

```swift
firstEventFraction: firstEventFraction,
marginSummaryLabel: LocalizedText.value(marginSummaryKey, language: language),
marginSummaryValue: LocalizedIntervalFormatter.duration(abs(margin), language: language),
```

- [ ] **Step 6: Run the infrastructure tests to verify GREEN**

Run the same `swiftc` command from Step 2, then:

```bash
"$TEST_DIR/InfrastructureTests"
```

Expected: `All infrastructure tests passed` with the assertion count printed by the harness.

- [ ] **Step 7: Commit the presentation layer**

```bash
git add Sources/Localization.swift Tests/InfrastructureTests.swift
git diff --cached --check
git commit -m "feat: add proportional verdict presentation"
```

### Task 2: Render the proportional AppKit timeline and remove the capsule

**Files:**
- Modify: `Sources/PanelComponents.swift:444-640`
- Modify: `Sources/Localization.swift:375-425`
- Modify: `Tests/InfrastructureTests.swift:270-295`
- Modify: `Tests/AppKitInteractionTests.swift`

**Interfaces:**
- Consumes: `PoolVerdictPresentation.firstEventFraction`
- Consumes: `PoolVerdictPresentation.marginSummaryLabel`
- Consumes: `PoolVerdictPresentation.marginSummaryValue`
- Removes: `PoolVerdictPresentation.marginBadge`
- Removes: private `CenteredBadgeTextView`

- [ ] **Step 1: Remove the obsolete signed-badge assertions**

Delete the three `marginBadge` assertions from `testPoolVerdictPresentation()`. Keep the standalone `LocalizedIntervalFormatter.signedMargin` tests because that formatter remains a valid independent utility.

- [ ] **Step 2: Replace the badge with two right-aligned labels**

In `PoolVerdictCardView.init`, replace `badgeWidth`, `badgeGap`, and `CenteredBadgeTextView` with a stable `124 pt` summary column:

```swift
let showsMarginSummary = presentation.marginSummaryLabel != nil && presentation.marginSummaryValue != nil
let summaryWidth: CGFloat = showsMarginSummary ? 124 : 0
let summaryGap: CGFloat = showsMarginSummary ? 10 : 0
let textTrailingInset: CGFloat = 14 + summaryWidth + summaryGap
```

When both values exist, add two labels:

```swift
let summaryX = bounds.width - 14 - summaryWidth
addSubview(Self.label(
    frame: NSRect(x: summaryX, y: 10, width: summaryWidth, height: 13),
    text: marginSummaryLabel,
    font: .systemFont(ofSize: 9.5, weight: .semibold),
    color: theme.secondaryText,
    alignment: .right
))
addSubview(Self.label(
    frame: NSRect(x: summaryX, y: 24, width: summaryWidth, height: 16),
    text: marginSummaryValue,
    font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .bold),
    color: style.accent,
    alignment: .right
))
```

- [ ] **Step 3: Draw the track split at the proportional point**

Keep the existing three label-column centers. Replace the fixed middle drawing center with:

```swift
guard let fraction = presentation.firstEventFraction else { return }
let labelCenters = (0..<3).map { horizontalInset + columnWidth * (CGFloat($0) + 0.5) }
let startX = labelCenters[0]
let endX = labelCenters[2]
let firstEventX = startX + (endX - startX) * CGFloat(max(0, min(1, fraction)))
let pointCenters = [startX, firstEventX, endX]
```

Draw the gradient only when `firstEventX > startX`, and draw the subdued segment only when `endX > firstEventX`. This prevents zero-width path work at clamped endpoints.

- [ ] **Step 4: Keep the label band visually quiet**

Do not draw a diagonal connector from `firstEventX` to the fixed center label column. Keep the proportional point on the horizontal track and let the ordered labels plus exact interval text identify the event. Add an AppKit bitmap regression test that renders `PoolVerdictCardView.draw(_:)` and verifies the band between the track and labels contains no auxiliary stroke.

- [ ] **Step 5: Remove the obsolete badge model and view**

Remove `marginBadge` from `PoolVerdictPresentation` and both presenter initializers. Delete the now-unused private `CenteredBadgeTextView` class from `Sources/PanelComponents.swift`. Do not remove `LocalizedIntervalFormatter.signedMargin` because its direct formatter tests remain.

- [ ] **Step 6: Run focused compile and full tests**

Run:

```bash
/bin/bash ./run-tests.sh
```

Expected:

- infrastructure tests pass;
- AppKit interaction tests compile and pass;
- reset self-test passes;
- install-script tests pass.

- [ ] **Step 7: Build without launching or visual inspection**

Run:

```bash
/bin/bash ./build.sh
```

Expected: prints the path to `build/Codex Account Switcher.app` and exits `0`. Do not open the app.

- [ ] **Step 8: Commit the AppKit rendering**

```bash
git add Sources/Localization.swift Sources/PanelComponents.swift Tests/InfrastructureTests.swift Tests/AppKitInteractionTests.swift
git diff --cached --check
git commit -m "feat: render proportional verdict timeline"
```

### Task 3: Final verification and scope audit

**Files:**
- Verify only: `Sources/Localization.swift`
- Verify only: `Sources/PanelComponents.swift`
- Verify only: `Tests/InfrastructureTests.swift`
- Verify only: `Tests/AppKitInteractionTests.swift`
- Verify only: `docs/superpowers/specs/2026-08-19-proportional-pool-verdict-timeline-design.md`

**Interfaces:**
- Consumes: completed Tasks 1 and 2
- Produces: evidence that the implementation matches the approved spec without visual testing

- [ ] **Step 1: Run repository checks**

```bash
/bin/bash ./run-tests.sh
/bin/bash ./build.sh
git diff --check HEAD~2..HEAD
```

Expected: both scripts exit `0` and `git diff --check` prints nothing.

- [ ] **Step 2: Audit the final diff and unrelated working-tree state**

```bash
git diff --stat HEAD~2..HEAD
git diff --name-status HEAD~2..HEAD
git status --short --branch
```

Expected committed implementation scope:

- `Sources/Localization.swift`
- `Sources/PanelComponents.swift`
- `Tests/InfrastructureTests.swift`
- `Tests/AppKitInteractionTests.swift`

Expected unrelated unstaged state remains untouched:

- `.agents/skills/swiftui-expert-skill/**` deletions from the approved skill relocation;
- `docs/plans/` untracked files that predated this feature.

- [ ] **Step 3: Report completion without a visual claim**

Report test and build results, committed file scope, and the absence of visual verification. Do not claim that the rendered layout was visually inspected.
