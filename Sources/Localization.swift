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

enum LocalizedTextKey: CaseIterable {
    case warmupButton
    case warmupTooltip
    case warmupWaiting
    case warmupRunning
    case warmupRefreshing
    case warmupCompleted
    case warmupQuota
    case warmupLogin
    case warmupNetwork
    case warmupServer
    case warmupRate
    case warmupAccess
    case warmupFailed
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
    case deleteAccountButton
    case fiveHourShort
    case weeklyShort
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
    case verdictDeficitSummary
    case verdictAfterResetSummary
    case verdictPreliminaryPace
    case verdictEstablishedPace
    case verdictReserveSummary
    case verdictCapacityWithResets
    case verdictAccountComparison
    case verdictMoreResets
    case verdictDaysShort
    case verdictHoursShort
    case nowEvent
    case resetEvent
    case exhaustionEvent
    case enoughAccessibility
    case notEnoughAccessibility
    case collectingAccessibility
    // SwiftUI settings surface
    case settingsTitle
    case settingsSubtitle
    case doneButton
    case backButton
    case generalSection
    case automationSection
    case advancedSection
    case followCodexToggle
    case usageReminderToggle
    case creditExpiryToggle
    case autoSwitchRow
    case advancedRow
    case advancedTitle
    case advancedSubtitle
    case refreshSection
    case reminderThresholdLabel
    case creditExpiryLeadDaysLabel
    case activeRefreshLabel
    case idleRefreshLabel
    case maintenanceSection
    case checkUpdatesButton
    case pluginsButton
    case diagnosticsButton
    case percentSuffix
    case daysSuffix
    case invalidReminderThreshold
    case invalidCreditExpiryLeadDays
    case settingsBackAccessibility
    case settingsDoneAccessibility
    case settingsNavigationHint
    case settingsToggleHint
    case settingsNumericHint
    case usageResetsTitle
    case updatedPrefix
    case useResetButton
    case redeemResetTooltip
    case displaySection
    case menuBarLabel
    case weeklyOption
    case fiveHourOption
    case followAppsTitle
    case followAppsDetail
    case usageReminderTitle
    case usageReminderDetail
    case creditExpiryTitle
    case creditExpiryDetail
    case autoSwitchTitle
    case healthSection
    case settingsAddAccount
    case settingsReminder
    case settingsRefreshRate
    case settingsCheckUpdate
    case settingsSavePlugins
    case accountsButton
    case resetVaultTitle
    case checkingAccounts
    case unavailable
    case checkingResetCredits
    case noAvailableResetCredits
    case toggleAccount
    case addAccountMenu
    case accountLabelsMenu
    case menuBarDisplayMenu
    case removeAccountMenu
    case forceRefreshMenu
    case checkUpdatesMenu
    case cleanBackupsMenu
    case quitAppMenu
    case activeAccountPrefix
    case noActiveAccount
    case activeButton
    case switchButtonShort
    case labelButton
    case deleteButtonShort
}

enum LocalizedText {
    static func activeAccount(_ account: String, language: AppLanguage) -> String {
        "\(value(.activeAccountPrefix, language: language)) \(account)"
    }

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
            case .warmupButton: return "Старт лимитов"
            case .warmupTooltip: return "Один запрос на аккаунт • GPT 5.6 Luna low"
            case .warmupWaiting: return "В очереди"
            case .warmupRunning: return "Отправка…"
            case .warmupRefreshing: return "Обновление токена…"
            case .warmupCompleted: return "Запрос выполнен"
            case .warmupFailed: return "Ошибка запроса"
            case .warmupQuota: return "Лимит исчерпан"
            case .warmupLogin: return "Войдите снова"
            case .warmupNetwork: return "Нет связи / таймаут"
            case .warmupServer: return "Ошибка сервера"
            case .warmupRate: return "Слишком часто"
            case .warmupAccess: return "Нет доступа"


