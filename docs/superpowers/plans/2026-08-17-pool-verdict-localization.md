# Pool Verdict and Main-Panel Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw pool forecast sentence with a localized Enough / Not Enough / Collecting verdict card and add immediate Russian/English switching for the main panel, with Russian as the persisted default.

**Architecture:** Add a standalone Foundation-only localization module that owns stable language values, `UserDefaults` persistence, typed copy, and localized time/number formatting. Simplify `PoolVerdict` into a pure event-order evaluator, then convert it into a display-ready `PoolVerdictPresentation` before AppKit rendering; the panel receives one captured `now`, the selected language, and immutable presentation data. Keep history collection, reset anchors, forecast sampling, network refreshes, account state, and technical errors unchanged.

**Tech Stack:** Swift 6, Foundation, AppKit, SwiftUI Charts, `UserDefaults`, custom shell-based Swift infrastructure tests, macOS 14 deployment floor.

## Global Constraints

- Russian is the default when the saved language is missing, empty, or unknown; supported stable raw values are exactly `ru` and `en`.
- The language row label remains exactly `Язык / Language`; its options are exactly `Русский` and `English`.
- Language changes persist and rebuild the currently visible panel immediately without restarting either application, changing account state, or triggering usage, reset-chance, or reset-credit refreshes.
- First-stage localization covers only the main account panel, inline switch/quit confirmations, pool-verdict card, reset-chance title, main-panel buttons/tooltips, and the language control.
- Settings content unrelated to language, reset-credit/API screens, notifications, technical logs, upstream error payloads, and technical error messages remain unchanged.
- Visible verdict semantics depend only on event order: exhaustion before reset is Not Enough; reset at or before exhaustion is Enough; incomplete, invalid, or non-finite inputs are Collecting.
- A burn rate above the full-week sustainable rate must still be Enough when exhaustion is after the next reset.
- The verdict presentation contains only verdict kind, reset interval, exhaustion interval, signed margin, selected language, and display-ready strings; all intervals use one captured `now`.
- Event intervals below `24 hours` render in hours; event intervals at or above `24 hours` render in days; useful fractions use one decimal digit. The compact signed margin badge always renders in days, matching `+0,9 дня` / `−0.7 days` from the specification.
- Russian uses `день / дня / дней` and `час / часа / часов`; English uses singular/plural; Russian decimals use a comma and English decimals use a period.
- Values below `0.1` of the selected unit use a less-than form instead of rendering zero.
- The event scale is ordinal, not proportional: Now is left, the first future event is center, and the later event is right.
- Keep the panel width at `520 pt`, preserve stable outer height during inline confirmation, and let the account-list viewport absorb the fixed verdict-card height without partially clipping rows.
- Keep macOS 14 as the deployment floor, add no dependencies, and preserve existing history storage, forecast cadence, chart semantics, and reset-chance data flow.

---

### Task 1: Typed localization and persisted language preference

**Files:**
- Create: `Sources/Localization.swift`
- Modify: `Tests/InfrastructureTests.swift`
- Modify: `run-tests.sh`
- Modify: `build.sh`

**Interfaces:**
- Produces: `enum AppLanguage: String, CaseIterable { case russian = "ru"; case english = "en" }`
- Produces: `struct AppLanguagePreferenceStore` with `load()`, `save(_:)`, and `select(_:rebuild:)`.
- Produces: `enum LocalizedTextKey: CaseIterable` and `LocalizedText.value(_:language:)` for fixed first-stage strings.
- Produces: typed localized functions for chart details, update age, reset-button counts/tooltips, and accessibility labels.
- Consumed later by: verdict presentation, `PoolPaceChartView`, `AccountSwitcherPanelView`, and `AppDelegate`.

- [ ] **Step 1: Compile the new module in both test and application builds**

Insert `"$ROOT_DIR/Sources/Localization.swift"` immediately before `AppInfrastructure.swift` in both Swift compiler invocations:

```bash
/usr/bin/xcrun swiftc \
  "$ROOT_DIR/Sources/Localization.swift" \
  "$ROOT_DIR/Sources/AppInfrastructure.swift" \
  "$ROOT_DIR/Tests/InfrastructureTests.swift" \
  -target arm64-apple-macosx14.0 \
  -o "$TEST_BINARY"
```

```bash
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swiftc \
  "$ROOT_DIR/Sources/Localization.swift" \
  "$ROOT_DIR/Sources/AppInfrastructure.swift" \
  "$ROOT_DIR/Sources/Models.swift" \
  "$ROOT_DIR/Sources/PanelComponents.swift" \
  "$ROOT_DIR/Sources/main.swift" \
  -target arm64-apple-macosx14.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework SwiftUI \
  -framework Charts \
  -framework UserNotifications \
  -o "$BIN_PATH"
```

- [ ] **Step 2: Register failing language persistence and copy-completeness tests**

Add both calls beside the other pure-policy tests in `InfrastructureTests.main()`:

```swift
testAppLanguagePreference()
testLocalizedTextCompleteness()
```

Add the tests, using a unique `UserDefaults` suite so the developer's real preference is never touched:

```swift
private static func testAppLanguagePreference() {
    let suiteName = "CodexAccountSwitcher.LanguageTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        expect(false, "language tests should create an isolated defaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = AppLanguagePreferenceStore(defaults: defaults)

    expect(store.load() == .russian, "missing language should default to Russian")
    defaults.set("", forKey: AppLanguagePreferenceStore.defaultsKey)
    expect(store.load() == .russian, "empty language should default to Russian")
    defaults.set("de", forKey: AppLanguagePreferenceStore.defaultsKey)
    expect(store.load() == .russian, "unknown language should default to Russian")

    store.save(.english)
    expect(defaults.string(forKey: AppLanguagePreferenceStore.defaultsKey) == "en", "English should persist with a stable raw value")
    expect(store.load() == .english, "English should restore from defaults")
    store.save(.russian)
    expect(defaults.string(forKey: AppLanguagePreferenceStore.defaultsKey) == "ru", "Russian should persist with a stable raw value")

    var rebuildCount = 0
    expect(!store.select(.russian) { rebuildCount += 1 }, "selecting the current language should be a no-op")
    expect(rebuildCount == 0, "an unchanged language should not rebuild the panel")
    expect(store.select(.english) { rebuildCount += 1 }, "selecting another language should report a change")
    expect(rebuildCount == 1, "a changed language should rebuild exactly once")
}

private static func testLocalizedTextCompleteness() {
    for key in LocalizedTextKey.allCases {
        for language in AppLanguage.allCases {
            let value = LocalizedText.value(key, language: language)
            expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key) should be translated for \(language)")
        }
    }
    expect(LocalizedText.value(.languageLabel, language: .russian) == "Язык / Language", "the language label should stay bilingual")
    expect(LocalizedText.value(.languageLabel, language: .english) == "Язык / Language", "the language label should stay bilingual in English mode")
    expect(LocalizedText.value(.russianOption, language: .english) == "Русский", "the Russian option should remain self-identifying")
    expect(LocalizedText.value(.englishOption, language: .russian) == "English", "the English option should remain self-identifying")
}
```

