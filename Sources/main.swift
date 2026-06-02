import AppKit
import Foundation
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

enum UsageDisplayMode: String {
    case fiveHour
    case weekly
}

enum ToolbarDisplayStyle: String {
    case detailed
    case compact
}

enum AccountPanelMode {
    case usage
    case settings
}

enum SettingsPanelAction: String {
    case usageView
    case addAccount
    case addDeviceAccount
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
    case toggleProtectCodex
    case editRefresh
    case forceRefresh
    case cleanBackups
    case quit
}

private func usageStatusColor(for percent: Int?) -> NSColor {
    guard let percent else { return .systemBlue }
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
        isDark ? NSColor.white.withAlphaComponent(0.58) : NSColor.black.withAlphaComponent(0.54)
    }

    var tertiaryText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.45) : NSColor.black.withAlphaComponent(0.42)
    }

    var valueText: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.72) : NSColor.black.withAlphaComponent(0.66)
    }

    var inactiveAccent: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.42) : NSColor.black.withAlphaComponent(0.36)
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
        isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.10)
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
        isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.10)
    }

    var progressTrack: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.11) : NSColor.black.withAlphaComponent(0.10)
    }

    var inactiveButtonFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.22) : NSColor(red: 0.90, green: 0.925, blue: 0.94, alpha: 1)
    }

    var usageInactiveButtonFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.18) : NSColor(red: 0.36, green: 0.39, blue: 0.43, alpha: 1)
    }

    var switchOffFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.18)
    }
}