            case .quitButton: return "Выйти"
            case .quitConfirmButton: return "Выйти?"
            case .quitTooltip: return "Выйти из Codex Account Switcher"
            case .switchPrompt: return "Переключиться на этот аккаунт?"
            case .switchRelaunchDetail: return "Codex будет перезапущен"
            case .cancelButton: return "Отмена"
            case .switchButton: return "Переключить"
            case .deleteAccountButton: return "Удалить"
            case .fiveHourShort: return "5 Ч"
            case .weeklyShort: return "НЕД"
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
            case .verdictDeficitSummary: return "Дефицит"
            case .verdictAfterResetSummary: return "Запас после сброса"
            case .verdictPreliminaryPace: return "Предварительный прогноз · темп за"
            case .verdictEstablishedPace: return "Средний темп за 7 дней"
            case .verdictReserveSummary: return "Запас"
            case .verdictCapacityWithResets: return "Запас с учётом сбросов"
            case .verdictAccountComparison: return "аккаунтов / нужно"
            case .verdictMoreResets: return "ещё"
            case .verdictDaysShort: return "д"
            case .verdictHoursShort: return "ч"
            case .nowEvent: return "Сейчас"
            case .resetEvent: return "Сброс"
            case .exhaustionEvent: return "Запас закончится"
            case .enoughAccessibility: return "Запаса хватит до сброса"
            case .notEnoughAccessibility: return "Запас закончится до сброса"
            case .collectingAccessibility: return "Собираем историю для прогноза"
            case .settingsTitle: return "Настройки"
            case .settingsSubtitle: return "Управляйте автоматизацией и обновлением данных"
            case .doneButton: return "Готово"
            case .backButton: return "Назад"
            case .generalSection: return "Основные"
            case .automationSection: return "Автоматизация"
            case .advancedSection: return "Дополнительно"
            case .followCodexToggle: return "Следовать за Codex / ChatGPT"
            case .usageReminderToggle: return "Напоминание об остатке"
            case .creditExpiryToggle: return "Истечение сбросов"
            case .autoSwitchRow: return "Автопереключение"
            case .advancedRow: return "Расширенные настройки"
            case .advancedTitle: return "Расширенные настройки"
            case .advancedSubtitle: return "Порог напоминания, обновление и обслуживание"
            case .refreshSection: return "Обновление данных"
            case .reminderThresholdLabel: return "Порог напоминания"
            case .creditExpiryLeadDaysLabel: return "Предупредить об истечении за"
            case .activeRefreshLabel: return "Обновление при активности"
            case .idleRefreshLabel: return "Обновление в простое"
            case .maintenanceSection: return "Обслуживание"
            case .checkUpdatesButton: return "Проверить обновления"
            case .pluginsButton: return "Сохранить эталонные плагины"
            case .diagnosticsButton: return "Диагностика"
            case .percentSuffix: return "%"
            case .daysSuffix: return "дн."
            case .invalidReminderThreshold: return "Введите число от 1 до 99"
            case .invalidCreditExpiryLeadDays: return "Введите число от 1 до 30"
            case .settingsBackAccessibility: return "Назад к настройкам"
            case .settingsDoneAccessibility: return "Закрыть настройки"
            case .settingsNavigationHint: return "Открывает подраздел настроек"
            case .settingsToggleHint: return "Переключатель"
            case .settingsNumericHint: return "Введите значение и нажмите Return"
            case .usageResetsTitle: return "Сбросы использования"
            case .updatedPrefix: return "Обновлено"
            case .useResetButton: return "Использовать"
            case .redeemResetTooltip: return "Использовать этот кредит после подтверждения"
            case .displaySection: return "Отображение"
            case .menuBarLabel: return "Строка меню"
            case .weeklyOption: return "Неделя"
            case .fiveHourOption: return "5 ч"
            case .followAppsTitle: return "Следовать за Codex / ChatGPT"
            case .followAppsDetail: return "Показывать только пока открыто одно из приложений"
            case .usageReminderTitle: return "Напоминание об использовании"
            case .usageReminderDetail: return "Показывать при достижении порога"
            case .creditExpiryTitle: return "Срок действия кредитов"
            case .creditExpiryDetail: return "Уведомлять за 3 дня до истечения кредитов сброса"
            case .autoSwitchTitle: return "Автопереключение"
            case .healthSection: return "Состояние"
            case .settingsAddAccount: return "Добавить аккаунт"
            case .settingsReminder: return "Напоминание"
            case .settingsRefreshRate: return "Частота обновления"
            case .settingsCheckUpdate: return "Проверить обновления"
            case .settingsSavePlugins: return "Сохранить плагины"
            case .accountsButton: return "Аккаунты"
            case .resetVaultTitle: return "ХРАНИЛИЩЕ СБРОСОВ"
            case .checkingAccounts: return "Проверяем сохранённые аккаунты"
            case .unavailable: return "Недоступно"
            case .checkingResetCredits: return "Проверяем кредиты сброса…"
            case .noAvailableResetCredits: return "Нет доступных кредитов сброса"
            case .toggleAccount: return "Переключить аккаунт"
            case .addAccountMenu: return "Добавить аккаунт…"
            case .accountLabelsMenu: return "Подписи аккаунтов"
            case .menuBarDisplayMenu: return "Отображение в строке меню"
            case .removeAccountMenu: return "Удалить аккаунт"
            case .forceRefreshMenu: return "Принудительно обновить"
            case .checkUpdatesMenu: return "Проверить обновления"
            case .cleanBackupsMenu: return "Очистить резервные копии"
            case .quitAppMenu: return "Выйти из Account Switcher"
            case .activeAccountPrefix: return "Активный аккаунт"
            case .noActiveAccount: return "Нет активного аккаунта"
            case .activeButton: return "Активен"
            case .switchButtonShort: return "Сменить"
            case .labelButton: return "Имя"
            case .deleteButtonShort: return "Удал."
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
            case .warmupButton: return "Start limits"
            case .warmupTooltip: return "One request per account • GPT 5.6 Luna low"
            case .warmupWaiting: return "Waiting"
            case .warmupRunning: return "Sending…"
            case .warmupRefreshing: return "Refreshing token…"
            case .warmupCompleted: return "Request completed"
            case .warmupFailed: return "Request failed"
            case .warmupQuota: return "Quota exhausted"
            case .warmupLogin: return "Sign in again"
            case .warmupNetwork: return "Connection / timeout"
            case .warmupServer: return "Server error"
            case .warmupRate: return "Too many requests"
            case .warmupAccess: return "Access denied"