- [ ] **Step 3: Run tests and verify that the localization types are missing**

Run: `./run-tests.sh`

Expected: Swift compilation fails because `AppLanguagePreferenceStore`, `LocalizedTextKey`, and `LocalizedText` do not exist.

- [ ] **Step 4: Implement stable language resolution and the rebuild-only preference store**

Create `Sources/Localization.swift` with this foundation:

```swift
import Foundation

enum AppLanguage: String, CaseIterable {
    case russian = "ru"
    case english = "en"

    static func resolve(_ rawValue: String?) -> AppLanguage {
        guard let rawValue, !rawValue.isEmpty else { return .russian }
        return AppLanguage(rawValue: rawValue) ?? .russian
    }

    var locale: Locale {
        Locale(identifier: self == .russian ? "ru_RU" : "en_US")
    }
}

struct AppLanguagePreferenceStore {
    static let defaultsKey = "appLanguage"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppLanguage {
        AppLanguage.resolve(defaults.string(forKey: Self.defaultsKey))
    }

    func save(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Self.defaultsKey)
    }

    @discardableResult
    func select(_ language: AppLanguage, rebuild: () -> Void) -> Bool {
        guard load() != language else { return false }
        save(language)
        rebuild()
        return true
    }
}
```

The store intentionally accepts only a `rebuild` closure. Do not add refresh, restart, account-switch, or networking callbacks.

- [ ] **Step 5: Add the exhaustive fixed-string catalog**

Define the exact fixed-key surface:

```swift
enum LocalizedTextKey: CaseIterable {
    case poolHistoryCollecting
    case noAccountsTitle
    case noAccountsDetail
    case settingsButton
    case settingsTooltip
    case addButton
    case addTooltip
    case refreshButton
    case refreshTooltip
    case quitButton
    case quitConfirmButton
    case quitTooltip
    case switchPrompt
    case switchRelaunchDetail
    case cancelButton
    case switchButton
    case resetChanceTitle
    case languageLabel
    case russianOption
    case englishOption
    case verdictEnoughTitle
    case verdictEnoughDetail
    case verdictNotEnoughTitle
    case verdictNotEnoughDetail
    case verdictCollectingTitle
    case verdictCollectingDetail
    case nowEvent
    case resetEvent
    case exhaustionEvent
    case enoughAccessibility
    case notEnoughAccessibility
    case collectingAccessibility
}

enum LocalizedText {
    static func value(_ key: LocalizedTextKey, language: AppLanguage) -> String {
        switch language {
        case .russian:
            switch key {
            case .poolHistoryCollecting: return "История пула набирается…"
            case .noAccountsTitle: return "Нет доступных аккаунтов"
            case .noAccountsDetail: return "Откройте настройки, чтобы добавить аккаунт."
            case .settingsButton: return "Настройки"
            case .settingsTooltip: return "Открыть настройки"
            case .addButton: return "Добавить"
            case .addTooltip: return "Добавить аккаунт"
            case .refreshButton: return "Обновить"
            case .refreshTooltip: return "Обновить данные всех сохранённых аккаунтов"
            case .quitButton: return "Выйти"
            case .quitConfirmButton: return "Выйти?"
            case .quitTooltip: return "Выйти из Codex Account Switcher"
            case .switchPrompt: return "Переключиться на этот аккаунт?"
            case .switchRelaunchDetail: return "Codex будет перезапущен"
            case .cancelButton: return "Отмена"
            case .switchButton: return "Переключить"
            case .resetChanceTitle: return "Шанс сброса от Tibo"
            case .languageLabel: return "Язык / Language"
            case .russianOption: return "Русский"
            case .englishOption: return "English"
            case .verdictEnoughTitle: return "Хватит до сброса"
            case .verdictEnoughDetail: return "Текущего запаса достаточно до следующего сброса."
            case .verdictNotEnoughTitle: return "Не хватит до сброса"
            case .verdictNotEnoughDetail: return "Запас закончится раньше следующего сброса."
            case .verdictCollectingTitle: return "Собираем историю"
            case .verdictCollectingDetail: return "Нужно больше данных для надёжного прогноза."
            case .nowEvent: return "Сейчас"
            case .resetEvent: return "Сброс"
            case .exhaustionEvent: return "Запас закончится"
            case .enoughAccessibility: return "Запаса хватит до сброса"
            case .notEnoughAccessibility: return "Запас закончится до сброса"
            case .collectingAccessibility: return "Собираем историю для прогноза"
            }
        case .english:
            switch key {
            case .poolHistoryCollecting: return "Collecting pool history…"
            case .noAccountsTitle: return "No accounts available"
            case .noAccountsDetail: return "Open settings to add an account."
            case .settingsButton: return "Settings"
            case .settingsTooltip: return "Open settings"
            case .addButton: return "Add"
            case .addTooltip: return "Add account"
            case .refreshButton: return "Refresh"
            case .refreshTooltip: return "Refresh usage for all saved accounts"
            case .quitButton: return "Quit"
            case .quitConfirmButton: return "Quit?"
            case .quitTooltip: return "Quit Codex Account Switcher"
            case .switchPrompt: return "Switch to this account?"
            case .switchRelaunchDetail: return "Codex will relaunch"
            case .cancelButton: return "Cancel"
            case .switchButton: return "Switch"
            case .resetChanceTitle: return "Reset chance by Tibo"
            case .languageLabel: return "Язык / Language"
            case .russianOption: return "Русский"
            case .englishOption: return "English"
            case .verdictEnoughTitle: return "Enough until reset"
            case .verdictEnoughDetail: return "Current capacity is sufficient until the next reset."
            case .verdictNotEnoughTitle: return "Runs out before reset"
            case .verdictNotEnoughDetail: return "Capacity will run out before the next reset."
            case .verdictCollectingTitle: return "Collecting history"
            case .verdictCollectingDetail: return "More data is needed for a reliable forecast."
            case .nowEvent: return "Now"
            case .resetEvent: return "Reset"
            case .exhaustionEvent: return "Capacity ends"
            case .enoughAccessibility: return "Capacity lasts until reset"
            case .notEnoughAccessibility: return "Capacity runs out before reset"
            case .collectingAccessibility: return "Collecting history for a forecast"
            }
        }
    }
}
```

Keep sentences with arguments as typed functions added in Tasks 3 and 6; callers must not concatenate translated fragments.

