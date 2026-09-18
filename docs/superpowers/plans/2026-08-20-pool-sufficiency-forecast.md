# Pool Sufficiency Forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the earliest-reset linear verdict with a seven-day forecast that uses observed consumption, current per-account balances, and every known account reset, then present it in the approved compact hybrid card.

**Architecture:** Keep history capture and forecast arithmetic in `AppInfrastructure.swift`, with one pure `PoolSufficiencyForecaster` returning a presentation-neutral value. Convert that value into localized strings in `Localization.swift`, render it in the existing AppKit card, and make `main.swift` only assemble current inputs. Retire the old weekly-curve/probability verdict path once the new model is integrated.

**Tech Stack:** Swift 5, Foundation, AppKit, existing shell-based Swift test binaries; macOS 14 target; no new dependencies.

## Global Constraints

- Forecast horizon is exactly seven rolling days from `now`.
- Use observed gross consumption from at most the latest seven days; resets and newly added capacity never reduce measured consumption.
- Fewer than seven usable history days is labeled `Предварительный прогноз` / `Preliminary forecast`.
- Fewer than two comparable samples or no positive observed consumption shows the collecting state; do not substitute a quota baseline.
- Every account's current remaining percentage and optional individual weekly reset date participates in the simulation.
- Spend accounts with the earliest upcoming reset first; a reset restores that specific account to 100%.
- Keep the titles `Хватит до сброса` and `Не хватит до сброса` and their existing English localization.
- Show only rounded whole percentages, compact reset intervals, and `current / ≈required` account counts; do not expose precise token or pool-point amounts.
- Preserve backward decoding of existing JSONL history.
- Keep the existing card frame and visual language; do not change the daily spending chart or the separate reset countdown.
- Add tests for every behavior change. Run tests and build, but do not perform visual verification; the user will inspect the installed application.

---

### Task 1: Persist individual account reset dates

**Files:**
- Modify: `Sources/AppInfrastructure.swift:1827-1893`
- Test: `Tests/InfrastructureTests.swift:1230-1310`

**Interfaces:**
- Produces: `PoolAccountSample.init(key:remaining:resetsAt:)` and `PoolAccountSample.resetsAt: Date?`.
- Produces: live/current samples whose `accounts` entries contain each account's own reset date.
- Preserves: `PoolHistorySample.resetsAt` as the legacy earliest-reset field during migration.

- [ ] **Step 1: Add failing sample and backward-compatibility tests**

Register `testPoolAccountResetDates()` in `InfrastructureTests.main()`. Extend the existing sample tests with assertions equivalent to:

```swift
private static func testPoolAccountResetDates() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let firstReset = now.addingTimeInterval(86_400)
    let secondReset = now.addingTimeInterval(2 * 86_400)
    let snapshots = [
        "a@example.com": DirectUsageSnapshot(
            fiveHour: UsageLimitWindowSnapshot(remainingPercent: 90, resetAt: nil),
            weekly: UsageLimitWindowSnapshot(remainingPercent: 70, resetAt: firstReset)
        ),
        "b@example.com": DirectUsageSnapshot(
            fiveHour: UsageLimitWindowSnapshot(remainingPercent: 80, resetAt: nil),
            weekly: UsageLimitWindowSnapshot(remainingPercent: 40, resetAt: secondReset)
        )
    ]

    let sample = PoolHistorySample.makeLive(snapshots: snapshots, now: now)
    let resets = Dictionary(uniqueKeysWithValues: sample?.accounts.map { ($0.key, $0.resetsAt) } ?? [])
    expect(resets["a@example.com"] == firstReset, "live sample should preserve the first account reset")
    expect(resets["b@example.com"] == secondReset, "live sample should preserve the second account reset")

    let legacy = Data(#"{"key":"legacy@example.com","remaining":55}"#.utf8)
    let decoded = try? JSONDecoder().decode(PoolAccountSample.self, from: legacy)
    expect(decoded?.resetsAt == nil, "legacy account samples should decode without a reset date")
}
```

- [ ] **Step 2: Run the infrastructure tests and confirm the new assertions fail**

Run:

```bash
./run-tests.sh
```

Expected: compilation or assertion failure because `PoolAccountSample` has no `resetsAt` member and live/current builders do not preserve individual dates.

- [ ] **Step 3: Add the optional field and populate it in both builders**

Implement the data shape with a defaulted initializer so existing call sites remain source-compatible:

```swift
struct PoolAccountSample: Codable, Equatable {
    let key: String
    let remaining: Double
    let resetsAt: Date?

    init(key: String, remaining: Double, resetsAt: Date? = nil) {
        self.key = key
        self.remaining = remaining
        self.resetsAt = resetsAt
    }
}
```

In `makeLive`, construct each account from the same snapshot used for its balance:

```swift
return PoolAccountSample(
    key: email,
    remaining: Double(snapshot.weekly.remainingPercent),
    resetsAt: snapshot.weekly.resetAt
)
```

In `makeCurrent`, compute the account-specific fallback before returning the sample:

```swift
let reset = snapshots[account.email]?.weekly.resetAt
    ?? WeeklyResetFormatter.upcomingResetDate(from: account.weeklyUsage, now: now, calendar: calendar)
return PoolAccountSample(key: account.email, remaining: remaining, resetsAt: reset)
```

Continue populating `PoolHistorySample.resetsAt` from the minimum known account reset so old callers and old JSON remain valid during this task.

- [ ] **Step 4: Run tests and confirm persistence behavior passes**

Run `./run-tests.sh`.

Expected: all infrastructure, AppKit, reset-logic, and install-script tests pass.

- [ ] **Step 5: Commit the persistence change**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "feat: preserve account reset dates in pool history"
```

---

### Task 2: Implement the seven-day event forecast

**Files:**
- Modify: `Sources/AppInfrastructure.swift:2006-2042, 2335-2630`
- Test: `Tests/InfrastructureTests.swift:1028-1225`

**Interfaces:**
- Consumes: `[PoolHistorySample]`, including the newest sample's `[PoolAccountSample]` with optional `resetsAt`.
- Produces: `PoolResetEvent(date:accountCount:)`.
- Produces: `PoolSufficiencyForecast` with `kind`, `isPreliminary`, `historyDays`, `burnPerDay`, `expectedDemand`, `usableCapacity`, `coverageRatio`, `exhaustionDate`, `resetEvents`, `accountCount`, and `requiredAccountCount`.
- Produces: `PoolSufficiencyForecaster.forecast(samples:now:)`.

- [ ] **Step 1: Replace old verdict tests with failing forecast scenarios**

Register focused test functions in `InfrastructureTests.main()` and build samples with explicit account balances/reset dates. Cover these exact outcomes:

```swift
private static func testPoolSufficiencyForecastStates() {
    let day: TimeInterval = 86_400
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let accounts = [PoolAccountSample(key: "a", remaining: 80, resetsAt: now.addingTimeInterval(3 * day))]

    let collecting = PoolSufficiencyForecaster.forecast(
        samples: [PoolHistorySample(ts: now, n: 1, poolTotal: 80, accounts: accounts)],
        now: now
    )
    expect(collecting.kind == .collecting, "one sample should keep collecting")

    let preliminaryHistory = burnHistory(
        start: now.addingTimeInterval(-2 * day),
        end: now,
        startRemaining: 100,
        currentAccounts: accounts
    )
    let preliminary = PoolSufficiencyForecaster.forecast(samples: preliminaryHistory, now: now)
    expect(preliminary.isPreliminary, "less than seven days should be preliminary")

    let establishedHistory = burnHistory(
        start: now.addingTimeInterval(-7 * day),
        end: now,
        startRemaining: 100,
        currentAccounts: accounts
    )
    expect(
        !PoolSufficiencyForecaster.forecast(samples: establishedHistory, now: now).isPreliminary,
        "seven usable days should establish the pace"
    )
}