            case .quitButton: return "Quit"
            case .quitConfirmButton: return "Quit?"
            case .quitTooltip: return "Quit Codex Account Switcher"
            case .switchPrompt: return "Switch to this account?"
            case .switchRelaunchDetail: return "Codex will relaunch"
            case .cancelButton: return "Cancel"
            case .switchButton: return "Switch"
            case .deleteAccountButton: return "Delete"
            case .fiveHourShort: return "5H"
            case .weeklyShort: return "WK"
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
            case .verdictDeficitSummary: return "Deficit"
            case .verdictAfterResetSummary: return "After reset"
            case .verdictPreliminaryPace: return "Preliminary forecast · pace over"
            case .verdictEstablishedPace: return "Average pace over 7 days"
            case .verdictReserveSummary: return "Reserve"
            case .verdictCapacityWithResets: return "Capacity with resets"
            case .verdictAccountComparison: return "accounts / needed"
            case .verdictMoreResets: return "more"
            case .verdictDaysShort: return "d"
            case .verdictHoursShort: return "h"
            case .nowEvent: return "Now"
            case .resetEvent: return "Reset"
            case .exhaustionEvent: return "Capacity ends"
            case .enoughAccessibility: return "Capacity lasts until reset"
            case .notEnoughAccessibility: return "Capacity runs out before reset"
            case .collectingAccessibility: return "Collecting history for a forecast"
            case .settingsTitle: return "Settings"
            case .settingsSubtitle: return "Control automation and data refresh"
            case .doneButton: return "Done"
            case .backButton: return "Back"
            case .generalSection: return "General"
            case .automationSection: return "Automation"
            case .advancedSection: return "Advanced"
            case .followCodexToggle: return "Follow Codex / ChatGPT"
            case .usageReminderToggle: return "Usage reminder"
            case .creditExpiryToggle: return "Reset-credit expiry"
            case .autoSwitchRow: return "Auto switch"
            case .advancedRow: return "Advanced settings"
            case .advancedTitle: return "Advanced settings"
            case .advancedSubtitle: return "Reminder threshold, refresh, and maintenance"
            case .refreshSection: return "Data refresh"
            case .reminderThresholdLabel: return "Reminder threshold"
            case .creditExpiryLeadDaysLabel: return "Warn before expiry"
            case .activeRefreshLabel: return "Refresh while active"
            case .idleRefreshLabel: return "Refresh while idle"
            case .maintenanceSection: return "Maintenance"
            case .checkUpdatesButton: return "Check for updates"
            case .pluginsButton: return "Save reference plugins"
            case .diagnosticsButton: return "Diagnostics"
            case .percentSuffix: return "%"
            case .daysSuffix: return "days"
            case .invalidReminderThreshold: return "Enter a number from 1 to 99"
            case .invalidCreditExpiryLeadDays: return "Enter a number from 1 to 30"
            case .settingsBackAccessibility: return "Back to settings"
            case .settingsDoneAccessibility: return "Close settings"
            case .settingsNavigationHint: return "Opens a settings subsection"
            case .settingsToggleHint: return "Toggle switch"
            case .settingsNumericHint: return "Enter a value and press Return"
            case .usageResetsTitle: return "Usage resets"
            case .updatedPrefix: return "Updated"
            case .useResetButton: return "Use"
            case .redeemResetTooltip: return "Redeem this reset credit after confirmation"
            case .displaySection: return "Display"
            case .menuBarLabel: return "Menu bar"
            case .weeklyOption: return "Weekly"
            case .fiveHourOption: return "5H"
            case .followAppsTitle: return "Follow Codex / ChatGPT"
            case .followAppsDetail: return "Show only while either app is open"
            case .usageReminderTitle: return "Usage reminder"
            case .usageReminderDetail: return "Show when the threshold is reached"
            case .creditExpiryTitle: return "Credit expiry"
            case .creditExpiryDetail: return "Alert 3 days before reset credits expire"
            case .autoSwitchTitle: return "Auto switch"
            case .healthSection: return "Health"
            case .settingsAddAccount: return "Add account"
            case .settingsReminder: return "Reminder"
            case .settingsRefreshRate: return "Refresh rate"
            case .settingsCheckUpdate: return "Check update"
            case .settingsSavePlugins: return "Save plugins"
            case .accountsButton: return "Accounts"
            case .resetVaultTitle: return "RESET VAULT"
            case .checkingAccounts: return "Checking saved accounts"
            case .unavailable: return "Unavailable"
            case .checkingResetCredits: return "Checking reset credits…"
            case .noAvailableResetCredits: return "No available reset credits"
            case .toggleAccount: return "Toggle Account"
            case .addAccountMenu: return "Add Account…"
            case .accountLabelsMenu: return "Account Display Labels"
            case .menuBarDisplayMenu: return "Menu Bar Display"
            case .removeAccountMenu: return "Remove Account"
            case .forceRefreshMenu: return "Force Usage Refresh"
            case .checkUpdatesMenu: return "Check for Updates"
            case .cleanBackupsMenu: return "Clean Account Backups"
            case .quitAppMenu: return "Quit Account Switcher"
            case .activeAccountPrefix: return "Active account"
            case .noActiveAccount: return "No active account"
            case .activeButton: return "Active"
            case .switchButtonShort: return "Switch"
            case .labelButton: return "Label"
            case .deleteButtonShort: return "Del"
            }
        }
    }

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
        if hasError, knownTotal == 0 { return language == .russian ? "Сбросы (?)" : "Resets (?)" }
        guard knownAccounts > 0 else { return language == .russian ? "Сбросы (…)" : "Resets (…)" }
        let suffix = hasError ? "+" : ""
        let label = language == .russian ? "Сбросы" : "Resets"
        return "\(label) (\(knownTotal)\(suffix))"
    }

    static func resetCreditsTooltip(
        knownTotal: Int,
        knownAccounts: Int,
        hasError: Bool,
        language: AppLanguage
    ) -> String {
        if hasError, knownTotal == 0 {
            return language == .russian
                ? "Не удалось проверить кредиты сброса для одного или нескольких аккаунтов"
                : "One or more reset-credit checks failed"
        }
        guard knownAccounts > 0 else {
            return language == .russian ? "Проверяем кредиты сброса" : "Checking reset credits"
        }
        if knownTotal == 0 {
            return language == .russian ? "Нет доступных кредитов сброса Codex" : "No Codex reset credits available"
        }
        return language == .russian
            ? "Показать кредиты сброса Codex по аккаунтам"
            : "Show Codex reset credits by account"
    }
}

