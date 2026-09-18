import Foundation

private final class FailingSecondMoveFileManager: FileManager, @unchecked Sendable {
    private var moveCount = 0

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveCount += 1
        if moveCount == 2 {
            throw NSError(
                domain: "ReferencePluginTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "forced staged swap failure"]
            )
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}

private final class FailingSwapAndRestoreFileManager: FileManager, @unchecked Sendable {
    private var moveCount = 0

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        moveCount += 1
        if moveCount == 2 || moveCount == 3 {
            throw NSError(
                domain: "ReferencePluginTests",
                code: moveCount,
                userInfo: [NSLocalizedDescriptionKey: "forced move failure \(moveCount)"]
            )
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}

@main
struct InfrastructureTests {
    private static var failures: [String] = []
    private static var assertionCount = 0

    static func main() throws {
        try testLimitWarmupRequestAndResponse()
        try testSavedAccountAuthFilePolicy()
        testSettingsNumericPolicy()
        testResetRefreshPolicy()
        testUsageRefreshPolicy()
        testWeeklyRemainingBand()
        testAccountUsagePresentationPolicy()
        testAccountListPresentationPolicy()
        testAccountListViewportHeightPolicy()
        testAccountRemovalPolicy()
        testUsagePanelLayoutMetrics()
        testInlineSwitchConfirmationPolicy()
        testInlineQuitConfirmationPolicy()
        testLastKnownGoodSnapshotPolicy()
        testToolbarStatusFormatting()
        let business = CodexAccount(selector: "1", email: "test@example.com", plan: "Business",
            fiveHourUsage: "--", weeklyUsage: "69%", fiveHourUsedPercent: nil,
            weeklyUsedPercent: 69, lastActivity: "Now", isActive: true, hasFiveHourWindow: false)
        expect(business.toolbarRemainingPercent == 69, "Weekly-only account uses weekly toolbar percentage")
        var standard = business
        standard.hasFiveHourWindow = true
        expect(standard.toolbarRemainingPercent == nil, "Standard missing five-hour usage stays unknown")
        testStatusAnimationPolicy()
        testAppLanguagePreference()
        testLocalizedTextCompleteness()
        testRemovedAPIModeHasNoProductionSurface()
        testMainActorBoundaryIsDeclared()
        testPoolChartLocalization()
        testLocalizedIntervalFormatting()
        testPoolVerdictPresentation()
        testPoolSufficiencyPresentation()
        try testComputerUsePluginDiscovery()
        try testBackupPruning()
        testProcessRunner()
        testWeeklyResetFormatter()
        testTokenRefreshRequest()
        testTokenRefreshResponseParsing()
        testTokenRefreshErrorMapping()
        testTokenRefreshAgePolicy()
        testCodexAuthDateParsing()
        try testCodexAuthTokenWriter()
        try testPoolHistoryStore()
        testPoolBurnRateEstimatorIgnoresAddedCapacity()
        testWeekCurveBuilder()
        testDailyPoolAggregator()
        testDailyPoolChartPolicies()
        testPaceEstimatorForecast()
        testPoolVerdict()
        testPoolVerdictWithoutHistory()
        testPoolSufficiencyForecastHistoryStates()
        testPoolSufficiencyForecastResetEvents()
        testPoolSufficiencyForecastCapacityGaps()
        testLivePoolSample()
        testCurrentPoolSampleFallsBackToAccountRows()
        testPoolAccountResetDates()
        testPoolHistorySampleResetsAtCoding()
        testResetChanceParsing()
        testResetChanceCommandFallback()
        try testBundledMarketplaceSnapshotOk()
        try testBundledMarketplaceSnapshotIncomplete()
        try testBundledMarketplaceSnapshotAbsent()
        try testBundledMarketplaceSnapshotMissingManifest()
        try testBundledMarketplaceAppSource()
        try testBundledMarketplaceRepairNoop()
        try testBundledMarketplaceRepairFromApp()
        try testBundledMarketplaceRepairRestoresAbsentSnapshot()
        try testBundledMarketplaceRepairRefreshesOutdatedSnapshot()
        try testBundledMarketplaceRepairNoApp()
        try testBundledMarketplaceRepairStaleMove()
        try testBundledMarketplaceRepairRollback()
        try testBundledMarketplaceRepairReinstall()
        try testBundledMarketplaceRepairReinstallsNewBundledPlugin()
        try testBundledMarketplaceRepairReinstallFailure()
        try testReferencePluginInventory()
        try testReferencePluginCaptureRoundTrip()
        try testReferencePluginCapturePreservesPreviousReference()
        try testReferencePluginCaptureReportsRollbackFailure()
        try testReferencePluginCaptureRequiresReadableConfig()
        try testReferencePluginLoadRejectsModifiedFiles()
        try testReferencePluginMarketplacePreparation()
        try testReferencePluginMarketplaceDetectsChangedInstalledPackage()
        testReferencePluginMarketplaceRejectsMissingDigests()
        try testReferencePluginReconcileExactMatch()
        try testReferencePluginReconcileRestoresChangedFiles()
        try testReferencePluginReconcileIdempotent()
        try testReferencePluginReconcileWithoutReference()
        try testReferencePluginReconcileRollsBackFailedSwap()
        try testReferencePluginReconcileReportsRollbackFailure()
        testCuratedPluginPlan()
        testReferenceMarketplacePluginPlan()
        testReferenceMarketplacePluginPlanReinstallsChangedPackage()
        try testReferenceMarketplacePluginReconcile()
        try testReferenceMarketplacePluginReconcileReinstallsChangedPackage()
        try testReferenceMarketplacePluginReconcileReportsCLIError()
        try testCuratedPluginReconcileRollsBackPartialFailure()
        try testReferencePluginTransactionRollsBackBothLayers()
        try testReferencePluginTransactionRollsBackFailedFinalization()
        try testReferencePluginTransactionPreservesBackupWhenRollbackIsUnsafe()
        testPluginSyncStabilityTracker()
        testProcessLookupPolicy()

        if failures.isEmpty {
            print("Infrastructure tests passed (\(assertionCount) assertions).")
            return
        }

        for failure in failures {
            FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8))
        }
        exit(1)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        if !condition() { failures.append(message) }
    }

    private static func testSettingsNumericPolicy() {
        let reminderRange = SettingsNumericPolicy.reminderThresholdRange
        for (draft, expected) in [("1", 1), ("99", 99)] {
            expect(
                SettingsNumericPolicy.normalizedInteger(draft, within: reminderRange) == .success(expected),
                "reminder draft \(draft) should normalize to \(expected)"
            )
        }
        for draft in ["0", "100", "", "   ", "ten"] {
            expect(
                (try? SettingsNumericPolicy.normalizedInteger(draft, within: reminderRange).get()) == nil,
                "reminder draft \(draft.debugDescription) should fail validation"
            )
        }

        let creditDaysRange = SettingsNumericPolicy.creditExpiryLeadDaysRange
        for (draft, expected) in [("1", 1), ("30", 30)] {
            expect(
                SettingsNumericPolicy.normalizedInteger(draft, within: creditDaysRange) == .success(expected),
                "credit-days draft \(draft) should normalize to \(expected)"
            )
        }
        for draft in ["0", "31"] {
            expect(
                (try? SettingsNumericPolicy.normalizedInteger(draft, within: creditDaysRange).get()) == nil,
                "credit-days draft \(draft) should fail validation"
            )
        }

        expect(SettingsNumericPolicy.reminderThresholdDefault == 10, "reminder default should be 10")
        expect(SettingsNumericPolicy.creditExpiryLeadDaysDefault == 3, "credit-days default should be 3")
        expect(SettingsNumericPolicy.creditExpiryInterval(leadDays: 3) == 259_200, "three lead days should equal 259200 seconds")
    }

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

    private static func testRemovedAPIModeHasNoProductionSurface() {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsURL.deletingLastPathComponent()
        let sourceURLs = ["Models.swift", "main.swift"].map {
            root.appendingPathComponent("Sources").appendingPathComponent($0)
        }
        let source = sourceURLs
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let removedSymbols = [
            "apiModeActive",
            "apiUsageSnapshot",
            "showApiSetupDialog",
            "switchToApiMode",
            "apiCodexKeyAccount",
            "apiUsageKeyAccount",
            "case api",
            "case .apiView",
            "case .setupApiMode"
        ]
        for symbol in removedSymbols {
            expect(!source.contains(symbol), "removed API mode symbol must stay absent: \(symbol)")
        }
    }

