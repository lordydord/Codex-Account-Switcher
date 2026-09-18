# Dynamic Daily Pool Spend Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the daily minimum-remaining chart with a dynamic 14-day chart of gross daily spend across the normalized weekly account pool, including the approved compact hover popover.

**Architecture:** Keep daily-spend aggregation and hover copy as pure, independently tested logic in `AppInfrastructure.swift` and `Localization.swift`. Feed prepared `DailyPoolSpendPoint` values into the existing Swift Charts view in `main.swift`; forecast and persistence continue using raw `PoolHistorySample` values unchanged.

**Tech Stack:** Swift 6.3, SwiftUI, Swift Charts, AppKit `NSHostingView`, Foundation calendar/date APIs, existing shell-driven Swift test suite.

## Global Constraints

- Target macOS 14+ and preserve the dark-only warm Native Glass design system.
- Keep exactly 14 local-calendar-day slots ending today.
- Treat each account as one normalized 100-point weekly quota unit; never present absolute tokens.
- Sum only decreases in per-account remaining capacity; resets, restored capacity, and account additions never subtract spend.
- Preserve existing JSONL history and all forecast/verdict behavior.
- Reuse `nativeMint/nativeBlue`, `nativeGold/nativeOrange`, and `nativeCoral/nativeRed`; do not introduce raw palette values.
- Keep the chart section at `104 pt` unless the compact popover provably cannot fit; do not change panel geometry in this implementation.
- Add every user-facing string in Russian and English.
- Do not visually inspect, install, or relaunch the app; the user explicitly requested automated verification only.

---

### Task 1: Daily spend aggregation

**Files:**
- Modify: `Sources/AppInfrastructure.swift:2145-2193`
- Modify: `Tests/InfrastructureTests.swift:65-75,900-950`

**Interfaces:**
- Consumes: `[PoolHistorySample]`, `dayCount`, `now`, `Calendar`, `PoolHistoryStore.samplingInterval`.
- Produces: `DailyPoolSpendCoverage`, `DailyPoolSpendPoint`, and `DailyPoolSpendAggregator.dailyPoints(from:dayCount:now:calendar:samplingInterval:) -> [DailyPoolSpendPoint]`.

- [ ] **Step 1: Replace daily-minimum assertions with failing daily-spend cases**

Add test fixtures whose `accounts` contain stable keys and remaining values. Cover accumulation, reset increases, two-account normalization, an added account, missing dates, current-day updates, local day boundaries, and lower-bound coverage:

```swift
func sample(_ ts: Date, _ values: [String: Double]) -> PoolHistorySample {
    let accounts = values.keys.sorted().map { PoolAccountSample(key: $0, remaining: values[$0]!) }
    return PoolHistorySample(
        ts: ts,
        n: accounts.count,
        poolTotal: accounts.reduce(0) { $0 + $1.remaining },
        accounts: accounts
    )
}

let points = DailyPoolSpendAggregator.dailyPoints(
    from: [
        sample(day0.addingTimeInterval(-15 * 60), ["a": 100, "b": 100]),
        sample(day0.addingTimeInterval(30 * 60), ["a": 90, "b": 100]),
        sample(day0.addingTimeInterval(60 * 60), ["a": 80, "b": 90])
    ],
    dayCount: 1,
    now: day0.addingTimeInterval(90 * 60),
    calendar: calendar
)
expect(abs((points[0].spentPercent ?? -1) - 15) < 0.001, "30 points across two accounts should consume 15% of the pool")
```

- [ ] **Step 2: Run the infrastructure suite and confirm the new test fails**

Run: `./run-tests.sh`
Expected: compile failure because `DailyPoolSpendAggregator` and its point types do not exist.

- [ ] **Step 3: Implement the pure aggregator**

Replace `DailyPoolPoint`/`DailyPoolAggregator` with:

```swift
enum DailyPoolSpendCoverage: Equatable {
    case noData
    case complete
    case lowerBound
    case inProgress
    case inProgressLowerBound
}

struct DailyPoolSpendPoint: Equatable {
    let date: Date
    let spentPercent: Double?
    let remainingPercent: Double?
    let accountCount: Int
    let coverage: DailyPoolSpendCoverage
}
```

For each day, include a valid opening anchor no older than one sampling interval; build the represented-account union; sum `max(0, previous - current)` only between consecutive observations of the same key; divide by the represented account count; classify no data, complete, lower bound, in progress, and in-progress lower bound. Mark a past day lower-bound when the anchor is missing, any global observation gap exceeds two sampling intervals, any represented account has fewer than two observations, or the final observation is more than two sampling intervals before day end.

- [ ] **Step 4: Run tests and make all aggregation cases pass**

Run: `./run-tests.sh`
Expected: all infrastructure assertions pass, followed by existing AppKit, reset self-test, and install-script tests.

- [ ] **Step 5: Commit the aggregation slice**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "feat: aggregate dynamic daily pool spend"
```

---

### Task 2: Localized popover and accessibility copy

**Files:**
- Modify: `Sources/Localization.swift:160-290`
- Modify: `Tests/InfrastructureTests.swift:190-255`

**Interfaces:**
- Consumes: `DailyPoolSpendPoint`, `isToday` encoded by its coverage, `AppLanguage`.
- Produces: `PoolChartLocalization.detailLines(for:language:) -> [String]`, `accessibilityValue(for:language:) -> String`, `dailyReference(language:) -> String`, and updated semantic labels.

- [ ] **Step 1: Write failing Russian and English copy tests**

Cover complete today, complete past day, lower-bound today, lower-bound past day, and no data:

```swift
let point = DailyPoolSpendPoint(
    date: date,
    spentPercent: 18,
    remainingPercent: 36.6,
    accountCount: 7,
    coverage: .inProgress
)
expect(
    PoolChartLocalization.detailLines(for: point, language: .russian) == [
        "20 авг.", "Потрачено: 18% пула", "Темп: 1,3× дневного ориентира", "Осталось сейчас: 36,6%"
    ],
    "today popover should use current remaining wording"
)
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `./run-tests.sh`
Expected: compile failure because the new localization APIs do not exist.

- [ ] **Step 3: Implement complete localized sentences and locale-aware formatting**

Use the existing `AppLanguage.locale`, `Date.FormatStyle`, and `FloatingPointFormatStyle`. Compute pace as `spentPercent / (100.0 / 7.0)`. Return only the date and no-data line for `.noData`; use `Потрачено не менее`/`Spent at least` for lower bounds; use `Осталось сейчас`/`Remaining now` for in-progress coverage and end/last-sample wording for past days.

- [ ] **Step 4: Run tests and confirm all copy cases pass**

