import AppKit
import ApplicationServices
import Foundation
import Security
import UserNotifications

struct CodexAccount: Equatable {
    let selector: String
    let email: String
    let plan: String
    let fiveHourUsage: String
    let weeklyUsage: String
    let fiveHourUsedPercent: Int?
    let weeklyUsedPercent: Int?
    let lastActivity: String
    let isActive: Bool
}

struct HealthStatus {
    let title: String
    let value: String
    let color: NSColor
}

enum RouteBCapabilityState {
    case ready
    case testRequired
    case blocked
}

struct RouteBCapability {
    let label: String
    let state: RouteBCapabilityState
}

struct RouteBProviderProfile {
    let id: String
    let name: String
    let provider: String
    let model: String
    let summary: String
    let capabilities: [RouteBCapability]
}

private let routeBProviderProfiles = [
    RouteBProviderProfile(
        id: "openrouter-text-helper",
        name: "Text Helper",
        provider: "OpenRouter",
        model: "z-ai/glm-5.2",
        summary: "Low-risk drafting, summaries, and read-only checks.",
        capabilities: [
            RouteBCapability(label: "Chat ready", state: .ready),
            RouteBCapability(label: "MCP test required", state: .testRequired),
            RouteBCapability(label: "Browser test required", state: .testRequired),
            RouteBCapability(label: "Live ops blocked", state: .blocked)
        ]
    ),
    RouteBProviderProfile(
        id: "openrouter-visual-helper",
        name: "Visual Helper",
        provider: "OpenRouter",
        model: "z-ai/glm-5v-turbo",
        summary: "Image review and visual context; no account actions.",
        capabilities: [
            RouteBCapability(label: "Chat ready", state: .ready),
            RouteBCapability(label: "Vision ready", state: .ready),
            RouteBCapability(label: "MCP blocked", state: .blocked),
            RouteBCapability(label: "Live ops blocked", state: .blocked)
        ]
    )
]

struct ApiUsageSnapshot: Equatable {
    let usedTokens: Int
    let limitTokens: Int
    let warningPercent: Int
    let lastUpdatedText: String
    let lastError: String?

    var usedPercent: Int {
        guard limitTokens > 0 else { return 0 }
        return max(0, min(100, Int((Double(usedTokens) / Double(limitTokens)) * 100.0)))
    }

    var remainingTokens: Int {
        max(0, limitTokens - usedTokens)
    }
}

struct ResetCredit: Equatable {
    let id: String
    let title: String
    let resetType: String
    let status: String
    let grantedAt: Date?
    let expiresAt: Date?
}

struct ResetCreditsSnapshot: Equatable {
    let availableCount: Int?
    let credits: [ResetCredit]
    let lastUpdatedText: String
    let lastError: String?

    var availableCredits: [ResetCredit] {
        credits.filter { $0.status.lowercased() == "available" }
    }

    var displayCount: Int? {
        availableCount ?? (credits.isEmpty ? nil : availableCredits.count)
    }
}

enum UsageDisplayMode: String {
    case fiveHour
    case weekly
}

enum ToolbarDisplayStyle: String {
    case detailed
    case compact
}

enum AutoSwitchMode: String {
    case off
    case ask
    case threshold
    case zero
}

enum AutoResumeMode: String {
    case off
    case ask
    case idle5
    case idle10
    case always
}

enum AccountPanelMode {
    case usage
    case settings
    case api
    case routeB
    case resets
}

enum SettingsPanelAction: String {
    case usageView
    case settingsView
    case routeBView
    case resetCreditsView
    case addAccount
    case addDeviceAccount
    case apiView
    case setupApiMode
    case switchApiMode
    case editApiLimit
    case refreshApiUsage
    case testApiReminder
    case editLabels
    case removeAccount
    case usageWeekly
    case usageFiveHour
    case styleDetailed
    case styleCompact
    case toggleLaunchAtLogin
    case toggleUsageReminder
    case editUsageReminder
    case toggleAutoSwitch
    case editAutoSwitch
    case editAutoResume
    case toggleConfirmSwitch
    case toggleProtectCodex
    case editRefresh
    case forceRefresh
    case checkUpdates
    case cleanBackups
    case quit
}

private func usageStatusColor(for percent: Int?) -> NSColor {
    guard let percent else { return .secondaryLabelColor }
    if percent >= 50 { return .systemGreen }
    if percent >= 20 { return .systemOrange }
    return .systemRed
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private struct PanelTheme {
    let isDark: Bool

    static func current(for appearance: NSAppearance?) -> PanelTheme {
        PanelTheme(isDark: appearance?.isDarkMode ?? NSApp.effectiveAppearance.isDarkMode)
    }

    var primaryText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.94) : NSColor.black.withAlphaComponent(0.80)
    }

    var secondaryText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.52) : NSColor.black.withAlphaComponent(0.50)
    }

    var tertiaryText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.38) : NSColor.black.withAlphaComponent(0.38)
    }

    var valueText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.72) : NSColor.black.withAlphaComponent(0.66)
    }

    var inactiveAccent: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.34) : NSColor.black.withAlphaComponent(0.32)
    }

    var activeCardFill: NSColor {
        isDark ? NSColor(red: 0.045, green: 0.105, blue: 0.085, alpha: 0.70) : NSColor(red: 0.91, green: 0.98, blue: 0.94, alpha: 0.95)
    }

    var inactiveCardFill: NSColor {
        isDark ? NSColor(red: 0.055, green: 0.075, blue: 0.10, alpha: 0.76) : NSColor(red: 0.965, green: 0.975, blue: 0.985, alpha: 0.94)
    }

    var inactiveCardHoverFill: NSColor {
        isDark ? NSColor(red: 0.08, green: 0.105, blue: 0.135, alpha: 0.82) : NSColor(red: 0.99, green: 0.995, blue: 1.0, alpha: 0.98)
    }

    var inactiveCardBorder: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.08)
    }

    var bottomBarFill: NSColor {
        isDark ? NSColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 0.72) : NSColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 0.94)
    }

    var divider: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.09) : NSColor.black.withAlphaComponent(0.08)
    }

    var iconTint: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.58) : NSColor.black.withAlphaComponent(0.46)
    }

    var ringTrack: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.08)
    }

    var progressTrack: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.085) : NSColor.black.withAlphaComponent(0.085)
    }

    var inactiveButtonFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.22) : NSColor(red: 0.90, green: 0.925, blue: 0.94, alpha: 1)
    }

    var usageInactiveButtonFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.15) : NSColor(red: 0.36, green: 0.39, blue: 0.43, alpha: 0.92)
    }

    var switchOffFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.18)
    }
}

struct CommandResult {
    let status: Int32
    let output: String
}

enum ApiUsageFetchResult {
    case success(Int)
    case failure(String)
}

enum ResetCreditsFetchResult {
    case success(ResetCreditsSnapshot)
    case failure(String)
}

enum ResetCreditRedemptionResult {
    case success(String)
    case failure(String)
}

struct SavedAccountAuth {
    let email: String
    let accessToken: String
    let accountID: String
}

enum SavedAccountAuthResult {
    case success(SavedAccountAuth)
    case failure(String)
}

final class AccountSwitcherPanelView: NSView {
    private let accounts: [CodexAccount]
    private let activeAccount: CodexAccount?
    private let mode: AccountPanelMode
    private let lastUpdatedText: String
    private let lastError: String?
    private let isSwitching: Bool
    private let launchAtLoginEnabled: Bool
    private let remindersEnabled: Bool
    private let reminderThreshold: Int
    private let autoSwitchEnabled: Bool
    private let autoSwitchThreshold: Int
    private let autoSwitchMode: AutoSwitchMode
    private let autoResumeMode: AutoResumeMode
    private let confirmBeforeSwitching: Bool
    private let armedSwitchEmail: String?
    private let protectFrontmostCodex: Bool
    private let apiModeActive: Bool
    private let apiKeyConfigured: Bool
    private let usageKeyConfigured: Bool
    private let apiUsage: ApiUsageSnapshot
    private let resetCreditsByEmail: [String: ResetCreditsSnapshot]
    private let healthStatuses: [HealthStatus]
    private let routeBProfiles: [RouteBProviderProfile]
    private let selectedRouteBProfileID: String?
    private let usageMode: UsageDisplayMode
    private let toolbarDisplayStyle: ToolbarDisplayStyle
    private let activeRefreshInterval: Int
    private let idleRefreshInterval: Int
    private let labelForAccount: (CodexAccount) -> String
    private let compactEmail: (String) -> String
    private let switchAccount: (String) -> Void
    private let refresh: () -> Void
    private let showSettings: () -> Void
    private let checkUpdates: () -> Void
    private let editAccountLabel: (String) -> Void
    private let showResetCredits: () -> Void
    private let redeemResetCredit: (String, String) -> Void
    private let selectRouteBProfile: (String) -> Void
    private let performSettingsAction: (SettingsPanelAction) -> Void
    private let close: () -> Void
    private let toggleLaunchAtLogin: () -> Void
    private var theme: PanelTheme { PanelTheme.current(for: effectiveAppearance) }
    private let outerInset: CGFloat = 18
    private let cardGap: CGFloat = 14
    private let bottomBarTopGap: CGFloat = 12
    private let bottomBarHeight: CGFloat = 42
    private var usesCompactGrid: Bool {
        mode == .usage && accounts.count >= 3
    }
    private var accountCardHeight: CGFloat {
        bounds.height - (outerInset * 2) - cardGap - bottomBarTopGap - bottomBarHeight
    }