private static func burnHistory(
    start: Date,
    end: Date,
    startRemaining: Double,
    currentAccounts: [PoolAccountSample]
) -> [PoolHistorySample] {
    let firstAccounts = currentAccounts.map {
        PoolAccountSample(key: $0.key, remaining: startRemaining, resetsAt: $0.resetsAt)
    }
    return [
        PoolHistorySample(
            ts: start,
            n: firstAccounts.count,
            poolTotal: firstAccounts.reduce(0) { $0 + $1.remaining },
            accounts: firstAccounts
        ),
        PoolHistorySample(
            ts: end,
            n: currentAccounts.count,
            poolTotal: currentAccounts.reduce(0) { $0 + $1.remaining },
            accounts: currentAccounts
        )
    ]
}
```

Add separate cases for: zero burn → collecting; depletion before the first reset despite enough later capacity → not enough; two simultaneous resets → one event with `accountCount == 2`; distinct resets → ordered events; unknown reset → current balance only; enough through every event and the seven-day endpoint → enough; required account count equals `ceil(expectedDemand / 100)`.

- [ ] **Step 2: Run tests and confirm the forecaster is missing**

Run `./run-tests.sh`.

Expected: compilation failure for the undefined `PoolSufficiencyForecaster` and result types.

- [ ] **Step 3: Define the forecast value and grouped reset event**

Add a forecast-neutral result beside the existing `PoolVerdict`; keep the old type temporarily so every task remains buildable until the UI cutover:

```swift
struct PoolResetEvent: Equatable {
    let date: Date
    let accountCount: Int
}

struct PoolSufficiencyForecast: Equatable {
    let kind: PoolVerdictKind
    let isPreliminary: Bool
    let historyDays: Double
    let burnPerDay: Double?
    let expectedDemand: Double?
    let usableCapacity: Double?
    let coverageRatio: Double?
    let exhaustionDate: Date?
    let resetEvents: [PoolResetEvent]
    let accountCount: Int
    let requiredAccountCount: Int?

    static func collecting(historyDays: Double, accountCount: Int) -> Self {
        Self(
            kind: .collecting,
            isPreliminary: historyDays < 7,
            historyDays: historyDays,
            burnPerDay: nil,
            expectedDemand: nil,
            usableCapacity: nil,
            coverageRatio: nil,
            exhaustionDate: nil,
            resetEvents: [],
            accountCount: accountCount,
            requiredAccountCount: nil
        )
    }
}
```

Keep `PoolVerdictKind` because localization and semantic colors already depend on it. Add a single collecting factory that retains `historyDays` and `accountCount` while all calculation fields remain `nil`.

- [ ] **Step 4: Implement chronological consumption and reset grouping**

Add `PoolSufficiencyForecaster` beside `PoolBurnRateEstimator`. Its public entry point must:

```swift
enum PoolSufficiencyForecaster {
    static let horizonSeconds: TimeInterval = 7 * 86_400

    static func forecast(
        samples: [PoolHistorySample],
        now: Date = Date()
    ) -> PoolSufficiencyForecast
}
```

Implementation rules:

1. Restrict pace history to `PoolBurnRateEstimator.lookbackSeconds` and obtain `grossBurnPerDay`.
2. Require at least two comparable samples, a positive finite span, a positive finite burn, and a newest sample with accounts; otherwise return collecting.
3. Roll each past reset anchor forward by whole seven-day cycles until it is strictly after `now`.
4. Group equal reset dates and sort ascending.
5. Between `now`, reset events, and `now + horizonSeconds`, calculate interval demand as `burnPerDay * seconds / 86_400`.
6. Deduct demand from account balances sorted by upcoming reset date, with unknown dates last. If available balance is smaller than interval demand, set exhaustion to `cursor + available / burnPerSecond` and stop with `.notEnough`.
7. When an event is reached, restore only matching accounts to `100` before continuing.
8. If the horizon is reached, return `.enough` and include the remaining balance in usable capacity.

Use one mutable internal account value and one consumption helper so ordering is explicit:

```swift
private struct SimulatedAccount {
    let key: String
    var remaining: Double
    let resetDate: Date?
}