struct CommandResult {
    let status: Int32
    let output: String
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
    private let protectFrontmostCodex: Bool
    private let usageMode: UsageDisplayMode
    private let toolbarDisplayStyle: ToolbarDisplayStyle
    private let activeRefreshInterval: Int
    private let idleRefreshInterval: Int
    private let labelForAccount: (CodexAccount) -> String
    private let compactEmail: (String) -> String
    private let switchAccount: (String) -> Void
    private let refresh: () -> Void
    private let showSettings: () -> Void
    private let performSettingsAction: (SettingsPanelAction) -> Void
    private let close: () -> Void
    private let toggleLaunchAtLogin: () -> Void
    private var theme: PanelTheme { PanelTheme.current(for: effectiveAppearance) }
    private let outerInset: CGFloat = 14
    private let cardGap: CGFloat = 14
    private let bottomBarHeight: CGFloat = 42
    private var accountCardHeight: CGFloat {
        bounds.height - (outerInset * 2) - cardGap - bottomBarHeight
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
        protectFrontmostCodex: Bool,
        usageMode: UsageDisplayMode,
        toolbarDisplayStyle: ToolbarDisplayStyle,
        activeRefreshInterval: Int,
        idleRefreshInterval: Int,
        labelForAccount: @escaping (CodexAccount) -> String,
        compactEmail: @escaping (String) -> String,
        switchAccount: @escaping (String) -> Void,
        refresh: @escaping () -> Void,
        showSettings: @escaping () -> Void,
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
        self.protectFrontmostCodex = protectFrontmostCodex
        self.usageMode = usageMode
        self.toolbarDisplayStyle = toolbarDisplayStyle
        self.activeRefreshInterval = activeRefreshInterval
        self.idleRefreshInterval = idleRefreshInterval
        self.labelForAccount = labelForAccount
        self.compactEmail = compactEmail
        self.switchAccount = switchAccount
        self.refresh = refresh
        self.showSettings = showSettings
        self.performSettingsAction = performSettingsAction
        self.close = close
        self.toggleLaunchAtLogin = toggleLaunchAtLogin
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 430))
        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.masksToBounds = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    private func build() {
        let background = DashboardBackgroundView(frame: bounds)
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        switch mode {
        case .usage:
            buildUsageContent()
        case .settings:
            buildSettingsContent()
        }
    }

    private func buildUsageContent() {
        if accounts.isEmpty {
            addSubview(emptyStateCard())
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

    private func buildSettingsContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(settingsHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 38)))

        let accountSection = settingsSection(frame: NSRect(x: outerInset, y: 60, width: contentWidth, height: 92), title: "Accounts")
        let accountRows = min(accounts.count, 2)
        if accountRows == 0 {
            accountSection.addSubview(label("No accounts yet", frame: NSRect(x: 16, y: 36, width: 160, height: 18), size: 12, weight: .medium, color: theme.secondaryText))
        } else {
            for (index, account) in orderedSettingsAccounts().prefix(2).enumerated() {
                accountSection.addSubview(settingsAccountRow(account, frame: NSRect(x: 12, y: 32 + CGFloat(index) * 28, width: contentWidth - 24, height: 24)))
            }
        }
        addSubview(accountSection)

        let displaySection = settingsSection(frame: NSRect(x: outerInset, y: 160, width: contentWidth, height: 86), title: "Display")
        displaySection.addSubview(segmentedRow(label: "Menu bar", frame: NSRect(x: 14, y: 32, width: contentWidth - 28, height: 24), options: [
            ("Weekly", usageMode == .weekly, SettingsPanelAction.usageWeekly),
            ("5H", usageMode == .fiveHour, SettingsPanelAction.usageFiveHour)
        ]))
        displaySection.addSubview(segmentedRow(label: "Style", frame: NSRect(x: 14, y: 58, width: contentWidth - 28, height: 24), options: [
            ("Large", toolbarDisplayStyle == .detailed, SettingsPanelAction.styleDetailed),
            ("Small", toolbarDisplayStyle == .compact, SettingsPanelAction.styleCompact)
        ]))
        addSubview(displaySection)

        let automationSection = settingsSection(frame: NSRect(x: outerInset, y: 254, width: contentWidth, height: 96), title: "Automation")
        automationSection.addSubview(settingToggleRow(title: "Launch at login", detail: "Open this helper automatically", isOn: launchAtLoginEnabled, action: .toggleLaunchAtLogin, frame: NSRect(x: 14, y: 28, width: contentWidth - 28, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Usage reminder", detail: "Alert at \(reminderThreshold)%", isOn: remindersEnabled, action: .toggleUsageReminder, frame: NSRect(x: 14, y: 58, width: 154, height: 28)))
        automationSection.addSubview(settingToggleRow(title: "Auto switch", detail: "\(autoSwitchThreshold)% 5H", isOn: autoSwitchEnabled, action: .toggleAutoSwitch, frame: NSRect(x: 186, y: 58, width: 152, height: 28)))
        addSubview(automationSection)

        addSubview(settingsFooter(frame: NSRect(x: outerInset, y: bounds.height - outerInset - bottomBarHeight, width: contentWidth, height: bottomBarHeight)))
    }

    private func settingsHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label("Settings", frame: NSRect(x: 2, y: 1, width: 120, height: 26), size: 22, weight: .semibold, color: theme.primaryText))
        header.addSubview(label("Switcher controls", frame: NSRect(x: 2, y: 27, width: 180, height: 14), size: 10.5, weight: .medium, color: theme.secondaryText))
        let back = SettingsActionButton(frame: NSRect(x: frame.width - 78, y: 4, width: 78, height: 28), title: "Usage", color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func settingsSection(frame: NSRect, title: String) -> NSView {
        let section = RoundedPanelView(frame: frame, fillColor: cardFillColor(isActive: false), borderColor: cardBorderColor(isActive: false), cornerRadius: 16)
        section.addSubview(label(title, frame: NSRect(x: 14, y: 10, width: frame.width - 28, height: 18), size: 12, weight: .semibold, color: theme.primaryText))
        return section
    }

    private func settingsAccountRow(_ account: CodexAccount, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        let accent = account.isActive ? NSColor.systemGreen : theme.inactiveAccent
        row.addSubview(label(labelForAccount(account), frame: NSRect(x: 0, y: 0, width: 22, height: 24), size: 17, weight: .semibold, color: accent, alignment: .center))
        row.addSubview(label(compactSettingsEmail(account.email), frame: NSRect(x: 30, y: 2, width: 144, height: 20), size: 11.5, weight: .medium, color: theme.primaryText))

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
            ("Refresh", .editRefresh, 58)
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

        let more = SettingsActionButton(frame: NSRect(x: frame.width - 74, y: buttonY, width: 62, height: 26), title: "Clean", color: theme.bottomBarFill, textColor: theme.primaryText)
        more.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.cleanBackups.rawValue)
        more.target = self
        more.action = #selector(settingsActionPressed(_:))
        footer.addSubview(more)
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

        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: 377, y: 29, width: 32, height: 32), action: #selector(refreshPressed))
        view.addSubview(refreshButton)

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: 421, y: 28, width: 34, height: 34), action: #selector(settingsPressed(_:)))
        view.addSubview(settingsButton)

        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: 465, y: 29, width: 32, height: 32), action: #selector(closePressed))
        view.addSubview(closeButton)

        return view
    }

    private func accountCard(_ account: CodexAccount, frame: NSRect) -> NSView {
        let weeklyPercent = account.weeklyUsedPercent
        let fiveHourPercent = account.fiveHourUsedPercent
        let weeklyColor = accentColor(for: weeklyPercent, isActive: account.isActive)
        let fiveHourColor = accentColor(for: fiveHourPercent, isActive: account.isActive)
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

        let statusTitle = account.isActive ? "Active" : (isSwitching ? "Switching..." : "Switch")
        let buttonColor = account.isActive ? fiveHourColor : theme.usageInactiveButtonFill
        let switchButton = PillButton(frame: NSRect(x: 18, y: 20, width: frame.width - 36, height: 30), title: statusTitle, color: buttonColor, showsCheckmark: account.isActive, allowsHover: false)
        switchButton.target = self
        switchButton.action = #selector(accountSwitchPressed(_:))
        switchButton.identifier = NSUserInterfaceItemIdentifier(account.email)
        switchButton.isEnabled = !account.isActive && !isSwitching && !accounts.isEmpty
        card.addSubview(switchButton)

        card.addSubview(label(labelText, frame: NSRect(x: 18, y: 68, width: frame.width - 36, height: 30), size: 26, weight: .semibold, color: fiveHourColor, alignment: .center))
        card.addSubview(label(compactCardEmail(account.email), frame: NSRect(x: 18, y: 99, width: frame.width - 36, height: 14), size: 9.2, weight: .medium, color: theme.tertiaryText, alignment: .center))

        let ringSize: CGFloat = columnsFitWide(frame.width) ? 150 : 116
        let ringX = (frame.width - ringSize) / 2
        let ring = UsageRingView(frame: NSRect(x: ringX, y: 116, width: ringSize, height: ringSize), color: fiveHourColor, trackColor: theme.ringTrack, percent: CGFloat(fiveHourPercent ?? 0) / 100, isActive: account.isActive)
        card.addSubview(ring)
        card.addSubview(PercentCenterLabelView(frame: NSRect(x: ringX + 8, y: 148, width: ringSize - 16, height: 42), percent: fiveHourPercent, color: fiveHourColor))
        card.addSubview(label("Remaining", frame: NSRect(x: ringX + 18, y: 184, width: ringSize - 36, height: 18), size: 10.5, weight: .medium, color: theme.secondaryText, alignment: .center))

        card.addSubview(label("5H Remaining", frame: NSRect(x: 18, y: 242, width: frame.width - 36, height: 18), size: 11, weight: .semibold, color: theme.tertiaryText, alignment: .center))

        let divider = NSView(frame: NSRect(x: 18, y: 272, width: frame.width - 36, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = theme.divider.cgColor
        card.addSubview(divider)

        let weeklyLabel = label("Weekly", frame: NSRect(x: 18, y: 288, width: 64, height: 16), size: 10.5, weight: .medium, color: theme.secondaryText)
        card.addSubview(weeklyLabel)
        let weeklyValue = label(percentText(weeklyPercent), frame: NSRect(x: frame.width - 60, y: 288, width: 42, height: 16), size: 10.5, weight: .semibold, color: theme.valueText, alignment: .right)
        card.addSubview(weeklyValue)

        let progress = ProgressLineView(frame: NSRect(x: 18, y: 310, width: frame.width - 36, height: 7), color: weeklyColor, trackColor: theme.progressTrack, percent: CGFloat(weeklyPercent ?? 0) / 100)
        card.addSubview(progress)
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

    private func compactCardEmail(_ email: String) -> String {
        let maximumLength = 16
        guard email.count > maximumLength else { return email }
        return String(email.prefix(maximumLength - 3)) + "..."
    }

    private func compactSettingsEmail(_ email: String) -> String {
        let maximumLength = 21
        guard email.count > maximumLength else { return email }
        return String(email.prefix(maximumLength - 3)) + "..."
    }

    private func columnsFitWide(_ width: CGFloat) -> Bool {
        width > 260
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
        return card
    }

    private func bottomBar(frame: NSRect) -> NSView {
        let bar = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 14)
        let toolbarInset: CGFloat = 14
        let toolbarGap: CGFloat = 14
        let iconSize: CGFloat = 28
        let clockSize: CGFloat = 24
        let iconY = (frame.height - iconSize) / 2
        let clockY = (frame.height - clockSize) / 2

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: toolbarInset, y: iconY, width: iconSize, height: iconSize), action: #selector(settingsPressed(_:)))
        bar.addSubview(settingsButton)

        let clockX = toolbarInset + iconSize + toolbarGap
        let clock = CircleIconView(frame: NSRect(x: clockX, y: clockY, width: clockSize, height: clockSize), color: theme.iconTint, symbol: "clock", symbolColor: theme.iconTint)
        bar.addSubview(clock)
        let timeX = clockX + clockSize + toolbarGap
        bar.addSubview(CenteredTextView(frame: NSRect(x: timeX, y: 9, width: 72, height: 24), text: lastUpdatedText, size: 10.5, weight: .medium, color: theme.primaryText, alignment: .left))

        let closeX = frame.width - toolbarInset - iconSize
        let refreshX = closeX - toolbarGap - iconSize
        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: refreshX, y: iconY, width: iconSize, height: iconSize), action: #selector(refreshPressed))
        bar.addSubview(refreshButton)

        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: closeX, y: iconY, width: iconSize, height: iconSize), action: #selector(closePressed))
        bar.addSubview(closeButton)
        return bar
    }

    private func usageColor(for percent: Int?) -> NSColor {
        usageStatusColor(for: percent)
    }

    private func accentColor(for percent: Int?, isActive: Bool) -> NSColor {
        guard isActive else { return NSColor.systemGray.withAlphaComponent(0.32) }
        return usageColor(for: percent)
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
        return usageColor(for: account.fiveHourUsedPercent).withAlphaComponent(theme.isDark ? 0.68 : 0.52)
    }

    private func activeCardFillColor(for percent: Int?) -> NSColor {
        guard let percent else {
            return theme.activeCardFill
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

    private func iconButton(symbol: String, frame: NSRect, action: Selector) -> NSButton {
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
        return button
    }

    @objc private func refreshPressed() {
        refresh()
    }

    @objc private func settingsPressed(_ sender: NSButton) {
        showSettings()
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
        guard let rawValue = sender.identifier?.rawValue,
              let action = SettingsPanelAction(rawValue: rawValue) else { return }
        performSettingsAction(action)
    }

    @objc private func accountSettingsActionPressed(_ sender: NSControl) {
        guard let rawValue = sender.identifier?.rawValue else { return }
        let parts = rawValue.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "switch":
            switchAccount(parts[1])
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
        layer?.borderWidth = 1.1
        layer?.borderColor = borderColor.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.24
        layer?.shadowRadius = 18
        layer?.shadowOffset = NSSize(width: 0, height: -8)
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
        color.withAlphaComponent(0.92).setFill()
        fill.roundedPath(radius: track.height / 2).fill()
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
            .font: NSFont.systemFont(ofSize: 27, weight: .semibold),
            .foregroundColor: color
        ]
        let percentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
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
        let lineWidth: CGFloat = 9
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
        color.withAlphaComponent(isActive ? 0.94 : 0.72).setStroke()
        fill.stroke()
    }
}