    init(
        accounts: [CodexAccount],
        activeAccount: CodexAccount?,
        mode: AccountPanelMode,
        lastUpdatedText: String,
        lastError: String?,
        isSwitching: Bool,
        launchAtLoginEnabled: Bool,
        remindersEnabled: Bool,
        reminderThreshold: Int,
        autoSwitchEnabled: Bool,
        autoSwitchThreshold: Int,
        autoSwitchMode: AutoSwitchMode,
        autoResumeMode: AutoResumeMode,
        confirmBeforeSwitching: Bool,
        armedSwitchEmail: String?,
        protectFrontmostCodex: Bool,
        apiModeActive: Bool,
        apiKeyConfigured: Bool,
        usageKeyConfigured: Bool,
        apiUsage: ApiUsageSnapshot,
        resetCreditsByEmail: [String: ResetCreditsSnapshot],
        healthStatuses: [HealthStatus],
        routeBProfiles: [RouteBProviderProfile],
        selectedRouteBProfileID: String?,
        usageMode: UsageDisplayMode,
        toolbarDisplayStyle: ToolbarDisplayStyle,
        activeRefreshInterval: Int,
        idleRefreshInterval: Int,
        labelForAccount: @escaping (CodexAccount) -> String,
        compactEmail: @escaping (String) -> String,
        switchAccount: @escaping (String) -> Void,
        refresh: @escaping () -> Void,
        showSettings: @escaping () -> Void,
        checkUpdates: @escaping () -> Void,
        editAccountLabel: @escaping (String) -> Void,
        showResetCredits: @escaping () -> Void,
        redeemResetCredit: @escaping (String, String) -> Void,
        selectRouteBProfile: @escaping (String) -> Void,
        performSettingsAction: @escaping (SettingsPanelAction) -> Void,
        close: @escaping () -> Void,
        toggleLaunchAtLogin: @escaping () -> Void
    ) {
        self.accounts = accounts
        self.activeAccount = activeAccount
        self.mode = mode
        self.lastUpdatedText = lastUpdatedText
        self.lastError = lastError
        self.isSwitching = isSwitching
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.remindersEnabled = remindersEnabled
        self.reminderThreshold = reminderThreshold
        self.autoSwitchEnabled = autoSwitchEnabled
        self.autoSwitchThreshold = autoSwitchThreshold
        self.autoSwitchMode = autoSwitchMode
        self.autoResumeMode = autoResumeMode
        self.confirmBeforeSwitching = confirmBeforeSwitching
        self.armedSwitchEmail = armedSwitchEmail
        self.protectFrontmostCodex = protectFrontmostCodex
        self.apiModeActive = apiModeActive
        self.apiKeyConfigured = apiKeyConfigured
        self.usageKeyConfigured = usageKeyConfigured
        self.apiUsage = apiUsage
        self.resetCreditsByEmail = resetCreditsByEmail
        self.healthStatuses = healthStatuses
        self.routeBProfiles = routeBProfiles
        self.selectedRouteBProfileID = selectedRouteBProfileID
        self.usageMode = usageMode
        self.toolbarDisplayStyle = toolbarDisplayStyle
        self.activeRefreshInterval = activeRefreshInterval
        self.idleRefreshInterval = idleRefreshInterval
        self.labelForAccount = labelForAccount
        self.compactEmail = compactEmail
        self.switchAccount = switchAccount
        self.refresh = refresh
        self.showSettings = showSettings
        self.checkUpdates = checkUpdates
        self.editAccountLabel = editAccountLabel
        self.showResetCredits = showResetCredits
        self.redeemResetCredit = redeemResetCredit
        self.selectRouteBProfile = selectRouteBProfile
        self.performSettingsAction = performSettingsAction
        self.close = close
        self.toggleLaunchAtLogin = toggleLaunchAtLogin
        let panelSize = AccountSwitcherPanelView.preferredSize(mode: mode, accountCount: accounts.count)
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.masksToBounds = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    static func preferredSize(mode: AccountPanelMode, accountCount: Int) -> NSSize {
        if mode == .usage && accountCount >= 3 {
            return NSSize(width: 430, height: 520)
        }
        if mode == .settings {
            return NSSize(width: 370, height: 500)
        }
        if mode == .routeB {
            return NSSize(width: 430, height: 520)
        }
        if mode == .resets && accountCount >= 3 {
            return NSSize(width: 430, height: 580)
        }
        return NSSize(width: 370, height: 450)
    }

    private func build() {
        let background = DashboardBackgroundView(frame: bounds)
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        switch mode {
        case .usage:
            buildUsageContent()
        case .settings:
            buildSettingsContent()
        case .api:
            buildApiContent()
        case .routeB:
            buildRouteBContent()
        case .resets:
            buildResetCreditsContent()
        }
    }

    private func buildUsageContent() {
        if accounts.isEmpty {
            addSubview(emptyStateCard())
        } else if accounts.count >= 3 {
            buildCompactGridUsageContent()
        } else {
            let orderedAccounts = accounts.sorted { left, right in
                let leftPriority = panelSortPriority(for: left)
                let rightPriority = panelSortPriority(for: right)
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                return labelForAccount(left).localizedCaseInsensitiveCompare(labelForAccount(right)) == .orderedAscending
            }
            let columns = min(orderedAccounts.count, 2)
            let contentWidth = bounds.width - (outerInset * 2)
            let cardWidth = columns == 1 ? contentWidth : (contentWidth - cardGap) / 2
            for (index, account) in orderedAccounts.prefix(2).enumerated() {
                let x = columns == 1 ? outerInset : outerInset + CGFloat(index) * (cardWidth + cardGap)
                addSubview(accountCard(account, frame: NSRect(x: x, y: outerInset, width: cardWidth, height: accountCardHeight)))
            }
        }

        addSubview(bottomBar(frame: NSRect(x: outerInset, y: bounds.height - outerInset - bottomBarHeight, width: bounds.width - (outerInset * 2), height: bottomBarHeight)))
    }

    private func buildCompactGridUsageContent() {
        let orderedAccounts = accounts.sorted { left, right in
            let leftPriority = panelSortPriority(for: left)
            let rightPriority = panelSortPriority(for: right)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return labelForAccount(left).localizedCaseInsensitiveCompare(labelForAccount(right)) == .orderedAscending
        }

        let contentWidth = bounds.width - (outerInset * 2)
        let cardWidth = (contentWidth - cardGap) / 2
        let cardHeight = (bounds.height - (outerInset * 2) - cardGap - bottomBarTopGap - bottomBarHeight) / 2

        for index in 0..<4 {
            let column = index % 2
            let row = index / 2
            let x = outerInset + CGFloat(column) * (cardWidth + cardGap)
            let y = outerInset + CGFloat(row) * (cardHeight + cardGap)
            let frame = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
            if index < orderedAccounts.count {
                addSubview(compactAccountCard(orderedAccounts[index], frame: frame))
            } else {
                addSubview(emptyCompactAccountSlot(frame: frame))
            }
        }
    }

    private func buildSettingsContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(settingsHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 38)))

        let displaySection = settingsSection(frame: NSRect(x: outerInset, y: 64, width: contentWidth, height: 80), title: "Display")
        displaySection.addSubview(segmentedRow(label: "Menu bar", frame: NSRect(x: 14, y: 29, width: contentWidth - 28, height: 24), options: [
            ("Weekly", usageMode == .weekly, SettingsPanelAction.usageWeekly),
            ("5H", usageMode == .fiveHour, SettingsPanelAction.usageFiveHour)
        ]))
        displaySection.addSubview(segmentedRow(label: "Style", frame: NSRect(x: 14, y: 54, width: contentWidth - 28, height: 24), options: [
            ("Large", toolbarDisplayStyle == .detailed, SettingsPanelAction.styleDetailed),
            ("Small", toolbarDisplayStyle == .compact, SettingsPanelAction.styleCompact)
        ]))
        addSubview(displaySection)

        let automationSection = settingsSection(frame: NSRect(x: outerInset, y: 152, width: contentWidth, height: 158), title: "Automation")
        automationSection.addSubview(settingToggleRow(title: "Launch at login", detail: "Open this helper automatically", isOn: launchAtLoginEnabled, action: .toggleLaunchAtLogin, frame: NSRect(x: 14, y: 26, width: contentWidth - 28, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Usage reminder", detail: "Alert at \(reminderThreshold)%", isOn: remindersEnabled, action: .toggleUsageReminder, frame: NSRect(x: 14, y: 52, width: contentWidth - 28, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Auto switch", detail: autoSwitchDetailText(), isOn: autoSwitchEnabled, action: .editAutoSwitch, frame: NSRect(x: 14, y: 78, width: contentWidth - 28, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Auto resume", detail: autoResumeDetailText(), isOn: autoResumeMode != .off, action: .editAutoResume, frame: NSRect(x: 14, y: 104, width: contentWidth - 28, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Card confirmation", detail: "Arm card first, then switch", isOn: confirmBeforeSwitching, action: .toggleConfirmSwitch, frame: NSRect(x: 14, y: 130, width: contentWidth - 28, height: 28)))
        addSubview(automationSection)

        addSubview(healthSection(frame: NSRect(x: outerInset, y: 318, width: contentWidth, height: 106)))
        addSubview(settingsFooter(frame: NSRect(x: outerInset, y: bounds.height - outerInset - bottomBarHeight, width: contentWidth, height: bottomBarHeight)))
    }

    private func buildRouteBContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(routeBHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 44)))
        addSubview(routeBSafetyBanner(frame: NSRect(x: outerInset, y: 72, width: contentWidth, height: 62)))

        for (index, profile) in routeBProfiles.prefix(2).enumerated() {
            let y = 146 + CGFloat(index) * 142
            addSubview(routeBProfileCard(profile, frame: NSRect(x: outerInset, y: y, width: contentWidth, height: 130)))
        }

        addSubview(routeBFooter(frame: NSRect(x: outerInset, y: bounds.height - outerInset - bottomBarHeight, width: contentWidth, height: bottomBarHeight)))
    }

    private func buildResetCreditsContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(resetCreditsHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 44)))

        if accounts.isEmpty {
            let empty = emptyStateCard()
            empty.frame = NSRect(x: outerInset, y: 74, width: contentWidth, height: bounds.height - 74 - outerInset)
            addSubview(empty)
            return
        }

        let orderedAccounts = orderedSettingsAccounts()
        let areaY: CGFloat = 74
        let areaHeight = bounds.height - areaY - outerInset
        let columns = orderedAccounts.count >= 4 ? 2 : 1
        let rows = Int(ceil(Double(orderedAccounts.count) / Double(columns)))
        let cardWidth = columns == 1 ? contentWidth : (contentWidth - cardGap) / 2
        let cardHeight = (areaHeight - CGFloat(max(0, rows - 1)) * cardGap) / CGFloat(max(1, rows))

        for (index, account) in orderedAccounts.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = outerInset + CGFloat(column) * (cardWidth + cardGap)
            let y = areaY + CGFloat(row) * (cardHeight + cardGap)
            addSubview(resetCreditAccountCard(account, frame: NSRect(x: x, y: y, width: cardWidth, height: cardHeight)))
        }
    }

    private func resetCreditsHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label("Resets", frame: NSRect(x: 2, y: 1, width: 170, height: 26), size: 22, weight: .semibold, color: theme.primaryText))
        header.addSubview(label(resetCreditsHeaderSubtitle(), frame: NSRect(x: 2, y: 28, width: frame.width - 96, height: 14), size: 10.5, weight: .medium, color: theme.secondaryText))

        let back = SettingsActionButton(frame: NSRect(x: frame.width - 78, y: 4, width: 78, height: 28), title: "Usage", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func resetCreditsHeaderSubtitle() -> String {
        let state = resetCreditsSummaryState()
        if state.knownAccounts == 0 {
            return "Checking saved accounts"
        }
        if state.knownTotal == 0 {
            return state.hasError ? "Some accounts could not be checked" : "No available reset credits"
        }
        let suffix = state.hasError ? " plus unchecked accounts" : ""
        return state.knownTotal == 1 ? "1 available reset\(suffix)" : "\(state.knownTotal) available resets\(suffix)"
    }

    private func resetCreditAccountCard(_ account: CodexAccount, frame: NSRect) -> NSView {
        let snapshot = resetCreditsByEmail[account.email]
        let count = snapshot?.displayCount
        let countText: String
        if let count {
            countText = count == 1 ? "1 RESET" : "\(count) RESETS"
        } else {
            countText = "CHECKING"
        }

        let color = resetCreditsAccentColor(snapshot: snapshot)
        let card = RoundedPanelView(
            frame: frame,
            fillColor: account.isActive ? cardFillColor(isActive: true) : cardFillColor(isActive: false),
            borderColor: account.isActive ? color.withAlphaComponent(0.45) : cardBorderColor(isActive: false),
            cornerRadius: accounts.count >= 4 ? 10 : 16
        )

        let labelText = labelForAccount(account)
        card.addSubview(label(labelText, frame: NSRect(x: 14, y: 13, width: 42, height: 24), size: 18, weight: .semibold, color: color, alignment: .center))
        card.addSubview(label(compactCardEmail(account.email), frame: NSRect(x: 58, y: 15, width: frame.width - 148, height: 18), size: 11.5, weight: .semibold, color: theme.primaryText))

        let badge = ResetTimeBadgeView(frame: NSRect(x: frame.width - 86, y: 13, width: 72, height: 22), text: countText, color: color, isActive: account.isActive)
        card.addSubview(badge)

        let divider = NSView(frame: NSRect(x: 14, y: 48, width: frame.width - 28, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = theme.divider.cgColor
        card.addSubview(divider)

        if let error = snapshot?.lastError {
            card.addSubview(label("Unavailable", frame: NSRect(x: 16, y: 64, width: frame.width - 32, height: 18), size: 12, weight: .semibold, color: NSColor.systemOrange))
            card.addSubview(label(error, frame: NSRect(x: 16, y: 86, width: frame.width - 32, height: 36), size: 10, weight: .medium, color: theme.secondaryText))
            return card
        }

        guard let snapshot else {
            card.addSubview(label("Checking reset credits...", frame: NSRect(x: 16, y: 72, width: frame.width - 32, height: 18), size: 11.5, weight: .semibold, color: theme.secondaryText))
            return card
        }

        let credits = sortedAvailableResetCredits(snapshot)
        if credits.isEmpty {
            card.addSubview(label("No available reset credits", frame: NSRect(x: 16, y: 72, width: frame.width - 32, height: 18), size: 11.5, weight: .semibold, color: theme.secondaryText))
            let updated = "Updated \(snapshot.lastUpdatedText)"
            card.addSubview(label(updated, frame: NSRect(x: 16, y: 94, width: frame.width - 32, height: 16), size: 10, weight: .medium, color: theme.tertiaryText))
            return card
        }

        let rowHeight: CGFloat = accounts.count >= 4 ? 34 : 22
        let maxRows = max(1, Int((frame.height - 58) / rowHeight))
        for (index, credit) in credits.prefix(maxRows).enumerated() {
            let y = 58 + CGFloat(index) * rowHeight
            card.addSubview(resetCreditRow(credit, index: index + 1, account: account, frame: NSRect(x: 14, y: y, width: frame.width - 28, height: rowHeight)))
        }

        if credits.count > maxRows {
            let remaining = credits.count - maxRows
            let text = remaining == 1 ? "1 more reset available" : "\(remaining) more resets available"
            card.addSubview(label(text, frame: NSRect(x: 16, y: frame.height - 22, width: frame.width - 32, height: 14), size: 9.5, weight: .medium, color: theme.tertiaryText))
        }
        return card
    }

    private func resetCreditsAccentColor(snapshot: ResetCreditsSnapshot?) -> NSColor {
        if snapshot?.lastError != nil {
            return .systemOrange
        }
        if let count = snapshot?.displayCount, count > 0 {
            return .systemBlue
        }
        return theme.inactiveAccent
    }

    private func sortedAvailableResetCredits(_ snapshot: ResetCreditsSnapshot) -> [ResetCredit] {
        snapshot.availableCredits.sorted { left, right in
            switch (left.expiresAt, right.expiresAt) {
            case let (left?, right?):
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
        }
    }

    private func resetCreditRow(_ credit: ResetCredit, index: Int, account: CodexAccount, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        let urgencyColor = resetCreditUrgencyColor(for: credit)
        let buttonWidth: CGFloat = 54
        let buttonX = frame.width - buttonWidth
        let indexWidth: CGFloat = 34
        let expiresWidth: CGFloat = min(160, max(118, frame.width * 0.34))
        let daysX = indexWidth + expiresWidth + 18
        let daysWidth = max(82, buttonX - daysX - 16)
        let primaryTextY: CGFloat = frame.height >= 28 ? 1 : 2
        let buttonHeight: CGFloat = frame.height >= 28 ? 18 : 16
        let buttonY: CGFloat = primaryTextY

        row.addSubview(label("#\(index)", frame: NSRect(x: 0, y: primaryTextY, width: indexWidth, height: 16), size: 10.8, weight: .semibold, color: urgencyColor))
        row.addSubview(label(resetCreditExpiryText(credit), frame: NSRect(x: indexWidth, y: primaryTextY, width: expiresWidth, height: 16), size: 10.8, weight: .semibold, color: urgencyColor))
        row.addSubview(label(resetCreditDaysLeftText(credit), frame: NSRect(x: daysX, y: primaryTextY, width: daysWidth, height: 16), size: 10.8, weight: .semibold, color: urgencyColor))
        if frame.height >= 28 {
            row.addSubview(label(resetCreditGrantedText(credit), frame: NSRect(x: indexWidth, y: 17, width: frame.width - indexWidth - buttonWidth - 12, height: 14), size: 9.5, weight: .medium, color: theme.secondaryText))
        }

        let redeem = SettingsActionButton(frame: NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight), title: "Use", color: urgencyColor.withAlphaComponent(theme.isDark ? 0.42 : 0.22), textColor: urgencyColor)
        redeem.identifier = NSUserInterfaceItemIdentifier(resetCreditActionPayload(email: account.email, creditID: credit.id))
        redeem.target = self
        redeem.action = #selector(resetCreditRedeemPressed(_:))
        redeem.toolTip = "Redeem this reset credit after confirmation"
        row.addSubview(redeem)
        return row
    }

    private func resetCreditExpiryText(_ credit: ResetCredit) -> String {
        let expires = credit.expiresAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown expiry"
        return expires
    }

    private func resetCreditDaysLeftText(_ credit: ResetCredit) -> String {
        guard let days = resetCreditDaysLeft(credit) else {
            return "unknown"
        }
        if days <= 0 {
            return "today"
        }
        return days == 1 ? "1 day left" : "\(days) days left"
    }

    private func resetCreditGrantedText(_ credit: ResetCredit) -> String {
        let granted = credit.grantedAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown grant"
        return "Grant \(granted)"
    }

    private func resetCreditDaysLeft(_ credit: ResetCredit) -> Int? {
        guard let expiresAt = credit.expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSince(Date())
        return max(0, Int(ceil(seconds / 86_400)))
    }

    private func resetCreditUrgencyColor(for credit: ResetCredit) -> NSColor {
        guard let days = resetCreditDaysLeft(credit) else {
            return .systemBlue
        }
        if days <= 7 {
            return .systemRed
        }
        if days <= 20 {
            return .systemOrange
        }
        return .systemGreen
    }

    private func routeBHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label("OpenRouter", frame: NSRect(x: 2, y: 1, width: 190, height: 26), size: 22, weight: .semibold, color: theme.primaryText))
        header.addSubview(label("Route B · secondary profiles", frame: NSRect(x: 2, y: 28, width: 220, height: 14), size: 10.5, weight: .medium, color: theme.secondaryText))

        let back = SettingsActionButton(frame: NSRect(x: frame.width - 78, y: 4, width: 78, height: 28), title: "Usage", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func routeBSafetyBanner(frame: NSRect) -> NSView {
        let banner = RoundedPanelView(
            frame: frame,
            fillColor: NSColor.systemIndigo.withAlphaComponent(theme.isDark ? 0.16 : 0.09),
            borderColor: NSColor.systemIndigo.withAlphaComponent(0.32),
            cornerRadius: 14
        )
        banner.addSubview(label("SECONDARY LANE ONLY", frame: NSRect(x: 14, y: 10, width: frame.width - 28, height: 15), size: 10.5, weight: .bold, color: NSColor.systemIndigo))
        banner.addSubview(label("No requests or keys in this prototype. Native Codex stays the default", frame: NSRect(x: 14, y: 27, width: frame.width - 28, height: 14), size: 10, weight: .medium, color: theme.secondaryText))
        banner.addSubview(label("for sends, uploads, accounts, and other live operations.", frame: NSRect(x: 14, y: 41, width: frame.width - 28, height: 14), size: 10, weight: .medium, color: theme.secondaryText))
        return banner
    }

    private func routeBProfileCard(_ profile: RouteBProviderProfile, frame: NSRect) -> NSView {
        let isSelected = profile.id == selectedRouteBProfileID
        let card = RoundedPanelView(
            frame: frame,
            fillColor: cardFillColor(isActive: isSelected),
            borderColor: isSelected ? NSColor.systemGreen.withAlphaComponent(0.48) : cardBorderColor(isActive: false),
            cornerRadius: 16
        )
        card.addSubview(label(profile.name, frame: NSRect(x: 16, y: 13, width: frame.width - 112, height: 20), size: 15, weight: .semibold, color: theme.primaryText))
        card.addSubview(label("\(profile.provider) · \(profile.model)", frame: NSRect(x: 16, y: 34, width: frame.width - 32, height: 16), size: 10.5, weight: .medium, color: theme.secondaryText))
        card.addSubview(label(profile.summary, frame: NSRect(x: 16, y: 53, width: frame.width - 32, height: 16), size: 10.5, weight: .medium, color: theme.valueText))

        let button = SettingsActionButton(
            frame: NSRect(x: frame.width - 88, y: 12, width: 72, height: 24),
            title: isSelected ? "Selected" : "Switch",
            color: isSelected ? NSColor.systemGreen : theme.inactiveButtonFill,
            textColor: isSelected ? .white : theme.primaryText
        )
        button.identifier = NSUserInterfaceItemIdentifier("routeBSelect|\(profile.id)")
        button.target = self
        button.action = #selector(settingsActionPressed(_:))
        button.isEnabled = !isSelected
        card.addSubview(button)

        var x: CGFloat = 16
        var y: CGFloat = 82
        for capability in profile.capabilities {
            let width = routeBCapabilityWidth(capability.label)
            if x + width > frame.width - 16 {
                x = 16
                y += 27
            }
            card.addSubview(routeBCapabilityBadge(capability, frame: NSRect(x: x, y: y, width: width, height: 21)))
            x += width + 8
        }
        return card
    }

    private func routeBCapabilityBadge(_ capability: RouteBCapability, frame: NSRect) -> NSView {
        let color: NSColor
        let symbol: String
        switch capability.state {
        case .ready:
            color = .systemGreen
            symbol = "✓"
        case .testRequired:
            color = .systemOrange
            symbol = "!"
        case .blocked:
            color = .systemRed
            symbol = "×"
        }

        let badge = RoundedPanelView(frame: frame, fillColor: color.withAlphaComponent(theme.isDark ? 0.16 : 0.10), borderColor: color.withAlphaComponent(0.34), cornerRadius: 10)
        badge.addSubview(label("\(symbol)  \(capability.label)", frame: NSRect(x: 8, y: 3, width: frame.width - 16, height: 15), size: 9.5, weight: .semibold, color: color))
        return badge
    }

    private func routeBCapabilityWidth(_ text: String) -> CGFloat {
        max(100, min(180, CGFloat(text.count) * 6.4 + 36))
    }

    private func routeBFooter(frame: NSRect) -> NSView {
        let footer = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 14)
        footer.addSubview(label("Profile selection only · execution disabled", frame: NSRect(x: 14, y: 12, width: frame.width - 110, height: 18), size: 10.5, weight: .semibold, color: theme.secondaryText))
        let settings = SettingsActionButton(frame: NSRect(x: frame.width - 88, y: 8, width: 76, height: 26), title: "Settings", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        settings.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.settingsView.rawValue)
        settings.target = self
        settings.action = #selector(settingsActionPressed(_:))
        footer.addSubview(settings)
        return footer
    }

    private func autoSwitchDetailText() -> String {
        switch autoSwitchMode {
        case .off:
            return "Off"
        case .ask:
            return "Ask at \(autoSwitchThreshold)%"
        case .threshold:
            return "Switch at \(autoSwitchThreshold)%"
        case .zero:
            return "Ask at 0%"
        }
    }

    private func autoResumeDetailText() -> String {
        switch autoResumeMode {
        case .off:
            return "Off"
        case .ask:
            return "Ask first"
        case .idle5:
            return "Idle 5s"
        case .idle10:
            return "Idle 10s"
        case .always:
            return "Always"
        }
    }

    private func buildApiContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(apiHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 44)))
        addSubview(apiUsageCard(frame: NSRect(x: outerInset, y: 74, width: contentWidth, height: 258)))
        addSubview(apiActionBar(frame: NSRect(x: outerInset, y: 342, width: contentWidth, height: 46)))
        addSubview(apiFooter(frame: NSRect(x: outerInset, y: bounds.height - outerInset - bottomBarHeight, width: contentWidth, height: bottomBarHeight)))
    }

    private func settingsHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label("Settings", frame: NSRect(x: 2, y: 1, width: 120, height: 26), size: 22, weight: .semibold, color: theme.primaryText))
        header.addSubview(label("Switcher controls", frame: NSRect(x: 2, y: 27, width: 180, height: 14), size: 10.5, weight: .medium, color: theme.secondaryText))
        let openRouter = SettingsActionButton(frame: NSRect(x: frame.width - 164, y: 4, width: 78, height: 28), title: "OpenRouter", color: NSColor.systemIndigo.withAlphaComponent(0.82), textColor: .white)
        openRouter.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.routeBView.rawValue)
        openRouter.target = self
        openRouter.action = #selector(settingsActionPressed(_:))
        header.addSubview(openRouter)

        let back = SettingsActionButton(frame: NSRect(x: frame.width - 78, y: 4, width: 78, height: 28), title: "Usage", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func apiHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label("API Mode", frame: NSRect(x: 2, y: 1, width: 160, height: 26), size: 22, weight: .semibold, color: theme.primaryText))
        let status = apiModeActive ? "Active OpenAI API login" : "Codex account login active"
        header.addSubview(label(status, frame: NSRect(x: 2, y: 28, width: 220, height: 14), size: 10.5, weight: .medium, color: apiModeActive ? NSColor.systemGreen : theme.secondaryText))

        let back = SettingsActionButton(frame: NSRect(x: frame.width - 78, y: 4, width: 78, height: 28), title: "Usage", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func apiUsageCard(frame: NSRect) -> NSView {
        let percent = apiUsage.usedPercent
        let color = apiColor(for: percent)
        let card = RoundedPanelView(frame: frame, fillColor: apiModeActive ? cardFillColor(isActive: true) : cardFillColor(isActive: false), borderColor: apiModeActive ? color.withAlphaComponent(0.45) : cardBorderColor(isActive: false))

        card.addSubview(label(apiModeActive ? "ACTIVE" : "READY", frame: NSRect(x: 18, y: 18, width: 74, height: 22), size: 12, weight: .semibold, color: apiModeActive ? color : theme.secondaryText))
        card.addSubview(label("Daily complimentary tokens", frame: NSRect(x: 18, y: 42, width: frame.width - 36, height: 18), size: 12, weight: .medium, color: theme.secondaryText))

        let ringSize: CGFloat = 138
        let ringX = (frame.width - ringSize) / 2
        let ringY: CGFloat = 70
        card.addSubview(UsageRingView(frame: NSRect(x: ringX, y: ringY, width: ringSize, height: ringSize), color: color, trackColor: theme.ringTrack, percent: CGFloat(percent) / 100.0, isActive: true))
        card.addSubview(PercentCenterLabelView(frame: NSRect(x: ringX + 8, y: ringY + 31, width: ringSize - 16, height: 46), percent: percent, color: color))
        card.addSubview(label("USED", frame: NSRect(x: ringX + 12, y: ringY + 73, width: ringSize - 24, height: 16), size: 9.5, weight: .medium, color: theme.secondaryText, alignment: .center))

        let used = tokenText(apiUsage.usedTokens)
        let limit = tokenText(apiUsage.limitTokens)
        card.addSubview(label("\(used) / \(limit)", frame: NSRect(x: 24, y: 214, width: frame.width - 48, height: 18), size: 13, weight: .semibold, color: theme.primaryText, alignment: .center))

        let detail = apiUsage.lastError ?? "Updated \(apiUsage.lastUpdatedText) · alert at \(apiUsage.warningPercent)%"
        card.addSubview(label(detail, frame: NSRect(x: 24, y: 235, width: frame.width - 48, height: 16), size: 10, weight: .medium, color: apiUsage.lastError == nil ? theme.secondaryText : NSColor.systemOrange, alignment: .center))
        return card
    }

    private func apiActionBar(frame: NSRect) -> NSView {
        let bar = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 14)
        let setup = SettingsActionButton(frame: NSRect(x: 12, y: 10, width: 68, height: 26), title: apiKeyConfigured ? "Keys" : "Setup", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        setup.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.setupApiMode.rawValue)
        setup.target = self
        setup.action = #selector(settingsActionPressed(_:))
        bar.addSubview(setup)

        let switchButton = SettingsActionButton(frame: NSRect(x: 90, y: 10, width: 96, height: 26), title: apiModeActive ? "API Active" : "Use API", color: apiModeActive ? NSColor.systemGreen : theme.inactiveButtonFill, textColor: apiModeActive ? .white : theme.primaryText)
        switchButton.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.switchApiMode.rawValue)
        switchButton.target = self
        switchButton.action = #selector(settingsActionPressed(_:))
        switchButton.isEnabled = !apiModeActive
        bar.addSubview(switchButton)

        let limit = SettingsActionButton(frame: NSRect(x: 196, y: 10, width: 58, height: 26), title: "Limit", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        limit.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.editApiLimit.rawValue)
        limit.target = self
        limit.action = #selector(settingsActionPressed(_:))
        bar.addSubview(limit)

        let test = SettingsActionButton(frame: NSRect(x: frame.width - 70, y: 10, width: 58, height: 26), title: "Test", color: theme.bottomBarFill, textColor: theme.primaryText)
        test.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.testApiReminder.rawValue)
        test.target = self
        test.action = #selector(settingsActionPressed(_:))
        bar.addSubview(test)
        return bar
    }

    private func apiFooter(frame: NSRect) -> NSView {
        let footer = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 14)
        let api = iconButton(symbol: "server.rack", frame: NSRect(x: 16, y: 9, width: 24, height: 24), action: #selector(apiPressed(_:)), toolTip: "API mode")
        footer.addSubview(api)

        let centerText = apiModeActive ? "switch back from account card" : "switch API on when ready"
        footer.addSubview(CenteredTextView(frame: NSRect(x: 68, y: 10, width: frame.width - 136, height: 22), text: centerText, size: 12.5, weight: .medium, color: theme.primaryText, alignment: .center))

        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: frame.width - 86, y: 9, width: 24, height: 24), action: #selector(apiRefreshPressed), toolTip: "Refresh API token usage")
        footer.addSubview(refreshButton)
        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: frame.width - 40, y: 9, width: 24, height: 24), action: #selector(closePressed), toolTip: "Quit Account Switcher")
        footer.addSubview(closeButton)
        return footer
    }

    private func settingsSection(frame: NSRect, title: String) -> NSView {
        let section = RoundedPanelView(frame: frame, fillColor: cardFillColor(isActive: false), borderColor: cardBorderColor(isActive: false), cornerRadius: 16)
        section.addSubview(label(title, frame: NSRect(x: 14, y: 10, width: frame.width - 28, height: 18), size: 12, weight: .semibold, color: theme.primaryText))
        return section
    }

    private func healthSection(frame: NSRect) -> NSView {
        let section = settingsSection(frame: frame, title: "Health")
        let rows = Array(healthStatuses.prefix(6))
        let badgeWidth = (frame.width - 40) / 2
        for (index, status) in rows.enumerated() {
            let column = index % 2
            let row = index / 2
            let x = 14 + CGFloat(column) * (badgeWidth + 12)
            let y = 28 + CGFloat(row) * 22
            section.addSubview(healthBadge(status, frame: NSRect(x: x, y: y, width: badgeWidth, height: 14)))
        }
        return section
    }

    private func healthBadge(_ status: HealthStatus, frame: NSRect) -> NSView {
        let badge = FlippedContainerView(frame: frame)
        let dot = DotView(frame: NSRect(x: 0, y: 4, width: 6, height: 6), color: status.color)
        badge.addSubview(dot)
        badge.addSubview(label(status.title, frame: NSRect(x: 12, y: 0, width: 56, height: 14), size: 8.8, weight: .medium, color: theme.secondaryText))
        badge.addSubview(label(status.value, frame: NSRect(x: 66, y: 0, width: frame.width - 66, height: 14), size: 8.8, weight: .semibold, color: theme.primaryText, alignment: .right))
        return badge
    }

    private func settingsAccountRow(_ account: CodexAccount, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        let accent = account.isActive ? NSColor.systemGreen : theme.inactiveAccent
        row.addSubview(label(labelForAccount(account), frame: NSRect(x: 0, y: 0, width: 42, height: 24), size: 14, weight: .semibold, color: accent, alignment: .center))
        row.addSubview(label(compactSettingsEmail(account.email), frame: NSRect(x: 48, y: 2, width: 126, height: 20), size: 11.5, weight: .medium, color: theme.primaryText))

        let switchButton = SettingsActionButton(frame: NSRect(x: frame.width - 150, y: 1, width: 58, height: 22), title: account.isActive ? "Active" : "Switch", color: account.isActive ? NSColor.systemGreen : theme.inactiveButtonFill, textColor: account.isActive ? .white : theme.primaryText)
        switchButton.identifier = NSUserInterfaceItemIdentifier("switch|\(account.email)")
        switchButton.target = self
        switchButton.action = #selector(accountSettingsActionPressed(_:))
        switchButton.isEnabled = !account.isActive && !isSwitching
        row.addSubview(switchButton)

        let labelButton = SettingsActionButton(frame: NSRect(x: frame.width - 84, y: 1, width: 40, height: 22), title: "Label", color: theme.bottomBarFill, textColor: theme.primaryText)
        labelButton.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.editLabels.rawValue)
        labelButton.target = self
        labelButton.action = #selector(settingsActionPressed(_:))
        row.addSubview(labelButton)

        let removeButton = SettingsActionButton(frame: NSRect(x: frame.width - 38, y: 1, width: 38, height: 22), title: "Del", color: theme.bottomBarFill, textColor: NSColor.systemRed)
        removeButton.identifier = NSUserInterfaceItemIdentifier("remove|\(account.email)")
        removeButton.target = self
        removeButton.action = #selector(accountSettingsActionPressed(_:))
        removeButton.isEnabled = !isSwitching
        row.addSubview(removeButton)
        return row
    }

    private func segmentedRow(label title: String, frame: NSRect, options: [(String, Bool, SettingsPanelAction)]) -> NSView {
        let row = FlippedContainerView(frame: frame)
        row.addSubview(label(title, frame: NSRect(x: 0, y: 2, width: 76, height: 18), size: 11, weight: .medium, color: theme.secondaryText))
        let segmentWidth = (frame.width - 84) / CGFloat(options.count)
        for (index, option) in options.enumerated() {
            let color = option.1 ? NSColor.systemGreen : theme.bottomBarFill
            let textColor = option.1 ? NSColor.white : theme.primaryText
            let button = SettingsActionButton(frame: NSRect(x: 84 + CGFloat(index) * segmentWidth, y: 0, width: segmentWidth - 6, height: 24), title: option.0, color: color, textColor: textColor)
            button.identifier = NSUserInterfaceItemIdentifier(option.2.rawValue)
            button.target = self
            button.action = #selector(settingsActionPressed(_:))
            row.addSubview(button)
        }
        return row
    }

    private func settingToggleRow(title: String, detail: String, isOn: Bool, action: SettingsPanelAction, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        row.addSubview(label(title, frame: NSRect(x: 0, y: 1, width: frame.width - 44, height: 15), size: 11.2, weight: .semibold, color: theme.primaryText))
        row.addSubview(label(detail, frame: NSRect(x: 0, y: 15, width: frame.width - 44, height: 13), size: 9.5, weight: .medium, color: theme.secondaryText))
        let toggle = MiniSwitchButton(frame: NSRect(x: frame.width - 36, y: 3, width: 34, height: 22), isOn: isOn, offColor: theme.switchOffFill)
        toggle.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
        toggle.target = self
        toggle.action = #selector(settingsActionPressed(_:))
        row.addSubview(toggle)
        return row
    }

    private func settingsFooter(frame: NSRect) -> NSView {
        let footer = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 14)
        let buttonY: CGFloat = 8
        let actions: [(String, SettingsPanelAction, CGFloat)] = [
            ("Add", .addAccount, 40),
            ("Device", .addDeviceAccount, 54),
            ("Reminder", .editUsageReminder, 68),
            ("Refresh", .editRefresh, 58),
            ("Update", .checkUpdates, 54)
        ]
        var x: CGFloat = 12
        for action in actions {
            let button = SettingsActionButton(frame: NSRect(x: x, y: buttonY, width: action.2, height: 26), title: action.0, color: theme.inactiveButtonFill, textColor: theme.primaryText)
            button.identifier = NSUserInterfaceItemIdentifier(action.1.rawValue)
            button.target = self
            button.action = #selector(settingsActionPressed(_:))
            footer.addSubview(button)
            x += action.2 + 8
        }
        return footer
    }

    private func makeHeader() -> NSView {
        let view = FlippedContainerView(frame: NSRect(x: 0, y: 0, width: 520, height: 88))

        let icon = CircleIconView(frame: NSRect(x: 38, y: 24, width: 42, height: 42), color: .systemIndigo, symbol: "chevron.left.forwardslash.chevron.right")
        view.addSubview(icon)

        let title = label("Codex Control", frame: NSRect(x: 98, y: 23, width: 250, height: 28), size: 22, weight: .semibold, color: .white.withAlphaComponent(0.94))
        view.addSubview(title)

        let subtitleText = activeAccount.map { "Active account \(labelForAccount($0))" } ?? (lastError ?? "No active account")
        let subtitle = label(subtitleText, frame: NSRect(x: 99, y: 52, width: 260, height: 19), size: 13, weight: .medium, color: activeAccount == nil ? .systemOrange : .white.withAlphaComponent(0.58))
        subtitle.lineBreakMode = .byTruncatingTail
        view.addSubview(subtitle)

        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: 377, y: 29, width: 32, height: 32), action: #selector(refreshPressed), toolTip: "Refresh active usage; inactive accounts update when switched")
        view.addSubview(refreshButton)

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: 421, y: 28, width: 34, height: 34), action: #selector(settingsPressed(_:)), toolTip: "Open settings")
        view.addSubview(settingsButton)

        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: 465, y: 29, width: 32, height: 32), action: #selector(closePressed), toolTip: "Quit Account Switcher")
        view.addSubview(closeButton)

        return view
    }

    private func compactAccountCard(_ account: CodexAccount, frame: NSRect) -> NSView {
        let weeklyPercent = account.weeklyUsedPercent
        let fiveHourPercent = account.fiveHourUsedPercent
        let fiveHourColor = accentColor(for: fiveHourPercent, isActive: account.isActive)
        let weeklyColor = accentColor(for: weeklyPercent, isActive: account.isActive)
        let usageWeight: NSFont.Weight = account.isActive ? .semibold : .medium
        let compactProgressHeight = progressLineHeight(isActive: account.isActive)
        let card = RoundedPanelView(
            frame: frame,
            fillColor: cardFillColor(for: account),
            borderColor: cardBorderColor(for: account),
            cornerRadius: 10,
            hoverFillColor: account.isActive || isSwitching ? nil : theme.inactiveCardHoverFill,
            clickAction: account.isActive || isSwitching ? nil : { [weak self] in
                self?.switchAccount(account.email)
            }
        )

        let labelText = labelForAccount(account)
        let isArmed = confirmBeforeSwitching && armedSwitchEmail == account.email && !account.isActive
        let statusTitle = account.isActive ? "ACTIVE" : (isSwitching ? "..." : (isArmed ? "CONFIRM" : "SWITCH"))
        let buttonColor = account.isActive ? fiveHourColor : (isArmed ? NSColor.systemBlue : theme.usageInactiveButtonFill)
        let switchButtonWidth: CGFloat = isArmed ? 76 : 64
        let switchButton = PillButton(frame: NSRect(x: 12, y: 12, width: switchButtonWidth, height: 24), title: statusTitle, color: buttonColor, showsDot: isArmed, allowsHover: !account.isActive)
        switchButton.toolTip = isArmed ? "Confirm \(switchPreviewText(for: account))" : switchPreviewText(for: account)
        switchButton.target = self
        switchButton.action = #selector(accountSwitchPressed(_:))
        switchButton.identifier = NSUserInterfaceItemIdentifier(account.email)
        switchButton.isEnabled = !account.isActive && !isSwitching && !accounts.isEmpty
        card.addSubview(switchButton)

        let accountSettingsButton = AccountMoreButton(frame: NSRect(x: frame.width - 50, y: 8, width: 40, height: 34), tintColor: account.isActive ? fiveHourColor : theme.iconTint, label: labelText)
        accountSettingsButton.identifier = NSUserInterfaceItemIdentifier("label|\(account.email)")
        accountSettingsButton.target = self
        accountSettingsButton.action = #selector(accountSettingsActionPressed(_:))
        card.addSubview(accountSettingsButton)

        card.addSubview(label(compactCardEmail(account.email), frame: NSRect(x: 12, y: 46, width: frame.width - 24, height: 16), size: 11.2, weight: .semibold, color: theme.tertiaryText, alignment: .center))

        let contentX: CGFloat = 14
        let contentWidth = frame.width - 28
        let fiveHourY: CGFloat = 68
        card.addSubview(label("5H REMAINING", frame: NSRect(x: contentX, y: fiveHourY, width: contentWidth - 58, height: 16), size: 10.2, weight: usageWeight, color: fiveHourColor))
        card.addSubview(label(percentText(fiveHourPercent), frame: NSRect(x: frame.width - 72, y: fiveHourY - 3, width: 58, height: 22), size: 20, weight: usageWeight, color: fiveHourColor, alignment: .right))
        card.addSubview(ProgressLineView(frame: NSRect(x: contentX, y: fiveHourY + 25, width: contentWidth, height: compactProgressHeight), color: fiveHourColor, trackColor: theme.progressTrack, percent: CGFloat(fiveHourPercent ?? 0) / 100))

        let fiveHourResetY = fiveHourY + 41
        card.addSubview(label("5H", frame: NSRect(x: contentX, y: fiveHourResetY, width: 44, height: 16), size: 10.2, weight: .semibold, color: theme.tertiaryText))
        card.addSubview(label(fiveHourResetTimeText(from: account.fiveHourUsage), frame: NSRect(x: frame.width - 78, y: fiveHourResetY - 1, width: 64, height: 18), size: 11.2, weight: .semibold, color: fiveHourColor, alignment: .right))

        let dividerY = fiveHourResetY + 20
        let divider = NSView(frame: NSRect(x: contentX, y: dividerY, width: contentWidth, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = theme.divider.cgColor
        card.addSubview(divider)

        let weeklyY = dividerY + 12
        card.addSubview(label("WEEKLY", frame: NSRect(x: contentX, y: weeklyY, width: 74, height: 16), size: 10.2, weight: .semibold, color: theme.tertiaryText))
        card.addSubview(label(percentText(weeklyPercent), frame: NSRect(x: frame.width - 70, y: weeklyY - 1, width: 56, height: 18), size: 11.5, weight: usageWeight, color: weeklyColor, alignment: .right))
        card.addSubview(ProgressLineView(frame: NSRect(x: contentX, y: weeklyY + 23, width: contentWidth, height: compactProgressHeight), color: weeklyColor, trackColor: theme.progressTrack, percent: CGFloat(weeklyPercent ?? 0) / 100))

        let resetY = weeklyY + 38
        card.addSubview(label("RESET", frame: NSRect(x: contentX, y: resetY, width: 58, height: 16), size: 10.2, weight: .semibold, color: theme.tertiaryText))
        card.addSubview(label(weeklyResetText(from: account.weeklyUsage), frame: NSRect(x: frame.width - 92, y: resetY - 1, width: 78, height: 18), size: 11.2, weight: .semibold, color: weeklyColor, alignment: .right))
        return card
    }

    private func emptyCompactAccountSlot(frame: NSRect) -> NSView {
        let card = RoundedPanelView(frame: frame, fillColor: theme.inactiveCardFill.withAlphaComponent(theme.isDark ? 0.36 : 0.48), borderColor: theme.inactiveCardBorder, cornerRadius: 10)
        card.addSubview(SymbolIconView(frame: NSRect(x: (frame.width - 24) / 2, y: (frame.height - 38) / 2, width: 24, height: 24), symbol: "plus.circle", color: theme.iconTint.withAlphaComponent(0.45)))
        card.addSubview(label("Account slot", frame: NSRect(x: 14, y: (frame.height / 2) + 12, width: frame.width - 28, height: 16), size: 10.5, weight: .medium, color: theme.tertiaryText, alignment: .center))
        return card
    }

    private func accountCard(_ account: CodexAccount, frame: NSRect) -> NSView {
        let weeklyPercent = account.weeklyUsedPercent
        let fiveHourPercent = account.fiveHourUsedPercent
        let weeklyColor = accentColor(for: weeklyPercent, isActive: account.isActive)
        let fiveHourColor = accentColor(for: fiveHourPercent, isActive: account.isActive)
        let usageWeight: NSFont.Weight = account.isActive ? .semibold : .medium
        let fullProgressHeight = progressLineHeight(isActive: account.isActive)
        let card = RoundedPanelView(
            frame: frame,
            fillColor: cardFillColor(for: account),
            borderColor: cardBorderColor(for: account),
            hoverFillColor: account.isActive || isSwitching ? nil : theme.inactiveCardHoverFill,
            clickAction: account.isActive || isSwitching ? nil : { [weak self] in
                self?.switchAccount(account.email)
            }
        )
        let labelText = labelForAccount(account)

        let isArmed = confirmBeforeSwitching && armedSwitchEmail == account.email && !account.isActive
        let statusTitle = account.isActive ? "  ACTIVE" : (isSwitching ? "SWITCHING..." : (isArmed ? "CONFIRM" : "SWITCH"))
        let buttonColor = account.isActive ? fiveHourColor : (isArmed ? NSColor.systemBlue : theme.usageInactiveButtonFill)
        let switchButtonWidth: CGFloat = account.isActive ? 74 : (isArmed ? 80 : 66)
        let switchButton = PillButton(frame: NSRect(x: 18, y: 18, width: switchButtonWidth, height: 26), title: statusTitle, color: buttonColor, showsDot: isArmed, allowsHover: !account.isActive)
        switchButton.toolTip = isArmed ? "Confirm \(switchPreviewText(for: account))" : switchPreviewText(for: account)
        switchButton.target = self
        switchButton.action = #selector(accountSwitchPressed(_:))
        switchButton.identifier = NSUserInterfaceItemIdentifier(account.email)
        switchButton.isEnabled = !account.isActive && !isSwitching && !accounts.isEmpty
        card.addSubview(switchButton)

        let accountSettingsButton = AccountMoreButton(frame: NSRect(x: frame.width - 62, y: 14, width: 46, height: 38), tintColor: account.isActive ? fiveHourColor : theme.iconTint, label: labelText)
        accountSettingsButton.identifier = NSUserInterfaceItemIdentifier("label|\(account.email)")
        accountSettingsButton.target = self
        accountSettingsButton.action = #selector(accountSettingsActionPressed(_:))
        card.addSubview(accountSettingsButton)

        card.addSubview(label(compactCardEmail(account.email), frame: NSRect(x: 8, y: 64, width: frame.width - 16, height: 18), size: 12, weight: .medium, color: theme.tertiaryText, alignment: .center))

        let ringSize: CGFloat = columnsFitWide(frame.width) ? 142 : 126
        let ringX = (frame.width - ringSize) / 2
        let ringY: CGFloat = 90
        let ring = UsageRingView(frame: NSRect(x: ringX, y: ringY, width: ringSize, height: ringSize), color: fiveHourColor, trackColor: theme.ringTrack, percent: CGFloat(fiveHourPercent ?? 0) / 100, isActive: account.isActive)
        card.addSubview(ring)
        card.addSubview(PercentCenterLabelView(frame: NSRect(x: ringX + 8, y: ringY + 31, width: ringSize - 16, height: 46), percent: fiveHourPercent, color: fiveHourColor))
        card.addSubview(label("5H REMAINING", frame: NSRect(x: ringX + 12, y: ringY + 73, width: ringSize - 24, height: 16), size: 9.5, weight: .medium, color: theme.secondaryText, alignment: .center))

        let resetBlockY = ringY + ringSize + 8
        card.addSubview(resetRow(
            title: "5H",
            value: fiveHourResetTimeText(from: account.fiveHourUsage),
            color: fiveHourColor,
            isActive: account.isActive,
            frame: NSRect(x: 22, y: resetBlockY, width: frame.width - 44, height: 22)
        ))
        let dividerY = resetBlockY + 32
        let divider = NSView(frame: NSRect(x: 22, y: dividerY, width: frame.width - 44, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = theme.divider.cgColor
        card.addSubview(divider)

        let weeklyY = dividerY + 15
        let weeklyLabel = label("WEEKLY", frame: NSRect(x: 22, y: weeklyY, width: 74, height: 16), size: 10.8, weight: .medium, color: theme.secondaryText)
        card.addSubview(weeklyLabel)
        let weeklyValue = label(percentText(weeklyPercent), frame: NSRect(x: frame.width - 70, y: weeklyY, width: 48, height: 16), size: 12, weight: usageWeight, color: weeklyColor, alignment: .right)
        card.addSubview(weeklyValue)

        let progress = ProgressLineView(frame: NSRect(x: 22, y: weeklyY + 27, width: frame.width - 44, height: fullProgressHeight), color: weeklyColor, trackColor: theme.progressTrack, percent: CGFloat(weeklyPercent ?? 0) / 100)
        card.addSubview(progress)
        card.addSubview(resetRow(
            title: "RESET",
            value: weeklyResetText(from: account.weeklyUsage),
            color: weeklyColor,
            isActive: account.isActive,
            frame: NSRect(x: 22, y: weeklyY + 44, width: frame.width - 44, height: 22)
        ))
        return card
    }

    private func percentText(_ percent: Int?) -> String {
        guard let percent else { return "--" }
        return "\(max(0, min(100, percent)))%"
    }

    private func percentNumberText(_ percent: Int?) -> String {
        guard let percent else { return "--" }
        return "\(max(0, min(100, percent)))"
    }

    private func switchPreviewText(for account: CodexAccount) -> String {
        "Switch to \(labelForAccount(account)) · 5H \(percentText(account.fiveHourUsedPercent)) · Weekly \(percentText(account.weeklyUsedPercent))"
    }

    private func fiveHourResetTimeText(from usage: String) -> String {
        guard let inner = parenthesizedValue(from: usage) else { return "--.--" }
        let parts = inner.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else {
            return inner
        }
        let minute = String(parts[1].prefix(2))
        return String(format: "%02d.%@", hour, minute)
    }

    private func weeklyResetText(from usage: String) -> String {
        guard let inner = parenthesizedValue(from: usage) else { return "--" }
        let time = firstClockText(in: inner)
        let day = firstWeekdayText(in: inner) ?? inferredWeekdayText(from: inner)

        switch (time, day) {
        case let (time?, day?) where !time.isEmpty && !day.isEmpty:
            return "\(time) \(day)"
        case let (time?, nil):
            return time
        default:
            return inner.uppercased()
        }
    }

    private func firstClockText(in text: String) -> String? {
        let pattern = #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func firstWeekdayText(in text: String) -> String? {
        for token in text.split(whereSeparator: { !$0.isLetter }) {
            let day = compactWeekdayText(String(token))
            if isWeekdayAbbreviation(day) {
                return day
            }
        }
        return nil
    }

    private func compactWeekdayText(_ text: String) -> String {
        let lower = text.trimmingCharacters(in: .punctuationCharacters).lowercased()
        switch lower {
        case "monday", "mon":
            return "MON"
        case "tuesday", "tue", "tues":
            return "TUES"
        case "wednesday", "wed":
            return "WED"
        case "thursday", "thu", "thur", "thurs":
            return "THUR"
        case "friday", "fri":
            return "FRI"
        case "saturday", "sat":
            return "SAT"
        case "sunday", "sun":
            return "SUN"
        default:
            return text.uppercased()
        }
    }

    private func isWeekdayAbbreviation(_ text: String) -> Bool {
        ["MON", "TUES", "WED", "THUR", "FRI", "SAT", "SUN"].contains(text)
    }

    private func inferredWeekdayText(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: " on ", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentYear = Calendar.current.component(.year, from: Date())
        let candidates = [
            cleaned,
            "\(cleaned) \(currentYear)",
            "\(currentYear) \(cleaned)"
        ]
        let formats = [
            "HH:mm MMM d yyyy",
            "HH:mm MMMM d yyyy",
            "HH:mm d MMM yyyy",
            "HH:mm d MMMM yyyy",
            "MMM d HH:mm yyyy",
            "MMMM d HH:mm yyyy",
            "d MMM HH:mm yyyy",
            "d MMMM HH:mm yyyy",
            "yyyy HH:mm MMM d",
            "yyyy HH:mm MMMM d",
            "yyyy HH:mm d MMM",
            "yyyy HH:mm d MMMM",
            "yyyy MMM d HH:mm",
            "yyyy MMMM d HH:mm",
            "yyyy d MMM HH:mm",
            "yyyy d MMMM HH:mm"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for candidate in candidates {
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: candidate) {
                    let weekday = Calendar.current.component(.weekday, from: date)
                    return weekdayText(from: weekday)
                }
            }
        }
        return nil
    }

    private func weekdayText(from weekday: Int) -> String? {
        switch weekday {
        case 1:
            return "SUN"
        case 2:
            return "MON"
        case 3:
            return "TUES"
        case 4:
            return "WED"
        case 5:
            return "THUR"
        case 6:
            return "FRI"
        case 7:
            return "SAT"
        default:
            return nil
        }
    }

    private func resetRow(title: String, value: String, color: NSColor, isActive: Bool, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        row.addSubview(label(title, frame: NSRect(x: 0, y: 3, width: 50, height: 16), size: 10.2, weight: .semibold, color: theme.tertiaryText))
        row.addSubview(ResetTimeBadgeView(frame: NSRect(x: 56, y: 0, width: frame.width - 56, height: 22), text: value, color: color, isActive: isActive))
        return row
    }

    private func parenthesizedValue(from usage: String) -> String? {
        guard let open = usage.firstIndex(of: "("), let close = usage.firstIndex(of: ")"), open < close else {
            return nil
        }
        return String(usage[usage.index(after: open)..<close])
    }

    private func compactCardEmail(_ email: String) -> String {
        let maximumLength = 20
        guard email.count > maximumLength else { return email }
        return String(email.prefix(maximumLength - 3)) + "..."
    }

    private func compactSettingsEmail(_ email: String) -> String {
        let maximumLength = 21
        guard email.count > maximumLength else { return email }
        return String(email.prefix(maximumLength - 3)) + "..."
    }

    private func columnsFitWide(_ width: CGFloat) -> Bool {
        width > 200
    }

    private func orderedSettingsAccounts() -> [CodexAccount] {
        accounts.sorted { left, right in
            let leftPriority = panelSortPriority(for: left)
            let rightPriority = panelSortPriority(for: right)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return labelForAccount(left).localizedCaseInsensitiveCompare(labelForAccount(right)) == .orderedAscending
        }
    }

    private func panelSortPriority(for account: CodexAccount) -> Int {
        switch labelForAccount(account) {
        case "L":
            return 0
        case "A":
            return 1
        default:
            return 10
        }
    }

    private func emptyStateCard() -> NSView {
        let card = RoundedPanelView(frame: NSRect(x: outerInset, y: outerInset, width: bounds.width - (outerInset * 2), height: accountCardHeight), fillColor: cardFillColor(isActive: false), borderColor: cardBorderColor(isActive: false))
        card.addSubview(label("No accounts available", frame: NSRect(x: 22, y: 28, width: 240, height: 24), size: 18, weight: .semibold, color: theme.primaryText))
        card.addSubview(label(lastError ?? "Open settings to add an account.", frame: NSRect(x: 22, y: 62, width: 276, height: 40), size: 12, weight: .medium, color: theme.secondaryText))
        let settingsButton = SettingsActionButton(frame: NSRect(x: 22, y: 118, width: 92, height: 28), title: "Settings", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        settingsButton.target = self
        settingsButton.action = #selector(settingsPressedFromEmptyState)
        card.addSubview(settingsButton)

        let refreshButton = SettingsActionButton(frame: NSRect(x: 126, y: 118, width: 86, height: 28), title: "Refresh", color: theme.bottomBarFill, textColor: theme.primaryText)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressedFromEmptyState)
        card.addSubview(refreshButton)
        return card
    }

    @objc private func settingsPressedFromEmptyState() {
        showSettings()
    }

    @objc private func refreshPressedFromEmptyState() {
        refresh()
    }

    private func bottomBar(frame: NSRect) -> NSView {
        let bar = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 16)
        let toolbarInset: CGFloat = 16
        let toolbarGap: CGFloat = 16
        let iconSize: CGFloat = 24
        let clockSize: CGFloat = 20
        let iconY = (frame.height - iconSize) / 2
        let clockY = (frame.height - clockSize) / 2

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: toolbarInset, y: iconY, width: iconSize, height: iconSize), action: #selector(settingsPressed(_:)), toolTip: "Open settings")
        bar.addSubview(settingsButton)

        let leftDivider = NSView(frame: NSRect(x: toolbarInset + iconSize + 14, y: 10, width: 1, height: frame.height - 20))
        leftDivider.wantsLayer = true
        leftDivider.layer?.backgroundColor = theme.divider.cgColor
        bar.addSubview(leftDivider)

        let closeX = frame.width - toolbarInset - iconSize
        let refreshX = closeX - toolbarGap - iconSize - 10
        let resetWidth: CGFloat = frame.width >= 370 ? 82 : 74
        let resetX = refreshX - resetWidth - 12
        let clockX = toolbarInset + iconSize + toolbarGap + 12
        let clock = SymbolIconView(frame: NSRect(x: clockX, y: clockY, width: clockSize, height: clockSize), symbol: "clock", color: theme.iconTint)
        bar.addSubview(clock)
        let updatedX = clockX + clockSize + 6
        let updatedWidth = max(46, resetX - updatedX - 8)
        bar.addSubview(CenteredTextView(frame: NSRect(x: updatedX, y: (frame.height - 22) / 2, width: updatedWidth, height: 22), text: lastUpdatedText, size: 12.2, weight: .medium, color: theme.primaryText, alignment: .left))

        let resetButton = SettingsActionButton(frame: NSRect(x: resetX, y: 8, width: resetWidth, height: 26), title: resetCreditsButtonTitle(), color: resetCreditsButtonColor(), textColor: resetCreditsButtonTextColor())
        resetButton.target = self
        resetButton.action = #selector(resetCreditsPressed(_:))
        resetButton.toolTip = resetCreditsTooltip()
        bar.addSubview(resetButton)

        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: refreshX, y: iconY, width: iconSize, height: iconSize), action: #selector(refreshPressed), toolTip: "Refresh active usage; inactive accounts update when switched")
        bar.addSubview(refreshButton)

        let rightDivider = NSView(frame: NSRect(x: refreshX + iconSize + 10, y: 10, width: 1, height: frame.height - 20))
        rightDivider.wantsLayer = true
        rightDivider.layer?.backgroundColor = theme.divider.cgColor
        bar.addSubview(rightDivider)

        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: closeX, y: iconY, width: iconSize, height: iconSize), action: #selector(closePressed), toolTip: "Quit Account Switcher")
        closeButton.toolTip = "Quit Account Switcher"
        bar.addSubview(closeButton)
        return bar
    }

    private func resetCreditsButtonTitle() -> String {
        let state = resetCreditsSummaryState()
        if state.hasError, state.knownTotal == 0 {
            return "RESETS ?"
        }
        guard state.knownAccounts > 0 else {
            return "RESETS ..."
        }
        if state.knownTotal == 0 {
            return "NO RESETS"
        }
        let suffix = state.hasError ? "+" : ""
        return state.knownTotal == 1 ? "1\(suffix) RESET" : "\(state.knownTotal)\(suffix) RESETS"
    }

    private func resetCreditsButtonColor() -> NSColor {
        let state = resetCreditsSummaryState()
        if state.hasError, state.knownTotal == 0 {
            return NSColor.systemOrange.withAlphaComponent(theme.isDark ? 0.34 : 0.20)
        }
        if state.knownTotal > 0 {
            return NSColor.systemBlue.withAlphaComponent(theme.isDark ? 0.42 : 0.22)
        }
        return theme.inactiveButtonFill
    }

    private func resetCreditsButtonTextColor() -> NSColor {
        let state = resetCreditsSummaryState()
        if state.hasError, state.knownTotal == 0 {
            return NSColor.systemOrange
        }
        if state.knownTotal > 0 {
            return NSColor.systemBlue
        }
        return theme.primaryText
    }

    private func resetCreditsTooltip() -> String {
        let state = resetCreditsSummaryState()
        if state.hasError, state.knownTotal == 0 {
            return "One or more reset-credit checks failed"
        }
        guard state.knownAccounts > 0 else {
            return "Checking reset credits"
        }
        return state.knownTotal == 0 ? "No Codex reset credits available" : "Show Codex reset credits by account"
    }

    private func resetCreditsSummaryState() -> (knownTotal: Int, knownAccounts: Int, hasError: Bool) {
        let snapshots = accounts.compactMap { resetCreditsByEmail[$0.email] }
        let knownCounts = snapshots.compactMap { $0.displayCount }
        let total = knownCounts.reduce(0, +)
        let hasError = snapshots.contains { $0.lastError != nil }
        return (total, knownCounts.count, hasError)
    }

    private func resetCreditActionPayload(email: String, creditID: String) -> String {
        "redeemReset|\(email)\u{1F}\(creditID)"
    }

    private func resetCreditActionParts(from rawValue: String) -> (email: String, creditID: String)? {
        guard rawValue.hasPrefix("redeemReset|") else { return nil }
        let payload = String(rawValue.dropFirst("redeemReset|".count))
        let parts = payload.split(separator: "\u{1F}", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private func usageColor(for percent: Int?) -> NSColor {
        usageStatusColor(for: percent)
    }

    private func apiColor(for percent: Int) -> NSColor {
        if percent >= apiUsage.warningPercent { return .systemRed }
        if percent >= max(1, apiUsage.warningPercent - 20) { return .systemOrange }
        return .systemBlue
    }

    private func tokenText(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: "%.1fM", millions)
        }
        if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(value)"
    }

    private func accentColor(for percent: Int?, isActive: Bool) -> NSColor {
        let color = usageColor(for: percent)
        return isActive ? color : color.withAlphaComponent(theme.isDark ? 0.48 : 0.44)
    }

    private func progressLineHeight(isActive: Bool) -> CGFloat {
        isActive ? 8 : 6
    }

    private func inactiveAccentColor() -> NSColor {
        theme.inactiveAccent
    }

    private func cardFillColor(isActive: Bool) -> NSColor {
        if isActive {
            return theme.activeCardFill
        }
        return theme.inactiveCardFill
    }

    private func cardBorderColor(isActive: Bool) -> NSColor {
        isActive ? NSColor.systemGreen.withAlphaComponent(theme.isDark ? 0.68 : 0.52) : theme.inactiveCardBorder
    }

    private func cardFillColor(for account: CodexAccount) -> NSColor {
        guard account.isActive else { return theme.inactiveCardFill }
        return activeCardFillColor(for: account.fiveHourUsedPercent)
    }

    private func cardBorderColor(for account: CodexAccount) -> NSColor {
        guard account.isActive else { return theme.inactiveCardBorder }
        return usageColor(for: account.fiveHourUsedPercent).withAlphaComponent(theme.isDark ? 0.48 : 0.40)
    }

    private func activeCardFillColor(for percent: Int?) -> NSColor {
        guard let percent else {
            return theme.isDark
                ? NSColor(red: 0.065, green: 0.075, blue: 0.085, alpha: 0.76)
                : NSColor(red: 0.955, green: 0.965, blue: 0.975, alpha: 0.96)
        }
        if percent >= 50 {
            return theme.activeCardFill
        }
        if percent >= 20 {
            return theme.isDark
                ? NSColor(red: 0.145, green: 0.092, blue: 0.025, alpha: 0.78)
                : NSColor(red: 1.00, green: 0.945, blue: 0.835, alpha: 0.96)
        }
        return theme.isDark
            ? NSColor(red: 0.135, green: 0.045, blue: 0.048, alpha: 0.78)
            : NSColor(red: 1.00, green: 0.91, blue: 0.91, alpha: 0.96)
    }

    private func label(_ string: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .left) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.frame = frame
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = alignment
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func iconButton(symbol: String, frame: NSRect, action: Selector, toolTip: String? = nil) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imagePosition = .imageOnly
        button.contentTintColor = theme.iconTint
        button.target = self
        button.action = action
        button.toolTip = toolTip
        return button
    }

    @objc private func refreshPressed() {
        refresh()
    }

    @objc private func resetCreditsPressed(_ sender: NSButton) {
        showResetCredits()
    }

    @objc private func resetCreditRedeemPressed(_ sender: NSControl) {
        guard
            let rawValue = sender.identifier?.rawValue,
            let action = resetCreditActionParts(from: rawValue)
        else {
            return
        }
        redeemResetCredit(action.email, action.creditID)
    }

    @objc private func settingsPressed(_ sender: NSButton) {
        showSettings()
    }

    @objc private func apiPressed(_ sender: NSButton) {
        performSettingsAction(.apiView)
    }

    @objc private func apiRefreshPressed() {
        performSettingsAction(.refreshApiUsage)
    }

    @objc private func closePressed() {
        close()
    }

    @objc private func launchAtLoginPressed() {
        toggleLaunchAtLogin()
    }

    @objc private func accountSwitchPressed(_ sender: NSButton) {
        guard let email = sender.identifier?.rawValue, !email.isEmpty else { return }
        switchAccount(email)
    }

    @objc private func settingsActionPressed(_ sender: NSControl) {
        guard let rawValue = sender.identifier?.rawValue else { return }
        if rawValue.hasPrefix("routeBSelect|") {
            let profileID = String(rawValue.dropFirst("routeBSelect|".count))
            guard !profileID.isEmpty else { return }
            selectRouteBProfile(profileID)
            return
        }
        guard let action = SettingsPanelAction(rawValue: rawValue) else { return }
        performSettingsAction(action)
    }

    @objc private func accountSettingsActionPressed(_ sender: NSControl) {
        guard let rawValue = sender.identifier?.rawValue else { return }
        let parts = rawValue.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "switch":
            switchAccount(parts[1])
        case "label":
            editAccountLabel(parts[1])
        case "remove":
            performSettingsAction(.removeAccount)
        default:
            break
        }
    }
}

