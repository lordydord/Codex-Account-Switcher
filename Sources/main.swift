import AppKit
import Foundation
import UserNotifications

struct CodexAccount {
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

struct CommandResult {
    let status: Int32
    let output: String
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let timerTickInterval: TimeInterval = 5
    private let labelsDefaultsKey = "accountDisplayLabels"
    private let remindersEnabledDefaultsKey = "usageReminderEnabled"
    private let reminderThresholdDefaultsKey = "usageReminderThreshold"
    private let autoSwitchEnabledDefaultsKey = "autoSwitchEnabled"
    private let autoSwitchThresholdDefaultsKey = "autoSwitchThreshold"
    private let refreshIntervalDefaultsKey = "refreshIntervalSeconds"
    private let idleRefreshIntervalDefaultsKey = "idleRefreshIntervalSeconds"
    private let protectFrontmostCodexDefaultsKey = "protectFrontmostCodex"
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
    private var switchingTitle = "Switching"
    private let switchAnimationFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private let statusPulseFrames = ["·", "•", "·", " "]
    private var notifiedLowUsageKeys = Set<String>()
    private var notifiedAutoSwitchPauseKeys = Set<String>()
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureNotifications()
        configureStatusButton()
        refreshAccounts(force: true)
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
                if result.status == 0 {
                    self.accounts = parsed
                    self.lastError = parsed.isEmpty ? "No codex-auth accounts found." : nil
                    self.lastUpdatedAt = Date()
                } else {
                    self.accounts = []
                    self.lastError = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                self.checkUsageReminder()
                self.checkAutoSwitch()
                self.rebuildMenu()
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
            menu.addItem(headerItem("Active: \(active.email) (\(displayPlan(active.plan)))"))
        } else {
            if !isSwitching {
                statusItem.button?.title = ""
            }
            menu.addItem(headerItem(lastError ?? "No active account"))
        }

        menu.addItem(headerItem("Updated: \(lastUpdatedText())"))
        menu.addItem(.separator())

        if !accounts.isEmpty {
            let usageHeader = headerItem("5hr remaining")
            usageHeader.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent", accessibilityDescription: "Usage remaining")
            menu.addItem(usageHeader)
            for account in toolbarAccounts() {
                menu.addItem(fiveHourUsageItem(for: account))
            }
            menu.addItem(.separator())
        }