- [ ] **Step 6: Run tests and build**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: all infrastructure assertions, reset self-test, full compilation, and ad-hoc signing pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Localization.swift Tests/InfrastructureTests.swift run-tests.sh build.sh
git commit -m "feat: add typed app localization"
```

---

### Task 2: Event-order verdict evaluator

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Replaces: the associated-value `PoolVerdict` cases and sustainable-burn branch.
- Produces: `enum PoolVerdictKind: Equatable { case enough, notEnough, collecting }`.
- Produces: `struct PoolVerdict: Equatable` with `kind`, `resetInterval`, `exhaustionInterval`, and `margin`.
- Produces: `PoolVerdict.evaluate(poolTotal:burnPerDay:eolDate:resetDate:hasSufficientHistory:now:)`.
- Consumed later by: `PoolVerdictPresenter` and the verdict card.

- [ ] **Step 1: Replace the old verdict test with complete event-order coverage**

Replace `testPoolVerdict()` with:

```swift
private static func testPoolVerdict() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reset = now.addingTimeInterval(3 * 86_400)
    let eolSoon = now.addingTimeInterval(2 * 86_400)
    let eolLater = now.addingTimeInterval(5 * 86_400)

    let deficit = PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: eolSoon, resetDate: reset, hasSufficientHistory: true, now: now)
    expect(deficit.kind == .notEnough, "exhaustion before reset should be not enough")
    expect(deficit.resetInterval == 3 * 86_400, "reset interval should use the captured now")
    expect(deficit.exhaustionInterval == 2 * 86_400, "exhaustion interval should use the captured now")
    expect(deficit.margin == -86_400, "exhaustion before reset should have a negative margin")

    let buffer = PoolVerdict.evaluate(poolTotal: 500, burnPerDay: 120, eolDate: eolLater, resetDate: reset, hasSufficientHistory: true, now: now)
    expect(buffer.kind == .enough, "high burn should still be enough when exhaustion follows reset")
    expect(buffer.margin == 2 * 86_400, "exhaustion after reset should have a positive margin")

    let boundary = PoolVerdict.evaluate(poolTotal: 300, burnPerDay: 100, eolDate: reset, resetDate: reset, hasSufficientHistory: true, now: now)
    expect(boundary.kind == .enough, "an exhaustion event exactly at reset should not be negative")
    expect(boundary.margin == 0, "equal events should have a zero margin")

    let fallbackEOL = now.addingTimeInterval(2 * 86_400)
    let fallback = PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: nil, resetDate: reset, hasSufficientHistory: true, now: now)
    expect(fallback.exhaustionInterval == fallbackEOL.timeIntervalSince(now), "missing forecast EOL should use the linear pool/burn fallback")

    let collectingInputs: [PoolVerdict] = [
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: eolLater, resetDate: reset, hasSufficientHistory: false, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: nil, eolDate: eolLater, resetDate: reset, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 0, eolDate: eolLater, resetDate: reset, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: .infinity, burnPerDay: 100, eolDate: eolLater, resetDate: reset, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: .nan, eolDate: eolLater, resetDate: reset, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: eolLater, resetDate: nil, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: now.addingTimeInterval(-1), resetDate: reset, hasSufficientHistory: true, now: now),
        PoolVerdict.evaluate(poolTotal: 200, burnPerDay: 100, eolDate: eolLater, resetDate: now, hasSufficientHistory: true, now: now)
    ]
    expect(collectingInputs.allSatisfy { $0.kind == .collecting }, "incomplete, non-finite, and invalid dates should collect")
    expect(collectingInputs.allSatisfy { $0.margin == nil }, "collecting must not expose display intervals")
}
```

- [ ] **Step 2: Run tests and verify the old API fails the new expectations**

Run: `./run-tests.sh`

Expected: compilation fails because `PoolVerdict.kind`, `.notEnough`, `.collecting`, and the new evaluator parameter are missing.

- [ ] **Step 3: Implement the pure event-order model**

Replace the existing `PoolVerdict` enum with:

```swift
enum PoolVerdictKind: Equatable {
    case enough
    case notEnough
    case collecting
}

struct PoolVerdict: Equatable {
    let kind: PoolVerdictKind
    let resetInterval: TimeInterval?
    let exhaustionInterval: TimeInterval?
    let margin: TimeInterval?

    static let collecting = PoolVerdict(
        kind: .collecting,
        resetInterval: nil,
        exhaustionInterval: nil,
        margin: nil
    )

    static func evaluate(
        poolTotal: Double,
        burnPerDay: Double?,
        eolDate: Date?,
        resetDate: Date?,
        hasSufficientHistory: Bool,
        now: Date
    ) -> PoolVerdict {
        guard hasSufficientHistory,
              poolTotal.isFinite, poolTotal > 0,
              let burnPerDay, burnPerDay.isFinite, burnPerDay > 1e-9,
              let resetDate else {
            return .collecting
        }
        let effectiveEOL = eolDate ?? now.addingTimeInterval(poolTotal / burnPerDay * 86_400)
        let resetInterval = resetDate.timeIntervalSince(now)
        let exhaustionInterval = effectiveEOL.timeIntervalSince(now)
        guard resetInterval.isFinite, exhaustionInterval.isFinite,
              resetInterval > 0, exhaustionInterval >= 0 else {
            return .collecting
        }
        let margin = exhaustionInterval - resetInterval
        return PoolVerdict(
            kind: margin >= 0 ? .enough : .notEnough,
            resetInterval: resetInterval,
            exhaustionInterval: exhaustionInterval,
            margin: margin
        )
    }
}
```

Delete the old `accountCount`/`limitPerDay` branch from verdict evaluation only. Do not remove burn calculations, history data, or forecast inputs used elsewhere.

- [ ] **Step 4: Run tests**

Run: `./run-tests.sh`

Expected: all tests pass, including the high-burn/late-exhaustion Enough case and non-finite Collecting cases.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppInfrastructure.swift Tests/InfrastructureTests.swift
git commit -m "refactor: evaluate pool verdict by event order"
```

---

### Task 3: Localized interval formatting and display-ready verdict presentation