struct PoolChartSemanticLabels: Equatable {
    let index: String
    let base: String
    let capacity: String
    let pool: String
}

enum PoolChartLocalization {
    private static let dailyReferencePercent = 100.0 / 7.0

    static func axisDate(_ date: Date, language: AppLanguage) -> String {
        date.formatted(
            Date.FormatStyle(locale: language.locale)
                .day()
                .month(.abbreviated)
        )
    }

    static func detailLines(for point: DailyPoolSpendPoint, language: AppLanguage) -> [String] {
        let dateText = axisDate(point.date, language: language)
        guard let spentPercent = point.spentPercent, point.coverage != .noData else {
            return [dateText, language == .russian ? "Нет данных" : "No data"]
        }

        let spent = number(spentPercent, language: language)
        switch language {
        case .russian:
            var lines = [dateText, "Потрачено: \(spent)% пула"]
            if let remainingPercent = point.remainingPercent {
                lines.append("Осталось: \(number(remainingPercent, language: language))%")
            }
            return lines
        case .english:
            var lines = [dateText, "Spent: \(spent)% of pool"]
            if let remainingPercent = point.remainingPercent {
                lines.append("Remaining: \(number(remainingPercent, language: language))%")
            }
            return lines
        }
    }

    static func accessibilityValue(for point: DailyPoolSpendPoint, language: AppLanguage) -> String {
        let dateText = axisDate(point.date, language: language)
        guard let spentPercent = point.spentPercent, point.coverage != .noData else {
            return [dateText, language == .russian ? "Нет данных" : "No data"].joined(separator: ". ")
        }

        let spent = number(spentPercent, language: language)
        let pace = number(spentPercent / dailyReferencePercent, language: language)
        let isLowerBound = point.coverage == .lowerBound || point.coverage == .inProgressLowerBound
        let isInProgress = point.coverage == .inProgress || point.coverage == .inProgressLowerBound
        var lines: [String]
        switch language {
        case .russian:
            lines = [dateText, isLowerBound ? "Потрачено не менее: \(spent)% пула" : "Потрачено: \(spent)% пула"]
            lines.append("Темп: \(pace)× дневного ориентира")
            if isLowerBound { lines.append("Неполный день") }
            if let remainingPercent = point.remainingPercent {
                let remaining = number(remainingPercent, language: language)
                lines.append(
                    isInProgress
                        ? "Осталось сейчас: \(remaining)%"
                        : isLowerBound
                            ? "Осталось в последнем замере: \(remaining)%"
                            : "Осталось к концу дня: \(remaining)%"
                )
            }
            lines.append(
                DailyPoolSpendBand.classify(spentPercent) == .withinReference
                    ? "В пределах дневного ориентира"
                    : "Выше дневного ориентира"
            )
        case .english:
            lines = [dateText, isLowerBound ? "Spent at least: \(spent)% of pool" : "Spent: \(spent)% of pool"]
            lines.append("Pace: \(pace)× daily reference")
            if isLowerBound { lines.append("Incomplete day") }
            if let remainingPercent = point.remainingPercent {
                let remaining = number(remainingPercent, language: language)
                lines.append(
                    isInProgress
                        ? "Remaining now: \(remaining)%"
                        : isLowerBound
                            ? "Remaining at last sample: \(remaining)%"
                            : "Remaining at day end: \(remaining)%"
                )
            }
            lines.append(
                DailyPoolSpendBand.classify(spentPercent) == .withinReference
                    ? "Within the daily reference"
                    : "Above the daily reference"
            )
        }
        return lines.joined(separator: ". ")
    }