        if accounts.isEmpty {
            let item = NSMenuItem(title: lastError ?? "No accounts available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            menu.addItem(headerItem("Accounts:"))
            for account in accounts {
                let item = NSMenuItem(title: "", action: #selector(switchAccount(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = account.email
                item.attributedTitle = accountAttributedTitle(label: displayLabel(for: account), email: account.email)
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
            let labelsItem = NSMenuItem(title: "Account Display Labels", action: nil, keyEquivalent: "")
            let labelsMenu = NSMenu()
            for account in accounts {
                let setItem = NSMenuItem(title: "Set \(account.selector) (\(account.email))...", action: #selector(setAccountLabel(_:)), keyEquivalent: "")
                setItem.target = self
                setItem.representedObject = account.email
                labelsMenu.addItem(setItem)

                let clearItem = NSMenuItem(title: "Clear \(account.selector)", action: #selector(clearAccountLabel(_:)), keyEquivalent: "")
                clearItem.target = self
                clearItem.representedObject = account.email
                clearItem.isEnabled = customLabel(forEmail: account.email) != nil
                labelsMenu.addItem(clearItem)
            }
            labelsItem.submenu = labelsMenu
            menu.addItem(labelsItem)

            let removeItem = NSMenuItem(title: "Remove Account", action: nil, keyEquivalent: "")
            let removeMenu = NSMenu()
            for account in accounts {
                let item = NSMenuItem(title: "\(displayLabel(for: account))  \(account.email)", action: #selector(removeAccount(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = account.email
                item.isEnabled = !isSwitching
                removeMenu.addItem(item)
            }
            removeItem.submenu = removeMenu
            menu.addItem(removeItem)
        }

        let reminderItem = NSMenuItem(title: "Usage Reminder", action: nil, keyEquivalent: "")
        let reminderMenu = NSMenu()
        let enableReminder = NSMenuItem(title: "Notify below \(reminderThreshold)%", action: #selector(toggleUsageReminder), keyEquivalent: "")
        enableReminder.target = self
        enableReminder.state = remindersEnabled ? .on : .off
        reminderMenu.addItem(enableReminder)

        let autoSwitch = NSMenuItem(title: "Auto-switch 5hr below \(autoSwitchThreshold)%", action: #selector(toggleAutoSwitch), keyEquivalent: "")
        autoSwitch.target = self
        autoSwitch.state = autoSwitchEnabled ? .on : .off
        autoSwitch.isEnabled = accounts.count > 1 && !isSwitching
        reminderMenu.addItem(autoSwitch)

        let protectSwitch = NSMenuItem(title: "Do not auto-switch while Codex is frontmost", action: #selector(toggleProtectFrontmostCodex), keyEquivalent: "")
        protectSwitch.target = self
        protectSwitch.state = protectFrontmostCodex ? .on : .off
        protectSwitch.isEnabled = autoSwitchEnabled
        reminderMenu.addItem(protectSwitch)

        reminderMenu.addItem(.separator())

        let setThreshold = NSMenuItem(title: "Set Notification Percentage...", action: #selector(setReminderThreshold), keyEquivalent: "")
        setThreshold.target = self
        reminderMenu.addItem(setThreshold)

        let setAutoSwitchThreshold = NSMenuItem(title: "Set Auto-switch Percentage...", action: #selector(setAutoSwitchThreshold), keyEquivalent: "")
        setAutoSwitchThreshold.target = self
        reminderMenu.addItem(setAutoSwitchThreshold)

        let testNotification = NSMenuItem(title: "Test Notification", action: #selector(testUsageReminder), keyEquivalent: "")
        testNotification.target = self
        testNotification.isEnabled = remindersEnabled
        reminderMenu.addItem(testNotification)
        reminderItem.submenu = reminderMenu
        menu.addItem(reminderItem)

        let refreshSettings = NSMenuItem(title: "Refresh Settings", action: nil, keyEquivalent: "")
        let refreshMenu = NSMenu()
        for seconds in [5, 15, 30, 60] {
            let item = NSMenuItem(title: "When Codex is active: \(seconds)s", action: #selector(setActiveRefreshInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = activeRefreshInterval == seconds ? .on : .off
            refreshMenu.addItem(item)
        }
        refreshMenu.addItem(.separator())
        for seconds in [15, 30, 60] {
            let item = NSMenuItem(title: "When idle: \(seconds)s", action: #selector(setIdleRefreshInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = idleRefreshInterval == seconds ? .on : .off
            refreshMenu.addItem(item)
        }
        refreshSettings.submenu = refreshMenu
        menu.addItem(refreshSettings)

        let refresh = NSMenuItem(title: "Force Usage Refresh", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = !isSwitching
        menu.addItem(refresh)

        let cleanBackups = NSMenuItem(title: "Clean Account Backups", action: #selector(cleanAccountBackups), keyEquivalent: "")
        cleanBackups.target = self
        cleanBackups.isEnabled = !isSwitching
        menu.addItem(cleanBackups)

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = launchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLogin)

        let quit = NSMenuItem(title: "Quit Account Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func advanceStatusAnimation() {
        guard !isSwitching, !accounts.isEmpty else { return }
        statusAnimationFrame += 1
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        statusItem.button?.title = ""
        statusItem.button?.attributedTitle = statusAttributedTitle()
    }

    private func statusAttributedTitle() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, account) in toolbarAccounts().enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: toolbarTitleAttributes(isActive: true)))
            }
            result.append(NSAttributedString(
                string: "\(toolbarLabel(for: account))\(remainingPercentNumberText(fromUsed: account.weeklyUsedPercent))",
                attributes: toolbarTitleAttributes(isActive: account.isActive)
            ))
        }
        return result
    }

    private func toolbarTitleAttributes(isActive: Bool) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor
        ]
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
        if let first = account.email.first(where: { $0.isLetter || $0.isNumber }) {
            return String(first).uppercased()
        }
        return String(displayLabel(for: account).prefix(1)).uppercased()
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

    private func fiveHourUsageItem(for account: CodexAccount) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = usageAttributedTitle(
            title: toolbarLabel(for: account),
            percent: remainingPercentText(fromUsed: account.fiveHourUsedPercent),
            reset: resetTimeText(from: account.fiveHourUsage)
        )
        item.state = account.isActive ? .on : .off
        item.toolTip = account.email
        return item
    }

    private func usageAttributedTitle(title: String, percent: String, reset: String) -> NSAttributedString {
        attributedColumns(
            "\(title)\t\(percent)\t\(reset)",
            tabs: [112, 162],
            font: NSFont.menuFont(ofSize: 0),
            color: .labelColor
        )
    }

    private func accountAttributedTitle(label: String, email: String) -> NSAttributedString {
        attributedColumns(
            "\(limitedLabel(label))\t\(email)",
            tabs: [86],
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
        alert.informativeText = "Choose the label shown in the menu bar for \(account.email). Use 01, 02, text, or an emoji."
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
        limitedLabel(customLabel(forEmail: account.email) ?? account.selector)
    }

    private func limitedLabel(_ label: String) -> String {
        String(label.prefix(5))
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