**Files:**
- Modify: `Sources/Localization.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `enum PoolVerdictEventKind { case now, reset, exhaustion }`.
- Produces: `struct PoolVerdictEventPresentation` with `kind`, `title`, and `intervalText`.
- Produces: `struct PoolVerdictPresentation` with semantic kind, selected language, title, detail, optional badge, accessibility label, and ordered events.
- Produces: `LocalizedIntervalFormatter.duration(_:)` and `.signedMargin(_:)`.
- Produces: `PoolVerdictPresenter.make(verdict:language:)`.

- [ ] **Step 1: Register formatting and presentation tests**

Add to `InfrastructureTests.main()`:

```swift
testLocalizedIntervalFormatting()
testPoolVerdictPresentation()
```

Add deterministic tests:

```swift
private static func testLocalizedIntervalFormatting() {
    expect(LocalizedIntervalFormatter.duration(90, language: .russian) == "<0,1 часа", "tiny Russian intervals should use a less-than form")
    expect(LocalizedIntervalFormatter.duration(90, language: .english) == "<0.1 hours", "tiny English intervals should use a less-than form")
    expect(LocalizedIntervalFormatter.duration(3_600, language: .russian) == "1 час", "Russian one-hour singular should be correct")
    expect(LocalizedIntervalFormatter.duration(2 * 3_600, language: .russian) == "2 часа", "Russian paucal hours should be correct")
    expect(LocalizedIntervalFormatter.duration(5 * 3_600, language: .russian) == "5 часов", "Russian plural hours should be correct")
    expect(LocalizedIntervalFormatter.duration(86_400, language: .russian) == "1 день", "Russian one-day singular should be correct")
    expect(LocalizedIntervalFormatter.duration(2 * 86_400, language: .russian) == "2 дня", "Russian paucal days should be correct")
    expect(LocalizedIntervalFormatter.duration(5 * 86_400, language: .russian) == "5 дней", "Russian plural days should be correct")
    expect(LocalizedIntervalFormatter.duration(1.5 * 86_400, language: .russian) == "1,5 дня", "Russian decimals should use comma")
    expect(LocalizedIntervalFormatter.duration(3_600, language: .english) == "1 hour", "English singular should be correct")
    expect(LocalizedIntervalFormatter.duration(2 * 3_600, language: .english) == "2 hours", "English plural should be correct")
    expect(LocalizedIntervalFormatter.duration(1.5 * 86_400, language: .english) == "1.5 days", "English decimals should use period")
    expect(LocalizedIntervalFormatter.signedMargin(0.9 * 86_400, language: .russian) == "+0,9 дня", "Russian positive badge should use plus and comma")
    expect(LocalizedIntervalFormatter.signedMargin(-0.7 * 86_400, language: .english) == "−0.7 days", "English deficit badge should use a typographic minus")
}

private static func testPoolVerdictPresentation() {
    let enough = PoolVerdict(kind: .enough, resetInterval: 2 * 86_400, exhaustionInterval: 2.9 * 86_400, margin: 0.9 * 86_400)
    let enoughRU = PoolVerdictPresenter.make(verdict: enough, language: .russian)
    expect(enoughRU.title == "Хватит до сброса", "Enough should use the Russian title")
    expect(enoughRU.marginBadge == "+0,9 дня", "Enough should show a positive buffer")
    expect(enoughRU.events.map(\.kind) == [.now, .reset, .exhaustion], "Enough should order reset before exhaustion")
    expect(enoughRU.events.map(\.intervalText) == [nil, "через 2 дня", "через 2,9 дня"], "Russian events should include localized intervals")

    let notEnough = PoolVerdict(kind: .notEnough, resetInterval: 2 * 86_400, exhaustionInterval: 1.3 * 86_400, margin: -0.7 * 86_400)
    let notEnoughEN = PoolVerdictPresenter.make(verdict: notEnough, language: .english)
    expect(notEnoughEN.title == "Runs out before reset", "Not Enough should use the English title")
    expect(notEnoughEN.marginBadge == "−0.7 days", "Not Enough should show a negative deficit")
    expect(notEnoughEN.events.map(\.kind) == [.now, .exhaustion, .reset], "Not Enough should order exhaustion before reset")
    expect(notEnoughEN.events.map(\.intervalText) == [nil, "in 1.3 days", "in 2 days"], "English events should include localized intervals")

    let collecting = PoolVerdictPresenter.make(verdict: .collecting, language: .russian)
    expect(collecting.kind == .collecting, "incomplete inputs should remain collecting")
    expect(collecting.marginBadge == nil, "Collecting should not show a badge")
    expect(collecting.events.isEmpty, "Collecting should not show an event scale")
}
```

- [ ] **Step 2: Run tests and verify formatter/presenter types are missing**

Run: `./run-tests.sh`

Expected: compilation fails because the presentation and formatter types do not exist.

- [ ] **Step 3: Implement deterministic unit and plural formatting**

Add `LocalizedIntervalFormatter` to `Localization.swift`. Normalize to hours below 24 hours and days otherwise, round to one decimal, omit `.0`, and use the Russian integer plural rule based on `value % 100` and `value % 10`:

```swift
enum LocalizedIntervalFormatter {
    private enum Unit { case hour, day }

    static func duration(_ interval: TimeInterval, language: AppLanguage) -> String {
        let safeInterval = max(0, interval)
        let unit: Unit = safeInterval < 86_400 ? .hour : .day
        let divisor: Double = unit == .hour ? 3_600 : 86_400
        let value = safeInterval / divisor
        if value < 0.1 {
            return language == .russian
                ? "<0,1 \(unit == .hour ? "часа" : "дня")"
                : "<0.1 \(unit == .hour ? "hours" : "days")"
        }
        let rounded = (value * 10).rounded() / 10
        let number = numberText(rounded, language: language)
        return "\(number) \(unitText(unit, value: rounded, language: language))"
    }

    static func signedMargin(_ interval: TimeInterval, language: AppLanguage) -> String {
        let sign = interval < 0 ? "−" : "+"
        let days = abs(interval) / 86_400
        if days < 0.1 {
            return sign + (language == .russian ? "<0,1 дня" : "<0.1 days")
        }
        let rounded = (days * 10).rounded() / 10
        return sign + numberText(rounded, language: language)
            + " " + unitText(.day, value: rounded, language: language)
    }