    static func dailyReference(language: AppLanguage) -> String {
        language == .russian ? "Дневной ориентир 14%" : "Daily reference 14%"
    }

    static func dailyReferenceAccessibility(language: AppLanguage) -> String {
        language == .russian
            ? "Дневной ориентир 14% — равномерный расход пула на 7 дней"
            : "Daily reference 14% — an even seven-day pool pace"
    }

    static func chartSummary(language: AppLanguage) -> String {
        language == .russian
            ? "Дневной расход общего недельного пула аккаунтов за 14 дней"
            : "Daily consumption of the combined weekly account pool over 14 days"
    }

    private static func number(_ value: Double, language: AppLanguage) -> String {
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value.rounded()))
    }

    static func semanticLabels(language: AppLanguage) -> PoolChartSemanticLabels {
        switch language {
        case .russian:
            return PoolChartSemanticLabels(
                index: "Индекс",
                base: "Основание",
                capacity: "Полная ёмкость",
                pool: "Расход пула"
            )
        case .english:
            return PoolChartSemanticLabels(
                index: "Index",
                base: "Base",
                capacity: "Full capacity",
                pool: "Pool spend"
            )
        }
    }
}

enum LocalizedIntervalFormatter {
    private enum Unit { case minute, hour, day }

    static func duration(_ interval: TimeInterval, language: AppLanguage) -> String {
        let safeInterval = max(0, interval)
        let totalMinutes = Int((safeInterval / 60).rounded())
        if totalMinutes < 60 {
            return component(totalMinutes, unit: .minute, language: language)
        }
        if totalMinutes < 24 * 60 {
            return joinedComponents(
                [
                    (totalMinutes / 60, .hour),
                    (totalMinutes % 60, .minute)
                ],
                language: language
            )
        }

        let totalHours = Int((safeInterval / 3_600).rounded())
        return joinedComponents(
            [
                (totalHours / 24, .day),
                (totalHours % 24, .hour)
            ],
            language: language
        )
    }