final class DashboardBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        let isDark = effectiveAppearance.isDarkMode
        let gradientColors = isDark
            ? [
                NSColor(red: 0.12, green: 0.16, blue: 0.21, alpha: 1),
                NSColor(red: 0.035, green: 0.055, blue: 0.075, alpha: 1),
                NSColor(red: 0.018, green: 0.028, blue: 0.04, alpha: 1)
            ]
            : [
                NSColor(red: 0.86, green: 0.89, blue: 0.92, alpha: 1),
                NSColor(red: 0.975, green: 0.985, blue: 0.99, alpha: 1),
                NSColor(red: 0.90, green: 0.94, blue: 0.925, alpha: 1)
            ]
        let gradient = NSGradient(colors: gradientColors)
        gradient?.draw(in: rect, angle: -72)

        NSColor(red: 0.16, green: 0.42, blue: 0.31, alpha: isDark ? 0.10 : 0.08).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - 120, y: 132, width: 260, height: 300)).fill()

        (isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.10)).setStroke()
        let border = rect.insetBy(dx: 1, dy: 1).roundedPath(radius: 24)
        border.lineWidth = 1.2
        border.stroke()
    }
}

final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

final class RoundedPanelView: NSView {
    private let fillColor: NSColor
    private let hoverFillColor: NSColor?
    private let borderColor: NSColor
    private let cornerRadius: CGFloat
    private let clickAction: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, fillColor: NSColor, borderColor: NSColor, cornerRadius: CGFloat = 18, hoverFillColor: NSColor? = nil, clickAction: (() -> Void)? = nil) {
        self.fillColor = fillColor
        self.hoverFillColor = hoverFillColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.clickAction = clickAction
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderWidth = 0.9
        layer?.borderColor = borderColor.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 14
        layer?.shadowOffset = NSSize(width: 0, height: -6)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        guard hoverFillColor != nil else { return }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard let hoverFillColor else { return }
        layer?.backgroundColor = hoverFillColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = fillColor.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard clickAction != nil, let hitView = super.hitTest(point) else {
            return super.hitTest(point)
        }
        return hitView is NSButton ? hitView : self
    }

    override func mouseDown(with event: NSEvent) {
        if let clickAction {
            clickAction()
        } else {
            super.mouseDown(with: event)
        }
    }
}