    private static func numberText(_ value: Double, language: AppLanguage) -> String {
        let isWhole = abs(value.rounded() - value) < 1e-9
        let text = isWhole ? String(Int(value.rounded())) : String(format: "%.1f", value)
        return language == .russian ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    private static func unitText(_ unit: Unit, value: Double, language: AppLanguage) -> String {
        guard language == .russian else {
            let singular = abs(value - 1) < 1e-9
            return unit == .hour ? (singular ? "hour" : "hours") : (singular ? "day" : "days")
        }
        guard abs(value.rounded() - value) < 1e-9 else { return unit == .hour ? "часа" : "дня" }
        let integer = Int(value.rounded())
        let lastTwo = integer % 100
        let last = integer % 10
        if last == 1, lastTwo != 11 { return unit == .hour ? "час" : "день" }
        if (2...4).contains(last), !(12...14).contains(lastTwo) { return unit == .hour ? "часа" : "дня" }
        return unit == .hour ? "часов" : "дней"
    }
}
```

- [ ] **Step 4: Implement the display-ready presentation model and event ordering**

Add:

```swift
enum PoolVerdictEventKind: Equatable { case now, reset, exhaustion }

struct PoolVerdictEventPresentation: Equatable {
    let kind: PoolVerdictEventKind
    let title: String
    let intervalText: String?
}

struct PoolVerdictPresentation: Equatable {
    let kind: PoolVerdictKind
    let language: AppLanguage
    let resetInterval: TimeInterval?
    let exhaustionInterval: TimeInterval?
    let margin: TimeInterval?
    let title: String
    let detail: String
    let marginBadge: String?
    let accessibilityLabel: String
    let events: [PoolVerdictEventPresentation]
}

enum PoolVerdictPresenter {
    static func make(verdict: PoolVerdict, language: AppLanguage) -> PoolVerdictPresentation {
        switch verdict.kind {
        case .collecting:
            return PoolVerdictPresentation(
                kind: .collecting,
                language: language,
                resetInterval: nil,
                exhaustionInterval: nil,
                margin: nil,
                title: LocalizedText.value(.verdictCollectingTitle, language: language),
                detail: LocalizedText.value(.verdictCollectingDetail, language: language),
                marginBadge: nil,
                accessibilityLabel: LocalizedText.value(.collectingAccessibility, language: language),
                events: []
            )
        case .enough, .notEnough:
            guard let reset = verdict.resetInterval,
                  let exhaustion = verdict.exhaustionInterval,
                  let margin = verdict.margin else {
                return make(verdict: .collecting, language: language)
            }
            let resetEvent = event(.reset, interval: reset, language: language)
            let exhaustionEvent = event(.exhaustion, interval: exhaustion, language: language)
            let events = [event(.now, interval: nil, language: language)]
                + (verdict.kind == .enough ? [resetEvent, exhaustionEvent] : [exhaustionEvent, resetEvent])
            return PoolVerdictPresentation(
                kind: verdict.kind,
                language: language,
                resetInterval: reset,
                exhaustionInterval: exhaustion,
                margin: margin,
                title: LocalizedText.value(verdict.kind == .enough ? .verdictEnoughTitle : .verdictNotEnoughTitle, language: language),
                detail: LocalizedText.value(verdict.kind == .enough ? .verdictEnoughDetail : .verdictNotEnoughDetail, language: language),
                marginBadge: LocalizedIntervalFormatter.signedMargin(margin, language: language),
                accessibilityLabel: LocalizedText.value(verdict.kind == .enough ? .enoughAccessibility : .notEnoughAccessibility, language: language),
                events: events
            )
        }
    }