private static func consume(
    _ demand: Double,
    from accounts: inout [SimulatedAccount]
) -> Double {
    var unmet = max(0, demand)
    let order = accounts.indices.sorted {
        switch (accounts[$0].resetDate, accounts[$1].resetDate) {
        case let (left?, right?): return left < right
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return accounts[$0].key < accounts[$1].key
        }
    }
    for index in order where unmet > 1e-9 {
        let spent = min(accounts[index].remaining, unmet)
        accounts[index].remaining -= spent
        unmet -= spent
    }
    return unmet
}
```

Use these result formulas consistently:

```swift
let expectedDemand = burnPerDay * 7
let usableCapacity = consumedBeforeStop + remainingAtStop
let coverageRatio = usableCapacity / expectedDemand
let requiredAccountCount = Int(ceil(expectedDemand / 100))
```

For a successful simulation, `remainingAtStop` is the ending balance after the full horizon. For an early failure, it is the balance available immediately before exhaustion; later resets are intentionally inaccessible because the pool cannot bridge the gap.

- [ ] **Step 5: Run tests and correct only forecast-model failures**

Run `./run-tests.sh`.

Expected: all tests pass. The new forecaster coexists with the old verdict/presenter path until the UI is migrated.

- [ ] **Step 6: Commit the pure model**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "feat: forecast pool sufficiency across account resets"
```

---

### Task 3: Localize and present the hybrid forecast data

**Files:**
- Modify: `Sources/Localization.swift:42-157, 425-535`
- Test: `Tests/InfrastructureTests.swift:327-375`

**Interfaces:**
- Consumes: `PoolSufficiencyForecast` from Task 2.
- Produces: `PoolVerdictPresenter.make(forecast:language:now:)`.
- Produces: `PoolVerdictPresentation` fields used directly by `PoolVerdictCardView` in Task 4.

- [ ] **Step 1: Write failing Russian and English presentation tests**

Replace old timeline/margin presentation assertions with fixtures for an established enough forecast, a preliminary deficit, a grouped-reset overflow case, and collecting. Assert exact strings:

```swift
expect(preliminaryRU.title == "Не хватит до сброса", "Russian deficit title should stay unchanged")
expect(preliminaryRU.subtitle == "Предварительный прогноз · темп за 4,7 дня", "partial history should be explicit")
expect(preliminaryRU.coverageValue == "−16%", "deficit should be rounded to a whole signed percent")
expect(preliminaryRU.coverageLabel == "Дефицит", "deficit caption should be semantic")
expect(preliminaryRU.accountValue == "7 / ≈9", "account comparison should be compact")
expect(preliminaryRU.accountLabel == "аккаунтов / нужно", "account comparison should be explained")
expect(preliminaryRU.resetIndicators == ["2 д 22 ч · ×2", "4 д", "ещё 2"], "reset groups should compact overflow")

expect(enoughEN.subtitle == "Average pace over 7 days", "established English pace should be localized")
expect(enoughEN.coverageValue == "+18%", "reserve should use an explicit plus sign")
expect(enoughEN.coverageLabel == "Reserve", "reserve caption should be localized")
```

Also assert `capacityFraction == min(1, coverageRatio)`, collecting hides all optional hybrid fields, and the accessibility label contains the title, forecast status, rounded percentage, account comparison, and known reset count.

- [ ] **Step 2: Run tests and confirm the new presentation API fails**

Run `./run-tests.sh`.

Expected: compilation failure because the new localization keys and presentation fields do not exist.

- [ ] **Step 3: Add hybrid localization and presentation fields without breaking the old card**

Add localized keys for:

```swift
case verdictPreliminaryPace
case verdictEstablishedPace
case verdictReserveSummary
case verdictDeficitSummary
case verdictAccountComparison
case verdictMoreResets
case verdictDaysShort
case verdictHoursShort
```

Keep the old timeline keys and fields through this task because `PoolVerdictCardView` still consumes them. Extend the presentation with optional hybrid fields and add a full initializer used by `make(forecast:language:now:)`:

```swift
struct PoolVerdictPresentation: Equatable {
    let kind: PoolVerdictKind
    let language: AppLanguage
    let title: String
    let subtitle: String
    let coverageLabel: String?
    let coverageValue: String?
    let capacityFraction: Double?
    let resetIndicators: [String]
    let accountValue: String?
    let accountLabel: String?
    let accessibilityLabel: String

    // Temporary compatibility fields removed in Task 4.
    let resetInterval: TimeInterval?
    let exhaustionInterval: TimeInterval?
    let margin: TimeInterval?
    let firstEventFraction: Double?
    let marginSummaryLabel: String?
    let marginSummaryValue: String?
    let events: [PoolVerdictEventPresentation]
}
```

The existing `make(verdict:language:)` fills hybrid fields with `nil`/empty values, and the new `make(forecast:language:now:)` fills compatibility fields with `nil`/empty values. Keep formatting helpers private to `PoolVerdictPresenter`. Format history days with one localized decimal only for preliminary forecasts; format reset intervals compactly using whole days/hours; group overflow as first two groups plus the localized remainder.

- [ ] **Step 4: Implement forecast-to-presentation mapping**

Expose one entry point:

```swift
static func make(
    forecast: PoolSufficiencyForecast,
    language: AppLanguage,
    now: Date
) -> PoolVerdictPresentation
```

Mapping rules:

- collecting uses existing collecting title/detail and nil hybrid values;
- enough uses `round((coverageRatio - 1) * 100)` with `+` and the reserve label;
- not enough uses the same signed calculation and the deficit label;
- `capacityFraction` clamps finite coverage to `0...1`;
- reset intervals are based on `event.date.timeIntervalSince(now)` and never display past events;
- a single reset omits `×1`; simultaneous resets append `· ×N`;
- account summary is `"\(accountCount) / ≈\(requiredAccountCount)"`.

Use a single signed whole-percent formatter to prevent `-0%` and inconsistent labels:

```swift
private static func signedCoverage(_ ratio: Double) -> String {
    let rounded = Int(((ratio - 1) * 100).rounded())
    if rounded > 0 { return "+\(rounded)%" }
    if rounded < 0 { return "−\(abs(rounded))%" }
    return "0%"
}
```

- [ ] **Step 5: Run tests and confirm localization/presentation passes**

Run `./run-tests.sh`.

Expected: all tests pass; the existing AppKit card continues using compatibility fields while the new presentation mapping is covered by infrastructure tests.

- [ ] **Step 6: Commit localization and presentation**

```bash
git add Sources/Localization.swift Tests/InfrastructureTests.swift
git commit -m "feat: present localized pool coverage forecast"
```

---

### Task 4: Render the approved compact hybrid AppKit card

**Files:**
- Modify: `Sources/PanelComponents.swift:444-650`
- Test: `Tests/AppKitInteractionTests.swift:10-115`

**Interfaces:**
- Consumes: the `PoolVerdictPresentation` shape from Task 3.
- Produces: `PoolVerdictCardView` with header, signed coverage summary, capacity track, reset indicators, account comparison, and collecting fallback.

- [ ] **Step 1: Replace timeline tests with failing hybrid-card assertions**

Create AppKit fixtures directly from `PoolVerdictPresentation`. Verify stable semantic content and frames rather than pixel-perfect appearance:

```swift
private static func testPoolVerdictCardShowsHybridForecast() {
    let presentation = PoolVerdictPresentation(
        kind: .notEnough,
        title: "Не хватит до сброса",
        subtitle: "Предварительный прогноз · темп за 4,7 дня",
        coverageLabel: "Дефицит",
        coverageValue: "−16%",
        capacityFraction: 0.84,
        resetIndicators: ["2 д 22 ч · ×2", "4 д", "6 д"],
        accountValue: "7 / ≈9",
        accountLabel: "аккаунтов / нужно",
        accessibilityLabel: "Не хватит до сброса. Предварительный прогноз. Дефицит 16%. 7 аккаунтов, нужно примерно 9. Известно 4 сброса."
    )
    let card = PoolVerdictCardView(
        frame: NSRect(x: 0, y: 0, width: 484, height: 108),
        presentation: presentation,
        theme: PanelTheme(isDark: true)
    )
    let labels = card.subviews.compactMap { $0 as? NSTextField }
    expect(labels.contains { $0.stringValue == "−16%" }, "card should show rounded deficit")
    expect(labels.contains { $0.stringValue == "7 / ≈9" }, "card should compare current and required accounts")
    expect(labels.contains { $0.stringValue == "2 д 22 ч · ×2" }, "card should show grouped resets")
    expect(card.accessibilityLabel() == presentation.accessibilityLabel, "card should expose the complete forecast")
}
```