final class PillButton: NSButton {
    private let pillColor: NSColor
    private let showsCheckmark: Bool
    private let allowsHover: Bool
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, title: String, color: NSColor, showsCheckmark: Bool = false, allowsHover: Bool = true) {
        self.pillColor = color
        self.showsCheckmark = showsCheckmark
        self.allowsHover = allowsHover
        super.init(frame: frame)
        self.title = title
        bezelStyle = .rounded
        isBordered = false
        font = .systemFont(ofSize: 14, weight: .semibold)
        contentTintColor = .white
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        layer?.backgroundColor = pillColor.cgColor
        layer?.borderWidth = showsCheckmark ? 1 : 0
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
        super.draw(dirtyRect)
        guard showsCheckmark,
              let image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) else {
            return
        }
        image.isTemplate = true
        NSColor.white.withAlphaComponent(0.92).set()
        image.draw(in: NSRect(x: bounds.maxX - 35, y: (bounds.height - 14) / 2, width: 14, height: 14))
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

final class AccountFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let accountPanelSize = NSSize(width: 380, height: 430)
    private var accountPanel: NSPanel?
    private var accountPanelMode: AccountPanelMode = .usage
    private let timerTickInterval: TimeInterval = 5
    private let labelsDefaultsKey = "accountDisplayLabels"
    private let remindersEnabledDefaultsKey = "usageReminderEnabled"
    private let reminderThresholdDefaultsKey = "usageReminderThreshold"
    private let autoSwitchEnabledDefaultsKey = "autoSwitchEnabled"
    private let autoSwitchThresholdDefaultsKey = "autoSwitchThreshold"
    private let refreshIntervalDefaultsKey = "refreshIntervalSeconds"
    private let idleRefreshIntervalDefaultsKey = "idleRefreshIntervalSeconds"
    private let protectFrontmostCodexDefaultsKey = "protectFrontmostCodex"
    private let toolbarDisplayStyleDefaultsKey = "toolbarDisplayStyle"
    private let autoSwitchNotificationCategory = "AUTO_SWITCH_CONFIRM"
    private let switchNowActionIdentifier = "SWITCH_NOW"
    private let launchAgentIdentifier = "com.mohamedfuad.codexaccountswitcher"
    private var refreshTimer: Timer?
    private var statusAnimationTimer: Timer?
    private var statusAnimationFrame = 0
    private var accounts: [CodexAccount] = []
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var lastRefreshStartedAt: Date?
    private var isRefreshing = false
    private var pendingForceRefresh = false
    private var isSwitching = false
    private var switchAnimationTimer: Timer?
    private var switchAnimationFrame = 0
    private var outsideClickMonitor: Any?
    private var didResignActiveObserver: NSObjectProtocol?
    private var switchingTitle = "Switching"
    private let switchAnimationFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private let statusPulseFrames = ["·", "•", "·", " "]
    private var notifiedLowUsageKeys = Set<String>()
    private var notifiedAutoSwitchPauseKeys = Set<String>()
    private var settingsMenu = NSMenu()
    private weak var accountLabelDialogField: NSTextField?
    private weak var accountLabelDialogPopup: NSPopUpButton?
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
            UserDefaults.standard.bool(forKey: autoSwitchEnabledDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoSwitchEnabledDefaultsKey)
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
                return true
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
    private var demoMode: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO"] == "1"
    }
    private var showPanelOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_PANEL"] == "1"
    }
    private var showSettingsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_SETTINGS"] == "1"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureNotifications()
        configureStatusButton()
        refreshAccounts(force: true)
        if showPanelOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showAccountPanel()
            }
            if showSettingsOnLaunch {
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
            self?.closeAccountPanel()
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeAccountPanel()
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
        let category = UNNotificationCategory(
            identifier: autoSwitchNotificationCategory,
            actions: [switchNow, later],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
            "/Applications/Codex.app/Contents/Resources/icon.icns",
            "/Applications/Codex.app/Contents/Resources/codexTemplate@2x.png",
            "/Applications/Codex.app/Contents/Resources/codexTemplate.png"
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
            lastError = nil
            lastUpdatedAt = Date()
            rebuildMenu()
            return
        }
        guard !isRefreshing else {
            if force { pendingForceRefresh = true }
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
        DispatchQueue.global(qos: .utility).async {
            var result = self.runCodexAuth(["list"])
            if result.status != 0 {
                result = self.runCodexAuth(["list", "--skip-api"])
            }
            let parsed = result.status == 0 ? self.parseAccounts(result.output) : []
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

                let stateChanged = newAccounts != self.accounts || newError != self.lastError
                if stateChanged || force {
                    self.accounts = newAccounts
                    self.lastError = newError
                    self.lastUpdatedAt = Date()
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

    private func rebuildMenu() {
        let menu = NSMenu()

        if let active = accounts.first(where: { $0.isActive }) {
            if !isSwitching {
                updateStatusTitle()
            }
            menu.addItem(headerItem("Active: \(compactEmail(active.email)) (\(displayPlan(active.plan)))"))
        } else {
            if !isSwitching {
                statusItem.button?.title = ""
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
                item.toolTip = "Plan \(account.plan), 5h \(account.fiveHourUsage), weekly \(account.weeklyUsage)"
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

        let refreshSettings = NSMenuItem(title: "Refresh Settings", action: #selector(showRefreshSettingsDialog), keyEquivalent: "")
        refreshSettings.target = self
        menu.addItem(refreshSettings)

        let refresh = NSMenuItem(title: "Force Usage Refresh", action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self
        refresh.isEnabled = !isSwitching
        menu.addItem(refresh)

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
        showAccountPanel()
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

    private func makeAccountPanel() -> NSPanel {
        let panel = AccountFloatingPanel(
            contentRect: NSRect(origin: .zero, size: accountPanelSize),
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

    private func refreshAccountPanelContent() {
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
            protectFrontmostCodex: protectFrontmostCodex,
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
                self?.closeAccountPanel()
                self?.switchTo(query: email)
            },
            refresh: { [weak self] in
                self?.refreshAccounts(force: true)
            },
            showSettings: { [weak self] in
                self?.showSettingsPanel()
            },
            performSettingsAction: { [weak self] action in
                self?.handleSettingsPanelAction(action)
            },
            close: { [weak self] in
                self?.closeAccountPanel()
            },
            toggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            }
        )
        let controller = NSViewController()
        controller.view = panel
        accountPanel?.contentViewController = controller
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

        var x = buttonFrame.midX - accountPanelSize.width / 2
        x = max(visibleFrame.minX + margin, min(x, visibleFrame.maxX - accountPanelSize.width - margin))

        var y = buttonFrame.minY - accountPanelSize.height - margin
        if y < visibleFrame.minY + margin {
            y = min(buttonFrame.maxY + margin, visibleFrame.maxY - accountPanelSize.height - margin)
        }

        panel.setFrame(NSRect(x: x, y: y, width: accountPanelSize.width, height: accountPanelSize.height), display: true)
    }

    private func positionAccountPanelAtScreenFallback(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 12
        let x = visibleFrame.maxX - accountPanelSize.width - margin
        let y = visibleFrame.maxY - accountPanelSize.height - margin
        panel.setFrame(NSRect(x: x, y: y, width: accountPanelSize.width, height: accountPanelSize.height), display: true)
    }

    private func closeAccountPanel() {
        accountPanel?.orderOut(nil)
    }

    private func handleSettingsPanelAction(_ action: SettingsPanelAction) {
        switch action {
        case .usageView:
            accountPanelMode = .usage
            refreshAccountPanelContent()
        case .addAccount:
            addAccountBrowser()
        case .addDeviceAccount:
            addAccountDeviceCode()
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
        case .toggleProtectCodex:
            toggleProtectFrontmostCodex()
        case .editRefresh:
            showRefreshSettingsDialog()
        case .forceRefresh:
            refreshNow()
        case .cleanBackups:
            cleanAccountBackups()
        case .quit:
            NSApp.terminate(nil)
        }
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
        }
    }

    private func showSettingsMenu(from sender: NSView) {
        settingsMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    private func showSettingsMenuForScreenshot() {
        guard demoMode, let panel = accountPanel else { return }
        let point = NSPoint(x: panel.frame.maxX - 190, y: panel.frame.maxY - 96)
        settingsMenu.popUp(positioning: nil, at: point, in: nil)
    }

    private func advanceStatusAnimation() {
        guard !isSwitching, !accounts.isEmpty else { return }
        statusAnimationFrame += 1
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = statusAttributedTitle()
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
    }

    private func statusAttributedTitle() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, account) in toolbarAccounts().enumerated() {
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
        if let account, account.isActive {
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
            return String(custom.prefix(1)).uppercased()
        }
        return defaultLabel(forEmail: account.email)
    }

    private func codexIsFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let name = app.localizedName?.lowercased() ?? ""
        let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
        return name == "codex" || bundleIdentifier.contains("codex")
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
            color: .labelColor
        )
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
        guard let lastUpdatedAt else {
            return "never"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: lastUpdatedAt)
    }

    private func normalizedRefreshInterval(_ seconds: Int) -> Int {
        [5, 15, 30, 60].contains(seconds) ? seconds : 5
    }

    @objc private func refreshNow() {
        refreshAccounts(force: true)
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
        guard !accounts.isEmpty else { return }
        let popup = accountPopup(width: 300)
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
        alert.informativeText = "Choose an account and set the short menu-bar label. Leave it blank to clear the custom label."
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

        let autoSwitchCheck = NSButton(checkboxWithTitle: "Auto-switch on low 5H", target: nil, action: nil)
        autoSwitchCheck.state = autoSwitchEnabled ? .on : .off
        autoSwitchCheck.isEnabled = accounts.count > 1 && !isSwitching

        let protectCheck = NSButton(checkboxWithTitle: "Do not auto-switch while Codex is frontmost", target: nil, action: nil)
        protectCheck.state = protectFrontmostCodex ? .on : .off

        let notifyField = NSTextField(frame: NSRect(x: 0, y: 0, width: 70, height: 24))
        notifyField.stringValue = "\(reminderThreshold)"
        let autoSwitchField = NSTextField(frame: NSRect(x: 0, y: 0, width: 70, height: 24))
        autoSwitchField.stringValue = "\(autoSwitchThreshold)"

        let notifyRow = settingsRow(label: "Notify %", control: notifyField)
        let autoSwitchRow = settingsRow(label: "Switch %", control: autoSwitchField)
        let stack = NSStackView(views: [notifyCheck, notifyRow, autoSwitchCheck, autoSwitchRow, protectCheck])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 138)

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
        let switchValue = Int(autoSwitchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let notifyValue, (1...99).contains(notifyValue),
              let switchValue, (1...99).contains(switchValue) else {
            showAlert(title: "Invalid percentage", message: "Enter numbers from 1 to 99.")
            return
        }

        remindersEnabled = notifyCheck.state == .on
        autoSwitchEnabled = autoSwitchCheck.state == .on
        protectFrontmostCodex = protectCheck.state == .on
        reminderThreshold = notifyValue
        autoSwitchThreshold = switchValue
        if remindersEnabled || autoSwitchEnabled {
            configureNotifications()
        }
        checkUsageReminder()
        checkAutoSwitch()
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
        alert.informativeText = "Choose the label shown in the menu bar for \(account.email). Use a short letter, number, word, or emoji."
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

    private func switchTo(query: String) {
        guard !isSwitching else { return }
        let target = accounts.first(where: { $0.email == query || $0.selector == query })
        isSwitching = true
        beginSwitchAnimation(label: target.map(displayLabel(for:)) ?? query)
        rebuildMenu()

        DispatchQueue.global(qos: .userInitiated).async {
            if let syncError = self.syncActiveAuthSnapshot() {
                DispatchQueue.main.async {
                    self.isSwitching = false
                    self.endSwitchAnimation()
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
                    self.showAlert(title: "Switch failed", message: switchResult.output)
                    self.refreshAccounts(force: true)
                }
                return
            }

            let restartResult = self.restartCodexApp()
            DispatchQueue.main.async {
                self.isSwitching = false
                self.endSwitchAnimation()
                if restartResult.status != 0 {
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
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
        statusItem.button?.title = "\(switchingTitle) \(frame)"
    }

    private func endSwitchAnimation() {
        switchAnimationTimer?.invalidate()
        switchAnimationTimer = nil
    }

    private func checkUsageReminder() {
        guard remindersEnabled, let active = accounts.first(where: { $0.isActive }) else { return }
        checkUsageReminder(account: active, metric: "5hr", percent: active.fiveHourUsedPercent)
        checkUsageReminder(account: active, metric: "Weekly", percent: active.weeklyUsedPercent)
    }

    private func checkAutoSwitch() {
        guard autoSwitchEnabled,
              !isSwitching,
              accounts.count > 1,
              let active = accounts.first(where: { $0.isActive }),
              let activeFiveHour = active.fiveHourUsedPercent,
              activeFiveHour <= autoSwitchThreshold,
              let target = bestAutoSwitchTarget(excluding: active.email) else {
            return
        }

        let key = "\(active.email)|\(target.email)|\(autoSwitchThreshold)"
        guard !notifiedAutoSwitchPauseKeys.contains(key) else { return }
        notifiedAutoSwitchPauseKeys.insert(key)
        sendAutoSwitchPrompt(active: active, target: target, activeFiveHour: activeFiveHour)
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
        guard response.actionIdentifier == switchNowActionIdentifier,
              let targetEmail = response.notification.request.content.userInfo["targetEmail"] as? String else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.switchTo(query: targetEmail)
        }
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

    private func runAccountMaintenance(title: String, args: [String], restartAfterSuccess: Bool = false) {
        guard !isSwitching else { return }
        isSwitching = true
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
        transcript.append("Force-quitting Codex App process tree...")

        for attempt in 1...6 {
            let pids = codexAppPIDs()
            if pids.isEmpty { break }
            let signal = attempt == 1 ? "-TERM" : "-KILL"
            _ = run("/bin/kill", [signal] + pids)
            Thread.sleep(forTimeInterval: 1)
        }

        let remaining = codexAppPIDs()
        if !remaining.isEmpty {
            return CommandResult(status: 1, output: "Codex processes survived force quit: \(remaining.joined(separator: ", "))")
        }

        transcript.append("Opening Codex App through codex-auth...")
        let appResult = runCodexAuth(["app", "--platform", "mac"])
        if appResult.status != 0 {
            transcript.append("codex-auth app failed; falling back to open -a Codex.")
            let openResult = run("/usr/bin/open", ["-a", "Codex"])
            if openResult.status != 0 {
                return CommandResult(status: openResult.status, output: transcript.joined(separator: "\n") + "\n" + openResult.output)
            }
        }

        Thread.sleep(forTimeInterval: 4)
        let runningResult = run("/usr/bin/osascript", ["-e", "application \"Codex\" is running"])
        if runningResult.output.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
            transcript.append("Codex App did not report as running after launch.")
            return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
        }

        return CommandResult(status: 0, output: transcript.joined(separator: "\n"))
    }

    private func codexAppPIDs() -> [String] {
        let result = run("/usr/bin/pgrep", ["-f", "/Applications/Codex\\.app/Contents/"])
        guard result.status == 0 else { return [] }
        return result.output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func parseAccounts(_ output: String) -> [CodexAccount] {
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
            let fiveHour = Self.parseUsage(tokens, from: cursor)
            cursor = fiveHour.nextIndex
            let weekly = Self.parseUsage(tokens, from: cursor)
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
            )
        ]
    }

    private static func parseUsage(_ tokens: [String], from startIndex: Int) -> (text: String, usedPercent: Int?, nextIndex: Int) {
        guard startIndex < tokens.count else {
            return ("-", nil, startIndex)
        }

        let first = tokens[startIndex]
        if first == "-" {
            return ("-", nil, startIndex + 1)
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

        return (parts.joined(separator: " "), firstPercent(in: first), cursor)
    }

    private static func firstPercent(in token: String) -> Int? {
        let digits = token.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
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
        let bundledNode = "/Applications/Codex.app/Contents/Resources/node"
        if FileManager.default.isExecutableFile(atPath: bundledNode) {
            environment["CODEX_AUTH_NODE_EXECUTABLE"] = bundledNode
        }
        let bundledCodex = "/Applications/Codex.app/Contents/Resources/codex"
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

    private func augmentedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = augmentedPath(from: environment["PATH"])
        return environment
    }

    private func augmentedPath(from currentPath: String?) -> String {
        let home = NSHomeDirectory()
        let candidates = [
            "/Applications/Codex.app/Contents/Resources",
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
        let bundledNode = "/Applications/Codex.app/Contents/Resources/node"
        if FileManager.default.isExecutableFile(atPath: bundledNode) {
            commands.append("export CODEX_AUTH_NODE_EXECUTABLE=\(shellEscaped(bundledNode))")
        }
        let bundledCodex = "/Applications/Codex.app/Contents/Resources/codex"
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
        String(label.prefix(5))
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