    private static func event(_ kind: PoolVerdictEventKind, interval: TimeInterval?, language: AppLanguage) -> PoolVerdictEventPresentation {
        let key: LocalizedTextKey = kind == .now ? .nowEvent : (kind == .reset ? .resetEvent : .exhaustionEvent)
        let intervalText = interval.map {
            let duration = LocalizedIntervalFormatter.duration($0, language: language)
            return language == .russian ? "через \(duration)" : "in \(duration)"
        }
        return PoolVerdictEventPresentation(kind: kind, title: LocalizedText.value(key, language: language), intervalText: intervalText)
    }
}
```

- [ ] **Step 5: Run tests**

Run: `./run-tests.sh`

Expected: all formatting, pluralization, margin-sign, and event-order assertions pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Localization.swift Tests/InfrastructureTests.swift
git commit -m "feat: format localized pool verdicts"
```

---

### Task 4: Native Glass verdict card and ordinal event scale

**Files:**
- Modify: `Sources/PanelComponents.swift`
- Modify: `Sources/main.swift`

**Interfaces:**
- Produces: `final class PoolVerdictCardView: NSView`.
- Consumes: `PoolVerdictPresentation` from Task 3 and `PanelTheme`/semantic Native colors already in the project.
- Changes: fixed usage layout constants and `AccountSwitcherPanelView.preferredSize(...)`.

- [ ] **Step 1: Add fixed layout constants and reserve verdict-card height**

In `AccountPanelLayout`, remove `paceRowHeight` from `paceSectionHeight`, keep the chart at `104`, and add:

```swift
static let verdictTopGap: CGFloat = 8
static let verdictCardHeight: CGFloat = 142
static var verdictSectionHeight: CGFloat { verdictTopGap + verdictCardHeight }
static var paceSectionHeight: CGFloat { paceChartHeight }
```

In `preferredSize`, include `verdictSectionHeight` whenever `showsPace` is true:

```swift
let forecastHeight = showsPace
    ? AccountPanelLayout.paceTopGap
        + AccountPanelLayout.paceSectionHeight
        + AccountPanelLayout.verdictSectionHeight
    : 0
```

Use `forecastHeight` in `fixedHeight`. Keep the existing account-row capacity and viewport policy so reduced space yields fewer complete visible rows rather than a clipped row.

- [ ] **Step 2: Implement semantic card styling**

Add `PoolVerdictCardView` to `PanelComponents.swift` with this public initializer:

```swift
init(frame: NSRect, presentation: PoolVerdictPresentation, theme: PanelTheme)
```

Map semantics exactly once inside the component:

```swift
private static func style(for kind: PoolVerdictKind, theme: PanelTheme) -> (accent: NSColor, fill: NSColor, border: NSColor, symbol: String) {
    switch kind {
    case .enough:
        return (.nativeMint, .nativeMint.withAlphaComponent(theme.isDark ? 0.10 : 0.08), .nativeMint.withAlphaComponent(0.38), "checkmark")
    case .notEnough:
        return (.nativeRed, .nativeCoral.withAlphaComponent(theme.isDark ? 0.10 : 0.08), .nativeRed.withAlphaComponent(0.38), "xmark")
    case .collecting:
        return (theme.secondaryText, theme.bottomBarFill, theme.inactiveCardBorder, "clock.arrow.circlepath")
    }
}
```

Build a rounded background, a `30×30` filled semantic circle at `(14, 14)`, title at `(54, 12)`, detail at `(54, 35)`, and optional fixed-size margin badge aligned to the trailing edge. Mark the symbol and card as accessibility elements and use `presentation.accessibilityLabel`; do not rely on color alone.

- [ ] **Step 3: Render the three-column non-proportional event scale**

When `presentation.events.count == 3`, render at `y = 76` using three equal columns and fixed point positions at the left, center, and right. Each column gets a centered title and interval label with `lineBreakMode = .byTruncatingTail`; the title column widths, not measured event times, determine positions:

```swift
let horizontalInset: CGFloat = 18
let scaleWidth = bounds.width - horizontalInset * 2
let columnWidth = scaleWidth / 3
let pointY: CGFloat = 92
let centers = (0..<3).map { horizontalInset + columnWidth * (CGFloat($0) + 0.5) }
```

Draw the left-to-center segment with an `NSGradient` from the semantic accent to its lighter variant and the center-to-right segment with `theme.progressTrack`. Place a 7-point dot at each center, then render each event's `title` at `y = 102` and `intervalText` at `y = 120`. For Collecting, stop after title/detail and do not allocate a badge or event scale.

- [ ] **Step 4: Build and verify the standalone component compiles**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: tests and app build pass; the card occupies a fixed section and the list remains the only scrollable region.

- [ ] **Step 5: Commit**

```bash
git add Sources/PanelComponents.swift Sources/main.swift
git commit -m "feat: render pool verdict event card"
```

---

### Task 5: Single-now forecast flow and localized chart content

**Files:**
- Modify: `Sources/main.swift`

**Interfaces:**
- Changes: `PaceDisplayState` contains only `history: [PoolHistorySample]`, `now: Date`, and `verdict: PoolVerdict`; obsolete forecast-copy inputs are removed.
- Changes: `PoolPaceChartData` gains `language: AppLanguage` and drops `forecastText`, `forecastColor`, and `verdict`.
- Produces: `pacePresentation(_:) -> PoolVerdictPresentation`.
- Removes: raw pool/burn/limit forecast sentence and chart verdict badge.

- [ ] **Step 1: Capture `now` once while constructing panel state**

Change `poolPaceState` to accept one explicit time and evaluate the verdict there:

```swift
private func poolPaceState(now: Date) -> PaceDisplayState? {
    guard !accounts.isEmpty else { return nil }
    let history = PoolHistoryStore.load()
    guard let last = history.last else {
        return PaceDisplayState(history: [], now: now, verdict: .collecting)
    }
    let forecast = PaceEstimator.forecast(samples: history, now: now)
    let resetDate = last.resetsAt.map { Self.nextResetDate(after: $0, now: now) }
    let burn = poolBurnRatePerDay(history)
    let verdict = PoolVerdict.evaluate(
        poolTotal: last.poolTotal,
        burnPerDay: burn,
        eolDate: forecast.eolDate,
        resetDate: resetDate,
        hasSufficientHistory: !forecast.insufficientData,
        now: now
    )
    return PaceDisplayState(
        history: history,
        now: now,
        verdict: verdict
    )
}
```

At the start of `refreshAccountPanelContent()`, use:

```swift
let now = Date()
let paceState = poolPaceState(now: now)
```

For `currentAccountPanelSize()`, use `!accounts.isEmpty` to decide `showsPace`; do not independently re-evaluate user-visible intervals. This deliberately reserves the chart and neutral Collecting card before the first history sample exists.

- [ ] **Step 2: Remove the old raw forecast row**

Delete from `PoolPaceChartData` and `PoolPaceChartView`:

```swift
forecastText
forecastColor
verdict
verdictBadge
```

Remove the now-unused `PoolPaceChartData.empty()` factory and the bottom `HStack` from `PoolPaceChartView.body`; the body now shows only the chart or localized collecting-history empty state. Delete `paceForecastText(_:)`, `poolBurnText(_:)`, `paceForecastColor(_:)`, and the view-local `poolVerdict(for:)`. Keep `poolBurnRatePerDay(_:)` because the state builder still needs it.

- [ ] **Step 3: Pass language into chart data and localize chart details as whole sentences**

Add `let language: AppLanguage` to `PoolPaceChartData` and use:

```swift
Text(LocalizedText.value(.poolHistoryCollecting, language: data.language))
```

Add typed functions to `LocalizedText`:

```swift
static func sampleChartDetail(date: Date, remainingPercent: Int, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    let dateText = formatter.string(from: date)
    switch language {
    case .russian:
        return "\(dateText) · осталось \(remainingPercent)%"
    case .english:
        return "\(dateText) · \(remainingPercent)% left"
    }
}

static func dailyChartDetail(
    date: Date,
    lowPercent: Int,
    endPercent: Int?,
    isToday: Bool,
    language: AppLanguage
) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    let dateText = formatter.string(from: date)
    switch language {
    case .russian:
        var text = "\(dateText) · минимум \(lowPercent)%"
        if let endPercent { text += " · конец \(endPercent)%" }
        if isToday { text += " · сегодня" }
        return text
    case .english:
        var text = "\(dateText) · low \(lowPercent)%"
        if let endPercent { text += " · end \(endPercent)%" }
        if isToday { text += " · today" }
        return text
    }
}
```

Each function creates a `Date.FormatStyle` with `locale: language.locale` and returns the complete sentence. Required shapes are:

```text
RU sample: 17 августа, 14:30 · осталось 42%
EN sample: Aug 17, 2:30 PM · 42% left
RU daily: 17 авг. · минимум 42% · конец 48% · сегодня
EN daily: Aug 17 · low 42% · end 48% · today
```

Call these functions from `detailLine`; do not concatenate localized words inside the SwiftUI view.

- [ ] **Step 4: Supply the display-ready verdict to the card**

Add:

```swift
private func pacePresentation(_ state: PaceDisplayState) -> PoolVerdictPresentation {
    PoolVerdictPresenter.make(verdict: state.verdict, language: language)
}

private func verdictSection(_ state: PaceDisplayState, frame: NSRect) -> NSView {
    PoolVerdictCardView(frame: frame, presentation: pacePresentation(state), theme: theme)
}
```

Insert the card between the chart and reset chance by calculating those sections bottom-up in `buildUsageContent()`:

```swift
var listBottom = resetChanceY
if let pace {
    let verdictY = resetChanceY - AccountPanelLayout.verdictSectionHeight
    addSubview(verdictSection(pace, frame: NSRect(
        x: usageInset,
        y: verdictY + AccountPanelLayout.verdictTopGap,
        width: contentWidth,
        height: AccountPanelLayout.verdictCardHeight
    )))
    let paceTop = verdictY - AccountPanelLayout.paceTopGap - AccountPanelLayout.paceSectionHeight
    addSubview(paceSection(pace, frame: NSRect(
        x: usageInset,
        y: paceTop,
        width: contentWidth,
        height: AccountPanelLayout.paceSectionHeight
    )))
    listBottom = paceTop
}
```

The card must not access history, burn, dates, or `Date()`; it renders the immutable presentation only.

- [ ] **Step 5: Build and verify no raw forecast vocabulary remains in the main-panel path**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
rg -n 'burn|limitPerDay|pool [0-9]|forecastText|verdictBadge' Sources/main.swift
```

Expected: tests/build pass; search results contain no raw forecast sentence, raw pool total, burn-rate display, or old chart badge in the main-panel presentation path. Internal calculation names may remain.

- [ ] **Step 6: Commit**

```bash
git add Sources/Localization.swift Sources/main.swift
git commit -m "refactor: build verdict from one forecast instant"
```

---

### Task 6: Immediate language switching and first-stage main-panel copy

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Sources/Models.swift`
- Modify: `Sources/main.swift`
- Modify: `Sources/Localization.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Adds: `SettingsPanelAction.languageRussian` and `.languageEnglish`.
- Changes: `AccountSwitcherPanelView.init(...)` receives `language: AppLanguage`.
- Adds: `AppDelegate.languageStore` and `setLanguage(_:)`.
- Consumes: all fixed and typed localization interfaces from Tasks 1 and 3.

- [ ] **Step 1: Add language actions and panel input**

Add the two action cases:

```swift
case languageRussian
case languageEnglish
```

Add `private let language: AppLanguage` to `AccountSwitcherPanelView`, accept it immediately after `mode`, and assign it in the initializer. Pass `languageStore.load()` from `refreshAccountPanelContent()`.

- [ ] **Step 2: Add the bilingual segmented language row**

Increase Settings preferred height from `556` to `590`. Expand Display to `104` points and add the language row below the existing Menu bar row:

```swift
displaySection.addSubview(segmentedRow(
    label: LocalizedText.value(.languageLabel, language: language),
    frame: NSRect(x: 16, y: 70, width: contentWidth - 32, height: 24),
    options: [
        (LocalizedText.value(.russianOption, language: language), language == .russian, .languageRussian),
        (LocalizedText.value(.englishOption, language: language), language == .english, .languageEnglish)
    ]
))
```

Shift Automation, Health, and Footer down by `34` points without changing their contents. The control remains keyboard-focusable because it uses normal enabled `NSButton` controls; set each option's accessibility label to its visible title and selected state.

- [ ] **Step 3: Persist and rebuild without any refresh side effect**

Add to `AppDelegate`:

```swift
private let languageStore = AppLanguagePreferenceStore()

private func setLanguage(_ language: AppLanguage) {
    languageStore.select(language) { [weak self] in
        self?.refreshAccountPanelContentIfVisible()
    }
}
```

Handle the settings actions with early returns so the common trailing rebuild does not run twice:

```swift
case .languageRussian:
    setLanguage(.russian)
    return
case .languageEnglish:
    setLanguage(.english)
    return
```

Do not call `refreshAccounts`, `refreshResetChanceIfNeeded`, `refreshResetCreditsIfNeeded`, `rebuildMenu`, `showAccountPanel`, or any restart/switch method from `setLanguage`.

- [ ] **Step 4: Localize all and only the first-stage main-panel strings**

Replace fixed text in the usage-panel path with `LocalizedText.value(...)`:

```swift
Switch to this account? / Codex will relaunch / Cancel / Switch
No accounts available / Open settings to add an account. / Settings / Refresh
Reset chance by Tibo
Settings tooltip / Add / Add tooltip / Refresh / Refresh tooltip / Quit / Quit? / Quit tooltip
```

Do not localize `lastError`: it is a technical error payload and remains unchanged. Split the empty-state helper so only the usage panel uses localized empty-state copy; reset-credit/API empty states retain their current language in this iteration.

Add typed functions to `LocalizedText` and route main-panel dynamic copy through them:

```swift
static func lastUpdated(isRefreshing: Bool, elapsed: TimeInterval?, language: AppLanguage) -> String {
    if isRefreshing { return language == .russian ? "обновление…" : "refreshing..." }
    guard let elapsed else { return language == .russian ? "никогда" : "never" }
    let seconds = max(0, Int(elapsed))
    if seconds < 15 { return language == .russian ? "только что" : "just now" }
    if seconds < 60 { return language == .russian ? "\(seconds) сек. назад" : "\(seconds)s ago" }
    let minutes = seconds / 60
    if minutes < 10 { return language == .russian ? "\(minutes) мин. назад" : "\(minutes)m ago" }
    if minutes < 60 { return language == .russian ? "устарело \(minutes) мин." : "stale \(minutes)m" }
    return language == .russian ? "устарело \(minutes / 60) ч." : "stale \(minutes / 60)h"
}

static func resetCreditsButtonTitle(
    knownTotal: Int,
    knownAccounts: Int,
    hasError: Bool,
    language: AppLanguage
) -> String {
    if hasError, knownTotal == 0 { return language == .russian ? "СБРОСЫ ?" : "RESETS ?" }
    guard knownAccounts > 0 else { return language == .russian ? "СБРОСЫ ..." : "RESETS ..." }
    if knownTotal == 0 { return language == .russian ? "НЕТ СБРОСОВ" : "NO RESETS" }
    let suffix = hasError ? "+" : ""
    if language == .english {
        return knownTotal == 1 ? "1\(suffix) RESET" : "\(knownTotal)\(suffix) RESETS"
    }
    let lastTwo = knownTotal % 100
    let last = knownTotal % 10
    let noun = last == 1 && lastTwo != 11 ? "СБРОС"
        : ((2...4).contains(last) && !(12...14).contains(lastTwo) ? "СБРОСА" : "СБРОСОВ")
    return "\(knownTotal)\(suffix) \(noun)"
}

static func resetCreditsTooltip(
    knownTotal: Int,
    knownAccounts: Int,
    hasError: Bool,
    language: AppLanguage
) -> String {
    if hasError, knownTotal == 0 {
        return language == .russian ? "Не удалось проверить кредиты сброса для одного или нескольких аккаунтов" : "One or more reset-credit checks failed"
    }
    guard knownAccounts > 0 else {
        return language == .russian ? "Проверяем кредиты сброса" : "Checking reset credits"
    }
    if knownTotal == 0 {
        return language == .russian ? "Нет доступных кредитов сброса Codex" : "No Codex reset credits available"
    }
    return language == .russian ? "Показать кредиты сброса Codex по аккаунтам" : "Show Codex reset credits by account"
}
```

Required Russian update-age shapes are `обновление…`, `никогда`, `только что`, `N сек. назад`, `N мин. назад`, `устарело N мин.`, `устарело N ч.`; preserve the existing English outputs. Required reset-button shapes are Russian equivalents of checking/none/count/error and the existing English outputs; keep the same count/error logic and do not localize the reset-credit screen itself.

- [ ] **Step 5: Add typed dynamic-copy tests**

Extend `testLocalizedTextCompleteness()` with:

```swift
expect(LocalizedText.lastUpdated(isRefreshing: true, elapsed: nil, language: .russian) == "обновление…", "Russian refreshing state should be localized")
expect(LocalizedText.lastUpdated(isRefreshing: false, elapsed: 5, language: .english) == "just now", "English update age should preserve current copy")
expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 1, knownAccounts: 2, hasError: false, language: .russian) == "1 СБРОС", "Russian singular reset count should be localized")
expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 3, knownAccounts: 2, hasError: false, language: .english) == "3 RESETS", "English plural reset count should be preserved")
expect(LocalizedText.resetCreditsTooltip(knownTotal: 0, knownAccounts: 0, hasError: false, language: .russian) == "Проверяем кредиты сброса", "Russian checking tooltip should be localized")

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
let saturday = utcDate(day: 15, month: 8, year: 2026, hour: 12, minute: 0, calendar: utc)
expect(WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .russian, now: saturday, calendar: utc) == "ПТ · 21 авг.", "account-row reset text should use Russian weekday and month")
expect(WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .english, now: saturday, calendar: utc) == "FRI · 21 Aug", "account-row reset text should preserve English formatting")
```

Move the elapsed-time branching from `AppDelegate.lastUpdatedText()` into the typed function and call it with a single captured elapsed value.

Extend `WeeklyResetFormatter.text` with `language: AppLanguage` and set both the weekday symbols and `DateFormatter.locale` per language. Keep parsing English upstream weekday tokens unchanged, but render `ПН / ВТ / СР / ЧТ / ПТ / СБ / ВС` with `ru_RU` month names for Russian and the existing `MON / TUES / WED / THUR / FRI / SAT / SUN` with `en_US_POSIX` for English:

```swift
static func text(
    from usage: String,
    language: AppLanguage,
    now: Date = Date(),
    calendar: Calendar = .current
) -> String {
    guard let open = usage.firstIndex(of: "("),
          let close = usage.firstIndex(of: ")"),
          open < close else { return "--" }
    let inner = String(usage[usage.index(after: open)..<close])
    guard let weekday = firstWeekday(in: inner) else { return inner.uppercased() }
    let target = upcomingDate(weekday: weekday, time: firstTime(in: inner), now: now, calendar: calendar)
    let russian = [1: "ВС", 2: "ПН", 3: "ВТ", 4: "СР", 5: "ЧТ", 6: "ПТ", 7: "СБ"]
    let english = [1: "SUN", 2: "MON", 3: "TUES", 4: "WED", 5: "THUR", 6: "FRI", 7: "SAT"]
    let formatter = DateFormatter()
    formatter.locale = language == .russian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "d MMM"
    let abbreviation = (language == .russian ? russian : english)[weekday] ?? "?"
    return "\(abbreviation) · \(formatter.string(from: target))"
}
```

Pass the selected language from `accountListRow`.

Update every existing `testWeeklyResetFormatter()` call to pass `language: .english`, preserving the current assertions before adding the Russian assertion below.

- [ ] **Step 6: Build and run automated tests**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
```

