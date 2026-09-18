# Compact Usage Panel and Complete Daily Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fit ten account rows in the current usage-panel height, make the reset button readable, and render fourteen dated chart slots including days without samples.

**Architecture:** `DailyPoolAggregator` remains the pure Foundation boundary that constructs calendar-day data. Swift Charts receives optional daily values and always draws fourteen capacity tracks, while AppKit layout constants control the compact account rows and shared lower-bar height.

**Tech Stack:** Swift 6.3, Foundation, AppKit, SwiftUI, Swift Charts, custom executable infrastructure tests.

## Global Constraints

- Display exactly 14 chronological calendar-day slots ending today.
- Missing history is represented by `nil`, never by a numeric zero.
- Use `Сбросы (N)`, `Сбросы (…)`, `Сбросы (?)`, and `Сбросы (N+)` for reset-credit states.
- Use 39 pt account rows with 4 pt gaps; ten rows occupy 426 pt.
- The reset-chance card and bottom settings bar are both 44 pt high.
- Do not change forecast calculations, reset redemption, networking, account sorting, panel width, or the ten-row visibility limit.

---

### Task 1: Build complete daily slots in pure infrastructure

**Files:**
- Modify: `Sources/AppInfrastructure.swift:906-950`
- Test: `Tests/InfrastructureTests.swift:565-608`

**Interfaces:**
- Produces: `DailyPoolPoint(date: Date, value: Double?, endValue: Double?, sampleCount: Int)`.
- Produces: `DailyPoolAggregator.dailyPoints(from:dayCount:now:calendar:) -> [DailyPoolPoint]`, returning exactly `dayCount` ordered points when `dayCount >= 1`.
- Consumes: `PoolHistorySample` and `PoolHistoryStore.poolAverage(n:poolTotal:)`.

- [ ] **Step 1: Rewrite the aggregation assertions to specify fourteen complete slots**

```swift
let points = DailyPoolAggregator.dailyPoints(
    from: history,
    dayCount: 4,
    now: day3.addingTimeInterval(2 * 3600),
    calendar: calendar
)
expect(points.count == 4, "the window should contain all four calendar-day slots")
expect(points[0].value == 80, "the first known day should keep its minimum")
expect(points[1].endValue == 70, "the second known day should keep its last sample")
expect(points[2].value == nil, "a missing day should have no numeric value")
expect(points[2].endValue == nil, "a missing day should have no end value")
expect(points[2].sampleCount == 0, "a missing day should have zero samples")
expect(points[3].value == 60, "the final known day should retain its value")

let empty = DailyPoolAggregator.dailyPoints(from: [], dayCount: 14, now: day3, calendar: calendar)
expect(empty.count == 14, "an empty history should still produce fourteen dated slots")
expect(empty.allSatisfy { $0.value == nil && $0.sampleCount == 0 }, "empty-history slots should remain unknown")
```

- [ ] **Step 2: Run the infrastructure tests and verify the new assertions fail**

Run: `./run-tests.sh`

Expected: FAIL because the current aggregator skips missing days and returns no points for empty history.

- [ ] **Step 3: Make daily values optional and construct every calendar day**

```swift
struct DailyPoolPoint: Equatable {
    let date: Date
    let value: Double?
    let endValue: Double?
    let sampleCount: Int
}

static func dailyPoints(...) -> [DailyPoolPoint] {
    guard dayCount >= 1,
          let windowStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: calendar.startOfDay(for: now))
    else { return [] }
    // Group only real samples, then map 0..<dayCount into dated slots.
    // Known slots aggregate min/end/count; unknown slots use nil/nil/0.
}
```

- [ ] **Step 4: Run infrastructure tests**

Run: `./run-tests.sh`

Expected: PASS, including the updated daily-slot assertions.