    private static func testMainActorBoundaryIsDeclared() {
        let testsURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsURL.deletingLastPathComponent()
        let mainURL = root.appendingPathComponent("Sources").appendingPathComponent("main.swift")
        guard let source = try? String(contentsOf: mainURL, encoding: .utf8) else {
            expect(false, "main actor contract should be readable")
            return
        }
        expect(source.contains("@MainActor\nfinal class AppDelegate"), "AppDelegate should be main-actor isolated")
        expect(source.contains("private var refreshGeneration = 0"), "refresh generation should remain explicit")
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
        expect(LocalizedText.value(.deleteAccountButton, language: .russian) == "Удалить", "the delete button should be localized in Russian")
        expect(LocalizedText.value(.deleteAccountButton, language: .english) == "Delete", "the delete button should be localized in English")
        expect(LocalizedText.lastUpdated(isRefreshing: true, elapsed: nil, language: .russian) == "обновление…", "Russian refreshing state should be localized")
        expect(LocalizedText.lastUpdated(isRefreshing: false, elapsed: 5, language: .english) == "just now", "English update age should preserve current copy")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 1, knownAccounts: 2, hasError: false, language: .russian) == "Сбросы (1)", "Russian reset count should use compact copy")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 3, knownAccounts: 2, hasError: false, language: .english) == "Resets (3)", "English reset count should use compact copy")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 0, knownAccounts: 2, hasError: false, language: .russian) == "Сбросы (0)", "known zero should remain numeric")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 0, knownAccounts: 0, hasError: false, language: .russian) == "Сбросы (…)", "unknown count should show loading")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 0, knownAccounts: 0, hasError: true, language: .russian) == "Сбросы (?)", "failed count should show an error")
        expect(LocalizedText.resetCreditsButtonTitle(knownTotal: 2, knownAccounts: 1, hasError: true, language: .russian) == "Сбросы (2+)", "partial count should retain the suffix")
        expect(LocalizedText.resetCreditsTooltip(knownTotal: 0, knownAccounts: 0, hasError: false, language: .russian) == "Проверяем кредиты сброса", "Russian checking tooltip should be localized")
    }

    private static func testPoolChartLocalization() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12)) else {
            expect(false, "chart localization tests should create a fixed local date")
            return
        }

        expect(
            PoolChartLocalization.axisDate(date, language: .russian) == "17 авг.",
            "the Russian chart axis date should not follow the system locale"
        )
        expect(
            PoolChartLocalization.axisDate(date, language: .english) == "Aug 17",
            "the English chart axis date should not follow the system locale"
        )

        let russian = PoolChartLocalization.semanticLabels(language: .russian)
        expect(russian.index == "Индекс", "the chart index semantic label should be Russian")
        expect(russian.base == "Основание", "the chart base semantic label should be Russian")
        expect(russian.capacity == "Полная ёмкость", "the chart capacity semantic label should describe the full pool in Russian")
        expect(russian.pool == "Расход пула", "the chart value semantic label should describe spend in Russian")

        let english = PoolChartLocalization.semanticLabels(language: .english)
        expect(english.index == "Index", "the chart index semantic label should be English")
        expect(english.base == "Base", "the chart base semantic label should be English")
        expect(english.capacity == "Full capacity", "the chart capacity semantic label should describe the full pool in English")
        expect(english.pool == "Pool spend", "the chart value semantic label should describe spend in English")

        let today = DailyPoolSpendPoint(
            date: date,
            spentPercent: 18,
            remainingPercent: 36.6,
            accountCount: 7,
            coverage: .inProgress
        )
        expect(
            PoolChartLocalization.detailLines(for: today, language: .russian) == [
                "17 авг.",
                "Потрачено: 18% пула",
                "Осталось: 36,6%"
            ],
            "Russian current-day popover should keep only the at-a-glance values"
        )
        expect(
            PoolChartLocalization.detailLines(for: today, language: .english) == [
                "Aug 17",
                "Spent: 18% of pool",
                "Remaining: 36.6%"
            ],
            "English current-day popover should keep only the at-a-glance values"
        )

        let incompletePast = DailyPoolSpendPoint(
            date: date,
            spentPercent: 12,
            remainingPercent: 6.6,
            accountCount: 5,
            coverage: .lowerBound
        )
        expect(
            PoolChartLocalization.detailLines(for: incompletePast, language: .russian) == [
                "17 авг.",
                "Потрачено: 12% пула",
                "Осталось: 6,6%"
            ],
            "Russian lower-bound popover should stay concise"
        )

        let noData = DailyPoolSpendPoint(
            date: date,
            spentPercent: nil,
            remainingPercent: nil,
            accountCount: 0,
            coverage: .noData
        )
        expect(
            PoolChartLocalization.detailLines(for: noData, language: .english) == ["Aug 17", "No data"],
            "no-data popover should remain compact"
        )
        expect(
            PoolChartLocalization.dailyReference(language: .russian) == "Дневной ориентир 14%",
            "daily reference label should be localized"
        )
        expect(
            PoolChartLocalization.chartSummary(language: .english) == "Daily consumption of the combined weekly account pool over 14 days",
            "chart summary should explain the accessible time series"
        )
        expect(
            PoolChartLocalization.accessibilityValue(for: incompletePast, language: .english).contains("Spent at least: 12% of pool"),
            "accessibility value should preserve lower-bound semantics"
        )
        expect(
            PoolChartLocalization.accessibilityValue(for: incompletePast, language: .russian).contains("Неполный день"),
            "accessibility value should disclose incomplete sampling in Russian"
        )
        let completePast = DailyPoolSpendPoint(
            date: date,
            spentPercent: 8,
            remainingPercent: 74,
            accountCount: 7,
            coverage: .complete
        )
        expect(
            PoolChartLocalization.accessibilityValue(for: completePast, language: .english).contains("Remaining at day end: 74%"),
            "accessibility value should preserve completed-day remaining wording"
        )
        expect(
            PoolChartLocalization.accessibilityValue(for: incompletePast, language: .english).contains("daily reference"),
            "accessibility value should compare lower-bound spend with the daily reference"
        )
        expect(
            PoolChartLocalization.dailyReferenceAccessibility(language: .russian).contains("7 дней"),
            "the accessible reference description should explain the even seven-day pace"
        )
    }

    private static func testLocalizedIntervalFormatting() {
        expect(LocalizedIntervalFormatter.duration(90, language: .russian) == "2 минуты", "short Russian intervals should use minutes")
        expect(LocalizedIntervalFormatter.duration(90, language: .english) == "2 minutes", "short English intervals should use minutes")
        expect(LocalizedIntervalFormatter.duration(0.7 * 3_600, language: .russian) == "42 минуты", "fractional Russian hours should become minutes")
        expect(LocalizedIntervalFormatter.duration(1.5 * 3_600, language: .russian) == "1 час 30 минут", "Russian intervals should combine hours and minutes")
        expect(LocalizedIntervalFormatter.duration(3_600, language: .russian) == "1 час", "Russian one-hour singular should be correct")
        expect(LocalizedIntervalFormatter.duration(2 * 3_600, language: .russian) == "2 часа", "Russian paucal hours should be correct")
        expect(LocalizedIntervalFormatter.duration(5 * 3_600, language: .russian) == "5 часов", "Russian plural hours should be correct")
        expect(LocalizedIntervalFormatter.duration(86_400, language: .russian) == "1 день", "Russian one-day singular should be correct")
        expect(LocalizedIntervalFormatter.duration(2 * 86_400, language: .russian) == "2 дня", "Russian paucal days should be correct")
        expect(LocalizedIntervalFormatter.duration(5 * 86_400, language: .russian) == "5 дней", "Russian plural days should be correct")
        expect(LocalizedIntervalFormatter.duration(1.8 * 86_400, language: .russian) == "1 день 19 часов", "fractional Russian days should become days and hours")
        expect(LocalizedIntervalFormatter.duration(3_600, language: .english) == "1 hour", "English singular should be correct")
        expect(LocalizedIntervalFormatter.duration(2 * 3_600, language: .english) == "2 hours", "English plural should be correct")
        expect(LocalizedIntervalFormatter.duration(1.8 * 86_400, language: .english) == "1 day 19 hours", "fractional English days should become days and hours")
        expect(LocalizedIntervalFormatter.signedMargin(0.9 * 86_400, language: .russian) == "+21 час 36 минут", "Russian positive badge should use clock units")
        expect(LocalizedIntervalFormatter.signedMargin(-0.7 * 86_400, language: .english) == "−16 hours 48 minutes", "English deficit badge should use clock units")
    }

    private static func testPoolVerdictPresentation() {
        let enough = PoolVerdict(kind: .enough, resetInterval: 2 * 86_400, exhaustionInterval: 2.9 * 86_400, margin: 0.9 * 86_400)
        let enoughRU = PoolVerdictPresenter.make(verdict: enough, language: .russian)
        expect(enoughRU.title == "Хватит до сброса", "Enough should use the Russian title")
        expect(abs((enoughRU.firstEventFraction ?? -1) - (2.0 / 2.9)) < 0.000_001, "Enough should place reset proportionally before exhaustion")
        expect(enoughRU.marginSummaryLabel == "Запас после сброса", "Enough should explain the positive margin")
        expect(enoughRU.marginSummaryValue == "21 час 36 минут", "Enough should show the absolute localized margin")
        expect(enoughRU.events.map(\.kind) == [.now, .reset, .exhaustion], "Enough should order reset before exhaustion")
        expect(enoughRU.events.map(\.intervalText) == [nil, "через 2 дня", "через 2 дня 22 часа"], "Russian events should include localized intervals")

        let enoughEN = PoolVerdictPresenter.make(verdict: enough, language: .english)
        expect(enoughEN.marginSummaryLabel == "After reset", "English Enough should explain the positive margin")
        expect(enoughEN.marginSummaryValue == "21 hours 36 minutes", "English Enough should show the absolute localized margin")

        let notEnough = PoolVerdict(kind: .notEnough, resetInterval: 2 * 86_400, exhaustionInterval: 1.3 * 86_400, margin: -0.7 * 86_400)
        let notEnoughEN = PoolVerdictPresenter.make(verdict: notEnough, language: .english)
        expect(notEnoughEN.title == "Runs out before reset", "Not Enough should use the English title")
        expect(abs((notEnoughEN.firstEventFraction ?? -1) - (1.3 / 2.0)) < 0.000_001, "Not Enough should place exhaustion proportionally before reset")
        expect(notEnoughEN.marginSummaryLabel == "Deficit", "Not Enough should explain the negative margin")
        expect(notEnoughEN.marginSummaryValue == "16 hours 48 minutes", "Not Enough should show the absolute localized margin")
        expect(notEnoughEN.events.map(\.kind) == [.now, .exhaustion, .reset], "Not Enough should order exhaustion before reset")
        expect(notEnoughEN.events.map(\.intervalText) == [nil, "in 1 day 7 hours", "in 2 days"], "English events should include localized intervals")

        let notEnoughRU = PoolVerdictPresenter.make(verdict: notEnough, language: .russian)
        expect(notEnoughRU.marginSummaryLabel == "Дефицит", "Russian Not Enough should explain the negative margin")
        expect(notEnoughRU.marginSummaryValue == "16 часов 48 минут", "Russian Not Enough should show the absolute localized margin")

        let collecting = PoolVerdictPresenter.make(verdict: .collecting, language: .russian)
        expect(collecting.kind == .collecting, "incomplete inputs should remain collecting")
        expect(collecting.firstEventFraction == nil, "Collecting should not expose timeline geometry")
        expect(collecting.marginSummaryLabel == nil, "Collecting should not show a margin label")
        expect(collecting.marginSummaryValue == nil, "Collecting should not show a margin value")
        expect(collecting.events.isEmpty, "Collecting should not show an event scale")

        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 5, lastInterval: 10) == 0.5, "timeline geometry should preserve ratios")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 1, lastInterval: 100) == 0.01, "timeline geometry should preserve a fraction near the lower endpoint")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 99, lastInterval: 100) == 0.99, "timeline geometry should preserve a fraction near the upper endpoint")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: -1, lastInterval: 10) == nil, "timeline geometry should reject a negative first interval")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 0, lastInterval: 10) == nil, "timeline geometry should reject a zero first interval")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 12, lastInterval: 10) == 1, "timeline geometry should clamp the upper endpoint")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: 1, lastInterval: 0) == nil, "timeline geometry should reject an empty horizon")
        expect(PoolVerdictTimelineGeometry.firstEventFraction(firstInterval: .infinity, lastInterval: 10) == nil, "timeline geometry should reject non-finite intervals")

        let exhaustedNow = PoolVerdict(kind: .notEnough, resetInterval: 3_600, exhaustionInterval: 0, margin: -3_600)
        expect(PoolVerdictPresenter.make(verdict: exhaustedNow, language: .russian).kind == .collecting, "a non-positive first event should fall back to Collecting")
    }

    private static func testPoolSufficiencyPresentation() {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let preliminary = PoolSufficiencyForecast(
            kind: .notEnough,
            isPreliminary: true,
            historyDays: 4.7,
            burnPerDay: 118.7,
            expectedDemand: 830.9,
            usableCapacity: 697.956,
            coverageRatio: 0.84,
            exhaustionDate: now.addingTimeInterval(2 * day),
            resetEvents: [
                PoolResetEvent(date: now.addingTimeInterval(2 * day + 22 * 3_600), accountCount: 2),
                PoolResetEvent(date: now.addingTimeInterval(4 * day), accountCount: 1),
                PoolResetEvent(date: now.addingTimeInterval(5 * day), accountCount: 1),
                PoolResetEvent(date: now.addingTimeInterval(6 * day), accountCount: 1)
            ],
            accountCount: 7,
            requiredAccountCount: 9
        )
        let preliminaryRU = PoolVerdictPresenter.make(
            forecast: preliminary,
            language: .russian,
            now: now
        )
        expect(preliminaryRU.title == "Не хватит до сброса", "Russian deficit title should stay unchanged")
        expect(preliminaryRU.subtitle == "Предварительный прогноз · темп за 4,7 дня", "partial history should be explicit")
        expect(preliminaryRU.coverageValue == "−16%", "deficit should be rounded to a whole signed percent")
        expect(preliminaryRU.coverageLabel == "Дефицит", "deficit caption should be semantic")
        expect(preliminaryRU.capacityFraction == 0.84, "capacity fill should preserve coverage below one")
        expect(preliminaryRU.accountValue == "7 / ≈9", "account comparison should be compact")
        expect(preliminaryRU.accountLabel == "аккаунтов / нужно", "account comparison should be explained")
        expect(
            preliminaryRU.resetIndicators == ["2 д 22 ч · ×2", "4 д", "ещё 2"],
            "reset groups should compact overflow"
        )
        expect(preliminaryRU.accessibilityLabel.contains("Дефицит 16%"), "accessibility should describe the deficit")
        expect(preliminaryRU.accessibilityLabel.contains("7 аккаунтов"), "accessibility should describe current accounts")
        expect(preliminaryRU.accessibilityLabel.contains("5 сбросов"), "accessibility should describe known account resets")

        let enough = PoolSufficiencyForecast(
            kind: .enough,
            isPreliminary: false,
            historyDays: 7,
            burnPerDay: 100,
            expectedDemand: 700,
            usableCapacity: 826,
            coverageRatio: 1.18,
            exhaustionDate: nil,
            resetEvents: [],
            accountCount: 7,
            requiredAccountCount: 7
        )
        let enoughEN = PoolVerdictPresenter.make(forecast: enough, language: .english, now: now)
        expect(enoughEN.title == "Enough until reset", "English enough title should stay unchanged")
        expect(enoughEN.subtitle == "Average pace over 7 days", "established English pace should be localized")
        expect(enoughEN.coverageValue == "+18%", "reserve should use an explicit plus sign")
        expect(enoughEN.coverageLabel == "Reserve", "reserve caption should be localized")
        expect(enoughEN.capacityFraction == 1, "capacity fill should clamp reserve above one")

        let collecting = PoolVerdictPresenter.make(
            forecast: .collecting(historyDays: 0, accountCount: 7),
            language: .russian,
            now: now
        )
        expect(collecting.title == "Собираем историю", "collecting title should remain familiar")
        expect(collecting.coverageValue == nil, "collecting should hide invented coverage")
        expect(collecting.capacityFraction == nil, "collecting should hide the capacity track")
        expect(collecting.resetIndicators.isEmpty, "collecting should hide reset indicators")
        expect(collecting.accountValue == nil, "collecting should hide the account requirement")
    }

    private static func testResetRefreshPolicy() {
        let now = Date(timeIntervalSince1970: 1_000)
        expect(ResetRefreshPolicy.shouldRefresh(lastRefresh: nil, now: now, ttl: 300, force: false), "missing reset snapshot should refresh")
        expect(!ResetRefreshPolicy.shouldRefresh(lastRefresh: now.addingTimeInterval(-299), now: now, ttl: 300, force: false), "fresh reset snapshot should stay cached")
        expect(ResetRefreshPolicy.shouldRefresh(lastRefresh: now.addingTimeInterval(-300), now: now, ttl: 300, force: false), "expired reset snapshot should refresh")
        expect(ResetRefreshPolicy.shouldRefresh(lastRefresh: now, now: now, ttl: 300, force: true), "forced reset refresh should bypass cache")
    }

    private static func testUsageRefreshPolicy() {
        let now = Date(timeIntervalSince1970: 2_000)
        expect(UsageRefreshPolicy.shouldRefresh(lastRefresh: nil, now: now, ttl: 30, force: false), "missing usage snapshot should refresh")
        expect(!UsageRefreshPolicy.shouldRefresh(lastRefresh: now.addingTimeInterval(-29), now: now, ttl: 30, force: false), "fresh usage snapshot should stay cached")
        expect(UsageRefreshPolicy.shouldRefresh(lastRefresh: now.addingTimeInterval(-30), now: now, ttl: 30, force: false), "expired usage snapshot should refresh")
        expect(UsageRefreshPolicy.shouldRefresh(lastRefresh: now, now: now, ttl: 30, force: true), "forced usage refresh should bypass cache")
    }

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

    private static func testLimitWarmupRequestAndResponse() throws {
        func payload(_ status: Int, _ body: String) -> HTTPPayload {
            HTTPPayload(data: Data(body.utf8), statusCode: status)
        }
        expect(CodexLimitWarmupClient.resultState(nil) == .networkFailure, "missing response is connection failure")
        expect(CodexLimitWarmupClient.resultState(payload(401, "")) == .loginExpired, "401 requests login")
        expect(CodexLimitWarmupClient.resultState(payload(429, "")) == .rateLimited, "429 alone does not prove exhausted quota")
        expect(CodexLimitWarmupClient.resultState(payload(429, #"{"error":{"type":"usage_limit_reached"}}"#)) == .quotaExceeded, "structured quota error")
        expect(CodexLimitWarmupClient.resultState(payload(200, #"data: {"type":"response.failed","response":{"error":{"code":"usage_limit_reached"}}}"#)) == .quotaExceeded, "stream quota error")
        expect(CodexLimitWarmupClient.resultState(payload(200, #"data: {"type":"error","code":"token_expired"}"#)) == .loginExpired, "stream expired login")
        expect(CodexLimitWarmupClient.resultState(payload(503, "")) == .serverFailure, "server failure")
        expect(CodexLimitWarmupClient.resultState(payload(403, "")) == .accessDenied, "403 not confused with login")
        expect(LimitWarmupState.quotaExceeded.isFailure && LimitWarmupState.loginExpired.isFailure && LimitWarmupState.failed.isFailure, "errors have red presentation")
        expect(!LimitWarmupState.completed.isFailure && !LimitWarmupState.running.isFailure, "normal statuses are not red")
        let auth = SavedAccountAuth(accountKey: "unique-key", email: "test@example.com", accessToken: "fake-token", accountID: "fake-workspace", refreshToken: nil, lastRefresh: nil)
        let request = try CodexLimitWarmupClient.makeRequest(using: auth)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-token", "warmup uses the selected account token")
        expect(request.value(forHTTPHeaderField: "ChatGPT-Account-ID") == "fake-workspace", "warmup keeps the selected workspace")
        expect(body["model"] as? String == "gpt-5.6-luna", "warmup selects Luna")
        expect((body["reasoning"] as? [String: String])?["effort"] == "low", "warmup selects the supported light effort")
        expect(body["stream"] as? Bool == true && body["store"] as? Bool == false, "Codex requires streaming without storage")
        expect(body["max_output_tokens"] == nil, "Codex rejects the normal Responses token cap")
        let complete = "data: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}\n\n"
        expect(CodexLimitWarmupClient.completed(HTTPPayload(data: Data(complete.utf8), statusCode: 200)), "terminal completion succeeds")
        for invalid in ["", "data: [DONE]", "data: {\"type\":\"response.created\"}", "data: {\"type\":\"response.failed\"}", "data: {\"type\":\"response.completed\",\"response\":{\"status\":\"failed\"}}", complete + "data: {\"type\":\"error\"}"] {
            expect(!CodexLimitWarmupClient.completed(HTTPPayload(data: Data(invalid.utf8), statusCode: 200)), "HTTP 200 without a successful stream must not report success")
        }
        expect(!CodexLimitWarmupClient.completed(HTTPPayload(data: Data(complete.utf8), statusCode: 401)), "auth rejection is not success")
    }

    private static func testSavedAccountAuthFilePolicy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstKey = "user-one::shared-workspace"
        let secondKey = "user-two::shared-workspace"
        func writeFixture(_ key: String, token: String) throws -> URL {
            let name = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
            let url = root.appendingPathComponent("\(name).auth.json")
            let data = try JSONSerialization.data(withJSONObject: [
                "tokens": ["account_id": "shared-workspace", "access_token": token]
            ])
            try data.write(to: url)
            return url
        }
        let first = try writeFixture(firstKey, token: "fixture-first")
        let second = try writeFixture(secondKey, token: "fixture-second")
        expect(SavedAccountAuthFilePolicy.fileURL(accountKey: firstKey, expectedAccountID: "shared-workspace", root: root) == first, "first workspace member should select their own auth file")
        let resolved = SavedAccountAuthFilePolicy.fileURL(accountKey: secondKey, expectedAccountID: "shared-workspace", root: root)
        expect(resolved == second, "second workspace member must not reuse first member auth")
        expect(SavedAccountAuthFilePolicy.fileURL(accountKey: "missing", expectedAccountID: "shared-workspace", root: root) == nil, "missing identity must not fall back to another workspace member")
        expect(SavedAccountAuthFilePolicy.fileURL(accountKey: secondKey, expectedAccountID: "other-workspace", root: root) == nil, "mismatched workspace must be rejected")
        expect(!SavedAccountAuthFilePolicy.shouldMirror(activeAccountKey: firstKey, refreshedAccountKey: secondKey), "refreshing another workspace member must not replace active auth")
        expect(SavedAccountAuthFilePolicy.shouldMirror(activeAccountKey: secondKey, refreshedAccountKey: secondKey), "active member refresh should be mirrored")
        let originalFirst = try Data(contentsOf: first)
        if let resolved {
            expect(CodexAuthTokenWriter.applyTokenUpdate(to: resolved, expectedAccountID: "shared-workspace", accessToken: "fixture-refreshed", refreshToken: nil, lastRefresh: Date()) == nil, "selected member refresh should succeed")
        }
        let unchangedFirst = try Data(contentsOf: first)
        expect(originalFirst == unchangedFirst, "refresh must preserve the other member's file")
        let updated = try JSONSerialization.jsonObject(with: Data(contentsOf: second)) as? [String: Any]
        expect((updated?["tokens"] as? [String: Any])?["access_token"] as? String == "fixture-refreshed", "refresh should update the selected member")
    }

    private static func testAccountUsagePresentationPolicy() {
        let pair = AccountUsagePresentationPolicy.pair(
            fiveHourRemaining: 10,
            weeklyRemaining: 80
        )
        expect(
            pair == AccountUsagePairText(fiveHour: "10%", weekly: "80%"),
            "usage pair should preserve five-hour then weekly order"
        )

        let unknownFiveHour = AccountUsagePresentationPolicy.pair(
            fiveHourRemaining: nil,
            weeklyRemaining: 120
        )
        expect(
            unknownFiveHour == AccountUsagePairText(fiveHour: "--", weekly: "100%"),
            "usage pair should preserve unknown values and clamp high values"
        )

        let unknownWeekly = AccountUsagePresentationPolicy.pair(
            fiveHourRemaining: -5,
            weeklyRemaining: nil
        )
        expect(
            unknownWeekly == AccountUsagePairText(fiveHour: "0%", weekly: "--"),
            "usage pair should clamp low values and preserve unknown weekly usage"
        )

        expect(
            LocalizedText.value(.fiveHourShort, language: .russian) == "5 Ч",
            "Russian five-hour label should be compact"
        )
        expect(
            LocalizedText.value(.weeklyShort, language: .russian) == "НЕД",
            "Russian weekly label should be compact"
        )
        expect(
            LocalizedText.value(.fiveHourShort, language: .english) == "5H",
            "English five-hour label should be compact"
        )
        expect(
            LocalizedText.value(.weeklyShort, language: .english) == "WK",
            "English weekly label should be compact"
        )

        let accessibility = LocalizedText.accountUsageAccessibility(
            pair: pair,
            weeklyReset: "Недельный сброс: пт, 09:00",
            language: .russian
        )
        expect(accessibility.contains("5 часов: 10%"), "accessibility should name five-hour remaining usage")
        expect(accessibility.contains("Недельный остаток: 80%"), "accessibility should name weekly remaining usage")
        expect(accessibility.contains("Недельный сброс: пт, 09:00"), "accessibility should include the weekly reset detail")
    }

    private static func testAccountRemovalPolicy() {
        let robert = AccountRemovalPolicy.arguments(email: "r.oberttonyer677408@gmail.com", isActive: false)
        let riccardo = AccountRemovalPolicy.arguments(email: "riccardoroberts6408@gmail.com", isActive: false)
        expect(riccardo == ["remove", "riccardoroberts6408@gmail.com"], "removal must pass the selected full email unchanged")
        expect(robert != riccardo, "similar account emails must remain distinct")
        expect(AccountRemovalPolicy.arguments(email: " riccardoroberts6408@gmail.com ", isActive: false) == ["remove", "riccardoroberts6408@gmail.com"], "email should be trimmed but not fuzzily rewritten")
        expect(AccountRemovalPolicy.arguments(email: "", isActive: false) == nil, "empty email should be rejected")
        expect(AccountRemovalPolicy.arguments(email: "active@example.com", isActive: true) == nil, "active account should be rejected")
        expect(AccountRemovalPolicy.arguments(email: "--all", isActive: false) == nil, "remove-all flag should be rejected")
        expect(AccountRemovalPolicy.arguments(email: "--api", isActive: false) == nil, "every flag-like email should be rejected")
        expect(AccountRemovalPolicy.arguments(email: "not-an-email", isActive: false) == nil, "non-email queries should be rejected")
        expect(!(riccardo ?? []).contains("--all"), "swipe deletion must never remove all accounts")
    }

    private static func testUsagePanelLayoutMetrics() {
        expect(UsagePanelLayoutMetrics.verdictCardHeight == 108, "compact verdict height should be exact")
        expect(UsagePanelLayoutMetrics.verdictResetGap == 10, "verdict and reset chance should use the shared ten-point gap")
        expect(UsagePanelLayoutMetrics.refreshButtonWidth == 68, "Refresh should gain horizontal padding")
        expect(UsagePanelLayoutMetrics.quitButtonWidth == 50, "Quit should gain horizontal padding")
        expect(UsagePanelLayoutMetrics.footerButtonHeight == 26, "footer height should stay stable")
        expect(UsagePanelLayoutMetrics.controlBarHeight == 40, "reset chance and footer should share one height")
        expect(UsagePanelLayoutMetrics.accountRowHeight == 39, "account rows should be compact")
        expect(UsagePanelLayoutMetrics.accountRowGap == 4, "account row gaps should be compact")
        expect(UsagePanelLayoutMetrics.accountPrimaryTrackHeight == 4, "five-hour track should remain primary")
        expect(UsagePanelLayoutMetrics.accountSecondaryTrackHeight == 3, "weekly track should be visually quieter")
        expect(UsagePanelLayoutMetrics.accountSecondaryOpacity == 0.55, "weekly track should keep the approved subdued treatment")
        expect(UsagePanelLayoutMetrics.accountListEdgeAllowance == 2, "native account table should reserve its final cell edge")
    }

    private static func testAccountListViewportHeightPolicy() {
        expect(AccountListPresentationPolicy.viewportHeight(accountCount: 2, visibleRowCount: 2, maximumHeight: 102, rowHeight: 48, confirmationRowHeight: 78, rowGap: 6, showsConfirmation: true) == 78, "confirmation should temporarily hide a non-fitting second row")
        expect(AccountListPresentationPolicy.viewportHeight(accountCount: 8, visibleRowCount: 8, maximumHeight: 426, rowHeight: 48, confirmationRowHeight: 78, rowGap: 6, showsConfirmation: true) == 402, "confirmation should show only complete rows")
        expect(AccountListPresentationPolicy.viewportHeight(accountCount: 8, visibleRowCount: 8, maximumHeight: 456, rowHeight: 48, confirmationRowHeight: 78, rowGap: 6, showsConfirmation: true) == 402, "confirmation viewport should stay compact even when more height is available")
        expect(AccountListPresentationPolicy.viewportHeight(accountCount: 8, visibleRowCount: 8, maximumHeight: 456, rowHeight: 48, confirmationRowHeight: 78, rowGap: 6, showsConfirmation: false) == 426, "normal lists should retain their compact height")
        expect(AccountListPresentationPolicy.viewportHeight(accountCount: 10, visibleRowCount: 10, maximumHeight: 426, rowHeight: 39, confirmationRowHeight: 78, rowGap: 4, showsConfirmation: false) == 426, "ten compact rows should fit the former eight-row stack")
    }

    private static func testInlineSwitchConfirmationPolicy() {
        expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "two@example.com", isActive: false, isSwitching: false) == .arm, "first click should arm confirmation")
        expect(InlineSwitchConfirmationPolicy.decision(armedEmail: "two@example.com", requestedEmail: "two@example.com", isActive: false, isSwitching: false) == .confirm, "confirmed target should switch")
        expect(InlineSwitchConfirmationPolicy.decision(armedEmail: "two@example.com", requestedEmail: "three@example.com", isActive: false, isSwitching: false) == .arm, "different target should replace confirmation")
        expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "one@example.com", isActive: true, isSwitching: false) == .ignore, "active account should not arm")
        expect(InlineSwitchConfirmationPolicy.decision(armedEmail: nil, requestedEmail: "two@example.com", isActive: false, isSwitching: true) == .ignore, "switching state should ignore clicks")
    }

    private static func testInlineQuitConfirmationPolicy() {
        expect(InlineQuitConfirmationPolicy.decision(isArmed: false) == .arm, "first quit click should request confirmation")
        expect(InlineQuitConfirmationPolicy.decision(isArmed: true) == .confirm, "second quit click should terminate")
    }

    private static func testLastKnownGoodSnapshotPolicy() {
        let current = ["one": 100, "two": 100, "removed": 42]
        let merged = LastKnownGoodSnapshotPolicy.merged(
            current: current,
            successful: ["one": 99],
            validKeys: Set(["one", "two", "three"])
        )
        expect(merged["one"] == 99, "new successful usage should replace the previous reading")
        expect(merged["two"] == 100, "a failed or missing refresh should retain the last known good reading")
        expect(merged["three"] == nil, "an account without a successful reading should not invent usage")
        expect(merged["removed"] == nil, "removed accounts should be pruned from retained usage")

        let unchanged = LastKnownGoodSnapshotPolicy.merged(
            current: ["one": 100, "two": 100],
            successful: [:],
            validKeys: Set(["one", "two"])
        )
        expect(unchanged == ["one": 100, "two": 100], "a wholly failed refresh should not roll usage back")
    }

    private static func testToolbarStatusFormatting() {
        expect(ToolbarStatusFormatter.text(usage: "89%") == "89%", "menu-bar status should show only the remaining percentage")
        expect(ToolbarStatusFormatter.text(usage: "100%") == "100%", "full remaining usage should have no account prefix")
        expect(ToolbarStatusFormatter.text(usage: "0%") == "0%", "exhausted usage should have no account prefix")
    }

    private static func testStatusAnimationPolicy() {
        expect(
            StatusAnimationPolicy.shouldContinue(isSwitching: true, isRedeemingReset: false),
            "a switch must keep its progress status"
        )
        expect(
            StatusAnimationPolicy.shouldContinue(isSwitching: false, isRedeemingReset: true),
            "a reset redemption must keep its progress status"
        )
        expect(
            !StatusAnimationPolicy.shouldContinue(isSwitching: false, isRedeemingReset: false),
            "an orphaned progress status must be cleared"
        )
    }

    private static func testComputerUsePluginDiscovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for version in ["1.0.799", "1.0.1000366", "1.2.1"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(version).appendingPathComponent("Codex Computer Use.app"),
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("9.9.9"), withIntermediateDirectories: true)
        let found = ComputerUsePluginLocator.latestApp(in: root)
        expect(found?.deletingLastPathComponent().lastPathComponent == "1.2.1", "plugin discovery should use the newest valid numeric version")
        expect(found?.lastPathComponent == "Codex Computer Use.app", "plugin discovery should return the app bundle")
    }

    private static func testBackupPruning() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for stamp in 1...5 {
            let url = root.appendingPathComponent("account.auth.json.bak.\(stamp)")
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        FileManager.default.createFile(atPath: root.appendingPathComponent("account.auth.json").path, contents: Data())
        let removed = AuthBackupPruner.prune(in: root, keepingPerAccount: 2)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
        expect(removed == 3, "backup pruning should report removed files")
        expect(remaining.contains("account.auth.json.bak.5"), "backup pruning should keep newest backup")
        expect(remaining.contains("account.auth.json.bak.4"), "backup pruning should keep requested backup count")
        expect(remaining.contains("account.auth.json"), "backup pruning should preserve active auth snapshot")
    }

    private static func testProcessRunner() {
        let environment = ProcessInfo.processInfo.environment
        let success = ProcessRunner.run("/bin/echo", ["healthy"], environment: environment, timeout: 2)
        expect(success.status == 0 && success.output.contains("healthy"), "process runner should capture successful output")
        let timeout = ProcessRunner.run("/bin/sleep", ["2"], environment: environment, timeout: 0.1)
        expect(timeout.status == 124 && timeout.output.contains("timed out"), "process runner should terminate stalled commands")
    }

    private static func utcDate(day: Int, month: Int, year: Int, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .distantPast
    }

    private static func testWeeklyResetFormatter() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let saturday = utcDate(day: 15, month: 8, year: 2026, hour: 12, minute: 0, calendar: utc)
        expect(
            WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .english, now: saturday, calendar: utc) == "FRI · 21 Aug · 09:00",
            "reset formatter should resolve the nearest upcoming weekday from the usage string"
        )

        let fridayMorning = utcDate(day: 21, month: 8, year: 2026, hour: 8, minute: 0, calendar: utc)
        expect(
            WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .english, now: fridayMorning, calendar: utc) == "FRI · 21 Aug · 09:00",
            "reset formatter should keep today when the reset time is still upcoming"
        )

        let fridayAfterReset = utcDate(day: 21, month: 8, year: 2026, hour: 10, minute: 0, calendar: utc)
        expect(
            WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .english, now: fridayAfterReset, calendar: utc) == "FRI · 28 Aug · 09:00",
            "reset formatter should jump to next week once today's reset has fired"
        )

        expect(
            WeeklyResetFormatter.text(from: "82% (Fri)", language: .english, now: fridayAfterReset, calendar: utc) == "FRI · 28 Aug",
            "day-only reset text should pick next week when the day matches today"
        )

        expect(
            WeeklyResetFormatter.text(from: "82% (09:00)", language: .english, now: saturday, calendar: utc) == "09:00",
            "reset formatter should fall back to the raw inner text when no weekday is parseable"
        )

        expect(
            WeeklyResetFormatter.text(from: "82% (Sat 09:00)", language: .english, now: saturday, calendar: utc) == "SAT · 22 Aug · 09:00",
            "reset formatter should resolve non-Friday weekdays"
        )

        expect(
            WeeklyResetFormatter.text(from: "--", language: .english, now: saturday, calendar: utc) == "--",
            "dash usage without a parenthesized value should pass through untouched"
        )

        expect(
            WeeklyResetFormatter.text(from: "82% (Fri 09:00)", language: .russian, now: saturday, calendar: utc) == "ПТ · 21 авг. · 09:00",
            "account-row reset text should use Russian weekday and month"
        )
    }

    private static func testTokenRefreshRequest() {
        let request = CodexTokenRefresher.makeRequest(refreshToken: "rt-123")
        expect(request.httpMethod == "POST", "token refresh should use POST")
        expect(request.url == CodexTokenRefresher.refreshEndpoint, "token refresh should target the OAuth token endpoint")
        expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "token refresh should send JSON")
        guard let bodyData = request.httpBody,
              let body = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: String] else {
            expect(false, "token refresh body should be parseable JSON")
            return
        }
        expect(body["grant_type"] == "refresh_token", "token refresh should request the refresh_token grant")
        expect(body["refresh_token"] == "rt-123", "token refresh should carry the refresh token")
        expect(body["client_id"] == CodexTokenRefresher.clientID, "token refresh should use the OpenAI app client id")
        expect(body["scope"] == "openid profile email", "token refresh should request the codex scope")
    }

    private static func testTokenRefreshResponseParsing() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)

        let successJSON = #"{"access_token":"at-new","refresh_token":"rt-new","id_token":"id-new"}"#
        guard let successData = successJSON.data(using: .utf8) else {
            expect(false, "success fixture should be UTF-8")
            return
        }
        if case .success(let payload) = CodexTokenRefresher.parseResponse(
            data: successData,
            statusCode: 200,
            previousRefreshToken: "rt-old",
            now: now
        ) {
            expect(payload.accessToken == "at-new", "token refresh should surface the new access token")
            expect(payload.refreshToken == "rt-new", "token refresh should surface the new refresh token")
            expect(payload.idToken == "id-new", "token refresh should surface the id token")
            expect(payload.lastRefresh == now, "token refresh should stamp the refresh time")
        } else {
            expect(false, "a well-formed 200 response should parse as success")
        }

        let rotatedOnlyJSON = #"{"access_token":"at-rotated"}"#
        guard let rotatedData = rotatedOnlyJSON.data(using: .utf8) else {
            expect(false, "rotated fixture should be UTF-8")
            return
        }
        if case .success(let payload) = CodexTokenRefresher.parseResponse(
            data: rotatedData,
            statusCode: 200,
            previousRefreshToken: "rt-old",
            now: now
        ) {
            expect(payload.refreshToken == "rt-old", "token refresh should keep the previous refresh token when omitted")
        } else {
            expect(false, "an access-token-only 200 response should still succeed")
        }

        let missingTokenJSON = #"{"id_token":"id-only"}"#
        guard let missingTokenData = missingTokenJSON.data(using: .utf8) else {
            expect(false, "missing-token fixture should be UTF-8")
            return
        }
        if case .invalidResponse = CodexTokenRefresher.parseResponse(
            data: missingTokenData,
            statusCode: 200,
            previousRefreshToken: "rt-old",
            now: now
        ) {} else {
            expect(false, "a 200 response without access_token should be invalid")
        }

        let garbage = Data("not json".utf8)
        if case .invalidResponse = CodexTokenRefresher.parseResponse(
            data: garbage,
            statusCode: 200,
            previousRefreshToken: "rt-old",
            now: now
        ) {} else {
            expect(false, "non-JSON 200 response should be invalid")
        }
    }

    private static func testTokenRefreshErrorMapping() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)

        let expiredJSON = #"{"error":{"code":"refresh_token_expired"}}"#
        if case .expired = CodexTokenRefresher.parseResponse(
            data: Data(expiredJSON.utf8),
            statusCode: 400,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "refresh_token_expired should map to expired")
        }

        let reusedJSON = #"{"error":{"code":"refresh_token_reused"}}"#
        if case .reused = CodexTokenRefresher.parseResponse(
            data: Data(reusedJSON.utf8),
            statusCode: 400,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "refresh_token_reused should map to reused")
        }

        let revokedJSON = #"{"error":"invalid_grant"}"#
        if case .revoked = CodexTokenRefresher.parseResponse(
            data: Data(revokedJSON.utf8),
            statusCode: 400,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "invalid_grant should map to revoked")
        }

        let invalidatedJSON = #"{"code":"refresh_token_invalidated"}"#
        if case .revoked = CodexTokenRefresher.parseResponse(
            data: Data(invalidatedJSON.utf8),
            statusCode: 400,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "refresh_token_invalidated should map to revoked")
        }

        if case .expired = CodexTokenRefresher.parseResponse(
            data: Data(),
            statusCode: 401,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "a bare 401 should map to expired")
        }

        if case .invalidResponse = CodexTokenRefresher.parseResponse(
            data: Data(),
            statusCode: 500,
            previousRefreshToken: "rt",
            now: now
        ) {} else {
            expect(false, "an unknown status should surface as invalid response")
        }
    }

    private static func testTokenRefreshAgePolicy() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        expect(CodexTokenRefresher.shouldRefresh(lastRefresh: nil, now: now), "a missing refresh stamp should be eligible for refresh")
        expect(
            !CodexTokenRefresher.shouldRefresh(lastRefresh: now.addingTimeInterval(-60), now: now),
            "a recent refresh stamp should not trigger proactive refresh"
        )
        expect(
            CodexTokenRefresher.shouldRefresh(lastRefresh: now.addingTimeInterval(-3 * 24 * 60 * 60), now: now),
            "a three-day-old refresh stamp should trigger proactive refresh"
        )
    }

    private static func testCodexAuthDateParsing() {
        let parsed = CodexAuthDate.parseLastRefresh("2026-08-12T09:30:00Z")
        expect(parsed != nil, "an ISO8601 refresh stamp should parse")
        if let parsed {
            let formatter = ISO8601DateFormatter()
            expect(formatter.string(from: parsed) == "2026-08-12T09:30:00Z", "an ISO8601 refresh stamp should keep its instant")
        }

        let fractional = CodexAuthDate.parseLastRefresh("2026-08-12T09:30:00.123Z")
        expect(fractional != nil, "a fractional-seconds refresh stamp should parse")

        expect(CodexAuthDate.parseLastRefresh(nil) == nil, "a missing refresh stamp should stay nil")
        expect(CodexAuthDate.parseLastRefresh("not-a-date") == nil, "a malformed refresh stamp should stay nil")

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let roundtrip = CodexAuthDate.parseLastRefresh(CodexAuthDate.encode(now))
        expect(roundtrip != nil, "an encoded refresh stamp should roundtrip")
        if let roundtrip {
            expect(abs(roundtrip.timeIntervalSince(now)) < 1, "an encoded refresh stamp should preserve the instant")
        }
    }

    private static func testCodexAuthTokenWriter() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("accounts.auth.json")

        let fixture: [String: Any] = [
            "tokens": [
                "access_token": "at-old",
                "refresh_token": "rt-old",
                "account_id": "acc-1",
                "unrelated": "keep-me"
            ],
            "oauth_account": ["id": "123"]
        ]
        let data = try JSONSerialization.data(withJSONObject: fixture)
        try data.write(to: fileURL)

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let failure = CodexAuthTokenWriter.applyTokenUpdate(
            to: fileURL,
            expectedAccountID: "acc-1",
            accessToken: "at-new",
            refreshToken: "rt-new",
            lastRefresh: now
        )
        expect(failure == nil, "a matching auth file should update without failure")

        guard let updatedData = try? Data(contentsOf: fileURL),
              let updated = (try? JSONSerialization.jsonObject(with: updatedData)) as? [String: Any],
              let tokens = updated["tokens"] as? [String: Any] else {
            expect(false, "the updated auth file should remain readable JSON")
            return
        }
        expect(tokens["access_token"] as? String == "at-new", "token update should write the new access token")
        expect(tokens["refresh_token"] as? String == "rt-new", "token update should write the new refresh token")
        expect(tokens["last_refresh"] as? String == CodexAuthDate.encode(now), "token update should write the refresh stamp")
        expect(tokens["account_id"] as? String == "acc-1", "token update should preserve the account id")
        expect(tokens["unrelated"] as? String == "keep-me", "token update should preserve unrelated token fields")
        expect((updated["oauth_account"] as? [String: Any])?["id"] as? String == "123", "token update should preserve the outer auth object")

        let mismatch = CodexAuthTokenWriter.applyTokenUpdate(
            to: fileURL,
            expectedAccountID: "acc-2",
            accessToken: "at-should-not-stick",
            refreshToken: "rt-should-not-stick",
            lastRefresh: now
        )
        expect(mismatch != nil, "a concurrent account switch should abort the token update")
        guard let afterMismatchData = try? Data(contentsOf: fileURL),
              let afterMismatch = (try? JSONSerialization.jsonObject(with: afterMismatchData)) as? [String: Any],
              let afterMismatchTokens = afterMismatch["tokens"] as? [String: Any] else {
            expect(false, "the aborted auth file should remain readable JSON")
            return
        }
        expect(afterMismatchTokens["access_token"] as? String == "at-new", "an aborted update must not clobber the file")

        let missingFailure = CodexAuthTokenWriter.applyTokenUpdate(
            to: root.appendingPathComponent("does-not-exist.json"),
            expectedAccountID: "acc-1",
            accessToken: "at",
            refreshToken: "rt",
            lastRefresh: now
        )
        expect(missingFailure != nil, "a missing auth file should report a failure")
    }

    private static func testPoolHistoryStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("pool-history.jsonl")

        let t0 = Date(timeIntervalSince1970: 1_750_000_000)
        let sampleA = PoolHistorySample(
            ts: t0,
            n: 5,
            poolTotal: 500,
            accounts: [
                PoolAccountSample(key: "a", remaining: 100),
                PoolAccountSample(key: "b", remaining: 100)
            ]
        )
        expect(PoolHistoryStore.poolAverage(n: 0, poolTotal: 0) == 0, "an empty pool should average to zero")
        expect(PoolHistoryStore.poolAverage(n: 5, poolTotal: 500) == 100, "the pool average should normalize by account count")

        let t1 = t0.addingTimeInterval(30 * 60)
        let sampleB = PoolHistorySample(ts: t1, n: 5, poolTotal: 460, accounts: [])
        let duplicateInBucket = PoolHistorySample(ts: t1.addingTimeInterval(60), n: 5, poolTotal: 458, accounts: [])
        try PoolHistoryStore.write([sampleA], to: fileURL, now: t1)
        expect(
            PoolHistoryStore.load(from: fileURL) == [sampleA],
            "a written history file should round-trip its samples"
        )

        let corrupt = root.appendingPathComponent("corrupt.jsonl")
        let isoEncoder = JSONEncoder()
        isoEncoder.dateEncodingStrategy = .iso8601
        var corruptText = "not-json\n"
        if let encoded = try? isoEncoder.encode(sampleA), let line = String(data: encoded, encoding: .utf8) {
            corruptText += line + "\n"
        }
        try corruptText.write(to: corrupt, atomically: true, encoding: .utf8)
        expect(
            PoolHistoryStore.load(from: corrupt) == [sampleA],
            "a corrupt line should be skipped without failing the load"
        )

        var running = PoolHistoryStore.load(from: fileURL)
        running.append(contentsOf: [sampleB, duplicateInBucket])
        try PoolHistoryStore.write(running, to: fileURL, now: t1)
        let deduped = PoolHistoryStore.load(from: fileURL)
        expect(deduped.count == 2, "samples in different buckets should both load")
        expect(deduped.last?.poolTotal == 458, "the newest sample in a bucket should win")

        let older = PoolHistorySample(ts: t0.addingTimeInterval(-100 * 24 * 60 * 60), n: 5, poolTotal: 400, accounts: [])
        let pruned = PoolHistoryStore.pruned([older, sampleA], now: t0)
        expect(pruned == [sampleA], "samples beyond the retention window should be pruned")

        expect(
            PoolHistoryStore.shouldRecord(lastSample: nil, poolAverage: 92, now: t0),
            "a missing last sample should always record"
        )
        expect(
            !PoolHistoryStore.shouldRecord(lastSample: sampleA, poolAverage: 99.9, now: t0.addingTimeInterval(60), minimumDelta: 1.0),
            "a fresh sample with a small delta should not record"
        )
        expect(
            PoolHistoryStore.shouldRecord(lastSample: sampleA, poolAverage: 90, now: t0.addingTimeInterval(60)),
            "a fresh sample with a large delta should record"
        )
        expect(
            PoolHistoryStore.shouldRecord(lastSample: sampleA, poolAverage: 99, now: t0.addingTimeInterval(30 * 60)),
            "a stale sample should record even without a large delta"
        )
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// Generates 30-minute pool samples with a linear weekly burn from 100%,
/// starting at a UTC week start, ending no later than `until` (defaults to the
/// full `weeks` span). The last sample never lies after `until`.
    private static func poolSamples(
        startingAt start: Date,
        weeks: Int,
        burnPerWeek: Double,
        accountCount: Int = 5,
        until now: Date? = nil
    ) -> [PoolHistorySample] {
        let weekDuration = 7 * 24 * 60 * 60
        let interval = 30 * 60.0
        let limit = start.addingTimeInterval(Double(weeks) * Double(weekDuration))
        let end = min(limit, now ?? limit)
        var samples: [PoolHistorySample] = []
        var ts = start
        while ts <= end {
            let elapsedWeeks = ts.timeIntervalSince(start) / Double(weekDuration)
            let average = max(0, 100 - burnPerWeek * elapsedWeeks)
            samples.append(PoolHistorySample(ts: ts, n: accountCount, poolTotal: average * Double(accountCount), accounts: []))
            ts = ts.addingTimeInterval(interval)
        }
        return samples
    }

    private static func testWeekCurveBuilder() {
        let calendar = utcCalendar
        let arbitrary = Date(timeIntervalSince1970: 1_752_000_000)
        let start = WeekCurveBuilder.weekStart(of: arbitrary, calendar: calendar)
        expect(calendar.component(.weekday, from: start) == calendar.firstWeekday, "the week start should be the calendar's first weekday")
        expect(start <= arbitrary && arbitrary.timeIntervalSince(start) < 7 * 24 * 60 * 60, "the week start should bracket the sample date")

        let samples = poolSamples(startingAt: start, weeks: 2, burnPerWeek: 25)
        let curves = WeekCurveBuilder.weekCurves(from: samples, calendar: calendar)
        expect(curves.count == 2, "two calendar weeks should build two curves")
        for (_, curve) in curves {
            expect(curve.count == WeekCurveBuilder.gridPointCount, "a week curve should fill the grid")
            for index in 1..<curve.count {
                expect(curve[index] <= curve[index - 1] + 1e-9, "a week curve should be monotone non-increasing")
            }
        }
        guard let firstCurve = curves.first?.curve else {
            expect(false, "the first week curve should exist")
            return
        }
        let middle = WeekCurveBuilder.interpolate(curve: firstCurve, at: 0.5)
        expect(abs(middle - 87.5) < 0.6, "halfway through a 25pt/week burn should sit near 87.5")
        expect(WeekCurveBuilder.interpolate(curve: firstCurve, at: 0) == firstCurve[0], "interpolate at zero should return the start value")
    }

    private static func testDailyPoolAggregator() {
        let calendar = utcCalendar
        let day0 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_000_000))
        let day1 = day0.addingTimeInterval(24 * 3600)
        let day2 = day1.addingTimeInterval(24 * 3600)

        func poolSample(_ ts: Date, _ values: [String: Double]) -> PoolHistorySample {
            let accounts = values.keys.sorted().compactMap { key -> PoolAccountSample? in
                guard let remaining = values[key] else { return nil }
                return PoolAccountSample(key: key, remaining: remaining)
            }
            return PoolHistorySample(
                ts: ts,
                n: accounts.count,
                poolTotal: accounts.reduce(0) { $0 + $1.remaining },
                accounts: accounts
            )
        }

        let livePoints = DailyPoolSpendAggregator.dailyPoints(
            from: [
                poolSample(day0.addingTimeInterval(-15 * 60), ["a": 100, "b": 100]),
                poolSample(day0.addingTimeInterval(30 * 60), ["a": 90, "b": 100]),
                poolSample(day0.addingTimeInterval(60 * 60), ["a": 80, "b": 90])
            ],
            dayCount: 1,
            now: day0.addingTimeInterval(90 * 60),
            calendar: calendar
        )
        expect(livePoints.count == 1, "one requested day should produce one slot")
        expect(abs((livePoints[0].spentPercent ?? -1) - 15) < 0.001, "30 points across two accounts should consume 15% of the pool")
        expect(abs((livePoints[0].remainingPercent ?? -1) - 85) < 0.001, "the final pool average should be 85% remaining")
        expect(livePoints[0].accountCount == 2, "both represented accounts should define full pool capacity")
        expect(livePoints[0].coverage == .inProgress, "a fully anchored current day should be in progress")

        let resetPoints = DailyPoolSpendAggregator.dailyPoints(
            from: [
                poolSample(day0.addingTimeInterval(-15 * 60), ["a": 10]),
                poolSample(day0.addingTimeInterval(30 * 60), ["a": 100]),
                poolSample(day0.addingTimeInterval(60 * 60), ["a": 80])
            ],
            dayCount: 1,
            now: day0.addingTimeInterval(90 * 60),
            calendar: calendar
        )
        expect(abs((resetPoints[0].spentPercent ?? -1) - 20) < 0.001, "a reset increase should not erase or invent spend")

        let addedAccountPoints = DailyPoolSpendAggregator.dailyPoints(
            from: [
                poolSample(day0.addingTimeInterval(-15 * 60), ["a": 100]),
                poolSample(day0.addingTimeInterval(30 * 60), ["a": 90, "b": 100]),
                poolSample(day0.addingTimeInterval(60 * 60), ["a": 80, "b": 80])
            ],
            dayCount: 1,
            now: day0.addingTimeInterval(90 * 60),
            calendar: calendar
        )
        expect(abs((addedAccountPoints[0].spentPercent ?? -1) - 20) < 0.001, "40 points across the two-account pool should normalize to 20%")
        expect(addedAccountPoints[0].coverage == .inProgressLowerBound, "an account without an opening anchor should make the day a lower bound")

        let sparsePoints = DailyPoolSpendAggregator.dailyPoints(
            from: [
                poolSample(day0.addingTimeInterval(30 * 60), ["a": 90]),
                poolSample(day0.addingTimeInterval(60 * 60), ["a": 80]),
                poolSample(day2.addingTimeInterval(30 * 60), ["a": 70])
            ],
            dayCount: 3,
            now: day2.addingTimeInterval(60 * 60),
            calendar: calendar
        )
        expect(sparsePoints.count == 3, "the window should preserve all requested calendar slots")
        expect(sparsePoints[0].coverage == .lowerBound, "a past day without an opening anchor should be a lower bound")
        expect(sparsePoints[1].coverage == .noData, "a missing day should retain a no-data slot")
        expect(sparsePoints[1].spentPercent == nil, "a missing day should not invent zero spend")
        expect(sparsePoints[2].coverage == .noData, "a day without any comparable observations should remain no data")

        let empty = DailyPoolSpendAggregator.dailyPoints(from: [], dayCount: 14, now: day2, calendar: calendar)
        expect(empty.count == 14, "empty history should still produce fourteen slots")
        expect(empty.allSatisfy { $0.spentPercent == nil && $0.coverage == .noData }, "empty slots should remain unknown")
    }

    private static func testPoolBurnRateEstimatorIgnoresAddedCapacity() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let history = [
            PoolHistorySample(
                ts: now.addingTimeInterval(-14 * 3600),
                n: 1,
                poolTotal: 29,
                accounts: [PoolAccountSample(key: "existing", remaining: 29)]
            ),
            PoolHistorySample(
                ts: now.addingTimeInterval(-4 * 3600),
                n: 2,
                poolTotal: 101,
                accounts: [
                    PoolAccountSample(key: "existing", remaining: 5),
                    PoolAccountSample(key: "added", remaining: 96)
                ]
            ),
            PoolHistorySample(
                ts: now,
                n: 2,
                poolTotal: 14,
                accounts: [
                    PoolAccountSample(key: "existing", remaining: 0),
                    PoolAccountSample(key: "added", remaining: 14)
                ]
            )
        ]

        let burn = PoolBurnRateEstimator.grossBurnPerDay(history)
        let expected = 111.0 / (14.0 / 24.0)
        expect(
            burn.map { abs($0 - expected) < 0.001 } == true,
            "added account capacity must not hide 111 percentage points of observed consumption"
        )
        if let burn {
            let reset = now.addingTimeInterval(44 * 3600)
            let verdict = PoolVerdict.evaluateAvailableData(
                poolTotal: 14,
                observedBurnPerDay: burn,
                accountCount: 2,
                eolDate: nil,
                resetDate: reset,
                now: now
            )
            expect(verdict.kind == .notEnough, "the observed burn should exhaust the pool before reset")
        }
    }

    private static func testDailyPoolChartPolicies() {
        expect(PoolChartPopoverMetrics.width == 164, "popover width should be compact")
        expect(PoolChartPopoverMetrics.minimumHeight == 80, "popover should be taller")
        expect(PoolChartPopoverMetrics.dateFontSize == 13, "date should be more readable")
        expect(PoolChartPopoverMetrics.bodyFontSize == 12, "body should be more readable")
        expect(PoolChartPopoverMetrics.horizontalPadding == 12, "horizontal padding should remain balanced")
        expect(PoolChartPopoverMetrics.verticalPadding == 10, "vertical padding should create a taller card")
        expect(DailyPoolSpendBand.classify(nil) == .unknown, "missing spend should remain neutral")
        expect(DailyPoolSpendBand.classify(14.3) == .withinReference, "14.3% should remain within the daily reference")
        expect(DailyPoolSpendBand.classify(14.31) == .aboveReference, "spend above the daily reference should warn")
        expect(DailyPoolSpendBand.classify(25) == .aboveReference, "25% should remain in the warning band")
        expect(DailyPoolSpendBand.classify(25.01) == .high, "spend above 25% should be high")
        expect(abs(PoolChartVisualScale.barHeight(for: DailyPoolSpendBand.dailyReferencePercent) - 50) < 0.001, "the daily reference should occupy half the chart visually")
        expect(PoolChartVisualScale.barHeight(for: 19) > 50, "19% spend should render above the visual guide")
        expect(PoolChartVisualScale.barHeight(for: 0) == 0, "zero spend should have no visible fill")
        expect(PoolChartHoverPolicy.nearestIndex(to: 4.6, count: 14) == 5, "hover should choose the nearest stable slot")
        expect(PoolChartHoverPolicy.nearestIndex(to: -2, count: 14) == 0, "hover should clamp to the first slot")
        expect(PoolChartHoverPolicy.nearestIndex(to: 20, count: 14) == 13, "hover should clamp to the final slot")
        expect(PoolChartHoverPolicy.nearestIndex(to: 2, count: 0) == nil, "an empty chart should not select a slot")
        expect(!PoolChartPopoverPolicy.shouldPlaceLeft(index: 8, count: 14), "earlier bars should place the popover on the right")
        expect(PoolChartPopoverPolicy.shouldPlaceLeft(index: 9, count: 14), "the last five bars should place the popover on the left")
        expect(PoolChartPopoverPolicy.shouldPlaceLeft(index: 0, count: 3), "all bars should place left when fewer than five are visible")

        let leadingPlacement = PoolChartPopoverPolicy.placement(
            anchorX: 4,
            preferredCenterY: 10,
            containerWidth: 520,
            containerHeight: 104,
            popoverWidth: 164,
            popoverHeight: 80
        )
        expect(leadingPlacement.centerX == 84, "the first-bar popover should remain inside the leading edge")
        expect(leadingPlacement.centerY == 42, "the popover should remain inside the chart's top edge")
        expect(leadingPlacement.caretOffsetX == -70, "the caret should point back toward the first bar")

        let trailingPlacement = PoolChartPopoverPolicy.placement(
            anchorX: 516,
            preferredCenterY: 94,
            containerWidth: 520,
            containerHeight: 104,
            popoverWidth: 164,
            popoverHeight: 80
        )
        expect(trailingPlacement.centerX == 436, "the final-bar popover should remain inside the trailing edge")
        expect(trailingPlacement.centerY == 62, "the popover should remain inside the chart's bottom edge")
        expect(trailingPlacement.caretOffsetX == 70, "the caret should point back toward the final bar")
    }

    private static func testPaceEstimatorForecast() {
        let calendar = utcCalendar
        let arbitrary = Date(timeIntervalSince1970: 1_752_000_000)
        let start = WeekCurveBuilder.weekStart(of: arbitrary, calendar: calendar)
        let now = start.addingTimeInterval(3.5 * 7 * 24 * 60 * 60) // middle of week 4

        // Fast burn: 25 pt per week ends exactly at the end of week 4.
        let fast = poolSamples(startingAt: start, weeks: 4, burnPerWeek: 25, until: now)
        let fastForecast = PaceEstimator.forecast(samples: fast, now: now, calendar: calendar)
        expect(!fastForecast.insufficientData, "four weeks of history should be enough data")
        if let eolDate = fastForecast.eolDate {
            expect(eolDate > now, "the EOL should lie in the future")
            expect(eolDate < now.addingTimeInterval(7 * 24 * 60 * 60), "a 25pt/week burn should end within the current week")
        } else {
            expect(false, "a draining pool should produce an EOL date")
        }

        // Slow burn: 10 pt per week survives every week.
        let slow = poolSamples(startingAt: start, weeks: 4, burnPerWeek: 10, until: now)
        let slowForecast = PaceEstimator.forecast(samples: slow, now: now, calendar: calendar)
        expect(!slowForecast.insufficientData, "the slow history should still be enough data")
        expect(slowForecast.willLastToReset, "a 10pt/week burn should survive the week")
        expect(slowForecast.eolDate == nil, "a surviving pool should have no EOL")
        expect((slowForecast.runOutProbability ?? 0) < 0.5, "the burn-out probability should stay low")

        // Almost no history: one day of samples.
        let sparse = poolSamples(startingAt: start, weeks: 1, burnPerWeek: 25).filter { $0.ts <= start.addingTimeInterval(24 * 60 * 60) }
        let sparseForecast = PaceEstimator.forecast(samples: sparse, now: sparse.last?.ts ?? now, calendar: calendar)
        expect(sparseForecast.insufficientData, "less than two days of history should be reported as insufficient")

        // Partial week only (no complete weeks): a sharp drop should still yield a near-term EOL.
        let partialStart = Date(timeIntervalSince1970: 1_752_000_000)
        var partial: [PoolHistorySample] = []
        var partialTs = partialStart
        var partialValue = 100.0
        while partialValue > 25 {
            partial.append(PoolHistorySample(ts: partialTs, n: 5, poolTotal: partialValue * 5, accounts: []))
            partialTs = partialTs.addingTimeInterval(60 * 60)
            partialValue -= 75.0 / 72.0
        }
        let partialNow = partial.last?.ts ?? partialStart
        let partialForecast = PaceEstimator.forecast(samples: partial, now: partialNow, calendar: calendar)
        expect(!partialForecast.insufficientData, "three days in the current week should produce an approximate forecast")
        expect(partialForecast.eolDate != nil, "a sharp drop within the partial week should forecast an EOL")
    }

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

    private static func testPoolVerdictWithoutHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(3 * 86_400)
        let fallback = PoolVerdict.evaluateAvailableData(
            poolTotal: 200,
            observedBurnPerDay: nil,
            accountCount: 5,
            eolDate: nil,
            resetDate: reset,
            now: now
        )
        expect(fallback.kind == .notEnough, "missing history should use the weekly quota baseline instead of Collecting")
        expect(fallback.resetInterval == 3 * 86_400, "the no-history verdict should still show the reset interval")
        expect(fallback.exhaustionInterval != nil, "the no-history verdict should still show an exhaustion estimate")
        expect(fallback.margin != nil, "the no-history verdict should still show a signed margin")
    }

    private static func testPoolSufficiencyForecastHistoryStates() {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let current = [
            PoolAccountSample(key: "a", remaining: 80, resetsAt: now.addingTimeInterval(3 * day))
        ]

        let collecting = PoolSufficiencyForecaster.forecast(
            samples: [poolForecastSample(ts: now, accounts: current)],
            now: now
        )
        expect(collecting.kind == .collecting, "one sample should keep collecting")

        let preliminary = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-2 * day),
                end: now,
                startAccounts: [PoolAccountSample(key: "a", remaining: 100, resetsAt: current[0].resetsAt)],
                currentAccounts: current
            ),
            now: now
        )
        expect(preliminary.kind == .enough, "a low preliminary burn should be forecast as enough")
        expect(preliminary.isPreliminary, "less than seven usable days should be preliminary")
        expect(abs(preliminary.historyDays - 2) < 0.001, "preliminary history span should be reported")

        let established = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-7 * day),
                end: now,
                startAccounts: [PoolAccountSample(key: "a", remaining: 100, resetsAt: current[0].resetsAt)],
                currentAccounts: current
            ),
            now: now
        )
        expect(!established.isPreliminary, "seven usable days should establish the pace")

        let flat = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-day),
                end: now,
                startAccounts: current,
                currentAccounts: current
            ),
            now: now
        )
        expect(flat.kind == .collecting, "zero observed consumption should keep collecting")
        expect(flat.burnPerDay == nil, "collecting should not invent a quota pace")
    }

    private static func testPoolSufficiencyForecastResetEvents() {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sharedReset = now.addingTimeInterval(2 * day)
        let laterReset = now.addingTimeInterval(4 * day)
        let current = [
            PoolAccountSample(key: "a", remaining: 90, resetsAt: sharedReset),
            PoolAccountSample(key: "b", remaining: 90, resetsAt: sharedReset),
            PoolAccountSample(key: "c", remaining: 90, resetsAt: laterReset)
        ]
        let history = poolForecastHistory(
            start: now.addingTimeInterval(-day),
            end: now,
            startAccounts: [
                PoolAccountSample(key: "a", remaining: 100, resetsAt: sharedReset),
                PoolAccountSample(key: "b", remaining: 100, resetsAt: sharedReset),
                PoolAccountSample(key: "c", remaining: 100, resetsAt: laterReset)
            ],
            currentAccounts: current
        )

        let forecast = PoolSufficiencyForecaster.forecast(samples: history, now: now)
        expect(forecast.kind == .enough, "large balances and upcoming resets should cover the horizon")
        expect(forecast.resetEvents.count == 2, "distinct reset times should stay ordered and separate")
        expect(forecast.resetEvents.first?.date == sharedReset, "the earliest reset should be first")
        expect(forecast.resetEvents.first?.accountCount == 2, "simultaneous resets should be grouped")
        expect(forecast.resetEvents.last?.date == laterReset, "the later reset should remain visible")
        expect(forecast.resetEvents.last?.accountCount == 1, "a single reset should keep a count of one")
    }

    private static func testPoolSufficiencyForecastCapacityGaps() {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let gapCurrent = [
            PoolAccountSample(key: "a", remaining: 30, resetsAt: now.addingTimeInterval(3 * day)),
            PoolAccountSample(key: "b", remaining: 10, resetsAt: now.addingTimeInterval(6 * day))
        ]
        let gapForecast = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-2 * day),
                end: now,
                startAccounts: [
                    PoolAccountSample(key: "a", remaining: 70, resetsAt: gapCurrent[0].resetsAt),
                    PoolAccountSample(key: "b", remaining: 10, resetsAt: gapCurrent[1].resetsAt)
                ],
                currentAccounts: gapCurrent
            ),
            now: now
        )
        expect(gapForecast.kind == .notEnough, "the pool should fail when it cannot bridge to the first reset")
        expect(
            gapForecast.exhaustionDate == now.addingTimeInterval(2 * day),
            "forty points at twenty points per day should exhaust in two days"
        )
        expect(gapForecast.coverageRatio.map { abs($0 - (40.0 / 140.0)) < 0.001 } == true, "inaccessible later resets should not inflate coverage")

        let unknownCurrent = [PoolAccountSample(key: "unknown", remaining: 30, resetsAt: nil)]
        let unknownForecast = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-7 * day),
                end: now,
                startAccounts: [PoolAccountSample(key: "unknown", remaining: 100, resetsAt: nil)],
                currentAccounts: unknownCurrent
            ),
            now: now
        )
        expect(unknownForecast.kind == .notEnough, "an unknown reset should contribute no invented replenishment")
        expect(unknownForecast.resetEvents.isEmpty, "unknown reset dates should not create events")
        expect(unknownForecast.exhaustionDate == now.addingTimeInterval(3 * day), "current unknown-reset balance should remain usable")

        let enoughCurrent = [
            PoolAccountSample(key: "a", remaining: 30, resetsAt: now.addingTimeInterval(2 * day)),
            PoolAccountSample(key: "b", remaining: 100, resetsAt: now.addingTimeInterval(5 * day))
        ]
        let enoughForecast = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-7 * day),
                end: now,
                startAccounts: [
                    PoolAccountSample(key: "a", remaining: 100, resetsAt: enoughCurrent[0].resetsAt),
                    PoolAccountSample(key: "b", remaining: 100, resetsAt: enoughCurrent[1].resetsAt)
                ],
                currentAccounts: enoughCurrent
            ),
            now: now
        )
        expect(enoughForecast.kind == .enough, "the pool should survive every reset gap and the full horizon")
        expect(enoughForecast.coverageRatio.map { $0 > 1 } == true, "surviving capacity should expose a positive reserve")
        expect(enoughForecast.requiredAccountCount == 1, "seventy points of weekly demand should require about one account")

        let highBurnCurrent = (0..<9).map {
            PoolAccountSample(key: "high-\($0)", remaining: $0 < 3 ? 80 : 90, resetsAt: nil)
        }
        let highBurnStart = highBurnCurrent.map {
            PoolAccountSample(key: $0.key, remaining: 100, resetsAt: nil)
        }
        let highBurn = PoolSufficiencyForecaster.forecast(
            samples: poolForecastHistory(
                start: now.addingTimeInterval(-day),
                end: now,
                startAccounts: highBurnStart,
                currentAccounts: highBurnCurrent
            ),
            now: now
        )
        expect(highBurn.burnPerDay == 120, "the high-burn fixture should consume 120 pool points per day")
        expect(highBurn.requiredAccountCount == 9, "840 points of weekly demand should require about nine accounts")
    }

    private static func poolForecastHistory(
        start: Date,
        end: Date,
        startAccounts: [PoolAccountSample],
        currentAccounts: [PoolAccountSample]
    ) -> [PoolHistorySample] {
        [
            poolForecastSample(ts: start, accounts: startAccounts),
            poolForecastSample(ts: end, accounts: currentAccounts)
        ]
    }

    private static func poolForecastSample(
        ts: Date,
        accounts: [PoolAccountSample]
    ) -> PoolHistorySample {
        PoolHistorySample(
            ts: ts,
            n: accounts.count,
            poolTotal: accounts.reduce(0) { $0 + $1.remaining },
            accounts: accounts,
            resetsAt: accounts.compactMap(\.resetsAt).min()
        )
    }

    private static func testLivePoolSample() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let earlyReset = now.addingTimeInterval(2 * 86_400)
        let lateReset = now.addingTimeInterval(3 * 86_400)
        let snapshots = [
            "first@example.com": DirectUsageSnapshot(
                fiveHour: UsageLimitWindowSnapshot(remainingPercent: 80, resetAt: nil),
                weekly: UsageLimitWindowSnapshot(remainingPercent: 70, resetAt: lateReset)
            ),
            "second@example.com": DirectUsageSnapshot(
                fiveHour: UsageLimitWindowSnapshot(remainingPercent: 60, resetAt: nil),
                weekly: UsageLimitWindowSnapshot(remainingPercent: 50, resetAt: earlyReset)
            )
        ]
        let sample = PoolHistorySample.makeLive(snapshots: snapshots, now: now)
        expect(sample?.n == 2, "a live fallback sample should include every available account")
        expect(sample?.poolTotal == 120, "a live fallback sample should sum weekly remaining capacity")
        expect(sample?.resetsAt == earlyReset, "a live fallback sample should use the earliest reset anchor")
    }

    private static func testCurrentPoolSampleFallsBackToAccountRows() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = utcDate(day: 18, month: 8, year: 2026, hour: 12, minute: 0, calendar: utc)
        let accounts = [
            CodexAccount(
                selector: "01",
                email: "first@example.com",
                plan: "plus",
                fiveHourUsage: "--",
                weeklyUsage: "70% (Fri 09:00)",
                fiveHourUsedPercent: nil,
                weeklyUsedPercent: 70,
                lastActivity: "--",
                isActive: true
            ),
            CodexAccount(
                selector: "02",
                email: "second@example.com",
                plan: "plus",
                fiveHourUsage: "--",
                weeklyUsage: "50% (Thu 09:00)",
                fiveHourUsedPercent: nil,
                weeklyUsedPercent: 50,
                lastActivity: "--",
                isActive: false
            )
        ]
        let sample = PoolHistorySample.makeCurrent(
            accounts: accounts,
            snapshots: [:],
            now: now,
            calendar: utc
        )
        expect(sample?.n == 2, "current pool display should use account-row percentages when live snapshots are absent")
        expect(sample?.poolTotal == 120, "account-row fallback should preserve the available pool total")
        expect(
            sample?.resetsAt == utcDate(day: 20, month: 8, year: 2026, hour: 9, minute: 0, calendar: utc),
            "account-row fallback should use the earliest upcoming weekly reset"
        )
    }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try? decoder.decode(PoolAccountSample.self, from: legacy)
        expect(decoded?.resetsAt == nil, "legacy account samples should decode without a reset date")
    }

    private static func testPoolHistorySampleResetsAtCoding() {
        let reset = Date(timeIntervalSince1970: 1_900_000_000)
        let sample = PoolHistorySample(ts: Date(timeIntervalSince1970: 1_800_000_000), n: 5, poolTotal: 220, accounts: [], resetsAt: reset)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(sample)) ?? Data()
        let text = String(data: data, encoding: .utf8) ?? ""
        expect(text.contains("resetsAt"), "an encoded sample should include resetsAt")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try? decoder.decode(PoolHistorySample.self, from: data)
        expect(decoded?.resetsAt == reset, "resetsAt should survive an encode/decode round trip")
        let legacy = Data(#"{"ts":"2026-08-15T19:40:56Z","n":5,"poolTotal":33,"accounts":[]}"#.utf8)
        let legacyDecoded = try? decoder.decode(PoolHistorySample.self, from: legacy)
        expect(legacyDecoded?.resetsAt == nil, "a legacy line without resetsAt should decode as nil")
    }

    private static func testResetChanceParsing() {
        let realFixture = #"{"mode":"model","probabilities":{"raw_24h":0.29446105287468405,"raw_48h":0.5022147940893007,"rounded_24h":30,"rounded_48h":50},"confidence":"medium","last_reset_at":"2026-08-13T01:01:37.000Z","cadence":{"recent_median_days":2.3}} "#.utf8
        if case .success(let forecast) = ResetChanceClient.parseResponse(data: Data(realFixture), statusCode: 200) {
            expect(forecast.rounded24h == 30, "real fixture should surface rounded 24h as 30")
            expect(forecast.rounded48h == 50, "real fixture should surface rounded 48h as 50")
        } else {
            expect(false, "a well-formed 200 response should parse as success")
        }

        let missing48Fixture = #"{"probabilities":{"rounded_24h":30}}"#.utf8
        if case .failure = ResetChanceClient.parseResponse(data: Data(missing48Fixture), statusCode: 200) {} else {
            expect(false, "a response without rounded_48h should be invalid")
        }

        let noProbabilitiesFixture = #"{"mode":"model","confidence":"low"}"#.utf8
        if case .failure = ResetChanceClient.parseResponse(data: Data(noProbabilitiesFixture), statusCode: 200) {} else {
            expect(false, "a response without a probabilities object should be invalid")
        }

        let garbage = Data("not json".utf8)
        if case .failure = ResetChanceClient.parseResponse(data: garbage, statusCode: 200) {} else {
            expect(false, "non-JSON 200 response should be invalid")
        }

        if case .failure = ResetChanceClient.parseResponse(data: Data(realFixture), statusCode: 500) {} else {
            expect(false, "a non-200 status should be a failure even with a valid body")
        }
    }

    private static func testResetChanceCommandFallback() {
        let fixture = #"{"probabilities":{"rounded_24h":30,"rounded_48h":50}}"#
        if case .success(let forecast) = ResetChanceClient.parseCommandResult(
            CommandResult(status: 0, output: fixture)
        ) {
            expect(forecast == ResetChanceForecast(rounded24h: 30, rounded48h: 50), "curl fallback should parse the same forecast payload")
        } else {
            expect(false, "a successful curl fallback should produce a forecast")
        }

        if case .failure = ResetChanceClient.parseCommandResult(CommandResult(status: 22, output: "HTTP 503")) {} else {
            expect(false, "a failed curl fallback must remain a fetch failure")
        }
    }

    // MARK: - Bundled marketplace fixtures

    private static func makePluginManifest(root: URL, pluginID: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("plugins/\(pluginID)/.codex-plugin"),
            withIntermediateDirectories: true
        )
    }

    private static func makeCompleteMarketplace(root: URL) throws {
        for id in BundledMarketplaceInspector.expectedPluginIDs() {
            try makePluginManifest(root: root, pluginID: id)
        }
    }

    private static func makeHomeSnapshot(home: URL) throws -> URL {
        let snapshot = home.appendingPathComponent(".codex/.tmp/bundled-marketplaces")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        return snapshot
    }

    private static func makeFakeApp(home: URL) throws -> String {
        let app = home.appendingPathComponent("ChatGPT.app")
        try FileManager.default.createDirectory(
            at: app.appendingPathComponent("Contents/Resources/plugins"),
            withIntermediateDirectories: true
        )
        return app.path
    }

    // MARK: - Bundled marketplace inspector

    private static func testBundledMarketplaceSnapshotOk() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .ok, "a snapshot with all expected plugin manifests should be ok")
    }

    private static func testBundledMarketplaceSnapshotIncomplete() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        try FileManager.default.removeItem(
            at: snapshots.appendingPathComponent("openai-bundled/plugins/browser")
        )
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .incomplete(missing: ["browser"]), "a snapshot missing the browser manifest should be incomplete")
    }

    private static func testBundledMarketplaceSnapshotAbsent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .absent, "a missing snapshot directory should be absent")
    }

    private static func testBundledMarketplaceSnapshotMissingManifest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        try FileManager.default.removeItem(
            at: snapshots.appendingPathComponent("openai-bundled/plugins/computer-use/.codex-plugin")
        )
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .incomplete(missing: ["computer-use"]), "a plugin without its manifest should be treated as missing")
    }

    private static func testBundledMarketplaceAppSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeFakeApp(home: root)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"),
            withIntermediateDirectories: true
        )
        let source = BundledMarketplaceInspector.appMarketplaceSource(appPath: app)
        expect(source != nil, "the app marketplace source should be found under Contents/Resources/plugins/openai-bundled")
        expect(source?.lastPathComponent == "openai-bundled", "the found source should be the openai-bundled marketplace")

        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        expect(BundledMarketplaceInspector.appMarketplaceSource(appPath: empty.path) == nil, "an app without the marketplace should return nil")
    }

    // MARK: - Bundled marketplace repairer

    private static func testBundledMarketplaceRepairNoop() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        let app = try makeFakeApp(home: root)
        try makeCompleteMarketplace(root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"))
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)
        expect(outcome == .ok, "a healthy snapshot should repair to ok without changes")
        let backups = try FileManager.default.contentsOfDirectory(atPath: snapshots.path)
        expect(!backups.contains { $0.hasPrefix("bundled-marketplaces.bak.") }, "a healthy snapshot should not create a backup")
    }

    private static func testBundledMarketplaceRepairFromApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let app = try makeFakeApp(home: root)
        try makeCompleteMarketplace(root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"))
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)
        expect(outcome == .repairedFromApp, "an incomplete snapshot with an app reference should be repaired from the app")
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .ok, "the snapshot should be complete after repairing from the app")
        let backups = try FileManager.default.contentsOfDirectory(atPath: snapshots.path)
        expect(backups.contains { $0.hasPrefix("bundled-marketplaces.bak.") }, "the stale snapshot should be moved to a backup before copying")
    }

    private static func testBundledMarketplaceRepairRestoresAbsentSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeHomeSnapshot(home: root)
        let app = try makeFakeApp(home: root)
        try makeCompleteMarketplace(
            root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled")
        )

        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)

        expect(outcome == .repairedFromApp, "an absent bundled snapshot should be restored from the app")
        expect(
            BundledMarketplaceInspector.snapshotState(homeDirectory: root.path) == .ok,
            "restoring an absent bundled snapshot should produce a complete marketplace"
        )
    }

    private static func testBundledMarketplaceRepairRefreshesOutdatedSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        let app = try makeFakeApp(home: root)
        let appMarketplace = URL(fileURLWithPath: app)
            .appendingPathComponent("Contents/Resources/plugins/openai-bundled")
        try makeCompleteMarketplace(root: appMarketplace)
        try makePluginManifest(root: appMarketplace, pluginID: "deep-research")

        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)

        expect(outcome == .repairedFromApp, "a snapshot missing a plugin shipped by the app should be refreshed")
        expect(
            FileManager.default.fileExists(
                atPath: snapshots.appendingPathComponent("openai-bundled/plugins/deep-research/.codex-plugin").path
            ),
            "repair should restore every plugin shipped by the app marketplace"
        )
    }

    private static func testBundledMarketplaceRepairNoApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(
            homeDirectory: root.path,
            appPath: root.appendingPathComponent("Missing.app").path
        )
        expect(outcome == .noAppFound, "repair without an app reference should report noAppFound")
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .incomplete(missing: ["browser", "computer-use"]), "repair without an app reference must not touch the snapshot")
    }

    private static func testBundledMarketplaceRepairStaleMove() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let app = try makeFakeApp(home: root) // app exists but has no marketplace inside
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)
        expect(outcome == .repairedByStaleMove, "an app without a marketplace should fall back to moving the stale snapshot aside")
        let entries = try FileManager.default.contentsOfDirectory(atPath: snapshots.path)
        expect(entries.contains { $0.hasPrefix("bundled-marketplaces.bak.") }, "the stale snapshot should be moved aside for regeneration")
        expect(!entries.contains("openai-bundled"), "the stale snapshot should no longer be in place")
    }

    private static func testBundledMarketplaceRepairRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let app = try makeFakeApp(home: root)
        // the app marketplace itself is incomplete (only chrome) — the copy will fail verification
        try makePluginManifest(root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"), pluginID: "chrome")
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(homeDirectory: root.path, appPath: app)
        if case .failed = outcome {} else {
            expect(false, "a copy that fails verification should report failed")
        }
        let state = BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
        expect(state == .incomplete(missing: ["browser", "computer-use"]), "the original snapshot should be restored after a failed repair")
        let backups = try FileManager.default.contentsOfDirectory(atPath: snapshots.path)
        expect(!backups.contains { $0.hasPrefix("bundled-marketplaces.bak.") }, "the backup should be restored, leaving no stale backup behind")
    }

    private static func testBundledMarketplaceRepairReinstall() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let app = try makeFakeApp(home: root)
        try makeCompleteMarketplace(root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"))
        let home = root.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let configText = """
        [plugins."chrome@openai-bundled"]
        enabled = true

        [plugins."browser@openai-bundled"]
        enabled = true
        """
        try configText.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        var calls: [[String]] = []
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(
            homeDirectory: root.path,
            appPath: app,
            codexExecutable: "/usr/bin/true",
            pluginRunner: { _, arguments, _ in
                calls.append(arguments)
                return CommandResult(status: 0, output: "ok")
            }
        )
        expect(outcome == .repairedFromApp, "reinstall success should still report repairedFromApp")
        let pluginCalls = calls.filter { $0.first == "plugin" }
        expect(pluginCalls.contains { $0.contains("chrome@openai-bundled") }, "enabled chrome plugin should be reinstalled")
        expect(pluginCalls.contains { $0.contains("browser@openai-bundled") }, "enabled browser plugin should be reinstalled")
        expect(!pluginCalls.contains { $0.contains("computer-use@openai-bundled") }, "a plugin absent from config should not be reinstalled")
    }

    private static func testBundledMarketplaceRepairReinstallsNewBundledPlugin() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makeCompleteMarketplace(root: snapshots.appendingPathComponent("openai-bundled"))
        let app = try makeFakeApp(home: root)
        let appMarketplace = URL(fileURLWithPath: app)
            .appendingPathComponent("Contents/Resources/plugins/openai-bundled")
        try makeCompleteMarketplace(root: appMarketplace)
        try makePluginManifest(root: appMarketplace, pluginID: "visualize")
        let home = root.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try """
        [plugins."visualize@openai-bundled"]
        enabled = true
        """.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        var calls: [[String]] = []

        _ = BundledMarketplaceRepairer.repairIfNeeded(
            homeDirectory: root.path,
            appPath: app,
            codexExecutable: "/usr/bin/true",
            pluginRunner: { _, arguments, _ in
                calls.append(arguments)
                return CommandResult(status: 0, output: "ok")
            }
        )

        expect(
            calls.contains(["plugin", "add", "visualize@openai-bundled"]),
            "an enabled plugin discovered in the app marketplace should be reinstalled"
        )
    }

    private static func testBundledMarketplaceRepairReinstallFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshots = try makeHomeSnapshot(home: root)
        try makePluginManifest(root: snapshots.appendingPathComponent("openai-bundled"), pluginID: "chrome")
        let app = try makeFakeApp(home: root)
        try makeCompleteMarketplace(root: URL(fileURLWithPath: app).appendingPathComponent("Contents/Resources/plugins/openai-bundled"))
        let home = root.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let configText = """
        [plugins."chrome@openai-bundled"]
        enabled = true
        """
        try configText.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(
            homeDirectory: root.path,
            appPath: app,
            codexExecutable: "/usr/bin/true",
            pluginRunner: { _, _, _ in CommandResult(status: 1, output: "boom") }
        )
        if case .failed = outcome {} else {
            expect(false, "a failed plugin reinstall should report failed")
        }
        expect(
            BundledMarketplaceInspector.snapshotState(homeDirectory: root.path)
                == .incomplete(missing: ["browser", "computer-use"]),
            "a failed bundled plugin reinstall should restore the previous snapshot"
        )
    }

    private static func testReferencePluginInventory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let remoteCache = root.appendingPathComponent(".codex/plugins/cache/openai-curated-remote")
        for id in ["superpowers", "cloudflare", "product-design"] {
            try FileManager.default.createDirectory(
                at: remoteCache.appendingPathComponent(id),
                withIntermediateDirectories: true
            )
        }

        let remoteIDs = ReferencePluginInventory.remotePluginIDs(homeDirectory: root.path)
        expect(
            remoteIDs == ["cloudflare", "product-design", "superpowers"],
            "remote reference inventory should contain sorted immediate cache directories"
        )

        let config = """
        [plugins."github@openai-curated"]
        enabled = true

        [plugins."superpowers@openai-curated"]
        enabled = false

        [plugins."browser@openai-bundled"]
        enabled = true

        [plugins."documents@openai-primary-runtime"]
        enabled = true
        """
        expect(
            ReferencePluginInventory.curatedPluginIDs(configText: config) == ["github"],
            "curated reference inventory should include only enabled openai-curated plugins"
        )
    }

    private static func testReferencePluginCaptureRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let remoteCache = home.appendingPathComponent(".codex/plugins/cache/openai-curated-remote")
        try FileManager.default.createDirectory(
            at: remoteCache.appendingPathComponent("product-design/0.1.52"),
            withIntermediateDirectories: true
        )
        try Data("payload".utf8).write(to: remoteCache.appendingPathComponent("product-design/0.1.52/SKILL.md"))
        try """
        [plugins."github@openai-curated"]
        enabled = true
        """.write(
            to: home.appendingPathComponent(".codex/config.toml"),
            atomically: true,
            encoding: .utf8
        )
        let store = root.appendingPathComponent("reference-plugins")

        let outcome = ReferencePluginStore.capture(homeDirectory: home.path, storeDirectory: store)
        expect(outcome == .captured(remoteCount: 1, curatedCount: 1), "capture should report saved plugin counts")
        guard let loaded = ReferencePluginStore.load(storeDirectory: store) else {
            expect(false, "a captured reference should load")
            return
        }
        expect(loaded.manifest.schemaVersion == 1, "captured reference should use schema version 1")
        expect(loaded.manifest.remotePluginIDs == ["product-design"], "captured manifest should list remote plugins")
        expect(loaded.manifest.curatedPluginIDs == ["github"], "captured manifest should list curated plugins")
        expect(
            FileManager.default.fileExists(
                atPath: loaded.remoteCacheURL.appendingPathComponent("product-design/0.1.52/SKILL.md").path
            ),
            "capture should preserve remote plugin files"
        )
    }

    private static func testReferencePluginCapturePreservesPreviousReference() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let validHome = root.appendingPathComponent("valid-home")
        try FileManager.default.createDirectory(
            at: validHome.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/vercel"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: validHome.appendingPathComponent(".codex"),
            withIntermediateDirectories: true
        )
        try "".write(
            to: validHome.appendingPathComponent(".codex/config.toml"),
            atomically: true,
            encoding: .utf8
        )
        let store = root.appendingPathComponent("reference-plugins")
        _ = ReferencePluginStore.capture(homeDirectory: validHome.path, storeDirectory: store)

        let outcome = ReferencePluginStore.capture(
            homeDirectory: root.appendingPathComponent("missing-home").path,
            storeDirectory: store
        )

        if case .failed = outcome {} else {
            expect(false, "capture without a remote cache should fail")
        }
        expect(
            ReferencePluginStore.load(storeDirectory: store)?.manifest.remotePluginIDs == ["vercel"],
            "failed capture should preserve the previous reference"
        )
    }

    private static func testReferencePluginLoadRejectsModifiedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["vercel"])
        let payload = reference.remoteCacheURL.appendingPathComponent("vercel/1.0.0/payload.txt")
        try Data("corrupt".utf8).write(to: payload)

        expect(
            ReferencePluginStore.load(storeDirectory: root.appendingPathComponent("reference-plugins")) == nil,
            "reference loading should reject modified plugin files even when IDs still match"
        )
    }

    private static func testReferencePluginMarketplacePreparation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare", "product-design"])

        let outcome = ReferencePluginMarketplace.prepare(reference: reference)
        guard case .prepared(let marketplaceURL, let pluginIDs) = outcome else {
            expect(false, "a valid reference should produce a local marketplace")
            return
        }

        expect(
            pluginIDs == ["cloudflare", "product-design"],
            "the local marketplace should contain every remote reference plugin"
        )
        expect(
            FileManager.default.fileExists(
                atPath: marketplaceURL.appendingPathComponent(".agents/plugins/marketplace.json").path
            ),
            "the local marketplace should contain a marketplace manifest"
        )
        for id in pluginIDs {
            expect(
                FileManager.default.fileExists(
                    atPath: marketplaceURL.appendingPathComponent("plugins/\(id)/.codex-plugin/plugin.json").path
                ),
                "the local marketplace should flatten the saved version for \(id)"
            )
        }
    }

    private static func testReferencePluginMarketplaceDetectsChangedInstalledPackage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare", "product-design"])
        guard case .prepared(let marketplaceURL, _) = ReferencePluginMarketplace.prepare(reference: reference) else {
            expect(false, "a valid reference should prepare before installed package comparison")
            return
        }
        let installedCache = root.appendingPathComponent("installed-cache")
        for id in ["cloudflare", "product-design"] {
            let destination = installedCache.appendingPathComponent("\(id)/1.0.0")
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: marketplaceURL.appendingPathComponent("plugins/\(id)"),
                to: destination
            )
        }
        try Data("stale".utf8).write(
            to: installedCache.appendingPathComponent("cloudflare/1.0.0/payload.txt")
        )

        expect(
            ReferencePluginMarketplace.staleInstalledPluginIDs(
                marketplaceURL: marketplaceURL,
                installedCacheURL: installedCache,
                pluginIDs: ["cloudflare", "product-design"]
            ) == ["cloudflare"],
            "content comparison should mark only the changed installed package as stale"
        )
    }

    private static func testReferencePluginMarketplaceRejectsMissingDigests() {
        expect(
            !ReferencePluginMarketplace.packageDigestsMatch(installed: nil, reference: nil),
            "two failed package fingerprints must not be treated as matching content"
        )
        expect(
            ReferencePluginMarketplace.packageDigestsMatch(installed: "same", reference: "same"),
            "two non-nil equal package fingerprints should match"
        )
    }

    private static func testReferencePluginCaptureReportsRollbackFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstHome = root.appendingPathComponent("first-home")
        let secondHome = root.appendingPathComponent("second-home")
        for (home, plugin) in [(firstHome, "vercel"), (secondHome, "cloudflare")] {
            try FileManager.default.createDirectory(
                at: home.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/\(plugin)"),
                withIntermediateDirectories: true
            )
            try "".write(
                to: home.appendingPathComponent(".codex/config.toml"),
                atomically: true,
                encoding: .utf8
            )
        }
        let store = root.appendingPathComponent("reference-plugins")
        _ = ReferencePluginStore.capture(homeDirectory: firstHome.path, storeDirectory: store)

        let outcome = ReferencePluginStore.capture(
            homeDirectory: secondHome.path,
            storeDirectory: store,
            fileManager: FailingSwapAndRestoreFileManager()
        )

        if case .failed(let reason) = outcome {
            expect(reason.contains("rollback failed"), "capture should report a failed reference rollback")
        } else {
            expect(false, "capture with a failed swap and restore should fail")
        }
        let parentEntries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        expect(
            parentEntries.contains(where: { $0.hasPrefix(".reference-plugins.backup.") }),
            "capture should preserve an unrestored reference backup"
        )
    }

    private static func testReferencePluginCaptureRequiresReadableConfig() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/vercel"),
            withIntermediateDirectories: true
        )

        let outcome = ReferencePluginStore.capture(
            homeDirectory: home.path,
            storeDirectory: root.appendingPathComponent("reference-plugins")
        )

        if case .failed = outcome {} else {
            expect(false, "capture should fail when config.toml cannot be read")
        }
    }

    private static func makeReferencePluginFixture(root: URL, remoteIDs: [String]) throws -> ReferencePluginStore.LoadedReference {
        let canonicalHome = root.appendingPathComponent("canonical-home")
        for id in remoteIDs {
            let version = canonicalHome.appendingPathComponent(
                ".codex/plugins/cache/openai-curated-remote/\(id)/1.0.0"
            )
            try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true)
            try Data(id.utf8).write(to: version.appendingPathComponent("payload.txt"))
            try FileManager.default.createDirectory(
                at: version.appendingPathComponent(".codex-plugin"),
                withIntermediateDirectories: true
            )
            try Data("{\"name\":\"\(id)\",\"version\":\"1.0.0\"}".utf8).write(
                to: version.appendingPathComponent(".codex-plugin/plugin.json")
            )
        }
        try FileManager.default.createDirectory(
            at: canonicalHome.appendingPathComponent(".codex"),
            withIntermediateDirectories: true
        )
        try "".write(
            to: canonicalHome.appendingPathComponent(".codex/config.toml"),
            atomically: true,
            encoding: .utf8
        )
        let store = root.appendingPathComponent("reference-plugins")
        _ = ReferencePluginStore.capture(homeDirectory: canonicalHome.path, storeDirectory: store)
        return ReferencePluginStore.load(storeDirectory: store)!
    }

    private static func testReferencePluginReconcileExactMatch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(
            root: root,
            remoteIDs: ["cloudflare", "product-design", "vercel"]
        )
        let targetHome = root.appendingPathComponent("target-home")
        for id in ["canva", "posthog", "vercel"] {
            try FileManager.default.createDirectory(
                at: targetHome.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/\(id)"),
                withIntermediateDirectories: true
            )
        }

        let outcome = ReferencePluginReconciler.reconcile(
            homeDirectory: targetHome.path,
            reference: reference
        )

        expect(
            outcome == .applied(
                added: ["cloudflare", "product-design"],
                removed: ["canva", "posthog"]
            ),
            "reconcile should report exact additions and removals"
        )
        expect(
            ReferencePluginInventory.remotePluginIDs(homeDirectory: targetHome.path) == ["cloudflare", "product-design", "vercel"],
            "reconcile should make the active remote set exactly match the reference"
        )
    }

    private static func testReferencePluginReconcileRestoresChangedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["vercel"])
        let targetHome = root.appendingPathComponent("target-home")
        let targetPayload = targetHome.appendingPathComponent(
            ".codex/plugins/cache/openai-curated-remote/vercel/1.0.0/payload.txt"
        )
        try FileManager.default.createDirectory(
            at: targetPayload.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("wrong-version".utf8).write(to: targetPayload)

        let outcome = ReferencePluginReconciler.reconcile(homeDirectory: targetHome.path, reference: reference)
        let restoredPayload = try String(contentsOf: targetPayload, encoding: .utf8)

        expect(outcome == .applied(added: [], removed: []), "changed reference files should trigger reconciliation")
        expect(
            restoredPayload == "vercel",
            "reconciliation should restore the exact saved plugin files"
        )
    }

    private static func testReferencePluginReconcileIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare", "vercel"])
        let targetHome = root.appendingPathComponent("target-home")
        try FileManager.default.createDirectory(
            at: targetHome.appendingPathComponent(".codex/plugins/cache/openai-curated-remote"),
            withIntermediateDirectories: true
        )

        _ = ReferencePluginReconciler.reconcile(homeDirectory: targetHome.path, reference: reference)
        let second = ReferencePluginReconciler.reconcile(homeDirectory: targetHome.path, reference: reference)

        expect(second == .alreadyMatched, "repeated reconciliation should be a no-op")
    }

    private static func testReferencePluginReconcileWithoutReference() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/canva"),
            withIntermediateDirectories: true
        )

        let outcome = ReferencePluginReconciler.reconcile(homeDirectory: root.path, reference: nil)

        expect(outcome == .noReference, "missing reference should be reported")
        expect(
            ReferencePluginInventory.remotePluginIDs(homeDirectory: root.path) == ["canva"],
            "missing reference should leave the active cache unchanged"
        )
    }

    private static func testReferencePluginReconcileRollsBackFailedSwap() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["vercel"])
        let targetHome = root.appendingPathComponent("target-home")
        try FileManager.default.createDirectory(
            at: targetHome.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/canva"),
            withIntermediateDirectories: true
        )

        let outcome = ReferencePluginReconciler.reconcile(
            homeDirectory: targetHome.path,
            reference: reference,
            fileManager: FailingSecondMoveFileManager()
        )

        if case .failed = outcome {} else {
            expect(false, "a staged swap failure should be reported")
        }
        expect(
            ReferencePluginInventory.remotePluginIDs(homeDirectory: targetHome.path) == ["canva"],
            "a staged swap failure should restore the target account cache"
        )
    }

    private static func testReferencePluginReconcileReportsRollbackFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["vercel"])
        let targetHome = root.appendingPathComponent("target-home")
        try FileManager.default.createDirectory(
            at: targetHome.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/canva"),
            withIntermediateDirectories: true
        )

        let outcome = ReferencePluginReconciler.reconcile(
            homeDirectory: targetHome.path,
            reference: reference,
            fileManager: FailingSwapAndRestoreFileManager()
        )

        if case .failed(let reason) = outcome {
            expect(reason.contains("rollback failed"), "a failed restore should be reported explicitly")
        } else {
            expect(false, "a failed restore should fail reconciliation")
        }
        let cacheParent = targetHome.appendingPathComponent(".codex/plugins/cache")
        let entries = try FileManager.default.contentsOfDirectory(atPath: cacheParent.path)
        expect(
            entries.contains(where: { $0.hasPrefix("openai-curated-remote.backup.") }),
            "a failed restore should preserve the backup for recovery"
        )
    }

    private static func testCuratedPluginPlan() {
        expect(
            CuratedPluginPlan.commands(
                referenceIDs: ["github"],
                installedIDs: ["canva", "github", "browser@openai-bundled"]
            ) == [["plugin", "remove", "canva@openai-curated"]],
            "curated plan should remove non-reference curated plugins and ignore system selectors"
        )
        expect(
            CuratedPluginPlan.commands(
                referenceIDs: ["github", "vercel"],
                installedIDs: ["github"]
            ) == [["plugin", "add", "vercel@openai-curated"]],
            "curated plan should add missing reference plugins"
        )
    }

    private static func testReferenceMarketplacePluginPlan() {
        let config = """
        [plugins."cloudflare@account-switcher-reference"]
        enabled = true

        [plugins."obsolete@account-switcher-reference"]
        enabled = true
        """
        expect(
            ReferencePluginInventory.pluginIDs(
                configText: config,
                marketplace: ReferencePluginMarketplace.name
            ) == ["cloudflare", "obsolete"],
            "plugin inventory should read an explicit marketplace"
        )
        expect(
            PluginInstallPlan.commands(
                referenceIDs: ["cloudflare", "product-design"],
                installedIDs: ["cloudflare", "obsolete"],
                marketplace: ReferencePluginMarketplace.name
            ) == [
                ["plugin", "remove", "obsolete@account-switcher-reference"],
                ["plugin", "add", "product-design@account-switcher-reference"],
            ],
            "the local marketplace plan should remove stale plugins before adding missing references"
        )
    }

    private static func testReferenceMarketplacePluginPlanReinstallsChangedPackage() {
        expect(
            PluginInstallPlan.commands(
                referenceIDs: ["cloudflare", "product-design"],
                installedIDs: ["cloudflare", "product-design"],
                staleIDs: ["product-design"],
                marketplace: ReferencePluginMarketplace.name
            ) == [
                ["plugin", "remove", "product-design@account-switcher-reference"],
                ["plugin", "add", "product-design@account-switcher-reference"],
            ],
            "a changed saved package should be removed and reinstalled even when its ID is unchanged"
        )
    }

    private static func testReferenceMarketplacePluginReconcile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare", "product-design"])
        let home = root.appendingPathComponent("target-home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: configURL, atomically: true, encoding: .utf8)
        var commands: [[String]] = []

        let outcome = ReferenceMarketplacePluginReconciler.reconcile(
            homeDirectory: home.path,
            reference: reference
        ) { arguments in
            commands.append(arguments)
            var config = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            if arguments.prefix(3) == ["plugin", "marketplace", "add"] {
                config += "\n[marketplaces.account-switcher-reference]\nsource_type = \"local\"\n"
            } else if arguments.prefix(2) == ["plugin", "add"], let selector = arguments.last {
                config += "\n[plugins.\"\(selector)\"]\nenabled = true\n"
                let pluginID = selector.split(separator: "@", maxSplits: 1).first.map(String.init) ?? selector
                let source = reference.remoteCacheURL
                    .deletingLastPathComponent()
                    .appendingPathComponent("local-marketplace/plugins/\(pluginID)")
                let destination = home.appendingPathComponent(
                    ".codex/plugins/cache/account-switcher-reference/\(pluginID)/1.0.0"
                )
                try? FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? FileManager.default.copyItem(at: source, to: destination)
            }
            try? config.write(to: configURL, atomically: true, encoding: .utf8)
            return CommandResult(status: 0, output: "ok")
        }

        expect(outcome == .applied(changes: 3), "reference marketplace registration and installs should be reported")
        expect(
            commands.dropFirst() == [
                ["plugin", "add", "cloudflare@account-switcher-reference"],
                ["plugin", "add", "product-design@account-switcher-reference"],
            ],
            "every saved remote plugin should be installed from the local reference marketplace"
        )
    }

    private static func testReferenceMarketplacePluginReconcileReinstallsChangedPackage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare"])
        let home = root.appendingPathComponent("target-home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        [marketplaces.account-switcher-reference]
        source_type = "local"

        [plugins."cloudflare@account-switcher-reference"]
        enabled = true
        """.write(to: configURL, atomically: true, encoding: .utf8)
        let installedCache = home.appendingPathComponent(".codex/plugins/cache/account-switcher-reference")
        let installedPackage = installedCache.appendingPathComponent("cloudflare/0.9.0")
        try FileManager.default.createDirectory(
            at: installedPackage.appendingPathComponent(".codex-plugin"),
            withIntermediateDirectories: true
        )
        try Data("{\"name\":\"cloudflare\",\"version\":\"0.9.0\"}".utf8).write(
            to: installedPackage.appendingPathComponent(".codex-plugin/plugin.json")
        )
        try Data("stale".utf8).write(to: installedPackage.appendingPathComponent("payload.txt"))
        var commands: [[String]] = []

        let outcome = ReferenceMarketplacePluginReconciler.reconcile(
            homeDirectory: home.path,
            reference: reference
        ) { arguments in
            commands.append(arguments)
            let cacheRoot = home.appendingPathComponent(".codex/plugins/cache/account-switcher-reference/cloudflare")
            if arguments.prefix(2) == ["plugin", "remove"] {
                try? FileManager.default.removeItem(at: cacheRoot)
            } else if arguments.prefix(2) == ["plugin", "add"] {
                let source = reference.remoteCacheURL
                    .deletingLastPathComponent()
                    .appendingPathComponent("local-marketplace/plugins/cloudflare")
                let destination = cacheRoot.appendingPathComponent("1.0.0")
                try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
                try? FileManager.default.copyItem(at: source, to: destination)
            }
            return CommandResult(status: 0, output: "ok")
        }

        expect(outcome == .applied(changes: 2), "a changed installed package should be reinstalled")
        expect(
            commands == [
                ["plugin", "remove", "cloudflare@account-switcher-reference"],
                ["plugin", "add", "cloudflare@account-switcher-reference"],
            ],
            "content drift should schedule remove then add for the same plugin ID"
        )
    }

    private static func testReferenceMarketplacePluginReconcileReportsCLIError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reference = try makeReferencePluginFixture(root: root, remoteIDs: ["cloudflare"])
        let home = root.appendingPathComponent("target-home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        [marketplaces.account-switcher-reference]
        source_type = "local"
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let outcome = ReferenceMarketplacePluginReconciler.reconcile(
            homeDirectory: home.path,
            reference: reference
        ) { arguments in
            CommandResult(status: 1, output: "forced failure: \(arguments.joined(separator: " "))")
        }

        if case .failed(let reason) = outcome {
            expect(
                reason.contains("plugin add cloudflare@account-switcher-reference failed"),
                "a local marketplace CLI failure should identify the failed command"
            )
        } else {
            expect(false, "a local marketplace CLI failure should fail reconciliation")
        }
    }

    private static func testCuratedPluginReconcileRollsBackPartialFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let originalConfig = "[plugins.\"canva@openai-curated\"]\nenabled = true\n"
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try originalConfig.write(to: configURL, atomically: true, encoding: .utf8)

        var commandCount = 0
        let outcome = CuratedPluginReconciler.reconcile(
            homeDirectory: home.path,
            referenceIDs: ["github"]
        ) { arguments in
            commandCount += 1
            if commandCount == 1 {
                try? "".write(to: configURL, atomically: true, encoding: .utf8)
                return CommandResult(status: 0, output: "removed")
            }
            return CommandResult(status: 1, output: "forced add failure")
        }

        if case .failed = outcome {} else {
            expect(false, "partial curated reconciliation should fail")
        }
        let restoredConfig = try String(contentsOf: configURL, encoding: .utf8)
        expect(
            restoredConfig == originalConfig,
            "partial curated reconciliation should restore the original config"
        )
    }

    private static func testPluginSyncStabilityTracker() {
        var tracker = PluginSyncStabilityTracker()
        expect(
            !tracker.observe(inventory: ["canva"], fingerprint: "digest-a"),
            "the first sync observation should not be stable"
        )
        expect(
            tracker.observe(inventory: ["canva"], fingerprint: "digest-a"),
            "two identical sync observations should be stable"
        )
        expect(
            !tracker.observe(inventory: ["canva"], fingerprint: "digest-b"),
            "a file content change should reset sync stability"
        )
        expect(
            !tracker.observe(inventory: ["canva", "posthog"], fingerprint: "digest-b"),
            "an inventory change should reset sync stability"
        )
        var cautiousTracker = PluginSyncStabilityTracker(requiredStableObservations: 4)
        expect(!cautiousTracker.observe(inventory: ["canva"], fingerprint: "digest-a"), "first cautious observation should wait")
        expect(!cautiousTracker.observe(inventory: ["canva"], fingerprint: "digest-a"), "second cautious observation should wait")
        expect(!cautiousTracker.observe(inventory: ["canva"], fingerprint: "digest-a"), "third cautious observation should wait")
        expect(cautiousTracker.observe(inventory: ["canva"], fingerprint: "digest-a"), "fourth cautious observation should stabilize")
    }

    private static func testReferencePluginTransactionRollsBackBothLayers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let remoteCache = home.appendingPathComponent(".codex/plugins/cache/openai-curated-remote")
        let remotePayload = remoteCache.appendingPathComponent("canva/1.0.0/payload.txt")
        let referenceCache = home.appendingPathComponent(".codex/plugins/cache/account-switcher-reference")
        let referencePayload = referenceCache.appendingPathComponent("cloudflare/1.0.0/payload.txt")
        let originalConfig = "[plugins.\"canva@openai-curated\"]\nenabled = true\n"
        try FileManager.default.createDirectory(at: remotePayload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try originalConfig.write(to: configURL, atomically: true, encoding: .utf8)
        try Data("canva".utf8).write(to: remotePayload)
        try FileManager.default.createDirectory(at: referencePayload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("cloudflare".utf8).write(to: referencePayload)

        let outcome = ReferencePluginTransaction.perform(homeDirectory: home.path) {
            try? FileManager.default.removeItem(at: remoteCache)
            try? FileManager.default.removeItem(at: referenceCache)
            try? "".write(to: configURL, atomically: true, encoding: .utf8)
            return "forced curated failure"
        }

        if case .failed(let reason) = outcome {
            expect(reason.contains("restored"), "plugin transaction should report successful rollback")
        } else {
            expect(false, "plugin transaction should fail when its operation fails")
        }
        let restoredConfig = try String(contentsOf: configURL, encoding: .utf8)
        let restoredPayload = try String(contentsOf: remotePayload, encoding: .utf8)
        let restoredReferencePayload = try String(contentsOf: referencePayload, encoding: .utf8)
        expect(
            restoredConfig == originalConfig,
            "plugin transaction should restore curated config"
        )
        expect(
            restoredPayload == "canva",
            "plugin transaction should restore remote cache files"
        )
        expect(
            restoredReferencePayload == "cloudflare",
            "plugin transaction should restore local reference cache files"
        )
    }

    private static func testReferencePluginTransactionRollsBackFailedFinalization() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let originalConfig = "[plugins.\"github@openai-curated\"]\nenabled = true\n"
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try originalConfig.write(to: configURL, atomically: true, encoding: .utf8)

        let outcome = ReferencePluginTransaction.perform(
            homeDirectory: home.path,
            finalize: {
                .rollback(reason: "final plugin verification failed")
            },
            operation: {
                try? "changed".write(to: configURL, atomically: true, encoding: .utf8)
                return nil
            }
        )

        if case .failed(let reason) = outcome {
            expect(reason.contains("restored"), "failed finalization should report a verified rollback")
        } else {
            expect(false, "failed finalization should fail the transaction")
        }
        let restoredConfig = try String(contentsOf: configURL, encoding: .utf8)
        expect(
            restoredConfig == originalConfig,
            "failed finalization should restore the pre-reconciliation config"
        )
    }

    private static func testReferencePluginTransactionPreservesBackupWhenRollbackIsUnsafe() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "original".write(to: configURL, atomically: true, encoding: .utf8)

        let outcome = ReferencePluginTransaction.perform(
            homeDirectory: home.path,
            finalize: {
                .preserveBackup(reason: "Codex could not be stopped")
            },
            operation: {
                try? "changed".write(to: configURL, atomically: true, encoding: .utf8)
                return nil
            }
        )

        if case .failed(let reason) = outcome {
            expect(reason.contains("backup kept"), "unsafe rollback should report the retained backup")
        } else {
            expect(false, "unsafe rollback should fail without touching live state")
        }
        let currentConfig = try String(contentsOf: configURL, encoding: .utf8)
        expect(
            currentConfig == "changed",
            "unsafe rollback should not overwrite config while Codex may still be running"
        )
        let codexDirectory = home.appendingPathComponent(".codex")
        let backups = try FileManager.default.contentsOfDirectory(atPath: codexDirectory.path)
        expect(
            backups.contains(where: { $0.hasPrefix(".reference-plugin-transaction.") }),
            "unsafe rollback should retain the transaction backup"
        )
        let backupName = backups.first(where: { $0.hasPrefix(".reference-plugin-transaction.") })!
        let savedConfig = try String(
            contentsOf: codexDirectory.appendingPathComponent("\(backupName)/config.toml"),
            encoding: .utf8
        )
        expect(savedConfig == "original", "retained transaction backup should include the original config")
    }

    private static func testProcessLookupPolicy() {
        expect(ProcessLookupPolicy.parse(status: 1, output: "") == .noMatches, "pgrep status 1 should mean no matches")
        expect(
            ProcessLookupPolicy.parse(status: 0, output: "12\n34\n") == .matches(["12", "34"]),
            "successful pgrep output should return process IDs"
        )
        if case .failed = ProcessLookupPolicy.parse(status: 2, output: "usage error") {} else {
            expect(false, "pgrep errors should not be treated as no matches")
        }
    }

}