Add tests that collecting has no track/reset/account subviews and that enough/not-enough tracks use the existing mint/coral semantic style.

- [ ] **Step 2: Run AppKit tests and verify the new structure fails**

Run `./run-tests.sh`.

Expected: AppKit assertion or compilation failures because the old card still expects timeline events and time-margin fields.

- [ ] **Step 3: Replace the three-event scale with the option C layout**

Keep the current `108`-point card height, `18`-point corner radius, symbol, fill, border, and style lookup. Lay out:

- title/subtitle at the existing left header origin;
- right-aligned coverage label/value in the existing `124`-point summary column;
- lower-left capacity label/track and up to three reset indicator labels;
- lower-right account value/caption.

Create one private `PoolCapacityTrackView` that draws only the track, colored fill, and terminal requirement marker from a clamped `0...1` fraction. Use `NSBezierPath` and existing theme colors; do not add image assets or dependencies. Give each reset indicator a subtle rounded background using a small `NSView` plus child label, and use the existing accent color only for the first upcoming reset group.

Use fixed geometry derived from the existing `484 × 108` card and let widths derive from `bounds.width`:

```swift
private enum ForecastCardLayout {
    static let horizontalInset: CGFloat = 18
    static let summaryWidth: CGFloat = 124
    static let accountWidth: CGFloat = 106
    static let lowerGap: CGFloat = 12
    static let trackY: CGFloat = 67
    static let trackHeight: CGFloat = 8
}

private final class PoolCapacityTrackView: NSView {
    let fraction: CGFloat
    let accent: NSColor
    let track: NSColor

    init(frame: NSRect, fraction: Double, accent: NSColor, track: NSColor) {
        self.fraction = CGFloat(max(0, min(1, fraction)))
        self.accent = accent
        self.track = track
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        track.setFill()
        bounds.roundedPath(radius: bounds.height / 2).fill()
        accent.setFill()
        NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
            .roundedPath(radius: bounds.height / 2)
            .fill()
        accent.setFill()
        NSRect(x: bounds.maxX - 1, y: -4, width: 2, height: bounds.height + 8)
            .roundedPath(radius: 1)
            .fill()
    }
}
```

The collecting state keeps the current vertically centered symbol/title/detail and creates none of the lower forecast views.

At the same cutover, remove `PoolVerdictTimelineGeometry`, `PoolVerdictEventKind`, `PoolVerdictEventPresentation`, all compatibility fields added in Task 3, and `PoolVerdictPresenter.make(verdict:language:)`. Remove the now-unused localization keys `nowEvent`, `resetEvent`, `exhaustionEvent`, and `verdictAfterResetSummary`. Update the old infrastructure presentation tests and AppKit tests in the same commit so the repository remains buildable.

- [ ] **Step 4: Run tests and confirm the card behavior passes**

Run `./run-tests.sh`.

Expected: infrastructure and AppKit interaction tests pass, including collecting behavior and accessibility.

- [ ] **Step 5: Commit the AppKit card**

```bash
git add Sources/PanelComponents.swift Tests/AppKitInteractionTests.swift
git commit -m "feat: render hybrid pool sufficiency card"
```

---

### Task 5: Integrate the forecaster and remove the obsolete model

**Files:**
- Modify: `Sources/main.swift:286-290, 1405-1420, 1752, 2295-2385`
- Modify: `Sources/AppInfrastructure.swift:2044-2180, 2335-2630`
- Modify: `Tests/InfrastructureTests.swift:68-74, 928-955, 1125-1225`

**Interfaces:**
- Consumes: `PoolSufficiencyForecaster.forecast(samples:now:)` from Task 2.
- Consumes: `PoolVerdictPresenter.make(forecast:language:now:)` from Task 3.
- Produces: `PaceDisplayState.forecast: PoolSufficiencyForecast` for the panel.