Run: `./run-tests.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit the localization slice**

```bash
git add Sources/Localization.swift Tests/InfrastructureTests.swift
git commit -m "feat: localize daily spend chart details"
```

---

### Task 3: Dynamic Swift Charts rendering and compact hover popover

**Files:**
- Modify: `Sources/AppInfrastructure.swift:2145-2200`
- Modify: `Sources/main.swift:34-240,1350-1392`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Consumes: `[DailyPoolSpendPoint]` and `PoolChartLocalization` APIs from Tasks 1–2.
- Produces: the updated `PoolPaceChartView` with stable daily identity, semantic spend gradients, 14.3% reference rule, pointer selection, selected-bar emphasis, compact popover, and accessibility values.

- [ ] **Step 1: Add failing pure policy tests for spend bands and hover selection**

Extract view-independent rules into `AppInfrastructure.swift` so they compile in the infrastructure suite:

```swift
expect(DailyPoolSpendBand.classify(14.3) == .withinReference, "14.3% should remain within reference")
expect(DailyPoolSpendBand.classify(14.31) == .aboveReference, "values above the reference should warn")
expect(DailyPoolSpendBand.classify(25.01) == .high, "values above 25% should be high")
expect(PoolChartHoverPolicy.nearestIndex(to: 4.6, count: 14) == 5, "hover should choose the nearest stable slot")
expect(PoolChartHoverPolicy.nearestIndex(to: -2, count: 14) == 0, "hover should clamp to the first slot")
```

- [ ] **Step 2: Run tests and confirm policy failures**

Run: `./run-tests.sh`
Expected: compile failure for the new policy types.

- [ ] **Step 3: Implement policy types and update chart data mapping**

Add `DailyPoolSpendBand` with thresholds `14.3` and `25`, plus a clamped nearest-index helper. Change `paceChartData(_:)` to call `DailyPoolSpendAggregator.dailyPoints(from:now:)` and pass those points directly to the chart.

- [ ] **Step 4: Replace remaining-capacity fills with spend fills**

Render the muted `0...100` track and optional `spentPercent` fill for every stable date. Add a dashed `RuleMark(y: 100.0 / 7.0)` using the subdued gold token. Map spend bands to the approved native gradients. Keep the Y axis hidden and four X labels distributed across all 14 slots.

- [ ] **Step 5: Implement hover emphasis without layout movement**

Keep `@State private var hoveredIndex: Int?`. Use the chart overlay and `PoolChartHoverPolicy` to select a slot. Increase the selected fill opacity and semantic shadow/outline while reducing non-selected opacity; do not change `BarMark` width or chart geometry. Respect `accessibilityReduceMotion` by disabling non-essential animation.

- [ ] **Step 6: Implement the compact bounded popover**

Use a chart overlay anchored to `ChartProxy.position(forX:)`. Render `PoolChartLocalization.detailLines` in a compact dark glass container with monospaced numeric text, a low-contrast border, compact continuous radius, and restrained shadow. Clamp its center so the first and last bars remain inside the chart width. The overlay disappears on hover exit and updates in place between slots.

- [ ] **Step 7: Add accessibility semantics**

Expose a chart-level daily-spend summary and a localized value for each prepared point. Ensure no-data and lower-bound days are distinguishable without color or hover.

- [ ] **Step 8: Run automated verification for the chart slice**

Run: `./run-tests.sh`
Expected: all tests pass.
Run: `./build.sh`
Expected: app compiles and signs successfully; no visual launch is performed.

- [ ] **Step 9: Commit the chart slice**

```bash
git add Sources/AppInfrastructure.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "feat: render dynamic daily pool spend chart"
```

---

### Task 4: Documentation consistency and final automated verification

**Files:**
- Modify: `docs/design-system.md:95-115,250-270`
- Modify: `CHANGELOG.md:1-20`
- Modify: `docs/superpowers/specs/2026-08-20-dynamic-daily-pool-spend-chart-design.md`

**Interfaces:**
- Consumes: the completed runtime behavior from Tasks 1–3.
- Produces: canonical documentation that distinguishes account remaining-capacity meters from the daily consumed-capacity pool chart.

- [ ] **Step 1: Update canonical chart semantics**

State explicitly that account progress continues to show remaining capacity, while the 14-day pool chart shows gross daily consumed capacity normalized across observed accounts. Document the 14.3% reference and approved spend bands.

- [ ] **Step 2: Correct changelog wording**

Replace the stale five-hour description with weekly-pool wording and describe the dynamic daily-spend bars and compact hover details.

- [ ] **Step 3: Align the approved spec with the implemented deterministic completeness rule**

Record the opening-anchor, two-interval gap, and past-day tail coverage conditions exactly as implemented.

- [ ] **Step 4: Run complete non-visual verification**

Run: `./run-tests.sh`
Expected: all suites pass.
Run: `./build.sh`
Expected: successful build and signing.
Run: `git diff --check`
Expected: no whitespace errors.
Run: `git status --short`
Expected: only intended implementation files are modified before the final commit.

- [ ] **Step 5: Commit documentation**

```bash
git add docs/design-system.md CHANGELOG.md docs/superpowers/specs/2026-08-20-dynamic-daily-pool-spend-chart-design.md
git commit -m "docs: describe daily pool spend chart"
```