final class CircleIconView: NSView {
    private let color: NSColor
    private let symbolColor: NSColor
    private let symbol: String

    init(frame: NSRect, color: NSColor, symbol: String, symbolColor: NSColor = NSColor.white.withAlphaComponent(0.78)) {
        self.color = color
        self.symbolColor = symbolColor
        self.symbol = symbol
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.withAlphaComponent(0.24).setFill()
        bounds.insetBy(dx: 1, dy: 1).roundedPath(radius: bounds.width / 2).fill()
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            image.isTemplate = true
            symbolColor.set()
            image.draw(in: bounds.insetBy(dx: bounds.width * 0.28, dy: bounds.height * 0.28))
        }
    }
}

final class SymbolIconView: NSView {
    init(frame: NSRect, symbol: String, color: NSColor) {
        super.init(frame: frame)
        wantsLayer = true
        let imageView = NSImageView(frame: bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = color
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        imageView.image?.isTemplate = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DotView: NSView {
    private let color: NSColor

    init(frame: NSRect, color: NSColor) {
        self.color = color
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

final class ProgressLineView: NSView {
    private let color: NSColor
    private let trackColor: NSColor
    private let percent: CGFloat

    init(frame: NSRect, color: NSColor, trackColor: NSColor = NSColor.white.withAlphaComponent(0.11), percent: CGFloat) {
        self.color = color
        self.trackColor = trackColor
        self.percent = max(0, min(1, percent))
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = bounds.insetBy(dx: 0, dy: 2)
        trackColor.setFill()
        track.roundedPath(radius: track.height / 2).fill()
        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * percent, height: track.height)
        color.withAlphaComponent(min(color.alphaComponent, 0.92)).setFill()
        fill.roundedPath(radius: track.height / 2).fill()
    }
}

final class ResetTimeBadgeView: NSView {
    private let text: String
    private let color: NSColor
    private let isActive: Bool

    init(frame: NSRect, text: String, color: NSColor, isActive: Bool) {
        self.text = text
        self.color = color
        self.isActive = isActive
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color.withAlphaComponent(isActive ? 0.95 : 0.58)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 - 0.5))
    }
}

final class PercentCenterLabelView: NSView {
    private let percent: Int?
    private let color: NSColor

    init(frame: NSRect, percent: Int?, color: NSColor) {
        self.percent = percent
        self.color = color
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let value = percent.map { "\(max(0, min(100, $0)))" } ?? "--"
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 29, weight: .semibold),
            .foregroundColor: color
        ]
        let percentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: color.withAlphaComponent(0.92),
            .baselineOffset: -0.5
        ]

        let text = NSMutableAttributedString(string: value, attributes: numberAttributes)
        text.append(NSAttributedString(string: "%", attributes: percentAttributes))
        let size = text.size()
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 - 1)
        text.draw(at: point)
    }
}

final class CenteredTextView: NSView {
    private let text: String
    private let size: CGFloat
    private let weight: NSFont.Weight
    private let color: NSColor
    private let alignment: NSTextAlignment

    init(frame: NSRect, text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .left) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.alignment = alignment
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let x: CGFloat
        switch alignment {
        case .right:
            x = max(0, bounds.width - textSize.width)
        case .center:
            x = max(0, (bounds.width - textSize.width) / 2)
        default:
            x = 0
        }
        attributed.draw(at: NSPoint(x: x, y: (bounds.height - textSize.height) / 2))
    }
}

final class MiniSwitchButton: NSButton {
    private let offColor: NSColor

    init(frame: NSRect, isOn: Bool, offColor: NSColor = NSColor.white.withAlphaComponent(0.18)) {
        self.offColor = offColor
        super.init(frame: frame)
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        state = isOn ? .on : .off
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let on = state == .on
        let track = bounds.insetBy(dx: 1, dy: 3)
        (on ? NSColor.systemBlue : offColor).setFill()
        track.roundedPath(radius: track.height / 2).fill()

        let knobSize = track.height - 4
        let knobX = on ? track.maxX - knobSize - 2 : track.minX + 2
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(ovalIn: NSRect(x: knobX, y: track.minY + 2, width: knobSize, height: knobSize)).fill()
    }

    override func mouseDown(with event: NSEvent) {
        state = state == .on ? .off : .on
        needsDisplay = true
        sendAction(action, to: target)
    }
}

final class UsageRingView: NSView {
    private let color: NSColor
    private let trackColor: NSColor
    private let percent: CGFloat
    private let isActive: Bool
    private var isLowUsage: Bool {
        percent > 0 && percent <= 0.10
    }

    init(frame: NSRect, color: NSColor, trackColor: NSColor = NSColor.white.withAlphaComponent(0.10), percent: CGFloat, isActive: Bool) {
        self.color = color
        self.trackColor = trackColor
        self.percent = max(0, min(1, percent))
        self.isActive = isActive
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 10, dy: 10)
        let lineWidth: CGFloat = isActive ? 4 : 3
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        trackColor.withAlphaComponent(isLowUsage ? min(trackColor.alphaComponent + 0.08, 1) : trackColor.alphaComponent).setStroke()
        track.stroke()

        if isLowUsage {
            let warningTrack = NSBezierPath()
            warningTrack.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            warningTrack.lineWidth = lineWidth
            color.withAlphaComponent(0.22).setStroke()
            warningTrack.stroke()
        }

        guard percent > 0 else { return }

        let fill = NSBezierPath()
        let visiblePercent = isLowUsage ? max(percent, 0.08) : percent
        fill.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - (360 * visiblePercent), clockwise: true)
        fill.lineWidth = lineWidth
        fill.lineCapStyle = .round
        color.withAlphaComponent(isActive ? 0.94 : min(color.alphaComponent, 0.54)).setStroke()
        fill.stroke()
    }
}

final class PillButton: NSButton {
    private let pillColor: NSColor
    private let showsDot: Bool
    private let allowsHover: Bool
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, title: String, color: NSColor, showsDot: Bool = false, allowsHover: Bool = true) {
        self.pillColor = color
        self.showsDot = showsDot
        self.allowsHover = allowsHover
        super.init(frame: frame)
        self.title = title
        bezelStyle = .rounded
        isBordered = false
        font = .systemFont(ofSize: 13, weight: .semibold)
        contentTintColor = .white
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        layer?.backgroundColor = pillColor.cgColor
        layer?.borderWidth = showsDot ? 1 : 0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard allowsHover else { return }
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard allowsHover, isEnabled else { return }
        layer?.backgroundColor = pillColor.blended(withFraction: 0.16, of: .white)?.cgColor ?? pillColor.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowRadius = 6
        layer?.shadowOffset = NSSize(width: 0, height: -2)
    }

    override func mouseExited(with event: NSEvent) {
        guard allowsHover else { return }
        layer?.backgroundColor = pillColor.cgColor
        layer?.shadowOpacity = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        if showsDot {
            NSColor.white.withAlphaComponent(0.72).setFill()
            NSBezierPath(ovalIn: NSRect(x: 15, y: (bounds.height - 6) / 2, width: 6, height: 6)).fill()
        }
        super.draw(dirtyRect)
    }
}

final class AccountMoreButton: NSButton {
    private let tintColor: NSColor
    private let badgeLabel: String
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, tintColor: NSColor, label: String) {
        self.tintColor = tintColor
        self.badgeLabel = String(label.prefix(4)).uppercased()
        super.init(frame: frame)
        title = ""
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.065).cgColor
        layer?.borderWidth = 1.2
        layer?.borderColor = tintColor.withAlphaComponent(0.30).cgColor
        toolTip = "Edit account label"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = tintColor.withAlphaComponent(0.13).cgColor
        layer?.borderColor = tintColor.withAlphaComponent(0.52).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
        layer?.borderColor = tintColor.withAlphaComponent(0.30).cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let fontSize: CGFloat
        switch badgeLabel.count {
        case 0, 1:
            fontSize = 16
        case 2:
            fontSize = 14
        case 3:
            fontSize = 12.5
        default:
            fontSize = 11
        }
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: tintColor.withAlphaComponent(0.96)
        ]
        let attributed = NSAttributedString(string: badgeLabel, attributes: labelAttributes)
        let labelSize = attributed.size()
        attributed.draw(at: NSPoint(x: (bounds.width - labelSize.width) / 2, y: (bounds.height - labelSize.height) / 2))
    }
}

final class SettingsActionButton: NSButton {
    private let fillColor: NSColor
    private let textColor: NSColor
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, title: String, color: NSColor, textColor: NSColor) {
        self.fillColor = color
        self.textColor = textColor
        super.init(frame: frame)
        self.title = title
        bezelStyle = .rounded
        isBordered = false
        font = .systemFont(ofSize: min(12, max(10, frame.height * 0.42)), weight: .semibold)
        contentTintColor = textColor
        wantsLayer = true
        layer?.cornerRadius = min(12, frame.height / 2)
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = textColor.withAlphaComponent(0.08).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        layer?.backgroundColor = fillColor.blended(withFraction: 0.10, of: .white)?.cgColor ?? fillColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = fillColor.cgColor
    }
}

private extension NSRect {
    func roundedPath(radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
    }
}

private extension DateFormatter {
    static let resetCreditISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let resetCreditDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static let apiDayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static let apiBackupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}