- [ ] **Step 5: Commit the infrastructure slice**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "feat: preserve empty daily chart slots"
```

### Task 2: Render all fourteen Swift Charts positions

**Files:**
- Modify: `Sources/main.swift:39-235`
- Modify: `Sources/main.swift:1408-1445`

**Interfaces:**
- Consumes: optional `DailyPoolPoint.value` and `endValue` from Task 1.
- Produces: optional `PoolPacePoint.value` and `PoolPaceChartView.Bar.value`.
- Preserves: `PoolPaceChartData`, `PoolResolution`, forecast text, verdict badge, and hover selection.

- [ ] **Step 1: Change chart point and bar values to optional**

```swift
struct PoolPacePoint: Identifiable {
    let date: Date
    let value: Double?
    var endValue: Double?
    var sampleCount: Int = 1
    var id: Date { date }
}
```

Mirror the optional type on `PoolPaceChartView.Bar.value`.

- [ ] **Step 2: Draw a track for every slot and a fill only for known values**

```swift
BarMark(
    x: .value("Index", Double(bar.index)),
    yStart: .value("Base", 0),
    yEnd: .value("Capacity", 100),
    width: .fixed(barWidth)
)
.foregroundStyle(data.gridLine.opacity(0.45))

if let value = bar.value {
    BarMark(
        x: .value("Index", Double(bar.index)),
        yStart: .value("Base", 0),
        yEnd: .value("Pool", value),
        width: .fixed(barWidth)
    )
    .foregroundStyle(barColor(for: value))
}
```

- [ ] **Step 3: Use daily slots unconditionally and describe missing hover values**

```swift
let history = DailyPoolAggregator.dailyPoints(from: state.history).map {
    PoolPacePoint(date: $0.date, value: $0.value, endValue: $0.endValue, sampleCount: $0.sampleCount)
}
```

In daily hover text, return `"<date> · Нет данных"` when `bar.value == nil`; otherwise preserve low/end/today details.

- [ ] **Step 4: Build the app**

Run: `./build.sh`

Expected: `Build complete` with no Swift type or Charts builder errors.

- [ ] **Step 5: Commit the chart slice**

```bash
git add Sources/main.swift
git commit -m "feat: render complete daily chart"
```

### Task 3: Compact account rows and reset controls

**Files:**
- Modify: `Sources/main.swift:9-30`
- Modify: `Sources/main.swift:412-520`
- Modify: `Sources/main.swift:1027-1080`
- Modify: `Sources/main.swift:1382-1405`
- Modify: `Sources/main.swift:1561-1660`

**Interfaces:**
- Produces: `AccountPanelLayout.controlBarHeight = 44`, shared by reset-chance and bottom-bar geometry.
- Produces: `AccountPanelLayout.rowHeight = 39` and `AccountPanelLayout.rowGap = 4`.
- Preserves: existing button actions, colors, tooltips, sort order, and panel width.

- [ ] **Step 1: Consolidate bar height and compact list constants**

```swift
static let controlBarHeight: CGFloat = 44
static let rowHeight: CGFloat = 39
static let rowGap: CGFloat = 4
```

Replace bottom-bar and reset-chance height uses with `controlBarHeight`.

- [ ] **Step 2: Re-center row content within 39 pt**

Use these exact vertical frames in `accountListRow`:

```swift
let switchButton = PillButton(... y: 7.5, ... height: 24, ...)
let emailLabel = label(... y: 4, ... height: 14, ...)
ProgressLineView(... y: 24, ... height: 8, ...)
label(percentText(...), ... y: 22, ... height: 16, ...)
label(WeeklyResetFormatter.text(...), ... y: 22, ... height: 16, ...)
```

- [ ] **Step 3: Replace reset-credit button titles and widen its frame**

```swift
if state.hasError, state.knownTotal == 0 { return "Сбросы (?)" }
guard state.knownAccounts > 0 else { return "Сбросы (…)" }
let suffix = state.hasError ? "+" : ""
return "Сбросы (\(state.knownTotal)\(suffix))"
```

Use a 94 pt reset button on the 448 pt usage panel and retain at least 8 pt between its frame and adjacent controls.

- [ ] **Step 4: Run complete automated verification**

Run: `./run-tests.sh`

Expected: all infrastructure assertions pass.

Run: `./build.sh`

Expected: `Build complete`.

- [ ] **Step 5: Install and relaunch for visual verification**

Run: `./install.sh`, terminate the running `CodexAccountSwitcher`, and relaunch `/Applications/Codex Account Switcher.app`.

Verify: ten rows are fully visible; neither lower panel is clipped; both lower panels are 44 pt; reset text has visible horizontal padding; chart shows fourteen evenly spaced tracks with gaps where history is unknown.

- [ ] **Step 6: Commit the layout slice**

```bash
git add Sources/main.swift
git commit -m "fix: compact usage panel layout"
```