    static func signedMargin(_ interval: TimeInterval, language: AppLanguage) -> String {
        let sign = interval < 0 ? "−" : "+"
        return sign + duration(abs(interval), language: language)
    }

    private static func joinedComponents(
        _ components: [(value: Int, unit: Unit)],
        language: AppLanguage
    ) -> String {
        components
            .filter { $0.value > 0 }
            .map { component($0.value, unit: $0.unit, language: language) }
            .joined(separator: " ")
    }

    private static func component(_ value: Int, unit: Unit, language: AppLanguage) -> String {
        "\(value) \(unitText(unit, value: value, language: language))"
    }

    private static func unitText(_ unit: Unit, value: Int, language: AppLanguage) -> String {
        guard language == .russian else {
            switch unit {
            case .minute: return value == 1 ? "minute" : "minutes"
            case .hour: return value == 1 ? "hour" : "hours"
            case .day: return value == 1 ? "day" : "days"
            }
        }

        let lastTwo = value % 100
        let last = value % 10
        let form: Int
        if last == 1, lastTwo != 11 {
            form = 0
        } else if (2...4).contains(last), !(12...14).contains(lastTwo) {
            form = 1
        } else {
            form = 2
        }
        switch unit {
        case .minute: return ["минута", "минуты", "минут"][form]
        case .hour: return ["час", "часа", "часов"][form]
        case .day: return ["день", "дня", "дней"][form]
        }
    }
}

enum PoolVerdictEventKind: Equatable {
    case now
    case reset
    case exhaustion
}

struct PoolVerdictEventPresentation: Equatable {
    let kind: PoolVerdictEventKind
    let title: String
    let intervalText: String?
}

enum PoolVerdictTimelineGeometry {
    static func firstEventFraction(
        firstInterval: TimeInterval,
        lastInterval: TimeInterval
    ) -> Double? {
        guard firstInterval.isFinite, lastInterval.isFinite,
              firstInterval > 0, lastInterval > 0 else { return nil }
        return max(0, min(1, firstInterval / lastInterval))
    }
}