final class AccountFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var accountPanel: NSPanel?
    private var accountPanelMode: AccountPanelMode = .usage
    private let timerTickInterval: TimeInterval = 5
    private let labelsDefaultsKey = "accountDisplayLabels"
    private let remindersEnabledDefaultsKey = "usageReminderEnabled"
    private let reminderThresholdDefaultsKey = "usageReminderThreshold"
    private let autoSwitchEnabledDefaultsKey = "autoSwitchEnabled"
    private let autoSwitchThresholdDefaultsKey = "autoSwitchThreshold"
    private let autoSwitchModeDefaultsKey = "autoSwitchMode"
    private let autoResumeModeDefaultsKey = "autoResumeMode"
    private let autoResumePromptDefaultsKey = "autoResumePrompt"
    private let confirmBeforeSwitchingDefaultsKey = "confirmBeforeSwitching"
    private let refreshIntervalDefaultsKey = "refreshIntervalSeconds"
    private let idleRefreshIntervalDefaultsKey = "idleRefreshIntervalSeconds"
    private let protectFrontmostCodexDefaultsKey = "protectFrontmostCodex"
    private let toolbarDisplayStyleDefaultsKey = "toolbarDisplayStyle"
    private let selectedRouteBProfileDefaultsKey = "selectedRouteBProfileID"
    private let apiDailyLimitDefaultsKey = "apiDailyLimitTokens"
    private let apiWarningPercentDefaultsKey = "apiWarningPercent"
    private let apiUsageNotificationDefaultsKey = "apiUsageNotificationEnabled"
    private let apiModeActiveDefaultsKey = "apiModeActive"
    private let apiTokenUsageService = "com.mohamedfuad.codexaccountswitcher.openai"
    private let apiCodexKeyAccount = "codex-api-key"
    private let apiUsageKeyAccount = "usage-api-key"
    private let autoSwitchNotificationCategory = "AUTO_SWITCH_CONFIRM"
    private let resumeNotificationCategory = "AUTO_RESUME_CONFIRM"
    private let switchNowActionIdentifier = "SWITCH_NOW"
    private let resumeNowActionIdentifier = "RESUME_NOW"
    private let cancelResumeActionIdentifier = "CANCEL_RESUME"
    private let autoResumeCodexReadyDelay: TimeInterval = 3.0
    private let launchAgentIdentifier = "com.mohamedfuad.codexaccountswitcher"
    private var refreshTimer: Timer?
    private var statusAnimationTimer: Timer?
    private var statusAnimationFrame = 0
    private var currentStatusTitleKey = ""
    private var currentStatusItemLength: CGFloat = 0
    private var accounts: [CodexAccount] = []
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var lastRefreshStartedAt: Date?
    private var lastUsageRefreshWasLocalOnly = false
    private var isRefreshing = false
    private var pendingForceRefresh = false
    private var isSwitching = false
    private var armedSwitchEmail: String?
    private var armedSwitchClearWorkItem: DispatchWorkItem?
    private var switchAnimationTimer: Timer?
    private var switchAnimationFrame = 0
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var didResignActiveObserver: NSObjectProtocol?
    private var suppressStatusToggleOpenUntil: Date?
    private var switchingTitle = "Switching"
    private let switchAnimationFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private let statusPulseFrames = ["·", "•", "·", " "]
    private var notifiedLowUsageKeys = Set<String>()
    private var notifiedAutoSwitchPauseKeys = Set<String>()
    private var notifiedApiUsageKeys = Set<String>()
    private var pendingResumeWorkItems: [String: DispatchWorkItem] = [:]
    private var settingsMenu = NSMenu()
    private weak var accountLabelDialogField: NSTextField?
    private weak var accountLabelDialogPopup: NSPopUpButton?
    private var notificationHealthTitle = "Checking"
    private var notificationHealthColor = NSColor.systemOrange
    private var updateHealthTitle = "Check"
    private var updateHealthColor = NSColor.systemOrange
    private var latestReleaseURL: URL?
    private var resetCreditsByEmail: [String: ResetCreditsSnapshot] = [:]
    private var remindersEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: remindersEnabledDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: remindersEnabledDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: remindersEnabledDefaultsKey)
        }
    }
    private var reminderThreshold: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: reminderThresholdDefaultsKey)
            return stored == 0 ? 10 : max(1, min(99, stored))
        }
        set {
            UserDefaults.standard.set(max(1, min(99, newValue)), forKey: reminderThresholdDefaultsKey)
        }
    }
    private var autoSwitchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoSwitchModeDefaultsKey) != nil {
                return autoSwitchMode != .off
            }
            return UserDefaults.standard.bool(forKey: autoSwitchEnabledDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoSwitchEnabledDefaultsKey)
            autoSwitchMode = newValue ? .ask : .off
        }
    }
    private var autoSwitchMode: AutoSwitchMode {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: autoSwitchModeDefaultsKey),
               let mode = AutoSwitchMode(rawValue: rawValue) {
                return mode
            }
            return UserDefaults.standard.bool(forKey: autoSwitchEnabledDefaultsKey) ? .ask : .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: autoSwitchModeDefaultsKey)
            UserDefaults.standard.set(newValue != .off, forKey: autoSwitchEnabledDefaultsKey)
        }
    }
    private var autoSwitchThreshold: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: autoSwitchThresholdDefaultsKey)
            return stored == 0 ? 10 : max(1, min(99, stored))
        }
        set {
            UserDefaults.standard.set(max(1, min(99, newValue)), forKey: autoSwitchThresholdDefaultsKey)
        }
    }
    private var autoResumeMode: AutoResumeMode {
        get {
            AutoResumeMode(rawValue: UserDefaults.standard.string(forKey: autoResumeModeDefaultsKey) ?? "") ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: autoResumeModeDefaultsKey)
        }
    }
    private var autoResumePrompt: String {
        get {
            let stored = UserDefaults.standard.string(forKey: autoResumePromptDefaultsKey) ?? ""
            return stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Carry on working from where you left off."
                : stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? "Carry on working from where you left off." : trimmed, forKey: autoResumePromptDefaultsKey)
        }
    }
    private var confirmBeforeSwitching: Bool {
        get {
            UserDefaults.standard.bool(forKey: confirmBeforeSwitchingDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: confirmBeforeSwitchingDefaultsKey)
        }
    }
    private var activeRefreshInterval: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: refreshIntervalDefaultsKey)
            return stored == 0 ? 5 : normalizedRefreshInterval(stored)
        }
        set {
            UserDefaults.standard.set(normalizedRefreshInterval(newValue), forKey: refreshIntervalDefaultsKey)
        }
    }
    private var idleRefreshInterval: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: idleRefreshIntervalDefaultsKey)
            return stored == 0 ? 30 : normalizedRefreshInterval(stored)
        }
        set {
            UserDefaults.standard.set(normalizedRefreshInterval(newValue), forKey: idleRefreshIntervalDefaultsKey)
        }
    }
    private var protectFrontmostCodex: Bool {
        get {
            if UserDefaults.standard.object(forKey: protectFrontmostCodexDefaultsKey) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: protectFrontmostCodexDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: protectFrontmostCodexDefaultsKey)
        }
    }
    private var usageMode: UsageDisplayMode {
        get {
            UsageDisplayMode(rawValue: UserDefaults.standard.string(forKey: "usageDisplayMode") ?? "") ?? .weekly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "usageDisplayMode")
        }
    }
    private var toolbarDisplayStyle: ToolbarDisplayStyle {
        get {
            ToolbarDisplayStyle(rawValue: UserDefaults.standard.string(forKey: toolbarDisplayStyleDefaultsKey) ?? "") ?? .detailed
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: toolbarDisplayStyleDefaultsKey)
        }
    }
    private var apiDailyLimit: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: apiDailyLimitDefaultsKey)
            return stored == 0 ? 50_000 : max(1_000, stored)
        }
        set {
            UserDefaults.standard.set(max(1_000, newValue), forKey: apiDailyLimitDefaultsKey)
        }
    }
    private var apiWarningPercent: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: apiWarningPercentDefaultsKey)
            return stored == 0 ? 80 : max(1, min(99, stored))
        }
        set {
            UserDefaults.standard.set(max(1, min(99, newValue)), forKey: apiWarningPercentDefaultsKey)
        }
    }
    private var apiUsageNotificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: apiUsageNotificationDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: apiUsageNotificationDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiUsageNotificationDefaultsKey)
        }
    }
    private var apiModeActive: Bool {
        get { false }
        set {
            if !newValue {
                UserDefaults.standard.set(false, forKey: apiModeActiveDefaultsKey)
            }
        }
    }
    private var apiUsedTokens: Int = 0
    private var apiUsageLastError: String?
    private var apiUsageUpdatedAt: Date?
    private var demoMode: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO"] == "1"
    }
    private var showPanelOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_PANEL"] == "1"
    }
    private var showSettingsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_SETTINGS"] == "1"
    }
    private var showRouteBOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_ROUTE_B"] == "1"
    }
    private var showResetsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_RESETS"] == "1"
    }

    private func disableApiMode() {
        UserDefaults.standard.set(false, forKey: apiModeActiveDefaultsKey)
        deleteKeychainSecret(account: apiCodexKeyAccount)
        deleteKeychainSecret(account: apiUsageKeyAccount)
        apiUsedTokens = 0
        apiUsageLastError = nil
        apiUsageUpdatedAt = nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        disableApiMode()
        configureNotifications()
        configureStatusButton()
        refreshAccounts(force: true)
        if showPanelOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showAccountPanel()
            }
            if showResetsOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.showResetCreditsPanel()
                }
            } else if showRouteBOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.showRouteBPanel()
                }
            } else if showSettingsOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.showSettingsPanel()
                }
            }
        }
        let timer = Timer(timeInterval: timerTickInterval, repeats: true) { [weak self] _ in
            self?.refreshAccountsIfNeeded()
        }
        RunLoop.current.add(timer, forMode: .common)
        refreshTimer = timer

        let animationTimer = Timer(timeInterval: 0.65, repeats: true) { [weak self] _ in
            self?.advanceStatusAnimation()
        }
        RunLoop.current.add(animationTimer, forMode: .common)
        statusAnimationTimer = animationTimer
        installPanelDismissHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
        if let didResignActiveObserver {
            NotificationCenter.default.removeObserver(didResignActiveObserver)
        }
    }

    private func installPanelDismissHandlers() {
        didResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.accountPanel?.isVisible == true, self.mouseIsOverStatusButton() {
                self.suppressStatusToggleOpenUntil = Date().addingTimeInterval(0.5)
            }
            self.closeAccountPanel()
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if self.accountPanel?.isVisible == true, self.mouseIsOverStatusButton() {
                self.suppressStatusToggleOpenUntil = Date().addingTimeInterval(0.5)
                self.closeAccountPanel()
            }
            return event
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.accountPanel?.isVisible == true, self.mouseIsOverStatusButton() {
                    self.suppressStatusToggleOpenUntil = Date().addingTimeInterval(0.5)
                }
                self.closeAccountPanel()
            }
        }
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let switchNow = UNNotificationAction(
            identifier: switchNowActionIdentifier,
            title: "Switch Now",
            options: [.foreground]
        )
        let later = UNNotificationAction(identifier: "LATER", title: "Later", options: [])
        let switchCategory = UNNotificationCategory(
            identifier: autoSwitchNotificationCategory,
            actions: [switchNow, later],
            intentIdentifiers: [],
            options: []
        )
        let resumeNow = UNNotificationAction(
            identifier: resumeNowActionIdentifier,
            title: "Resume Now",
            options: [.foreground]
        )
        let cancelResume = UNNotificationAction(identifier: cancelResumeActionIdentifier, title: "Cancel", options: [])
        let resumeCategory = UNNotificationCategory(
            identifier: resumeNotificationCategory,
            actions: [resumeNow, cancelResume],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([switchCategory, resumeCategory])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            self?.refreshNotificationHealth(rebuildVisiblePanel: true)
        }
        refreshNotificationHealth()
    }

    private func refreshNotificationHealth(rebuildVisiblePanel: Bool = false) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized:
                    self.notificationHealthTitle = "Allowed"
                    self.notificationHealthColor = .systemGreen
                case .provisional:
                    self.notificationHealthTitle = "Quiet"
                    self.notificationHealthColor = .systemGreen
                case .notDetermined:
                    self.notificationHealthTitle = "Ask"
                    self.notificationHealthColor = .systemOrange
                case .denied:
                    self.notificationHealthTitle = "Off"
                    self.notificationHealthColor = .systemRed
                @unknown default:
                    self.notificationHealthTitle = "Unknown"
                    self.notificationHealthColor = .systemOrange
                }

                if rebuildVisiblePanel, self.accountPanel?.isVisible == true {
                    self.refreshAccountPanelContent()
                }
            }
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.toolTip = "Codex Account Switcher"
        button.image = nil
        button.imagePosition = .noImage
        button.target = self
        button.action = #selector(toggleAccountPanel)
    }

    private func loadCodexIcon() -> NSImage? {
        let bundledCandidates = [
            Bundle.main.path(forResource: "ToolbarIcon", ofType: "png"),
            Bundle.main.path(forResource: "AccountSwitcherIcon", ofType: "png"),
            Bundle.main.path(forResource: "AccountSwitcherIcon", ofType: "icns")
        ].compactMap { $0 }
        let candidates = bundledCandidates + [
            "\(codexDesktopAppPath)/Contents/Resources/icon.icns",
            "\(codexDesktopAppPath)/Contents/Resources/codexTemplate@2x.png",
            "\(codexDesktopAppPath)/Contents/Resources/codexTemplate.png"
        ]

        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let image = NSImage(contentsOfFile: path) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func refreshAccountsIfNeeded() {
        let interval = codexIsFrontmost() ? activeRefreshInterval : idleRefreshInterval
        if let lastRefreshStartedAt,
           Date().timeIntervalSince(lastRefreshStartedAt) < TimeInterval(interval) {
            return
        }
        refreshAccounts(force: false)
    }

    private func refreshAccounts(force: Bool = false) {
        guard !isSwitching else { return }
        if demoMode {
            accounts = demoAccounts()
            resetCreditsByEmail = demoResetCreditsByEmail(for: accounts)
            lastError = nil
            lastUpdatedAt = Date()
            rebuildMenu()
            return
        }
        guard !isRefreshing else {
            if force {
                pendingForceRefresh = true
                rebuildMenu()
            }
            return
        }
        if !force, let lastRefreshStartedAt {
            let interval = codexIsFrontmost() ? activeRefreshInterval : idleRefreshInterval
            if Date().timeIntervalSince(lastRefreshStartedAt) < TimeInterval(interval) {
                return
            }
        }
        isRefreshing = true
        lastRefreshStartedAt = Date()
        if force {
            rebuildMenu()
        }
        DispatchQueue.global(qos: .utility).async {
            var result = self.runCodexAuth(force ? ["list", "--debug"] : ["list"])
            var usedSkipAPI = false
            if result.status != 0 {
                result = self.runCodexAuth(["list", "--skip-api"])
                usedSkipAPI = result.status == 0
            }
            let parsed = result.status == 0 ? self.parseAccounts(result.output, usageIsLive: !usedSkipAPI) : []
            let resetResults = result.status == 0
                ? self.fetchResetCredits(for: parsed)
                : [:]
            DispatchQueue.main.async {
                self.isRefreshing = false
                let newAccounts: [CodexAccount]
                let newError: String?
                if result.status == 0 {
                    newAccounts = parsed
                    newError = parsed.isEmpty ? "No codex-auth accounts found." : nil
                } else {
                    newAccounts = []
                    newError = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let previousResetCredits = self.resetCreditsByEmail
                if result.status == 0 {
                    if usedSkipAPI {
                        self.resetCreditsByEmail = Dictionary(uniqueKeysWithValues: parsed.map { account in
                            (
                                account.email,
                                ResetCreditsSnapshot(
                                    availableCount: nil,
                                    credits: [],
                                    lastUpdatedText: self.lastUpdatedText(),
                                    lastError: "usage refresh was local only"
                                )
                            )
                        })
                    } else {
                        self.resetCreditsByEmail = resetResults
                    }
                }

                let stateChanged = newAccounts != self.accounts || newError != self.lastError || self.resetCreditsByEmail != previousResetCredits
                if result.status == 0 {
                    self.lastUpdatedAt = Date()
                    self.lastUsageRefreshWasLocalOnly = !usedSkipAPI && (result.output.contains("mode=local-only") || !self.apiModeActive)
                }
                if stateChanged || force || self.accountPanel?.isVisible == true {
                    self.accounts = newAccounts
                    self.lastError = newError
                    self.checkUsageReminder()
                    self.checkAutoSwitch()
                    self.rebuildMenu()
                }

                if self.pendingForceRefresh {
                    self.pendingForceRefresh = false
                    self.refreshAccounts(force: true)
                }
            }
        }
    }

    private func refreshApiUsage(force: Bool = false) {
        disableApiMode()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let active = accounts.first(where: { $0.isActive }) {
            if !isSwitching {
                updateStatusTitle()
            }
            menu.addItem(headerItem("Active: \(compactEmail(active.email)) (\(displayPlan(active.plan)))"))
        } else {
            if !isSwitching {
                clearStatusTitle()
            }
            menu.addItem(headerItem(lastError ?? "No active account"))
        }

        menu.addItem(headerItem("Updated: \(lastUpdatedText())"))
        menu.addItem(.separator())

        if accounts.isEmpty {
            let item = NSMenuItem(title: lastError ?? "No accounts available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            menu.addItem(accountColumnsHeaderItem())
            for account in toolbarAccounts() {
                let item = NSMenuItem(title: "", action: #selector(switchAccount(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = account.email
                item.attributedTitle = accountAttributedTitle(for: account)
                item.state = account.isActive ? .on : .off
                item.toolTip = accountUsageTooltip(for: account)
                item.isEnabled = !isSwitching
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Toggle Account", action: #selector(toggleAccount), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = accounts.count == 2 && !isSwitching
        menu.addItem(toggle)

        menu.addItem(.separator())

        let addAccount = NSMenuItem(title: "Add Account...", action: #selector(addAccountBrowser), keyEquivalent: "")
        addAccount.target = self
        addAccount.isEnabled = !isSwitching
        menu.addItem(addAccount)

        let addDevice = NSMenuItem(title: "Add Account with Device Code...", action: #selector(addAccountDeviceCode), keyEquivalent: "")
        addDevice.target = self
        addDevice.isEnabled = !isSwitching
        addDevice.toolTip = "Opens Terminal so the device code remains visible while login waits."
        menu.addItem(addDevice)

        if !accounts.isEmpty {
            let labelsItem = NSMenuItem(title: "Account Display Labels", action: #selector(showAccountDisplayLabelsDialog), keyEquivalent: "")
            labelsItem.target = self
            menu.addItem(labelsItem)

            let displayItem = NSMenuItem(title: "Menu Bar Display", action: #selector(showMenuBarDisplayDialog), keyEquivalent: "")
            displayItem.target = self
            menu.addItem(displayItem)

            let removeItem = NSMenuItem(title: "Remove Account", action: #selector(showRemoveAccountDialog), keyEquivalent: "")
            removeItem.target = self
            removeItem.isEnabled = !isSwitching
            menu.addItem(removeItem)
        }

        let reminderItem = NSMenuItem(title: "Usage Reminder", action: #selector(showUsageReminderDialog), keyEquivalent: "")
        reminderItem.target = self
        menu.addItem(reminderItem)

        let confirmItem = NSMenuItem(title: "Confirm Panel Switches", action: #selector(toggleConfirmBeforeSwitching), keyEquivalent: "")
        confirmItem.target = self
        confirmItem.state = confirmBeforeSwitching ? .on : .off
        confirmItem.isEnabled = !isSwitching
        menu.addItem(confirmItem)

        let refreshSettings = NSMenuItem(title: "Refresh Settings", action: #selector(showRefreshSettingsDialog), keyEquivalent: "")
        refreshSettings.target = self
        menu.addItem(refreshSettings)

        let refresh = NSMenuItem(title: "Force Usage Refresh", action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self
        refresh.toolTip = "Refreshes the active account now; inactive account usage updates after switching."
        refresh.isEnabled = !isSwitching
        menu.addItem(refresh)

        let updates = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesMenu), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let cleanBackups = NSMenuItem(title: "Clean Account Backups", action: #selector(cleanAccountBackups), keyEquivalent: "")
        cleanBackups.target = self
        cleanBackups.isEnabled = !isSwitching
        menu.addItem(cleanBackups)

        let quit = NSMenuItem(title: "Quit Account Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quit)

        settingsMenu = menu
        statusItem.menu = nil
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
        } else {
            accountPanel = nil
        }
    }

    @objc private func toggleAccountPanel() {
        if accountPanel?.isVisible == true {
            closeAccountPanel()
            return
        }
        if let suppressUntil = suppressStatusToggleOpenUntil, Date() < suppressUntil {
            suppressStatusToggleOpenUntil = nil
            return
        }
        showAccountPanel()
    }

    private func mouseIsOverStatusButton() -> Bool {
        guard let button = statusItem.button,
              let window = button.window else {
            return false
        }
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = window.convertToScreen(buttonFrameInWindow).insetBy(dx: -6, dy: -6)
        return buttonFrame.contains(NSEvent.mouseLocation)
    }

    private func showAccountPanel() {
        accountPanelMode = .usage
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent()
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func showSettingsPanel() {
        accountPanelMode = .settings
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent()
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func showRouteBPanel() {
        accountPanelMode = .routeB
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent()
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    @objc private func showApiModePanel() {
        showAccountPanel()
    }

    @objc private func switchToApiModeFromMenu() {
        disableApiMode()
        showAccountPanel()
    }

    private func makeAccountPanel() -> NSPanel {
        let panel = AccountFloatingPanel(
            contentRect: NSRect(origin: .zero, size: currentAccountPanelSize()),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func currentAccountPanelSize() -> NSSize {
        AccountSwitcherPanelView.preferredSize(mode: accountPanelMode, accountCount: toolbarAccounts().count)
    }

    private func refreshAccountPanelContent() {
        refreshNotificationHealth()
        let panel = AccountSwitcherPanelView(
            accounts: toolbarAccounts(),
            activeAccount: accounts.first(where: { $0.isActive }),
            mode: accountPanelMode,
            lastUpdatedText: lastUpdatedText(),
            lastError: lastError,
            isSwitching: isSwitching,
            launchAtLoginEnabled: launchAtLoginEnabled(),
            remindersEnabled: remindersEnabled,
            reminderThreshold: reminderThreshold,
            autoSwitchEnabled: autoSwitchEnabled,
            autoSwitchThreshold: autoSwitchThreshold,
            autoSwitchMode: autoSwitchMode,
            autoResumeMode: autoResumeMode,
            confirmBeforeSwitching: confirmBeforeSwitching,
            armedSwitchEmail: armedSwitchEmail,
            protectFrontmostCodex: protectFrontmostCodex,
            apiModeActive: apiModeActive,
            apiKeyConfigured: apiKeyConfigured(),
            usageKeyConfigured: usageKeyConfigured(),
            apiUsage: apiUsageSnapshot(),
            resetCreditsByEmail: resetCreditsByEmail,
            healthStatuses: healthStatusRows(),
            routeBProfiles: routeBProviderProfiles,
            selectedRouteBProfileID: UserDefaults.standard.string(forKey: selectedRouteBProfileDefaultsKey),
            usageMode: usageMode,
            toolbarDisplayStyle: toolbarDisplayStyle,
            activeRefreshInterval: activeRefreshInterval,
            idleRefreshInterval: idleRefreshInterval,
            labelForAccount: { [weak self] account in
                self?.toolbarLabel(for: account) ?? String(account.selector.prefix(1))
            },
            compactEmail: { [weak self] email in
                self?.compactEmail(email) ?? email
            },
            switchAccount: { [weak self] email in
                self?.handlePanelSwitchRequest(email)
            },
            refresh: { [weak self] in
                self?.refreshAccounts(force: true)
            },
            showSettings: { [weak self] in
                self?.showSettingsPanel()
            },
            checkUpdates: { [weak self] in
                self?.checkForUpdates(showResult: true)
            },
            editAccountLabel: { [weak self] email in
                self?.showAccountDisplayLabelsDialogForAccount(email)
            },
            showResetCredits: { [weak self] in
                self?.showResetCreditsPanel()
            },
            redeemResetCredit: { [weak self] email, creditID in
                self?.redeemResetCreditFromPanel(email: email, creditID: creditID)
            },
            selectRouteBProfile: { [weak self] profileID in
                self?.selectRouteBProfile(profileID)
            },
            performSettingsAction: { [weak self] action in
                self?.handleSettingsPanelAction(action)
            },
            close: {
                NSApp.terminate(nil)
            },
            toggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            }
        )
        let controller = NSViewController()
        controller.view = panel
        accountPanel?.contentViewController = controller
    }

    private func handlePanelSwitchRequest(_ email: String) {
        guard !isSwitching else { return }
        if confirmBeforeSwitching {
            if armedSwitchEmail == email {
                clearArmedSwitch()
                closeAccountPanel()
                switchTo(query: email)
            } else {
                armSwitchConfirmation(for: email)
            }
            return
        }

        closeAccountPanel()
        switchTo(query: email)
    }

    private func armSwitchConfirmation(for email: String) {
        armedSwitchClearWorkItem?.cancel()
        armedSwitchEmail = email
        refreshAccountPanelContent()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.armedSwitchEmail == email else { return }
            self.armedSwitchEmail = nil
            if self.accountPanel?.isVisible == true {
                self.refreshAccountPanelContent()
            }
        }
        armedSwitchClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    private func clearArmedSwitch() {
        armedSwitchClearWorkItem?.cancel()
        armedSwitchClearWorkItem = nil
        armedSwitchEmail = nil
    }

    private func healthStatusRows() -> [HealthStatus] {
        let codexAuthOK = codexAuthPath() != nil
        let codexAppOK = FileManager.default.fileExists(atPath: codexDesktopAppPath)
        return [
            HealthStatus(title: "Auth", value: codexAuthOK ? "OK" : "Missing", color: codexAuthOK ? .systemGreen : .systemRed),
            HealthStatus(title: "Codex", value: codexAppOK ? "Found" : "Missing", color: codexAppOK ? .systemGreen : .systemRed),
            HealthStatus(title: "Mode", value: "ChatGPT", color: .systemGreen),
            HealthStatus(title: "Refresh", value: lastUpdatedText(), color: refreshHealthColor()),
            HealthStatus(title: "Notify", value: notificationHealthTitle, color: notificationHealthColor),
            HealthStatus(title: "Update", value: updateHealthTitle, color: updateHealthColor)
        ]
    }

    private func positionAccountPanel() {
        guard let panel = accountPanel else { return }

        guard let button = statusItem.button,
              let window = button.window,
              let screen = window.screen ?? NSScreen.main else {
            positionAccountPanelAtScreenFallback(panel)
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = window.convertToScreen(buttonFrameInWindow)
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 8
        let panelSize = currentAccountPanelSize()

        var x = buttonFrame.midX - panelSize.width / 2
        x = max(visibleFrame.minX + margin, min(x, visibleFrame.maxX - panelSize.width - margin))

        var y = buttonFrame.minY - panelSize.height - margin
        if y < visibleFrame.minY + margin {
            y = min(buttonFrame.maxY + margin, visibleFrame.maxY - panelSize.height - margin)
        }

        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    private func positionAccountPanelAtScreenFallback(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 12
        let panelSize = currentAccountPanelSize()
        let x = visibleFrame.maxX - panelSize.width - margin
        let y = visibleFrame.maxY - panelSize.height - margin
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    private func closeAccountPanel() {
        clearArmedSwitch()
        accountPanel?.orderOut(nil)
    }

    private func handleSettingsPanelAction(_ action: SettingsPanelAction) {
        switch action {
        case .usageView:
            accountPanelMode = .usage
            refreshAccountPanelContent()
        case .settingsView:
            accountPanelMode = .settings
            refreshAccountPanelContent()
        case .routeBView:
            accountPanelMode = .routeB
            refreshAccountPanelContent()
        case .resetCreditsView:
            accountPanelMode = .resets
            refreshAccountPanelContent()
        case .apiView:
            accountPanelMode = .usage
            refreshAccountPanelContent()
        case .addAccount:
            addAccountBrowser()
        case .addDeviceAccount:
            addAccountDeviceCode()
        case .setupApiMode:
            disableApiMode()
            showAlert(title: "API mode removed", message: "This build only switches between saved ChatGPT accounts.")
        case .switchApiMode:
            disableApiMode()
            showAlert(title: "API mode removed", message: "This build only switches between saved ChatGPT accounts.")
        case .editApiLimit:
            disableApiMode()
        case .refreshApiUsage:
            disableApiMode()
        case .testApiReminder:
            disableApiMode()
        case .editLabels:
            showAccountDisplayLabelsDialog()
        case .removeAccount:
            showRemoveAccountDialog()
        case .usageWeekly:
            usageMode = .weekly
            rebuildMenu()
        case .usageFiveHour:
            usageMode = .fiveHour
            rebuildMenu()
        case .styleDetailed:
            toolbarDisplayStyle = .detailed
            rebuildMenu()
        case .styleCompact:
            toolbarDisplayStyle = .compact
            rebuildMenu()
        case .toggleLaunchAtLogin:
            toggleLaunchAtLogin()
        case .toggleUsageReminder:
            toggleUsageReminder()
        case .editUsageReminder:
            showUsageReminderDialog()
        case .toggleAutoSwitch:
            toggleAutoSwitch()
        case .editAutoSwitch:
            showAutoSwitchDialog()
        case .editAutoResume:
            showAutoResumeDialog()
        case .toggleConfirmSwitch:
            toggleConfirmBeforeSwitching()
        case .toggleProtectCodex:
            toggleProtectFrontmostCodex()
        case .editRefresh:
            showRefreshSettingsDialog()
        case .forceRefresh:
            refreshNow()
        case .checkUpdates:
            checkForUpdates(showResult: true)
        case .cleanBackups:
            cleanAccountBackups()
        case .quit:
            NSApp.terminate(nil)
        }
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
        }
    }

    private func selectRouteBProfile(_ profileID: String) {
        guard routeBProviderProfiles.contains(where: { $0.id == profileID }) else { return }
        UserDefaults.standard.set(profileID, forKey: selectedRouteBProfileDefaultsKey)
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
        }
    }

    private func showResetCreditsPanel() {
        accountPanelMode = .resets
        refreshAccountPanelContent()
    }

    private func redeemResetCreditFromPanel(email: String, creditID: String) {
        guard
            let account = accounts.first(where: { $0.email == email }),
            let credit = resetCreditsByEmail[email]?.credits.first(where: { $0.id == creditID })
        else {
            showAlert(title: "Reset unavailable", message: "The selected reset credit could not be found. Refresh the switcher and try again.")
            return
        }

        confirmAndRedeemResetCredit(account: account, credit: credit)
    }

    private func showSettingsMenu(from sender: NSView) {
        settingsMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    private func showSettingsMenuForScreenshot() {
        guard demoMode, let panel = accountPanel else { return }
        let point = NSPoint(x: panel.frame.maxX - 190, y: panel.frame.maxY - 96)
        settingsMenu.popUp(positioning: nil, at: point, in: nil)
    }

    private func showResetCreditsMenu(from sender: NSView) {
        let menu = NSMenu()
        let header = NSMenuItem(title: resetCreditsMenuHeader(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for (accountIndex, account) in toolbarAccounts().enumerated() {
            if accountIndex > 0 {
                menu.addItem(.separator())
            }

            let snapshot = resetCreditsByEmail[account.email]
            let count = snapshot?.displayCount
            let accountHeader = NSMenuItem(title: resetAccountHeaderTitle(account, count: count), action: nil, keyEquivalent: "")
            accountHeader.isEnabled = false
            menu.addItem(accountHeader)

            if let error = snapshot?.lastError {
                let item = NSMenuItem(title: "Unavailable: \(error)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
                continue
            }

            guard let snapshot else {
                let item = NSMenuItem(title: "Checking reset credits...", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
                continue
            }

            let credits = snapshot.availableCredits.sorted { left, right in
                switch (left.expiresAt, right.expiresAt) {
                case let (left?, right?):
                    return left < right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
            }

            if credits.isEmpty {
                let item = NSMenuItem(title: "No available reset credits", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for (index, credit) in credits.enumerated() {
                    let title = resetCreditMenuTitle(credit, index: index + 1)
                    let item = NSMenuItem(title: title, action: #selector(redeemResetCreditMenuItem(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = resetCreditActionPayload(email: account.email, creditID: credit.id)
                    item.toolTip = "Redeem this reset credit after confirmation"
                    menu.addItem(item)
                }
            }
        }

        menu.addItem(.separator())
        let updated = NSMenuItem(title: resetCreditsUpdatedText(), action: nil, keyEquivalent: "")
        updated.isEnabled = false
        menu.addItem(updated)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    private func resetCreditsMenuHeader() -> String {
        let counts = toolbarAccounts().compactMap { resetCreditsByEmail[$0.email]?.displayCount }
        guard !counts.isEmpty else {
            return "Codex reset credits"
        }
        let total = counts.reduce(0, +)
        return total == 1 ? "1 Codex reset available" : "\(total) Codex resets available"
    }

    private func resetAccountHeaderTitle(_ account: CodexAccount, count: Int?) -> String {
        let label = toolbarLabel(for: account)
        let countText: String
        if let count {
            countText = count == 1 ? "1 reset" : "\(count) resets"
        } else {
            countText = "checking"
        }
        return "\(label)  \(compactEmail(account.email))  -  \(countText)"
    }

    private func resetCreditMenuTitle(_ credit: ResetCredit, index: Int) -> String {
        let granted = credit.grantedAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown grant"
        let expires = credit.expiresAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown expiry"
        return "#\(index)  Redeem reset  -  granted \(granted), expires \(expires)"
    }

    private func resetCreditsUpdatedText() -> String {
        let updates = toolbarAccounts().compactMap { resetCreditsByEmail[$0.email]?.lastUpdatedText }
        let unique = Array(Set(updates))
        if unique.count == 1, let first = unique.first {
            return "Updated \(first)"
        }
        if updates.isEmpty {
            return "Updated never"
        }
        return "Updated per account"
    }

    private func resetCreditActionPayload(email: String, creditID: String) -> String {
        "\(email)\u{1F}\(creditID)"
    }

    private func resetCreditActionParts(from payload: String) -> (email: String, creditID: String)? {
        let parts = payload.split(separator: "\u{1F}", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    @objc private func redeemResetCreditMenuItem(_ sender: NSMenuItem) {
        guard
            let payload = sender.representedObject as? String,
            let action = resetCreditActionParts(from: payload),
            let account = accounts.first(where: { $0.email == action.email }),
            let credit = resetCreditsByEmail[action.email]?.credits.first(where: { $0.id == action.creditID })
        else {
            showAlert(title: "Reset unavailable", message: "The selected reset credit could not be found. Refresh the switcher and try again.")
            return
        }

        confirmAndRedeemResetCredit(account: account, credit: credit)
    }

    private func confirmAndRedeemResetCredit(account: CodexAccount, credit: ResetCredit) {
        let expires = credit.expiresAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown expiry"
        let alert = NSAlert()
        alert.messageText = "Redeem reset for \(toolbarLabel(for: account))?"
        alert.informativeText = "This will spend one Codex reset credit for \(compactEmail(account.email)) and refresh the account's rate-limit window.\n\nExpires: \(expires)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Redeem Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        redeemResetCredit(account: account, credit: credit)
    }

    private func redeemResetCredit(account: CodexAccount, credit: ResetCredit) {
        closeAccountPanel()
        let label = toolbarLabel(for: account)
        statusItem.button?.title = "\(label) · reset"
        let accountsToRefresh = accounts

        DispatchQueue.global(qos: .utility).async {
            let result = self.consumeResetCredit(email: account.email, creditID: credit.id)
            let resetResults = self.fetchResetCredits(for: accountsToRefresh)
            let usageResult = self.runCodexAuth(["list", "--debug"])
            let parsed = usageResult.status == 0 ? self.parseAccounts(usageResult.output, usageIsLive: true) : accountsToRefresh

            DispatchQueue.main.async {
                self.resetCreditsByEmail = resetResults
                if usageResult.status == 0 {
                    self.accounts = parsed
                    self.lastUpdatedAt = Date()
                    self.lastError = parsed.isEmpty ? "No codex-auth accounts found." : nil
                }

                switch result {
                case .success(let message):
                    self.rebuildMenu()
                    self.showAlert(title: "Reset redeemed", message: message)
                case .failure(let message):
                    self.rebuildMenu()
                    self.showAlert(title: "Reset failed", message: message)
                }
            }
        }
    }

    private func advanceStatusAnimation() {
        guard !isSwitching, !accounts.isEmpty else { return }
        statusAnimationFrame += 1
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        let title = statusAttributedTitle()
        let titleKey = statusTitleKey()
        let stableLength = statusItemLength(for: title)
        guard titleKey != currentStatusTitleKey || abs(stableLength - currentStatusItemLength) > 0.5 else { return }

        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = title
        statusItem.length = stableLength
        statusItem.button?.needsDisplay = true
        currentStatusTitleKey = titleKey
        currentStatusItemLength = stableLength
    }

    private func clearStatusTitle() {
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        currentStatusTitleKey = ""
        currentStatusItemLength = 0
    }

    private func statusAttributedTitle() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, account) in toolbarStatusAccounts().enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: toolbarTitleAttributes(for: nil)))
            }
            result.append(NSAttributedString(
                string: toolbarStatusText(for: account),
                attributes: toolbarTitleAttributes(for: account)
            ))
        }
        return result
    }

    private func statusTitleKey() -> String {
        toolbarStatusAccounts().map { account in
            [
                toolbarStatusText(for: account),
                account.email,
                account.isActive ? "active" : "inactive",
                accountNeedsLogin(account) ? "login" : "ok",
                "\(toolbarUsagePercent(for: account) ?? -1)",
                usageMode.rawValue,
                toolbarDisplayStyle.rawValue
            ].joined(separator: "|")
        }.joined(separator: "||")
    }

    private func statusItemLength(for title: NSAttributedString) -> CGFloat {
        max(20, ceil(title.size().width) + 1)
    }

    private func toolbarStatusText(for account: CodexAccount) -> String {
        let label = toolbarLabel(for: account)
        let percent = toolbarUsagePercent(for: account)
        switch toolbarDisplayStyle {
        case .detailed:
            return "\(label)\(remainingPercentText(fromUsed: percent))"
        case .compact:
            return "\(label)\(remainingPercentNumberText(fromUsed: percent))"
        }
    }

    private func toolbarTitleAttributes(for account: CodexAccount?) -> [NSAttributedString.Key: Any] {
        let size: CGFloat = toolbarDisplayStyle == .detailed ? 12.5 : 10.5
        let color: NSColor
        if let account, accountNeedsLogin(account) {
            color = .systemRed
        } else if let account, account.isActive {
            color = usageStatusColor(for: toolbarUsagePercent(for: account))
        } else {
            color = NSColor.secondaryLabelColor
        }
        return [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium),
            .foregroundColor: color
        ]
    }

    private func toolbarUsagePercent(for account: CodexAccount) -> Int? {
        switch usageMode {
        case .fiveHour:
            return account.fiveHourUsedPercent
        case .weekly:
            return account.weeklyUsedPercent
        }
    }

    private func toolbarAccounts() -> [CodexAccount] {
        accounts.sorted { left, right in
            let leftPriority = toolbarSortPriority(for: left)
            let rightPriority = toolbarSortPriority(for: right)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return left.email.localizedCaseInsensitiveCompare(right.email) == .orderedAscending
        }
    }

    private func toolbarStatusAccounts() -> [CodexAccount] {
        let sortedAccounts = toolbarAccounts()
        if let active = sortedAccounts.first(where: { $0.isActive }) {
            return [active]
        }
        return sortedAccounts.prefix(1).map { $0 }
    }

    private func apiUsageSnapshot() -> ApiUsageSnapshot {
        ApiUsageSnapshot(
            usedTokens: apiUsedTokens,
            limitTokens: apiDailyLimit,
            warningPercent: apiWarningPercent,
            lastUpdatedText: apiUsageLastUpdatedText(),
            lastError: apiUsageLastError
        )
    }

    private func apiUsageLastUpdatedText() -> String {
        guard let apiUsageUpdatedAt else { return "never" }
        let elapsed = max(0, Int(Date().timeIntervalSince(apiUsageUpdatedAt)))
        if elapsed < 15 { return "just now" }
        if elapsed < 60 { return "\(elapsed)s ago" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    private func apiStatusColor(for percent: Int) -> NSColor {
        if percent >= apiWarningPercent { return .systemRed }
        if percent >= max(1, apiWarningPercent - 20) { return .systemOrange }
        return .systemBlue
    }

    private func toolbarSortPriority(for account: CodexAccount) -> Int {
        switch toolbarLabel(for: account) {
        case "L":
            return 0
        case "A":
            return 1
        default:
            return 10
        }
    }

    private func toolbarLabel(for account: CodexAccount) -> String {
        if let custom = customLabel(forEmail: account.email), !custom.isEmpty {
            return limitedLabel(custom).uppercased()
        }
        return defaultLabel(forEmail: account.email)
    }

    private func codexIsFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return isCodexDesktopApplication(app)
    }

    // ChatGPT Work now contains the Codex desktop surface. Keep the legacy
    // Codex.app fallback so standalone installations remain supported.
    private var codexDesktopAppPath: String {
        if FileManager.default.fileExists(atPath: "/Applications/ChatGPT.app") {
            return "/Applications/ChatGPT.app"
        }
        return "/Applications/Codex.app"
    }

    private var codexDesktopAppName: String {
        URL(fileURLWithPath: codexDesktopAppPath).deletingPathExtension().lastPathComponent
    }

    private var codexDesktopResourcesPath: String {
        "\(codexDesktopAppPath)/Contents/Resources"
    }

    private func isCodexDesktopApplication(_ app: NSRunningApplication) -> Bool {
        let name = app.localizedName?.lowercased() ?? ""
        let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
        return name == "codex" || name == "chatgpt" || bundleIdentifier == "com.openai.codex"
    }

    private func remainingSummary(for account: CodexAccount) -> String {
        switch usageMode {
        case .fiveHour:
            return "5h \(remainingPercentText(fromUsed: account.fiveHourUsedPercent)) left"
        case .weekly:
            return "W \(remainingPercentText(fromUsed: account.weeklyUsedPercent)) left"
        }
    }

    private func remainingPercentText(fromUsed used: Int?) -> String {
        guard let used else { return "--%" }
        return "\(max(0, min(100, used)))%"
    }

    private func remainingPercentNumberText(fromUsed used: Int?) -> String {
        guard let used else { return "--" }
        return "\(max(0, min(100, used)))"
    }

    private func usageModeItem(title: String, percent: String, reset: String, mode: UsageDisplayMode) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(setUsageMode(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode.rawValue
        item.state = usageMode == mode ? .on : .off
        item.attributedTitle = usageAttributedTitle(title: title, percent: percent, reset: reset)
        return item
    }

    private func toolbarDisplayStyleItem(title: String, style: ToolbarDisplayStyle) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setToolbarDisplayStyle(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = style.rawValue
        item.state = toolbarDisplayStyle == style ? .on : .off
        return item
    }

    private func accountPopup(width: CGFloat) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 26), pullsDown: false)
        for account in toolbarAccounts() {
            addPopupItem(
                to: popup,
                title: "\(toolbarLabel(for: account))  \(compactEmail(account.email))",
                representedObject: account.email
            )
        }
        if let active = accounts.first(where: { $0.isActive }) {
            popup.selectItem(withTitle: "\(toolbarLabel(for: active))  \(compactEmail(active.email))")
        }
        return popup
    }

    private func refreshIntervalPopup(width: CGFloat, values: [Int], selected: Int) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 26), pullsDown: false)
        for value in values {
            addPopupItem(to: popup, title: "\(value)s", representedObject: value)
        }
        popup.selectItem(withTitle: "\(selected)s")
        return popup
    }

    private func addPopupItem(to popup: NSPopUpButton, title: String, representedObject: Any) {
        popup.addItem(withTitle: title)
        popup.lastItem?.representedObject = representedObject
    }

    private func selectPopupItem(_ popup: NSPopUpButton, representedObject: Any) {
        for item in popup.itemArray where String(describing: item.representedObject ?? "") == String(describing: representedObject) {
            popup.select(item)
            return
        }
    }

    private func selectedAccountEmail(from popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func settingsRow(label: String, control: NSView) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.frame = NSRect(x: 0, y: 0, width: 110, height: 24)
        let row = NSStackView(views: [labelView, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.frame = NSRect(x: 0, y: 0, width: 250, height: 26)
        return row
    }

    private func usageAttributedTitle(title: String, percent: String, reset: String) -> NSAttributedString {
        attributedColumns(
            "\(title)\t\(percent)\t\(reset)",
            tabs: [112, 162],
            font: NSFont.menuFont(ofSize: 0),
            color: .labelColor
        )
    }

    private func accountColumnsHeaderItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = attributedColumns(
            "\tAccounts:\t5H\tReset\tWeekly",
            tabs: [18, 178, 226, 308],
            font: NSFont.menuFont(ofSize: 0),
            color: .secondaryLabelColor
        )
        return item
    }

    private func accountAttributedTitle(for account: CodexAccount) -> NSAttributedString {
        let label = toolbarLabel(for: account)
        let fiveHourPercent = remainingPercentText(fromUsed: account.fiveHourUsedPercent)
        let fiveHourReset = resetTimeText(from: account.fiveHourUsage)
        let weeklyPercent = remainingPercentText(fromUsed: account.weeklyUsedPercent)
        return attributedColumns(
            "\(label)\t\(compactEmail(account.email))\t\(fiveHourPercent)\t\(fiveHourReset)\t\(weeklyPercent)",
            tabs: [18, 178, 226, 308],
            font: NSFont.menuFont(ofSize: 0),
            color: accountNeedsLogin(account) ? .systemRed : .labelColor
        )
    }

    private func accountNeedsLogin(_ account: CodexAccount) -> Bool {
        account.fiveHourUsage == "Login expired" || account.weeklyUsage == "Login expired"
    }

    private func accountUsageTooltip(for account: CodexAccount) -> String {
        var parts = ["Plan \(account.plan)", "5h \(account.fiveHourUsage)", "weekly \(account.weeklyUsage)"]
        if inactiveLocalUsage(account) {
            parts.append("inactive usage updates after switching")
        }
        return parts.joined(separator: ", ")
    }

    private func inactiveLocalUsage(_ account: CodexAccount) -> Bool {
        lastUsageRefreshWasLocalOnly && !account.isActive
    }

    private func attributedColumns(_ text: String, tabs: [CGFloat], font: NSFont, color: NSColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = tabs.map { NSTextTab(textAlignment: .left, location: $0) }
        paragraph.defaultTabInterval = 48
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func resetTimeText(from usage: String) -> String {
        let inner = parenthesizedValue(from: usage)
        guard let inner else { return "" }
        let parts = inner.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else { return inner }
        let minute = String(parts[1].prefix(2))
        let suffix = hour >= 12 ? "PM" : "AM"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(hour12):\(minute) \(suffix)"
    }

    private func resetDateText(from usage: String) -> String {
        guard let inner = parenthesizedValue(from: usage) else { return "" }
        if let range = inner.range(of: " on ") {
            return monthFirstDate(String(inner[range.upperBound...]))
        }
        let parts = inner.split(separator: " ")
        if parts.count >= 3, let onIndex = parts.firstIndex(of: "on"), onIndex + 2 < parts.endIndex {
            return monthFirstDate("\(parts[onIndex + 1]) \(parts[onIndex + 2])")
        }
        if parts.count >= 2 {
            return monthFirstDate("\(parts[parts.count - 2]) \(parts[parts.count - 1])")
        }
        return inner
    }

    private func monthFirstDate(_ text: String) -> String {
        let parts = text.split(separator: " ")
        guard parts.count == 2 else { return text }

        let day: String
        let month: String
        if parts[0].allSatisfy(\.isNumber) {
            day = String(parts[0])
            month = String(parts[1])
        } else {
            month = String(parts[0])
            day = String(parts[1])
        }

        let months = [
            "Jan": "January", "Feb": "February", "Mar": "March", "Apr": "April",
            "May": "May", "Jun": "June", "Jul": "July", "Aug": "August",
            "Sep": "September", "Oct": "October", "Nov": "November", "Dec": "December"
        ]
        return "\(months[month] ?? month) \(day)"
    }

    private func parenthesizedValue(from usage: String) -> String? {
        guard let open = usage.firstIndex(of: "("),
              let close = usage.firstIndex(of: ")"),
              open < close else { return nil }
        return String(usage[usage.index(after: open)..<close])
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func lastUpdatedText() -> String {
        if isRefreshing {
            return "refreshing..."
        }
        guard let lastUpdatedAt else {
            return "never"
        }
        let elapsed = max(0, Int(Date().timeIntervalSince(lastUpdatedAt)))
        if elapsed < 15 {
            return "just now"
        }
        if elapsed < 60 {
            return "\(elapsed)s ago"
        }
        let minutes = elapsed / 60
        if minutes < 10 {
            return "\(minutes)m ago"
        }
        if minutes < 60 {
            return "stale \(minutes)m"
        }
        return "stale \(minutes / 60)h"
    }

    private func refreshHealthColor() -> NSColor {
        if isRefreshing { return .systemOrange }
        guard let lastUpdatedAt else { return .systemRed }
        let elapsed = Date().timeIntervalSince(lastUpdatedAt)
        if elapsed < 60 { return .systemGreen }
        if elapsed < 600 { return .systemOrange }
        return .systemRed
    }

    private func normalizedRefreshInterval(_ seconds: Int) -> Int {
        [5, 15, 30, 60].contains(seconds) ? seconds : 5
    }

    @objc private func refreshNow() {
        refreshAccounts(force: true)
    }

    @objc private func checkForUpdatesMenu() {
        checkForUpdates(showResult: true)
    }

    private func checkForUpdates(showResult: Bool) {
        guard let url = URL(string: "https://api.github.com/repos/lordydord/Codex-Account-Switcher/releases/latest") else { return }
        updateHealthTitle = "Checking"
        updateHealthColor = .systemOrange
        refreshAccountPanelContentIfVisible()

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.updateHealthTitle = "Error"
                    self.updateHealthColor = .systemRed
                    if showResult {
                        self.showAlert(title: "Update check failed", message: error.localizedDescription)
                    }
                    self.refreshAccountPanelContentIfVisible()
                    return
                }

                guard
                    let data,
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tag = object["tag_name"] as? String
                else {
                    self.updateHealthTitle = "Unknown"
                    self.updateHealthColor = .systemOrange
                    if showResult {
                        self.showAlert(title: "Update check failed", message: "GitHub did not return a readable latest release.")
                    }
                    self.refreshAccountPanelContentIfVisible()
                    return
                }

                let releaseURL = (object["html_url"] as? String).flatMap(URL.init(string:))
                self.latestReleaseURL = releaseURL
                let latestVersion = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let currentVersion = self.currentAppVersion()
                if self.version(latestVersion, isNewerThan: currentVersion) {
                    self.updateHealthTitle = tag
                    self.updateHealthColor = .systemOrange
                    if showResult {
                        self.showUpdateAvailableAlert(tag: tag, currentVersion: currentVersion, url: releaseURL)
                    }
                } else {
                    self.updateHealthTitle = "Current"
                    self.updateHealthColor = .systemGreen
                    if showResult {
                        self.showAlert(title: "Codex Account Switcher is up to date", message: "Installed version \(currentVersion) matches the latest GitHub release.")
                    }
                }
                self.refreshAccountPanelContentIfVisible()
            }
        }.resume()
    }

    private func showUpdateAvailableAlert(tag: String, currentVersion: String, url: URL?) {
        let alert = NSAlert()
        alert.messageText = "Update available"
        alert.informativeText = "Installed version \(currentVersion) can be updated to \(tag)."
        alert.addButton(withTitle: "Open Release")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn, let url {
            NSWorkspace.shared.open(url)
        }
    }

    private func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private func version(_ left: String, isNewerThan right: String) -> Bool {
        let leftParts = left.split(separator: ".").map { Int($0) ?? 0 }
        let rightParts = right.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(leftParts.count, rightParts.count)
        for index in 0..<count {
            let leftValue = index < leftParts.count ? leftParts[index] : 0
            let rightValue = index < rightParts.count ? rightParts[index] : 0
            if leftValue != rightValue {
                return leftValue > rightValue
            }
        }
        return false
    }

    @objc private func setActiveRefreshInterval(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        activeRefreshInterval = seconds
        rebuildMenu()
    }

    @objc private func setIdleRefreshInterval(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        idleRefreshInterval = seconds
        rebuildMenu()
    }

    @objc private func setFiveHourMode() {
        usageMode = .fiveHour
        rebuildMenu()
    }

    @objc private func setUsageMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = UsageDisplayMode(rawValue: rawValue) else { return }
        usageMode = mode
        rebuildMenu()
    }

    @objc private func setToolbarDisplayStyle(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let style = ToolbarDisplayStyle(rawValue: rawValue) else { return }
        toolbarDisplayStyle = style
        rebuildMenu()
    }

    @objc private func showAccountDisplayLabelsDialog() {
        showAccountDisplayLabelsDialogForAccount(nil)
    }

    private func showAccountDisplayLabelsDialogForAccount(_ preferredEmail: String?) {
        guard !accounts.isEmpty else { return }
        let popup = accountPopup(width: 300)
        if let preferredEmail,
           let preferredAccount = accounts.first(where: { $0.email.caseInsensitiveCompare(preferredEmail) == .orderedSame }) {
            popup.selectItem(withTitle: "\(toolbarLabel(for: preferredAccount))  \(compactEmail(preferredAccount.email))")
        }
        accountLabelDialogPopup = popup
        let selectedEmail = selectedAccountEmail(from: popup)
        let selectedAccount = selectedEmail.flatMap { email in accounts.first(where: { $0.email == email }) }
        popup.target = self
        popup.action = #selector(accountLabelPopupChanged(_:))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        accountLabelDialogField = field
        if let selectedAccount {
            field.stringValue = displayLabel(for: selectedAccount)
            field.placeholderString = defaultLabel(forEmail: selectedAccount.email)
        } else {
            field.placeholderString = "A"
        }

        let stack = NSStackView(views: [popup, field])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 58)

        let alert = NSAlert()
        alert.messageText = "Account display label"
        alert.informativeText = "Choose an account and set a label up to four characters. Leave it blank to clear the custom label."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard let email = selectedAccountEmail(from: popup) else { return }
        if response == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                clearCustomLabel(forEmail: email)
            } else {
                setCustomLabel(limitedLabel(value), forEmail: email)
            }
            rebuildMenu()
        } else if response == .alertSecondButtonReturn {
            clearCustomLabel(forEmail: email)
            rebuildMenu()
        }
        accountLabelDialogField = nil
        accountLabelDialogPopup = nil
    }

    @objc private func accountLabelPopupChanged(_ sender: NSPopUpButton) {
        guard let field = accountLabelDialogField,
              let email = selectedAccountEmail(from: sender),
              let account = accounts.first(where: { $0.email == email }) else { return }
        field.stringValue = displayLabel(for: account)
        field.placeholderString = defaultLabel(forEmail: account.email)
    }

    @objc private func showMenuBarDisplayDialog() {
        let usagePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
        addPopupItem(to: usagePopup, title: "Weekly usage left", representedObject: UsageDisplayMode.weekly.rawValue)
        addPopupItem(to: usagePopup, title: "5-hour usage left", representedObject: UsageDisplayMode.fiveHour.rawValue)
        usagePopup.selectItem(withTitle: usageMode == .weekly ? "Weekly usage left" : "5-hour usage left")

        let stylePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
        addPopupItem(to: stylePopup, title: "Large with Percentage", representedObject: ToolbarDisplayStyle.detailed.rawValue)
        addPopupItem(to: stylePopup, title: "Small Number Only", representedObject: ToolbarDisplayStyle.compact.rawValue)
        stylePopup.selectItem(withTitle: toolbarDisplayStyle == .detailed ? "Large with Percentage" : "Small Number Only")

        let stack = NSStackView(views: [usagePopup, stylePopup])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: 58)

        let alert = NSAlert()
        alert.messageText = "Menu bar display"
        alert.informativeText = "Choose which usage appears in the menu bar. The account panel keeps 5-hour as the main ring and weekly as the top bar."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let usageRawValue = usagePopup.selectedItem?.representedObject as? String,
           let selectedUsageMode = UsageDisplayMode(rawValue: usageRawValue),
           let styleRawValue = stylePopup.selectedItem?.representedObject as? String,
           let style = ToolbarDisplayStyle(rawValue: styleRawValue) {
            usageMode = selectedUsageMode
            toolbarDisplayStyle = style
            updateStatusTitle()
            rebuildMenu()
            DispatchQueue.main.async { [weak self] in
                self?.updateStatusTitle()
            }
        }
    }

    @objc private func showRemoveAccountDialog() {
        guard !accounts.isEmpty else { return }
        let popup = accountPopup(width: 320)
        let alert = NSAlert()
        alert.messageText = "Remove account?"
        alert.informativeText = "Remove the selected account from codex-auth switching."
        alert.alertStyle = .warning
        alert.accessoryView = popup
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let email = selectedAccountEmail(from: popup) {
            runAccountMaintenance(title: "Removing account", args: ["remove", email])
        }
    }

    @objc private func showUsageReminderDialog() {
        let notifyCheck = NSButton(checkboxWithTitle: "Notify on low usage", target: nil, action: nil)
        notifyCheck.state = remindersEnabled ? .on : .off

        let notifyField = NSTextField(frame: NSRect(x: 0, y: 0, width: 70, height: 24))
        notifyField.stringValue = "\(reminderThreshold)"

        let notifyRow = settingsRow(label: "Notify %", control: notifyField)
        let stack = NSStackView(views: [notifyCheck, notifyRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 58)

        let alert = NSAlert()
        alert.messageText = "Usage reminder"
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Test")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            testUsageReminder()
            return
        }
        guard response == .alertFirstButtonReturn else { return }

        let notifyValue = Int(notifyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let notifyValue, (1...99).contains(notifyValue) else {
            showAlert(title: "Invalid percentage", message: "Enter a number from 1 to 99.")
            return
        }

        remindersEnabled = notifyCheck.state == .on
        reminderThreshold = notifyValue
        if remindersEnabled {
            configureNotifications()
        }
        checkUsageReminder()
        rebuildMenu()
    }

    @objc private func showAutoSwitchDialog() {
        let modePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26), pullsDown: false)
        addPopupItem(to: modePopup, title: "Off", representedObject: AutoSwitchMode.off.rawValue)
        addPopupItem(to: modePopup, title: "Ask at threshold", representedObject: AutoSwitchMode.ask.rawValue)
        addPopupItem(to: modePopup, title: "Switch at threshold", representedObject: AutoSwitchMode.threshold.rawValue)
        addPopupItem(to: modePopup, title: "Ask at 0%", representedObject: AutoSwitchMode.zero.rawValue)
        selectPopupItem(modePopup, representedObject: autoSwitchMode.rawValue)

        let thresholdField = NSTextField(frame: NSRect(x: 0, y: 0, width: 70, height: 24))
        thresholdField.stringValue = "\(autoSwitchThreshold)"

        let protectCheck = NSButton(checkboxWithTitle: "Pause while Codex is frontmost", target: nil, action: nil)
        protectCheck.state = protectFrontmostCodex ? .on : .off

        let stack = NSStackView(views: [
            settingsRow(label: "Mode", control: modePopup),
            settingsRow(label: "Switch %", control: thresholdField),
            protectCheck
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 340, height: 96)

        let alert = NSAlert()
        alert.messageText = "Auto switch"
        alert.informativeText = "Choose whether the switcher asks first or changes accounts automatically when 5-hour usage is low. At 0%, it asks so Codex can finish any running task."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let switchValue = Int(thresholdField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let switchValue, (1...99).contains(switchValue) else {
            showAlert(title: "Invalid percentage", message: "Enter a number from 1 to 99.")
            return
        }
        if let rawValue = modePopup.selectedItem?.representedObject as? String,
           let mode = AutoSwitchMode(rawValue: rawValue) {
            autoSwitchMode = mode
        }
        autoSwitchThreshold = switchValue
        protectFrontmostCodex = protectCheck.state == .on
        notifiedAutoSwitchPauseKeys.removeAll()
        if autoSwitchEnabled {
            configureNotifications()
            checkAutoSwitch()
        }
        rebuildMenu()
    }

    @objc private func showAutoResumeDialog() {
        let modePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26), pullsDown: false)
        addPopupItem(to: modePopup, title: "Off", representedObject: AutoResumeMode.off.rawValue)
        addPopupItem(to: modePopup, title: "Ask first", representedObject: AutoResumeMode.ask.rawValue)
        addPopupItem(to: modePopup, title: "Auto after 5s idle", representedObject: AutoResumeMode.idle5.rawValue)
        addPopupItem(to: modePopup, title: "Auto after 10s idle", representedObject: AutoResumeMode.idle10.rawValue)
        addPopupItem(to: modePopup, title: "Always auto-resume", representedObject: AutoResumeMode.always.rawValue)
        selectPopupItem(modePopup, representedObject: autoResumeMode.rawValue)

        let promptField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        promptField.stringValue = autoResumePrompt

        let stack = NSStackView(views: [
            settingsRow(label: "Mode", control: modePopup),
            settingsRow(label: "Prompt", control: promptField)
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 380, height: 62)

        let alert = NSAlert()
        alert.messageText = "Auto resume"
        alert.informativeText = "After a successful account switch, the app can copy or paste a short prompt into Codex. Automatic paste requires Accessibility permission and only runs when Codex is frontmost."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let rawValue = modePopup.selectedItem?.representedObject as? String,
           let mode = AutoResumeMode(rawValue: rawValue) {
            autoResumeMode = mode
        }
        autoResumePrompt = promptField.stringValue
        if autoResumeMode != .off {
            configureNotifications()
        }
        rebuildMenu()
    }

    @objc private func showRefreshSettingsDialog() {
        let activePopup = refreshIntervalPopup(width: 120, values: [5, 15, 30, 60], selected: activeRefreshInterval)
        let idlePopup = refreshIntervalPopup(width: 120, values: [15, 30, 60], selected: idleRefreshInterval)
        let stack = NSStackView(views: [
            settingsRow(label: "Codex active", control: activePopup),
            settingsRow(label: "Idle", control: idlePopup)
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 62)

        let alert = NSAlert()
        alert.messageText = "Refresh settings"
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let active = activePopup.selectedItem?.representedObject as? Int,
           let idle = idlePopup.selectedItem?.representedObject as? Int {
            activeRefreshInterval = active
            idleRefreshInterval = idle
            rebuildMenu()
        }
    }

    private func showApiSetupDialog() {
        let codexField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        codexField.placeholderString = apiKeyConfigured() ? "Codex API key already saved" : "OpenAI project API key"

        let usageField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        usageField.placeholderString = usageKeyConfigured() ? "Usage/Admin key already saved" : "Usage/Admin API key"

        let codexLabel = NSTextField(labelWithString: "Codex API key")
        codexLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        let usageLabel = NSTextField(labelWithString: "Usage meter key")
        usageLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let stack = NSStackView(views: [
            codexLabel,
            codexField,
            usageLabel,
            usageField
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.frame = NSRect(x: 0, y: 0, width: 440, height: 94)

        let alert = NSAlert()
        alert.messageText = "API token mode"
        alert.informativeText = "Keys are saved in macOS Keychain. The usage meter key is optional unless you want the daily token count."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Clear Keys")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            deleteKeychainSecret(account: apiCodexKeyAccount)
            deleteKeychainSecret(account: apiUsageKeyAccount)
            apiModeActive = false
            apiUsedTokens = 0
            apiUsageLastError = "API keys cleared"
            rebuildMenu()
            return
        }
        guard response == .alertFirstButtonReturn else { return }

        let codexKey = codexField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let usageKey = usageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !codexKey.isEmpty {
            saveKeychainSecret(codexKey, account: apiCodexKeyAccount)
        }
        if !usageKey.isEmpty {
            saveKeychainSecret(usageKey, account: apiUsageKeyAccount)
        }
        refreshApiUsage(force: true)
        rebuildMenu()
    }

    private func showApiLimitDialog() {
        let limitField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        limitField.stringValue = "\(apiDailyLimit)"
        let warningField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        warningField.stringValue = "\(apiWarningPercent)"
        let notifyCheck = NSButton(checkboxWithTitle: "Notify when approaching the daily token limit", target: nil, action: nil)
        notifyCheck.state = apiUsageNotificationsEnabled ? .on : .off

        let stack = NSStackView(views: [
            settingsRow(label: "Daily limit", control: limitField),
            settingsRow(label: "Alert %", control: warningField),
            notifyCheck
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 330, height: 96)

        let alert = NSAlert()
        alert.messageText = "API token warning"
        alert.informativeText = "Set the daily token allowance you want this app to watch."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let limit = Int(limitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        let warning = Int(warningField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let limit, limit >= 1_000, let warning, (1...99).contains(warning) else {
            showAlert(title: "Invalid API limit", message: "Use a daily limit of at least 1,000 tokens and an alert percentage from 1 to 99.")
            return
        }
        apiDailyLimit = limit
        apiWarningPercent = warning
        apiUsageNotificationsEnabled = notifyCheck.state == .on
        notifiedApiUsageKeys.removeAll()
        checkApiUsageReminder()
        rebuildMenu()
    }

    private func testApiUsageReminder() {
        sendApiUsageReminder(reportResult: true)
    }

    private func switchToApiMode() {
        disableApiMode()
        showAlert(title: "API mode removed", message: "This build only switches between saved ChatGPT accounts.")
    }

    @objc private func addAccountBrowser() {
        runAccountMaintenance(title: "Adding account", args: ["login"], restartAfterSuccess: true)
    }

    @objc private func addAccountDeviceCode() {
        let path = codexAuthPath() ?? "codex-auth"
        let home = NSHomeDirectory()
        let restartPath = "\(home)/.codex/skills/codex-account-switcher/scripts/codex_account_switch.sh"
        let setupCommand = shellEnvironmentSetupCommand()
        let script = """
        tell application "Terminal"
          activate
          do script "\(setupCommand); \(shellEscaped(path)) login --device-auth && \(shellEscaped(restartPath)) restart-app; echo; echo 'Codex account login finished and Codex App was relaunched. You can close this window.'"
        end tell
        """
        let result = run("/usr/bin/osascript", ["-e", script])
        if result.status != 0 {
            showAlert(title: "Device-code login failed", message: result.output)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshAccounts(force: true)
        }
    }

    @objc private func toggleUsageReminder() {
        remindersEnabled.toggle()
        if remindersEnabled {
            configureNotifications()
            checkUsageReminder()
        } else {
            notifiedLowUsageKeys.removeAll()
        }
        rebuildMenu()
    }

    @objc private func toggleAutoSwitch() {
        autoSwitchEnabled.toggle()
        if autoSwitchEnabled {
            configureNotifications()
            checkAutoSwitch()
        }
        rebuildMenu()
    }

    @objc private func toggleConfirmBeforeSwitching() {
        confirmBeforeSwitching.toggle()
        clearArmedSwitch()
        rebuildMenu()
    }

    @objc private func toggleProtectFrontmostCodex() {
        protectFrontmostCodex.toggle()
        rebuildMenu()
    }

    @objc private func setReminderThreshold() {
        let alert = NSAlert()
        alert.messageText = "Usage reminder"
        alert.informativeText = "Notify when the active account usage display is at or below this percentage."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = "\(reminderThreshold)"
        field.placeholderString = "10"
        alert.accessoryView = field

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(trimmed), (1...99).contains(value) else {
                showAlert(title: "Invalid percentage", message: "Enter a number from 1 to 99.")
                return
            }
            reminderThreshold = value
            notifiedLowUsageKeys.removeAll()
            checkUsageReminder()
            rebuildMenu()
        }
    }

    @objc private func setAutoSwitchThreshold() {
        let alert = NSAlert()
        alert.messageText = "Auto-switch"
        alert.informativeText = "Switch accounts when the active account's 5hr usage remaining is at or below this percentage."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = "\(autoSwitchThreshold)"
        field.placeholderString = "10"
        alert.accessoryView = field

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(trimmed), (1...99).contains(value) else {
                showAlert(title: "Invalid percentage", message: "Enter a number from 1 to 99.")
                return
            }
            autoSwitchThreshold = value
            checkAutoSwitch()
            rebuildMenu()
        }
    }

    @objc private func testUsageReminder() {
        if let active = accounts.first(where: { $0.isActive }) {
            sendUsageReminder(account: active, metric: "5hr", percent: active.fiveHourUsedPercent ?? reminderThreshold, reportResult: true)
        } else {
            sendNotification(
                title: "Codex usage reminder",
                subtitle: "No active account",
                body: "Open the switcher after adding a Codex account.",
                reportResult: true
            )
        }
    }

    @objc private func setWeeklyMode() {
        usageMode = .weekly
        rebuildMenu()
    }

    @objc private func setAccountLabel(_ sender: NSMenuItem) {
        guard let email = sender.representedObject as? String,
              let account = accounts.first(where: { $0.email == email }) else { return }

        let alert = NSAlert()
        alert.messageText = "Set display label"
        alert.informativeText = "Choose the label shown in the menu bar for \(account.email). Use up to four characters."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = displayLabel(for: account)
        alert.accessoryView = field

        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                clearCustomLabel(forEmail: email)
            } else {
                setCustomLabel(limitedLabel(value), forEmail: email)
            }
            rebuildMenu()
        }
    }

    @objc private func clearAccountLabel(_ sender: NSMenuItem) {
        guard let email = sender.representedObject as? String else { return }
        clearCustomLabel(forEmail: email)
        rebuildMenu()
    }

    @objc private func removeAccount(_ sender: NSMenuItem) {
        guard let query = sender.representedObject as? String,
              let account = accounts.first(where: { $0.email == query || $0.selector == query }) else { return }

        let alert = NSAlert()
        alert.messageText = "Remove account?"
        alert.informativeText = "Remove \(account.email) from codex-auth switching?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            runAccountMaintenance(title: "Removing account", args: ["remove", query])
        }
    }

    @objc private func cleanAccountBackups() {
        runAccountMaintenance(title: "Cleaning backups", args: ["clean"])
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled() {
                try removeLaunchAgent()
            } else {
                try installLaunchAgent()
            }
        } catch {
            showAlert(title: "Launch at Login failed", message: error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func toggleAccount() {
        guard accounts.count == 2, let inactive = accounts.first(where: { !$0.isActive }) else {
            showAlert(title: "Cannot toggle", message: "Toggle requires exactly two saved accounts and one active account.")
            return
        }
        switchTo(query: inactive.email)
    }

    @objc private func switchAccount(_ sender: NSMenuItem) {
        guard let query = sender.representedObject as? String else { return }
        switchTo(query: query)
    }

    private func confirmSwitchPreview(for account: CodexAccount) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Switch to \(displayLabel(for: account))?"
        alert.informativeText = "5H \(remainingPercentText(fromUsed: account.fiveHourUsedPercent)) left · Weekly \(remainingPercentText(fromUsed: account.weeklyUsedPercent)) left\n\nCodex will relaunch after switching."
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func switchTo(query: String, allowAutoResume: Bool = false) {
        guard !isSwitching else { return }
        clearArmedSwitch()
        let target = accounts.first(where: { $0.email == query || $0.selector == query })
        if let target, accountNeedsLogin(target) {
            showAlert(
                title: "Account needs login",
                message: "Account \(displayLabel(for: target)) has an expired Codex session. Re-login it with Add Account with Device Code, then refresh."
            )
            refreshAccounts(force: true)
            return
        }
        if let target, !target.isActive, !allowAutoResume, !confirmBeforeSwitching, !confirmSwitchPreview(for: target) {
            return
        }
        isSwitching = true
        beginSwitchAnimation(label: target.map(displayLabel(for:)) ?? query)
        refreshAccountPanelContentIfVisible()

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.apiModeActive, let syncError = self.syncActiveAuthSnapshot() {
                DispatchQueue.main.async {
                    self.isSwitching = false
                    self.endSwitchAnimation()
                    self.updateStatusTitle()
                    self.showAlert(title: "Could not save active token", message: syncError)
                    self.refreshAccounts(force: true)
                }
                return
            }

            let switchResult = self.runCodexAuth(["switch", query])
            if switchResult.status != 0 {
                DispatchQueue.main.async {
                    self.isSwitching = false
                    self.endSwitchAnimation()
                    self.updateStatusTitle()
                    self.showAlert(title: "Switch failed", message: switchResult.output)
                    self.refreshAccounts(force: true)
                }
                return
            }

            DispatchQueue.main.sync {
                self.apiModeActive = false
                self.isSwitching = false
                self.endSwitchAnimation()
                self.refreshAccounts(force: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self, !self.isSwitching else { return }
                    self.refreshAccounts(force: true)
                }
            }

            let restartResult = self.restartCodexApp()
            DispatchQueue.main.async {
                if restartResult.status != 0 {
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
                } else if allowAutoResume {
                    self.handleAutoResumeAfterSwitch(to: target)
                }
                self.refreshAccounts(force: true)
            }
        }
    }

    private func beginSwitchAnimation(label: String) {
        switchAnimationTimer?.invalidate()
        switchAnimationFrame = 0
        switchingTitle = "\(limitedLabel(label)) · switching"
        updateSwitchAnimationTitle()
        switchAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.switchAnimationFrame += 1
            self.updateSwitchAnimationTitle()
        }
    }

    private func updateSwitchAnimationTitle() {
        let frame = switchAnimationFrames[switchAnimationFrame % switchAnimationFrames.count]
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        statusItem.button?.title = "\(switchingTitle) \(frame)"
    }

    private func endSwitchAnimation() {
        switchAnimationTimer?.invalidate()
        switchAnimationTimer = nil
    }

    private func refreshAccountPanelContentIfVisible() {
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
        }
    }

    private func checkUsageReminder() {
        guard remindersEnabled, let active = accounts.first(where: { $0.isActive }) else { return }
        checkUsageReminder(account: active, metric: "5hr", percent: active.fiveHourUsedPercent)
        checkUsageReminder(account: active, metric: "Weekly", percent: active.weeklyUsedPercent)
    }

    private func checkAutoSwitch() {
        let mode = autoSwitchMode
        guard mode != .off,
              !isSwitching,
              accounts.count > 1,
              let active = accounts.first(where: { $0.isActive }),
              let activeFiveHour = active.fiveHourUsedPercent,
              let target = bestAutoSwitchTarget(excluding: active.email) else {
            return
        }
        if protectFrontmostCodex, codexIsFrontmost() {
            return
        }
        switch mode {
        case .off:
            return
        case .ask, .threshold:
            guard activeFiveHour <= autoSwitchThreshold else { return }
        case .zero:
            guard activeFiveHour <= 0 else { return }
        }

        let key = "\(active.email)|\(target.email)|\(autoSwitchThreshold)|\(mode.rawValue)"
        guard !notifiedAutoSwitchPauseKeys.contains(key) else { return }
        notifiedAutoSwitchPauseKeys.insert(key)
        if mode == .ask || mode == .zero {
            sendAutoSwitchPrompt(active: active, target: target, activeFiveHour: activeFiveHour)
        } else {
            switchTo(query: target.email, allowAutoResume: true)
        }
    }

    private func bestAutoSwitchTarget(excluding activeEmail: String) -> CodexAccount? {
        accounts
            .filter { $0.email != activeEmail }
            .filter { ($0.fiveHourUsedPercent ?? -1) > autoSwitchThreshold }
            .sorted { ($0.fiveHourUsedPercent ?? -1) > ($1.fiveHourUsedPercent ?? -1) }
            .first
    }

    private func sendAutoSwitchPrompt(active: CodexAccount, target: CodexAccount, activeFiveHour: Int) {
        sendNotification(
            title: "Codex usage is low",
            subtitle: "\(toolbarLabel(for: active)) \(activeFiveHour)% -> \(toolbarLabel(for: target)) \(remainingPercentText(fromUsed: target.fiveHourUsedPercent))",
            body: "Switch to \(target.email) and relaunch Codex?",
            categoryIdentifier: autoSwitchNotificationCategory,
            userInfo: ["targetEmail": target.email]
        )
    }

    private func checkUsageReminder(account: CodexAccount, metric: String, percent: Int?) {
        guard let percent else { return }
        let threshold = reminderThreshold
        let key = "\(account.email)|\(metric)|\(threshold)"
        if percent <= threshold {
            guard !notifiedLowUsageKeys.contains(key) else { return }
            notifiedLowUsageKeys.insert(key)
            sendUsageReminder(account: account, metric: metric, percent: percent)
        } else {
            notifiedLowUsageKeys.remove(key)
        }
    }

    private func sendUsageReminder(account: CodexAccount, metric: String, percent: Int, reportResult: Bool = false) {
        let label = displayLabel(for: account)
        sendNotification(
            title: "Codex usage is low",
            subtitle: "\(label) · \(metric) \(percent)%",
            body: autoSwitchEnabled
                ? "\(account.email) is at or below \(reminderThreshold)%. Auto-switch is enabled at \(autoSwitchThreshold)% for 5hr usage."
                : "\(account.email) is at or below \(reminderThreshold)%. Switch to another saved account from the menu bar when you are ready.",
            reportResult: reportResult
        )
    }

    private func checkApiUsageReminder() {
        guard apiUsageNotificationsEnabled, apiModeActive, apiDailyLimit > 0 else { return }
        let percent = apiUsageSnapshot().usedPercent
        let key = "\(DateFormatter.apiDayKey.string(from: Date()))|\(apiWarningPercent)"
        if percent >= apiWarningPercent {
            guard !notifiedApiUsageKeys.contains(key) else { return }
            notifiedApiUsageKeys.insert(key)
            sendApiUsageReminder()
        } else {
            notifiedApiUsageKeys.remove(key)
        }
    }

    private func sendApiUsageReminder(reportResult: Bool = false) {
        let snapshot = apiUsageSnapshot()
        sendNotification(
            title: "OpenAI API token usage",
            subtitle: "\(snapshot.usedPercent)% of \(snapshot.limitTokens) tokens",
            body: "\(snapshot.usedTokens) tokens used today. Switch back to a normal Codex account from the account cards when you are ready.",
            reportResult: reportResult
        )
    }

    private func sendNotification(
        title: String,
        subtitle: String,
        body: String,
        categoryIdentifier: String? = nil,
        userInfo: [AnyHashable: Any] = [:],
        reportResult: Bool = false
    ) {
        ensureNotificationAuthorization { [weak self] isAuthorized, message in
            guard let self else { return }
            guard isAuthorized else {
                if reportResult {
                    DispatchQueue.main.async {
                        self.showNotificationSettingsAlert(message: message ?? self.notificationSettingsMessage())
                    }
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            content.body = body
            content.userInfo = userInfo
            if let categoryIdentifier {
                content.categoryIdentifier = categoryIdentifier
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "codex-usage-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    NSLog("Codex Account Switcher notification failed: \(error.localizedDescription)")
                    if reportResult {
                        DispatchQueue.main.async {
                            self.showNotificationSettingsAlert(message: self.notificationSettingsMessage())
                        }
                    }
                } else if reportResult {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showAlert(title: "Test notification sent", message: "If no banner appeared, check System Settings > Notifications > Codex Account Switcher and make sure alerts are enabled.")
                    }
                }
            }
        }
    }

    private func ensureNotificationAuthorization(_ completion: @escaping (Bool, String?) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true, nil)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if error != nil {
                        completion(false, self.notificationSettingsMessage())
                    } else if granted {
                        completion(true, nil)
                    } else {
                        completion(false, self.notificationSettingsMessage())
                    }
                }
            case .denied:
                completion(false, self.notificationSettingsMessage())
            @unknown default:
                completion(false, self.notificationSettingsMessage())
            }
        }
    }

    private func notificationSettingsMessage() -> String {
        "Enable notifications for Codex Account Switcher in System Settings > Notifications, then run Test Notification again. If it is not listed yet, quit and reopen the switcher once after this update."
    }

    private func showNotificationSettingsAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Enable notifications"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }

    private func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.mohamedfuad.codexaccountswitcher",
            "x-apple.systempreferences:com.apple.preference.notifications?id=com.mohamedfuad.codexaccountswitcher",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func launchAgentURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentIdentifier).plist")
    }

    private func launchAtLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL().path)
    }

    private func installLaunchAgent() throws {
        let appPath = Bundle.main.bundlePath
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(launchAgentIdentifier)</string>
          <key>ProgramArguments</key>
          <array>
            <string>/usr/bin/open</string>
            <string>\(appPath)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """
        let url = launchAgentURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plist.write(to: url, atomically: true, encoding: .utf8)
    }

    private func removeLaunchAgent() throws {
        let url = launchAgentURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        switch response.actionIdentifier {
        case switchNowActionIdentifier:
            guard let targetEmail = response.notification.request.content.userInfo["targetEmail"] as? String else { return }
            DispatchQueue.main.async { [weak self] in
                self?.switchTo(query: targetEmail, allowAutoResume: true)
            }
        case resumeNowActionIdentifier:
            let token = response.notification.request.content.userInfo["resumeToken"] as? String
            DispatchQueue.main.async { [weak self] in
                self?.cancelPendingResume(token: token)
                self?.resumeCodexTask(submit: true, promptForPermission: true)
            }
        case cancelResumeActionIdentifier:
            let token = response.notification.request.content.userInfo["resumeToken"] as? String
            DispatchQueue.main.async { [weak self] in
                self?.cancelPendingResume(token: token)
            }
        default:
            return
        }
    }

    private func handleAutoResumeAfterSwitch(to target: CodexAccount?) {
        let mode = autoResumeMode
        guard mode != .off else { return }
        let label = target.map(displayLabel(for:)) ?? "new account"
        let token = UUID().uuidString
        switch mode {
        case .off:
            return
        case .ask:
            sendResumePromptNotification(label: label, token: token, body: "Switch complete. Paste the resume prompt into Codex?")
        case .idle5:
            sendResumePromptNotification(label: label, token: token, body: "Switch complete. Resume will run after 5 seconds if the Mac is idle.")
            scheduleAutoResume(token: token, delay: 5, requireIdle: true)
        case .idle10:
            sendResumePromptNotification(label: label, token: token, body: "Switch complete. Resume will run after 10 seconds if the Mac is idle.")
            scheduleAutoResume(token: token, delay: 10, requireIdle: true)
        case .always:
            sendResumePromptNotification(label: label, token: token, body: "Switch complete. Resume prompt is being sent to Codex.")
            scheduleAutoResume(token: token, delay: 1, requireIdle: false)
        }
    }

    private func sendResumePromptNotification(label: String, token: String, body: String) {
        sendNotification(
            title: "Resume Codex task?",
            subtitle: "Active: \(label)",
            body: body,
            categoryIdentifier: resumeNotificationCategory,
            userInfo: ["resumeToken": token]
        )
    }

    private func scheduleAutoResume(token: String, delay: TimeInterval, requireIdle: Bool) {
        cancelPendingResume(token: token)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingResumeWorkItems[token] = nil
            if requireIdle, self.systemIdleSeconds() < delay {
                self.copyResumePromptToClipboard()
                self.sendNotification(
                    title: "Resume prompt copied",
                    subtitle: "Codex Account Switcher",
                    body: "The Mac was active, so the prompt was copied instead of pasted."
                )
                return
            }
            self.resumeCodexTask(submit: true, promptForPermission: true)
        }
        pendingResumeWorkItems[token] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPendingResume(token: String?) {
        if let token {
            pendingResumeWorkItems[token]?.cancel()
            pendingResumeWorkItems[token] = nil
        } else {
            pendingResumeWorkItems.values.forEach { $0.cancel() }
            pendingResumeWorkItems.removeAll()
        }
    }

    private func resumeCodexTask(submit: Bool, promptForPermission: Bool) {
        copyResumePromptToClipboard()
        guard accessibilityTrusted(prompt: promptForPermission) else {
            sendNotification(
                title: "Resume prompt copied",
                subtitle: "Accessibility needed",
                body: "Allow Accessibility for Codex Account Switcher, then paste the prompt into Codex."
            )
            return
        }
        activateCodex()
        DispatchQueue.main.asyncAfter(deadline: .now() + autoResumeCodexReadyDelay) { [weak self] in
            guard let self else { return }
            guard self.codexIsFrontmost() else {
                self.sendNotification(
                    title: "Resume prompt copied",
                    subtitle: "Codex is not frontmost",
                    body: "The app copied the prompt instead of pasting into another window."
                )
                return
            }
            self.sendPasteKeystroke()
            if submit {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.sendReturnKeystroke()
                }
            }
        }
    }

    private func copyResumePromptToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(autoResumePrompt, forType: .string)
    }

    private func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func activateCodex() {
        if let app = NSWorkspace.shared.runningApplications.first(where: isCodexDesktopApplication) {
            app.activate(options: [.activateAllWindows])
        } else {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: codexDesktopAppPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    private func sendPasteKeystroke() {
        sendKey(code: 9, flags: .maskCommand)
    }

    private func sendReturnKeystroke() {
        sendKey(code: 36, flags: .maskControl)
    }

    private func sendKey(code: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: UInt32.max)!)
    }

    private func syncActiveAuthSnapshot() -> String? {
        let home = NSHomeDirectory()
        let registryURL = URL(fileURLWithPath: "\(home)/.codex/accounts/registry.json")
        let activeAuthURL = URL(fileURLWithPath: "\(home)/.codex/auth.json")

        do {
            let data = try Data(contentsOf: registryURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let activeKey = json["active_account_key"] as? String else {
                return "Could not read active_account_key from registry.json."
            }

            let encoded = Data(activeKey.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
            let accountAuthURL = URL(fileURLWithPath: "\(home)/.codex/accounts/\(encoded).auth.json")
            guard FileManager.default.fileExists(atPath: activeAuthURL.path) else {
                return "Active auth file does not exist at \(activeAuthURL.path)."
            }
            if activeAuthUsesApiKey(activeAuthURL) {
                return nil
            }

            let backupURL = accountAuthURL.deletingLastPathComponent().appendingPathComponent(
                accountAuthURL.lastPathComponent + ".bak.\(Int(Date().timeIntervalSince1970))"
            )
            if FileManager.default.fileExists(atPath: accountAuthURL.path) {
                try? FileManager.default.copyItem(at: accountAuthURL, to: backupURL)
                try FileManager.default.removeItem(at: accountAuthURL)
            }
            try FileManager.default.copyItem(at: activeAuthURL, to: accountAuthURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func activeAuthUsesApiKey(_ authURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authMode = json["auth_mode"] as? String else {
            return false
        }
        return authMode.localizedCaseInsensitiveCompare("apikey") == .orderedSame
    }

    private func runAccountMaintenance(title: String, args: [String], restartAfterSuccess: Bool = false) {
        guard !isSwitching else { return }
        isSwitching = true
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        statusItem.button?.title = title
        rebuildMenu()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runCodexAuth(args)
            var restartResult: CommandResult?
            if result.status == 0, restartAfterSuccess {
                restartResult = self.restartCodexApp()
            }
            DispatchQueue.main.async {
                self.isSwitching = false
                if result.status != 0 {
                    self.showAlert(title: "\(title) failed", message: result.output)
                } else if let restartResult, restartResult.status != 0 {
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
                }
                self.refreshAccounts(force: true)
            }
        }
    }

    private func restartCodexApp() -> CommandResult {
        var transcript: [String] = []
        transcript.append("Quitting \(codexDesktopAppName) process tree...")

        for attempt in 1...6 {
            let pids = codexAppPIDs()
            if pids.isEmpty { break }
            let signal = attempt == 1 ? "-TERM" : "-KILL"
            _ = run("/bin/kill", [signal] + pids)
            Thread.sleep(forTimeInterval: 1)
        }

        let remaining = codexAppPIDs()
        if !remaining.isEmpty {
            transcript.append("Codex helper processes remained after force quit: \(remaining.joined(separator: ", ")). Opening Codex anyway.")
        }

        if let configMessage = ensureComputerUsePluginConfigured() {
            transcript.append(configMessage)
        }

        transcript.append("Opening \(codexDesktopAppName)...")
        let openResult = run("/usr/bin/open", [codexDesktopAppPath])
        if openResult.status != 0 {
            return CommandResult(status: openResult.status, output: transcript.joined(separator: "\n") + "\n" + openResult.output)
        }

        Thread.sleep(forTimeInterval: 4)
        let runningResult = run("/usr/bin/osascript", ["-e", "application \"\(codexDesktopAppName)\" is running"])
        if runningResult.output.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
            transcript.append("\(codexDesktopAppName) did not report as running after launch.")
            let stillRemaining = codexAppPIDs()
            if !stillRemaining.isEmpty {
                transcript.append("Remaining Codex process IDs: \(stillRemaining.joined(separator: ", "))")
            }
            return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
        }

        return CommandResult(status: 0, output: transcript.joined(separator: "\n"))
    }

    private func ensureComputerUsePluginConfigured() -> String? {
        let home = NSHomeDirectory()
        let configURL = URL(fileURLWithPath: "\(home)/.codex/config.toml")
        let stateURL = URL(fileURLWithPath: "\(home)/.codex/.codex-global-state.json")
        var changed = false

        do {
            var config = try String(contentsOf: configURL, encoding: .utf8)
            if !config.contains("[plugins.\"computer-use@openai-bundled\"]") {
                let chromeBlock = "[plugins.\"chrome@openai-bundled\"]\nenabled = true"
                let computerUseBlock = "\(chromeBlock)\n\n[plugins.\"computer-use@openai-bundled\"]\nenabled = true"
                if config.contains(chromeBlock) {
                    config = config.replacingOccurrences(of: chromeBlock, with: computerUseBlock)
                } else {
                    config += "\n\n[plugins.\"computer-use@openai-bundled\"]\nenabled = true\n"
                }
                changed = true
            }

            if !config.contains("SKY_CUA_SERVICE_PATH") {
                let codePathLine = "CODEX_CLI_PATH = \"\(codexDesktopResourcesPath)/codex\""
                let servicePathLine = "SKY_CUA_SERVICE_PATH = \"\(home)/.codex/plugins/cache/openai-bundled/computer-use/1.0.799/Codex Computer Use.app\""
                if config.contains(codePathLine) {
                    config = config.replacingOccurrences(of: codePathLine, with: "\(servicePathLine)\n\(codePathLine)")
                }
                changed = true
            }

            if changed {
                try config.write(to: configURL, atomically: true, encoding: .utf8)
            }
        } catch {
            return "Computer Use config check failed: \(error.localizedDescription)"
        }

        do {
            var state = try String(contentsOf: stateURL, encoding: .utf8)
            if state.contains("\"electron-chrome-extension-sync-managed-plugin-ids\":[\"chrome@openai-bundled\"]") {
                state = state.replacingOccurrences(
                    of: "\"electron-chrome-extension-sync-managed-plugin-ids\":[\"chrome@openai-bundled\"]",
                    with: "\"electron-chrome-extension-sync-managed-plugin-ids\":[\"chrome@openai-bundled\",\"computer-use@openai-bundled\"]"
                )
                try state.write(to: stateURL, atomically: true, encoding: .utf8)
                changed = true
            }
        } catch {
            return "Computer Use state check failed: \(error.localizedDescription)"
        }

        return changed ? "Repaired Computer Use plugin config before Codex launch." : nil
    }

    private func codexAppPIDs() -> [String] {
        let escapedPath = NSRegularExpression.escapedPattern(for: codexDesktopAppPath)
        let result = run("/usr/bin/pgrep", ["-f", "\(escapedPath)/Contents/"])
        guard result.status == 0 else { return [] }
        return result.output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func parseAccounts(_ output: String, usageIsLive: Bool = true) -> [CodexAccount] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = String(rawLine)
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard !tokens.isEmpty else { return nil }

            let isActive = tokens.first == "*"
            let offset = isActive ? 1 : 0
            guard tokens.count >= offset + 3 else { return nil }
            guard tokens[offset].allSatisfy(\.isNumber) else { return nil }

            let selector = tokens[offset]
            let email = tokens[offset + 1]
            let plan = tokens[offset + 2]
            var cursor = offset + 3
            let fiveHour = Self.parseUsage(tokens, from: cursor, usageIsLive: usageIsLive)
            cursor = fiveHour.nextIndex
            let weekly = Self.parseUsage(tokens, from: cursor, usageIsLive: usageIsLive)
            cursor = weekly.nextIndex
            let lastActivity = tokens.dropFirst(cursor).joined(separator: " ")

            return CodexAccount(
                selector: selector,
                email: email,
                plan: plan,
                fiveHourUsage: fiveHour.text,
                weeklyUsage: weekly.text,
                fiveHourUsedPercent: fiveHour.usedPercent,
                weeklyUsedPercent: weekly.usedPercent,
                lastActivity: lastActivity.isEmpty ? "-" : lastActivity,
                isActive: isActive
            )
        }
    }

    private func demoAccounts() -> [CodexAccount] {
        [
            CodexAccount(
                selector: "01",
                email: "alpha@example.com",
                plan: "plus",
                fiveHourUsage: "31% (16:40)",
                weeklyUsage: "82% (Fri 09:00)",
                fiveHourUsedPercent: 31,
                weeklyUsedPercent: 82,
                lastActivity: "Just now",
                isActive: true
            ),
            CodexAccount(
                selector: "02",
                email: "beta@example.com",
                plan: "plus",
                fiveHourUsage: "92% (18:15)",
                weeklyUsage: "64% (Fri 09:00)",
                fiveHourUsedPercent: 92,
                weeklyUsedPercent: 64,
                lastActivity: "1h ago",
                isActive: false
            ),
            CodexAccount(
                selector: "03",
                email: "gamma@example.com",
                plan: "plus",
                fiveHourUsage: "68% (20:25)",
                weeklyUsage: "41% (Fri 09:00)",
                fiveHourUsedPercent: 68,
                weeklyUsedPercent: 41,
                lastActivity: "2h ago",
                isActive: false
            )
        ]
    }

    private func demoResetCreditsByEmail(for accounts: [CodexAccount]) -> [String: ResetCreditsSnapshot] {
        let now = Date()
        var snapshots: [String: ResetCreditsSnapshot] = [:]
        for (index, account) in accounts.enumerated() {
            let expiryDaysByAccount: [[Int]] = [
                [24],
                [5, 10, 19, 24],
                [5, 10, 19, 24]
            ]
            let expiryDays = index < expiryDaysByAccount.count ? expiryDaysByAccount[index] : [14]

            var credits: [ResetCredit] = []
            for (creditIndex, daysUntilExpiry) in expiryDays.enumerated() {
                let grantOffset = TimeInterval(-(30 - daysUntilExpiry) * 86_400)
                let expiryOffset = TimeInterval(daysUntilExpiry * 86_400)
                credits.append(
                    ResetCredit(
                        id: "demo-\(account.selector)-\(creditIndex)",
                        title: "One free rate limit reset",
                        resetType: "codex_rate_limits",
                        status: "available",
                        grantedAt: now.addingTimeInterval(grantOffset),
                        expiresAt: now.addingTimeInterval(expiryOffset)
                    )
                )
            }

            snapshots[account.email] = ResetCreditsSnapshot(
                availableCount: credits.count,
                credits: credits,
                lastUpdatedText: "just now",
                lastError: nil
            )
        }
        return snapshots
    }

    private static func parseUsage(_ tokens: [String], from startIndex: Int, usageIsLive: Bool = true) -> (text: String, usedPercent: Int?, nextIndex: Int) {
        guard startIndex < tokens.count else {
            return ("-", nil, startIndex)
        }

        let first = tokens[startIndex]
        if first == "-" {
            return ("-", nil, startIndex + 1)
        }
        if !first.contains("%") {
            if usageIsLive, let errorText = usageErrorText(for: first) {
                return (errorText, nil, startIndex + 1)
            }
            return (usageIsLive ? "Unavailable" : "-", nil, startIndex + 1)
        }

        var parts = [first]
        var cursor = startIndex + 1
        if cursor < tokens.count, tokens[cursor].hasPrefix("(") {
            while cursor < tokens.count {
                parts.append(tokens[cursor])
                if tokens[cursor].hasSuffix(")") {
                    cursor += 1
                    break
                }
                cursor += 1
            }
        }

        let text = usageIsLive ? parts.joined(separator: " ") : "-"
        return (text, usageIsLive ? firstPercent(in: first) : nil, cursor)
    }

    private static func usageErrorText(for token: String) -> String? {
        switch token {
        case "400", "401":
            return "Login expired"
        case "403":
            return "Usage blocked"
        default:
            return nil
        }
    }

    private static func firstPercent(in token: String) -> Int? {
        let digits = token.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    private func fetchApiUsage() -> ApiUsageFetchResult {
        .failure("API mode disabled")
    }

    private func fetchResetCredits(for accounts: [CodexAccount]) -> [String: ResetCreditsSnapshot] {
        Dictionary(uniqueKeysWithValues: accounts.map { account in
            let snapshot: ResetCreditsSnapshot
            switch savedAuth(forEmail: account.email) {
            case .success(let auth):
                switch fetchResetCredits(using: auth) {
                case .success(let fetched):
                    snapshot = fetched
                case .failure(let message):
                    snapshot = ResetCreditsSnapshot(availableCount: nil, credits: [], lastUpdatedText: "just now", lastError: message)
                }
            case .failure(let message):
                snapshot = ResetCreditsSnapshot(availableCount: nil, credits: [], lastUpdatedText: "never", lastError: message)
            }
            return (account.email, snapshot)
        })
    }

    private func fetchResetCredits(using auth: SavedAccountAuth) -> ResetCreditsFetchResult {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits") else {
            return .failure("reset endpoint URL is invalid")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var statusCode: Int?
        var responseError: Error?

        URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }.resume()

        guard semaphore.wait(timeout: .now() + 14) == .success else {
            return .failure("reset endpoint timed out")
        }

        if let responseError {
            return .failure(responseError.localizedDescription)
        }
        guard statusCode == 200, let responseData else {
            let statusText = statusCode.map(String.init) ?? "unknown"
            return .failure("reset endpoint returned \(statusText)")
        }
        guard let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return .failure("reset endpoint returned unreadable JSON")
        }

        let credits = (object["credits"] as? [[String: Any]] ?? []).map { raw in
            ResetCredit(
                id: raw["id"] as? String ?? "",
                title: raw["title"] as? String ?? "Reset credit",
                resetType: raw["reset_type"] as? String ?? "codex_rate_limits",
                status: raw["status"] as? String ?? "unknown",
                grantedAt: (raw["granted_at"] as? String).flatMap { DateFormatter.resetCreditISO.date(from: $0) },
                expiresAt: (raw["expires_at"] as? String).flatMap { DateFormatter.resetCreditISO.date(from: $0) }
            )
        }

        return .success(ResetCreditsSnapshot(
            availableCount: object["available_count"] as? Int,
            credits: credits,
            lastUpdatedText: "just now",
            lastError: nil
        ))
    }

    private func consumeResetCredit(email: String, creditID: String) -> ResetCreditRedemptionResult {
        guard !creditID.isEmpty else {
            return .failure("The selected reset credit is missing its backend id.")
        }
        guard case .success(let auth) = savedAuth(forEmail: email) else {
            return .failure("Could not read the saved Codex auth for this account.")
        }
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume") else {
            return .failure("Reset consume endpoint URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "credit_id": creditID,
            "redeem_request_id": UUID().uuidString
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure("Could not prepare the reset request.")
        }
        request.httpBody = bodyData

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var statusCode: Int?
        var responseError: Error?

        URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }.resume()

        guard semaphore.wait(timeout: .now() + 24) == .success else {
            return .failure("Reset request timed out.")
        }
        if let responseError {
            return .failure(responseError.localizedDescription)
        }
        guard statusCode == 200, let responseData else {
            let statusText = statusCode.map(String.init) ?? "unknown"
            let detail = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return .failure("Reset endpoint returned \(statusText). \(detail)")
        }

        guard let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return .success("The reset request completed, then the app refreshed the account state.")
        }
        let code = object["code"] as? String ?? "reset"
        let windows = object["windows_reset"] as? Int ?? 0
        return .success("Reset redeemed for \(compactEmail(email)). Code: \(code). Windows reset: \(windows).")
    }

    private func savedAuth(forEmail email: String) -> SavedAccountAuthResult {
        let root = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/accounts")
        let registryURL = root.appendingPathComponent("registry.json")
        guard
            let registryData = try? Data(contentsOf: registryURL),
            let registry = try? JSONSerialization.jsonObject(with: registryData) as? [String: Any],
            let registryAccounts = registry["accounts"] as? [[String: Any]],
            let registryAccount = registryAccounts.first(where: { ($0["email"] as? String) == email }),
            let expectedAccountID = registryAccount["chatgpt_account_id"] as? String,
            !expectedAccountID.isEmpty
        else {
            return .failure("saved account registry was not readable")
        }

        guard let authURL = authFileURL(forAccountID: expectedAccountID, root: root) else {
            return .failure("saved account auth file was not found")
        }
        guard
            let authData = try? Data(contentsOf: authURL),
            let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
            let tokens = auth["tokens"] as? [String: Any],
            let accessToken = tokens["access_token"] as? String,
            let accountID = tokens["account_id"] as? String,
            !accessToken.isEmpty,
            !accountID.isEmpty
        else {
            return .failure("saved account auth token was not readable")
        }

        return .success(SavedAccountAuth(email: email, accessToken: accessToken, accountID: accountID))
    }

    private func authFileURL(forAccountID accountID: String, root: URL) -> URL? {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return nil
        }
        for url in urls where url.lastPathComponent.hasSuffix(".auth.json") {
            guard
                let data = try? Data(contentsOf: url),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tokens = object["tokens"] as? [String: Any],
                let candidate = tokens["account_id"] as? String,
                candidate == accountID
            else {
                continue
            }
            return url
        }
        return nil
    }

    private func apiKeyConfigured() -> Bool {
        false
    }

    private func usageKeyConfigured() -> Bool {
        false
    }

    private func saveKeychainSecret(_ secret: String, account: String) {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiTokenUsageService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readKeychainSecret(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiTokenUsageService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8),
              !secret.isEmpty else {
            return nil
        }
        return secret
    }

    private func deleteKeychainSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiTokenUsageService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func backupActiveAuthBeforeApiMode() -> String? {
        let home = NSHomeDirectory()
        let authURL = URL(fileURLWithPath: "\(home)/.codex/auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else { return nil }
        let backupDir = URL(fileURLWithPath: "\(home)/.codex/auth-backups")
        do {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let stamp = DateFormatter.apiBackupStamp.string(from: Date())
            let backupURL = backupDir.appendingPathComponent("auth.chatgpt-before-api-\(stamp).json")
            try FileManager.default.copyItem(at: authURL, to: backupURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func runCodexLoginWithApiKey(_ apiKey: String) -> CommandResult {
        let bundledCodex = "\(codexDesktopResourcesPath)/codex"
        let codexPath = FileManager.default.isExecutableFile(atPath: bundledCodex) ? bundledCodex : "codex"
        return runWithInput(codexPath, ["login", "--with-api-key"], input: apiKey)
    }

    private func runCodexAuth(_ args: [String]) -> CommandResult {
        guard let path = codexAuthPath() else {
            return CommandResult(status: 127, output: "codex-auth was not found in known locations.")
        }
        return run(path, args)
    }

    private func codexAuthPath() -> String? {
        let home = NSHomeDirectory()
        let nvmNodeDir = URL(fileURLWithPath: "\(home)/.nvm/versions/node")
        if let versions = try? FileManager.default.contentsOfDirectory(at: nvmNodeDir, includingPropertiesForKeys: nil) {
            for versionDir in versions {
                let path = versionDir.appendingPathComponent("bin/codex-auth").path
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        let candidates = [
            "\(home)/.local/bin/codex-auth",
            "/opt/homebrew/bin/codex-auth",
            "/usr/local/bin/codex-auth"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }

        // Fallback using interactive zsh shell to check user's environment path
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which codex-auth"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        } catch {}

        return nil
    }

    private func run(_ executable: String, _ args: [String]) -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        var environment = augmentedEnvironment()
        let bundledNode = "\(codexDesktopResourcesPath)/node"
        if FileManager.default.isExecutableFile(atPath: bundledNode) {
            environment["CODEX_AUTH_NODE_EXECUTABLE"] = bundledNode
        }
        let bundledCodex = "\(codexDesktopResourcesPath)/codex"
        if FileManager.default.isExecutableFile(atPath: bundledCodex) {
            environment["CODEX_CLI_PATH"] = bundledCodex
        }
        process.environment = environment

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return CommandResult(status: process.terminationStatus, output: output)
        } catch {
            return CommandResult(status: 127, output: error.localizedDescription)
        }
    }

    private func runWithInput(_ executable: String, _ args: [String], input: String) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.environment = augmentedEnvironment()

        do {
            try process.run()
            if let data = input.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            inputPipe.fileHandleForWriting.closeFile()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return CommandResult(status: process.terminationStatus, output: output)
        } catch {
            return CommandResult(status: 127, output: error.localizedDescription)
        }
    }

    private func augmentedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = augmentedPath(from: environment["PATH"])
        return environment
    }

    private func augmentedPath(from currentPath: String?) -> String {
        let home = NSHomeDirectory()
        let candidates = [
            codexDesktopResourcesPath,
            "\(home)/.nvm/versions/node/v20.11.0/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        var seen = Set<String>()
        var parts: [String] = []
        for path in candidates + (currentPath?.split(separator: ":").map(String.init) ?? []) {
            guard !path.isEmpty, !seen.contains(path) else { continue }
            seen.insert(path)
            parts.append(path)
        }
        return parts.joined(separator: ":")
    }

    private func shellEnvironmentSetupCommand() -> String {
        let path = augmentedPath(from: nil)
        var commands = ["export PATH=\(shellEscaped(path))"]
        let bundledNode = "\(codexDesktopResourcesPath)/node"
        if FileManager.default.isExecutableFile(atPath: bundledNode) {
            commands.append("export CODEX_AUTH_NODE_EXECUTABLE=\(shellEscaped(bundledNode))")
        }
        let bundledCodex = "\(codexDesktopResourcesPath)/codex"
        if FileManager.default.isExecutableFile(atPath: bundledCodex) {
            commands.append("export CODEX_CLI_PATH=\(shellEscaped(bundledCodex))")
        }
        return commands.joined(separator: "; ")
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func displayLabel(for account: CodexAccount) -> String {
        limitedLabel(customLabel(forEmail: account.email) ?? defaultLabel(forEmail: account.email))
    }

    private func defaultLabel(forEmail email: String) -> String {
        if let first = email.first(where: { $0.isLetter || $0.isNumber }) {
            return String(first).uppercased()
        }
        return "A"
    }

    private func limitedLabel(_ label: String) -> String {
        String(label.prefix(4))
    }

    private func compactEmail(_ email: String, maximumLength: Int = 18) -> String {
        guard email.count > maximumLength else { return email }
        return String(email.prefix(maximumLength - 3)) + "..."
    }

    private func displayPlan(_ plan: String) -> String {
        guard let first = plan.first else { return plan }
        return first.uppercased() + plan.dropFirst().lowercased()
    }

    private func customLabel(forEmail email: String) -> String? {
        accountLabels()[email]
    }

    private func setCustomLabel(_ label: String, forEmail email: String) {
        var labels = accountLabels()
        labels[email] = label
        UserDefaults.standard.set(labels, forKey: labelsDefaultsKey)
    }

    private func clearCustomLabel(forEmail email: String) {
        var labels = accountLabels()
        labels.removeValue(forKey: email)
        UserDefaults.standard.set(labels, forKey: labelsDefaultsKey)
    }

    private func accountLabels() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: labelsDefaultsKey) as? [String: String] ?? [:]
    }

    private func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