Expected: all language, persistence, verdict, formatting, infrastructure, reset self-test, application compilation, and signing checks pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Localization.swift Sources/AppInfrastructure.swift Sources/Models.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "feat: localize the main account panel"
```

---

### Task 7: Final regression, accessibility, and visual verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/release-notes/v1.8.5.md`

**Interfaces:**
- No new runtime interface.
- Verifies the complete localized main-panel flow and records the user-visible change.

- [ ] **Step 1: Run the full clean verification**

Run:

```bash
./run-tests.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CODEX_SWITCHER_MODULE_CACHE_DIR=.build/module-cache ./build.sh
git diff --check
```

Expected: all tests pass, the app builds/signs, and `git diff --check` reports no whitespace errors.

- [ ] **Step 2: Verify copy scope and forbidden raw forecast values**

Run:

```bash
rg -n 'burn|limit [0-9]|pool [0-9]|Enough|Not enough|Reset chance by Tibo|Switch to this account|Quit\?' Sources/main.swift Sources/PanelComponents.swift
```

Expected: no hard-coded first-stage English UI copy or raw pool/burn/limit forecast text remains in the main-panel renderer. Technical/internal identifiers and the centralized English translations in `Localization.swift` are allowed.

- [ ] **Step 3: Perform manual visual and interaction checks**