struct PoolVerdictPresentation: Equatable {
    let kind: PoolVerdictKind
    let language: AppLanguage
    let resetInterval: TimeInterval?
    let exhaustionInterval: TimeInterval?
    let margin: TimeInterval?
    let title: String
    let detail: String
    let firstEventFraction: Double?
    let marginSummaryLabel: String?
    let marginSummaryValue: String?
    let accessibilityLabel: String
    let events: [PoolVerdictEventPresentation]
    let subtitle: String
    let coverageLabel: String?
    let coverageValue: String?
    let capacityFraction: Double?
    let resetIndicators: [String]
    let accountValue: String?
    let accountLabel: String?
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
                firstEventFraction: nil,
                marginSummaryLabel: nil,
                marginSummaryValue: nil,
                accessibilityLabel: LocalizedText.value(.collectingAccessibility, language: language),
                events: [],
                subtitle: LocalizedText.value(.verdictCollectingDetail, language: language),
                coverageLabel: nil,
                coverageValue: nil,
                capacityFraction: nil,
                resetIndicators: [],
                accountValue: nil,
                accountLabel: nil
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
            return PoolVerdictPresentation(
                kind: verdict.kind,
                language: language,
                resetInterval: reset,
                exhaustionInterval: exhaustion,
                margin: margin,
                title: LocalizedText.value(verdict.kind == .enough ? .verdictEnoughTitle : .verdictNotEnoughTitle, language: language),
                detail: LocalizedText.value(verdict.kind == .enough ? .verdictEnoughDetail : .verdictNotEnoughDetail, language: language),
                firstEventFraction: firstEventFraction,
                marginSummaryLabel: LocalizedText.value(marginSummaryKey, language: language),
                marginSummaryValue: LocalizedIntervalFormatter.duration(abs(margin), language: language),
                accessibilityLabel: LocalizedText.value(verdict.kind == .enough ? .enoughAccessibility : .notEnoughAccessibility, language: language),
                events: events,
                subtitle: LocalizedText.value(verdict.kind == .enough ? .verdictEnoughDetail : .verdictNotEnoughDetail, language: language),
                coverageLabel: nil,
                coverageValue: nil,
                capacityFraction: nil,
                resetIndicators: [],
                accountValue: nil,
                accountLabel: nil
            )
        }
    }

    static func make(
        forecast: PoolSufficiencyForecast,
        language: AppLanguage,
        now: Date
    ) -> PoolVerdictPresentation {
        guard forecast.kind != .collecting,
              let coverageRatio = forecast.coverageRatio,
              coverageRatio.isFinite,
              let requiredAccountCount = forecast.requiredAccountCount else {
            return make(verdict: .collecting, language: language)
        }

        let titleKey: LocalizedTextKey = forecast.kind == .enough
            ? .verdictEnoughTitle
            : .verdictNotEnoughTitle
        let coverageKey: LocalizedTextKey = forecast.kind == .enough
            ? .verdictReserveSummary
            : .verdictDeficitSummary
        let subtitle = forecast.isPreliminary
            ? preliminarySubtitle(historyDays: forecast.historyDays, language: language)
            : LocalizedText.value(.verdictEstablishedPace, language: language)
        let coverageValue = signedCoverage(coverageRatio)
        let resetIndicators = resetIndicators(
            events: forecast.resetEvents,
            now: now,
            language: language
        )
        let resetCount = forecast.resetEvents.reduce(0) { $0 + $1.accountCount }
        let accountValue = "\(forecast.accountCount) / ≈\(requiredAccountCount)"
        let accessibilityLabel = accessibilityLabel(
            title: LocalizedText.value(titleKey, language: language),
            subtitle: subtitle,
            coverageLabel: LocalizedText.value(coverageKey, language: language),
            coverageValue: coverageValue,
            accountCount: forecast.accountCount,
            requiredAccountCount: requiredAccountCount,
            resetCount: resetCount,
            language: language
        )
        return PoolVerdictPresentation(
            kind: forecast.kind,
            language: language,
            resetInterval: nil,
            exhaustionInterval: forecast.exhaustionDate.map { $0.timeIntervalSince(now) },
            margin: nil,
            title: LocalizedText.value(titleKey, language: language),
            detail: subtitle,
            firstEventFraction: nil,
            marginSummaryLabel: nil,
            marginSummaryValue: nil,
            accessibilityLabel: accessibilityLabel,
            events: [],
            subtitle: subtitle,
            coverageLabel: LocalizedText.value(coverageKey, language: language),
            coverageValue: coverageValue,
            capacityFraction: max(0, min(1, coverageRatio)),
            resetIndicators: resetIndicators,
            accountValue: accountValue,
            accountLabel: LocalizedText.value(.verdictAccountComparison, language: language)
        )
    }

    private static func preliminarySubtitle(historyDays: Double, language: AppLanguage) -> String {
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let number = formatter.string(from: NSNumber(value: historyDays)) ?? String(format: "%.1f", historyDays)
        let prefix = LocalizedText.value(.verdictPreliminaryPace, language: language)
        return language == .russian
            ? "\(prefix) \(number) дня"
            : "\(prefix) \(number) days"
    }

    private static func signedCoverage(_ ratio: Double) -> String {
        let rounded = Int(((ratio - 1) * 100).rounded())
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "−\(abs(rounded))%" }
        return "0%"
    }

    private static func resetIndicators(
        events: [PoolResetEvent],
        now: Date,
        language: AppLanguage
    ) -> [String] {
        let future = events.filter { $0.date > now }.sorted { $0.date < $1.date }
        let visible = future.count <= 3 ? future : Array(future.prefix(2))
        var labels = visible.map { resetIndicator(event: $0, now: now, language: language) }
        if future.count > 3 {
            labels.append("\(LocalizedText.value(.verdictMoreResets, language: language)) \(future.count - 2)")
        }
        return labels
    }

    private static func resetIndicator(
        event: PoolResetEvent,
        now: Date,
        language: AppLanguage
    ) -> String {
        let totalHours = max(0, Int(event.date.timeIntervalSince(now) / 3_600))
        let days = totalHours / 24
        let hours = totalHours % 24
        let dayUnit = LocalizedText.value(.verdictDaysShort, language: language)
        let hourUnit = LocalizedText.value(.verdictHoursShort, language: language)
        let interval: String
        if days > 0, hours > 0 {
            interval = "\(days) \(dayUnit) \(hours) \(hourUnit)"
        } else if days > 0 {
            interval = "\(days) \(dayUnit)"
        } else {
            interval = "\(max(1, hours)) \(hourUnit)"
        }
        return event.accountCount > 1 ? "\(interval) · ×\(event.accountCount)" : interval
    }

    private static func accessibilityLabel(
        title: String,
        subtitle: String,
        coverageLabel: String,
        coverageValue: String,
        accountCount: Int,
        requiredAccountCount: Int,
        resetCount: Int,
        language: AppLanguage
    ) -> String {
        let unsignedCoverage = coverageValue.replacingOccurrences(of: "−", with: "").replacingOccurrences(of: "+", with: "")
        if language == .russian {
            return "\(title). \(subtitle). \(coverageLabel) \(unsignedCoverage). \(accountCount) аккаунтов, нужно примерно \(requiredAccountCount). Известно \(resetCount) сбросов."
        }
        return "\(title). \(subtitle). \(coverageLabel) \(unsignedCoverage). \(accountCount) accounts, approximately \(requiredAccountCount) needed. \(resetCount) known resets."
    }

    private static func event(
        _ kind: PoolVerdictEventKind,
        interval: TimeInterval?,
        language: AppLanguage
    ) -> PoolVerdictEventPresentation {
        let key: LocalizedTextKey = kind == .now ? .nowEvent : (kind == .reset ? .resetEvent : .exhaustionEvent)
        let intervalText = interval.map {
            let duration = LocalizedIntervalFormatter.duration($0, language: language)
            return language == .russian ? "через \(duration)" : "in \(duration)"
        }
        return PoolVerdictEventPresentation(
            kind: kind,
            title: LocalizedText.value(key, language: language),
            intervalText: intervalText
        )
    }
}