- [ ] **Step 1: Add a failing integration-shaped state assertion**

Change the pure display-state construction exercised by existing tests/helpers so it requires a `forecast` rather than a `verdict`. Ensure the collecting constructor remains possible:

```swift
let state = PaceDisplayState(
    history: [],
    now: now,
    forecast: PoolSufficiencyForecast.collecting(historyDays: 0, accountCount: 2)
)
expect(state.forecast.kind == .collecting, "empty display history should collect")
```

- [ ] **Step 2: Run tests and verify main/presenter call sites still use the old verdict**

Run `./run-tests.sh`.

Expected: compilation failures at `PaceDisplayState.verdict`, `PoolVerdict.evaluateAvailableData`, or `PoolVerdictPresenter.make(verdict:)`.

- [ ] **Step 3: Route the current sample directly through the new forecaster**

Change the display state and presenter calls to:

```swift
struct PaceDisplayState {
    let history: [PoolHistorySample]
    let now: Date
    let forecast: PoolSufficiencyForecast
}

private func pacePresentation(_ state: PaceDisplayState) -> PoolVerdictPresentation {
    PoolVerdictPresenter.make(forecast: state.forecast, language: language, now: state.now)
}
```

In `poolPaceState(now:)`, append the live/current sample as today, then calculate exactly once:

```swift
let forecast = PoolSufficiencyForecaster.forecast(samples: history, now: now)
return PaceDisplayState(history: history, now: now, forecast: forecast)
```

Remove `poolPaceForecast`, its assignment in `samplePoolHistory`, `poolBurnRatePerDay(_:)`, and `nextResetDate(after:now:)`; their responsibilities now belong to the pure forecaster.

- [ ] **Step 4: Remove algorithms made unreachable by this feature**

After `rg` confirms they have no production references, delete `WeekCurveBuilder`, `PaceEstimator`, old `PoolVerdict.evaluate`/`evaluateAvailableData`, and their dedicated tests. Keep `PoolBurnRateEstimator`, daily aggregation, and all chart code.

Run:

```bash
rg -n "WeekCurveBuilder|PaceEstimator|evaluateAvailableData|PoolVerdictTimelineGeometry|poolPaceForecast" Sources Tests
```

Expected: no matches.

- [ ] **Step 5: Run the complete non-visual verification sequence**

Run:

```bash
./run-tests.sh
./build.sh
git diff --check
```

Expected: all tests pass, the app bundle builds successfully, and `git diff --check` produces no output. Do not open, screenshot, or visually inspect the application.

- [ ] **Step 6: Check documentation consistency**

Read `docs/plans/2026-08-20-pool-sufficiency-forecast-design.md` against the final names and behavior. Update it only if implementation necessarily changed an approved public behavior; do not edit unrelated plans.

- [ ] **Step 7: Commit the integration and cleanup**

```bash
git add Sources/main.swift Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift docs/plans/2026-08-20-pool-sufficiency-forecast-design.md
git commit -m "feat: use reset-aware pool sufficiency forecast"
```

---

### Task 6: Install for user inspection

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: the verified app bundle from Task 5.
- Produces: an installed and relaunched local `Codex Account Switcher` for the user's own visual review.

- [ ] **Step 1: Confirm the worktree contains only intended changes**

Run:

```bash
git status --short
git diff --stat HEAD~5..HEAD
```

Expected: feature commits contain only the forecast, presentation, tests, and any necessary design-doc consistency update. Pre-existing unrelated user changes remain untouched.

- [ ] **Step 2: Install and relaunch without visual inspection**

Run:

```bash
./install.sh
pkill -x CodexAccountSwitcher
open "/Applications/Codex Account Switcher.app"
```

Expected: install script succeeds and the process relaunches. A non-zero `pkill` only means the app was not running; continue with `open`. Do not inspect the window or capture screenshots.

- [ ] **Step 3: Report the exact verification and commit state**

Report test/build/install results, the final commit hash, and that visual verification was intentionally left to the user. Do not push or create a pull request unless the user separately requests it.