Launch the built app in both light and dark appearance and verify:

```text
1. With no saved preference, the usage panel opens in Russian.
2. Settings shows “Язык / Language” with “Русский” selected.
3. Selecting English rebuilds the visible Settings panel immediately and does not animate Refresh, alter timestamps, or start network activity.
4. Returning to the usage panel shows English; relaunching restores English.
5. Re-selecting Russian updates immediately and survives relaunch.
6. Enough is green/mint with checkmark, positive badge, and Now → Reset → Capacity ends.
7. Not Enough is red/coral with cross, negative badge, and Now → Capacity ends → Reset.
8. Collecting is neutral, has a history/progress icon, and shows neither badge nor scale.
9. Russian and English titles/event labels fit at 520 pt without truncation or overlap.
10. Three scale labels stay in distinct left/center/right columns when event times are minutes apart.
11. VoiceOver announces the verdict symbol/title and selected language; color is not the only verdict signal.
12. Arming switch and quit confirmations keeps the outer usage-panel height stable and every visible account row complete.
```

- [ ] **Step 4: Update release documentation with the verified behavior**

Add concise bullets to both documents:

```markdown
- Replace raw pool/burn forecast text with an ordered Enough / Not Enough / Collecting verdict card.
- Add immediate Russian/English switching for the main panel, defaulting to Russian for new installations.
```

Keep existing version numbers and unrelated release notes unchanged.

- [ ] **Step 5: Re-run documentation consistency checks and commit**

Run:

```bash
rg -n 'pool|forecast|language|Russian|English' README.md CHANGELOG.md docs/release-notes/v1.8.5.md docs/superpowers/specs/2026-08-17-pool-verdict-localization-design.md
git diff --check
```

Expected: current docs no longer claim that the main panel exposes raw burn/limit text, and no unrelated documentation is changed.

```bash
git add CHANGELOG.md docs/release-notes/v1.8.5.md
git commit -m "docs: describe localized pool verdict"
```

---

## Final Acceptance

- [ ] `./run-tests.sh` passes.
- [ ] The full macOS application build and ad-hoc signing pass.
- [ ] Missing, empty, and unknown preferences resolve to Russian; both `ru` and `en` persist and restore.
- [ ] Language selection rebuilds once and cannot call any refresh/restart/account mutation path.
- [ ] Enough / Not Enough / Collecting, high-burn Enough, both margin signs, event ordering, non-finite inputs, plurals, decimals, and less-than boundaries have automated coverage.
- [ ] The usage panel contains no raw pool total, burn rate, or sustainable-rate limit.
- [ ] Russian and English are visually verified at 520 pt in light and dark appearances.
- [ ] Inline switch/quit confirmation preserves stable outer height and complete account rows.
