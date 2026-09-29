import AppKit
import ApplicationServices
import Foundation
import Security
import UserNotifications

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
    private let fiveHourMenuBarMigrationDefaultsKey = "fiveHourMenuBarMigrationV1"
    private let selectedRouteBProfileDefaultsKey = "selectedRouteBProfileID"
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
    private let switchHistoryDefaultsKey = "switchHistoryV1"
    private let resetHistoryDefaultsKey = "resetHistoryV1"
    private let lastSwitchDateDefaultsKey = "lastSuccessfulSwitchDate"
    private let switchCooldown: TimeInterval = 90
    private let resetCreditsRefreshInterval: TimeInterval = 300
    private let directUsageRefreshInterval: TimeInterval = 30
    private var refreshTimer: Timer?
    private var cachedCodexAuthPath: String?
    private let codexAuthPathLock = NSLock()
    private var isResolvingCodexAuthPath = false
    private var codexAuthResolveFinished = false
    private var labelsCache: [String: String]?
    private var lastPanelSignature: String?
    private let authIndexLock = NSLock()
    private var authIndexCache: (modified: Date, index: [String: URL])?
    private var currentStatusTitleKey = ""
    private var statusSpinnerFrame: Int?
    private var accounts: [CodexAccount] = []
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var lastRefreshStartedAt: Date?
    private var lastResetCreditsRefreshAt: Date?
    private var lastDirectUsageRefreshAt: Date?
    private var isRefreshing = false
    private var isRefreshingResetCredits = false
    private var pendingForceRefresh = false
    private var isSwitching = false
    private var isRedeemingReset = false
    private var resetStatusText: String?
    private var directUsageSnapshotsByEmail: [String: DirectUsageSnapshot] = [:]
    private var armedSwitchEmail: String?
    private var armedSwitchClearWorkItem: DispatchWorkItem?
    private var switchAnimationTimer: Timer?
    private var switchAnimationFrame = 0
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var didResignActiveObserver: NSObjectProtocol?
    private var suppressStatusToggleOpenUntil: Date?
    private var panelRefreshScheduled = false
    private var statusAnimationTitle = "Switching"
    private var statusAnimationGeneration = 0
    private var notifiedLowUsageKeys = Set<String>()
    private var notifiedAutoSwitchPauseKeys = Set<String>()
    private var pendingResumeWorkItems: [String: DispatchWorkItem] = [:]
    private var savedClipboardString: String?
    private weak var accountLabelDialogField: NSTextField?
    private weak var accountLabelDialogPopup: NSPopUpButton?
    private var notificationHealthTitle = "Checking"
    private var notificationHealthColor = NSColor.systemOrange
    private var updateHealthTitle = "Check"
    private var updateHealthColor = NSColor.systemOrange
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
            UsageDisplayMode(rawValue: UserDefaults.standard.string(forKey: "usageDisplayMode") ?? "") ?? .fiveHour
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
    private var showRouteBOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_ROUTE_B"] == "1"
    }
    private var showResetsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_RESETS"] == "1"
    }

    /// Removes the retired API-mode keys once; later launches skip the keychain entirely.
    private func removeLegacyApiModeDataIfNeeded() {
        let migrationKey = "legacyApiModeRemovedV3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(false, forKey: apiModeActiveDefaultsKey)
        deleteKeychainSecret(account: apiCodexKeyAccount)
        deleteKeychainSecret(account: apiUsageKeyAccount)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if demoMode, let appearance = ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "light" ? .aqua : .darkAqua)
        }
        if ProcessInfo.processInfo.arguments.contains("--install-lifecycle-monitor") {
            do {
                try installLaunchAgent()
            } catch {
                NSLog("Codex Account Switcher lifecycle monitor install failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--self-test-reset-logic") {
            let result = resetLogicSelfTest()
            FileHandle.standardOutput.write(Data("\(result)\n".utf8))
            NSApp.terminate(nil)
            return
        }
        migrateMenuBarUsageModeToFiveHourIfNeeded()
        removeLegacyApiModeDataIfNeeded()
        DispatchQueue.global(qos: .utility).async {
            let accountsDirectory = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".codex/accounts", isDirectory: true)
            _ = AuthBackupPruner.prune(in: accountsDirectory, keepingPerAccount: 10)
        }
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
        timer.tolerance = 1
        RunLoop.current.add(timer, forMode: .common)
        refreshTimer = timer

        installPanelDismissHandlers()
    }

    private func migrateMenuBarUsageModeToFiveHourIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: fiveHourMenuBarMigrationDefaultsKey) else { return }
        usageMode = .fiveHour
        UserDefaults.standard.set(true, forKey: fiveHourMenuBarMigrationDefaultsKey)
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
                    self.refreshAccountPanelContentIfVisible()
                }
            }
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.toolTip = "Codex Account Switcher"
        button.image = MenuBarGlyph.symbol("arrow.left.arrow.right", color: nil)
        button.imagePosition = .imageOnly
        button.imageHugsTitle = true
        button.target = self
        button.action = #selector(toggleAccountPanel)
    }


    private func refreshAccountsIfNeeded() {
        let interval = codexIsFrontmost() ? activeRefreshInterval : idleRefreshInterval
        if let lastRefreshStartedAt,
           Date().timeIntervalSince(lastRefreshStartedAt) < TimeInterval(interval) {
            return
        }
        refreshAccounts(force: false)
    }

    private func refreshAccounts(force: Bool = false, refreshResets: Bool = true) {
        guard !isSwitching, !isRedeemingReset else { return }
        if demoMode {
            accounts = demoAccounts()
            resetCreditsByEmail = demoResetCreditsByEmail(for: accounts)
            lastError = nil
            lastUpdatedAt = Date()
            refreshUI()
            return
        }
        guard !isRefreshing else {
            if force {
                pendingForceRefresh = true
                refreshUI()
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
        let shouldRefreshResets = !isRefreshingResetCredits && ResetRefreshPolicy.shouldRefresh(
            lastRefresh: lastResetCreditsRefreshAt,
            ttl: resetCreditsRefreshInterval,
            force: force && refreshResets
        )
        if shouldRefreshResets {
            isRefreshingResetCredits = true
        }
        let shouldRefreshDirectUsage = UsageRefreshPolicy.shouldRefresh(
            lastRefresh: lastDirectUsageRefreshAt,
            ttl: directUsageRefreshInterval,
            force: force
        )
        if force {
            refreshUI()
        }
        DispatchQueue.global(qos: .utility).async {
            var result = self.runCodexAuth(force ? ["list", "--debug"] : ["list"])
            var usedSkipAPI = false
            if result.status != 0 {
                result = self.runCodexAuth(["list", "--skip-api"])
                usedSkipAPI = result.status == 0
            }
            let parsed = result.status == 0 ? self.parseAccounts(result.output, usageIsLive: !usedSkipAPI) : []
            let completedResult = result
            Task {
                async let resetTask = self.fetchResetCreditsForRefresh(
                    accounts: parsed,
                    shouldRefresh: completedResult.status == 0 && shouldRefreshResets
                )
                async let directUsageTask = self.fetchDirectUsageForRefresh(
                    accounts: parsed,
                    shouldRefresh: completedResult.status == 0 && shouldRefreshDirectUsage
                )
                let (resetResults, directUsageResults) = await (resetTask, directUsageTask)
                await MainActor.run {
                self.isRefreshing = false
                if shouldRefreshResets {
                    self.isRefreshingResetCredits = false
                }
                var newAccounts: [CodexAccount]
                let newError: String?
                if completedResult.status == 0 {
                    newAccounts = parsed
                    newError = parsed.isEmpty ? "No codex-auth accounts found." : nil
                } else {
                    newAccounts = []
                    newError = completedResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if completedResult.status == 0 {
                    let validEmails = Set(newAccounts.map(\.email))
                    self.directUsageSnapshotsByEmail = LastKnownGoodSnapshotPolicy.merged(
                        current: self.directUsageSnapshotsByEmail,
                        successful: directUsageResults,
                        validKeys: validEmails
                    )
                    if shouldRefreshDirectUsage {
                        self.lastDirectUsageRefreshAt = Date()
                    }
                }
                newAccounts = self.applyingDirectUsageSnapshots(to: newAccounts)

                let previousResetCredits = self.resetCreditsByEmail
                if completedResult.status == 0 && shouldRefreshResets {
                    self.resetCreditsByEmail = resetResults
                    self.lastResetCreditsRefreshAt = Date()
                }

                let stateChanged = newAccounts != self.accounts || newError != self.lastError || self.resetCreditsByEmail != previousResetCredits
                if completedResult.status == 0 {
                    self.lastUpdatedAt = Date()
                }
                if stateChanged || force || self.accountPanel?.isVisible == true {
                    self.accounts = newAccounts
                    self.lastError = newError
                    self.checkUsageReminder()
                    self.checkAutoSwitch()
                    self.refreshUI()
                }

                if self.pendingForceRefresh {
                    self.pendingForceRefresh = false
                    self.refreshAccounts(force: true, refreshResets: false)
                }
                }
            }
        }
    }


    private func refreshUI() {
        if !isSwitching {
            if accounts.contains(where: { $0.isActive }) {
                updateStatusTitle()
            } else {
                clearStatusTitle()
            }
        }
        if accountPanel?.isVisible == true {
            refreshAccountPanelContentIfVisible()
        } else {
            accountPanel = nil
            lastPanelSignature = nil
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
        refreshAccountPanelContent(force: true)
        refreshNotificationHealth(rebuildVisiblePanel: true)
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        let isStale = lastUpdatedAt.map { Date().timeIntervalSince($0) > 10 } ?? true
        if isStale {
            refreshAccounts(force: true, refreshResets: false)
        }
    }

    private func showSettingsPanel() {
        accountPanelMode = .settings
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent(force: true)
        refreshNotificationHealth(rebuildVisiblePanel: true)
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func showRouteBPanel() {
        accountPanelMode = .routeB
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent(force: true)
        refreshNotificationHealth(rebuildVisiblePanel: true)
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
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
        if let size = accountPanel?.contentViewController?.view.frame.size, size.width > 0, size.height > 0 {
            return size
        }
        return AccountSwitcherPanelView.preferredSize(mode: accountPanelMode, accountCount: toolbarAccounts().count)
    }

    /// Everything the panel draws, flattened. When it matches the last build the
    /// rebuild is skipped, so the open panel no longer re-creates its views on
    /// every background refresh.
    private func panelSignature() -> String {
        let health = healthStatusRows().map { "\($0.title)=\($0.value)" }.joined(separator: ",")
        let resets = resetCreditsByEmail.keys.sorted().map { email in
            "\(email):\(String(describing: resetCreditsByEmail[email]))"
        }.joined(separator: ";")
        return [
            "\(accountPanelMode)",
            String(describing: accounts),
            lastUpdatedText(),
            lastError ?? "",
            "\(isSwitching)",
            "\(confirmBeforeSwitching)|\(armedSwitchEmail ?? "")",
            "\(launchAtLoginEnabled())|\(remindersEnabled)|\(reminderThreshold)",
            "\(autoSwitchMode.rawValue)|\(autoSwitchThreshold)|\(autoResumeMode.rawValue)",
            "\(usageMode.rawValue)|\(toolbarDisplayStyle.rawValue)|\(activeRefreshInterval)|\(idleRefreshInterval)",
            UserDefaults.standard.string(forKey: selectedRouteBProfileDefaultsKey) ?? "",
            accountLabels().sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ","),
            health,
            resets
        ].joined(separator: "\u{1E}")
    }

    private func refreshAccountPanelContent(force: Bool = false) {
        let signature = panelSignature()
        if !force, signature == lastPanelSignature, accountPanel?.contentViewController != nil {
            return
        }
        lastPanelSignature = signature
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
            autoSwitchThreshold: autoSwitchThreshold,
            autoSwitchMode: autoSwitchMode,
            autoResumeMode: autoResumeMode,
            confirmBeforeSwitching: demoScenario == "four" ? true : confirmBeforeSwitching,
            armedSwitchEmail: demoScenario == "four" ? "creative@example.com" : armedSwitchEmail,
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
            switchAccount: { [weak self] email in
                self?.handlePanelSwitchRequest(email)
            },
            logoutAccount: { [weak self] email in
                self?.confirmLogoutAccount(email)
            },
            refresh: { [weak self] in
                self?.refreshAccounts(force: true)
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
        accountPanel?.setContentSize(panel.frame.size)
        if accountPanel?.isVisible == true {
            positionAccountPanel()
        }
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
        refreshAccountPanelContentIfVisible()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.armedSwitchEmail == email else { return }
            self.armedSwitchEmail = nil
            if self.accountPanel?.isVisible == true {
                self.refreshAccountPanelContentIfVisible()
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
        // Never resolve codex-auth here: this runs on the main thread for every panel build.
        codexAuthPathLock.lock()
        let codexAuthOK = cachedCodexAuthPath != nil
        codexAuthPathLock.unlock()
        if !codexAuthOK {
            resolveCodexAuthPathInBackground()
        }
        let authStillChecking = !codexAuthOK && !codexAuthResolveFinished
        let codexAppOK = FileManager.default.fileExists(atPath: codexDesktopAppPath)
        return [
            HealthStatus(
                title: "Auth",
                value: codexAuthOK ? "OK" : (authStillChecking ? "Checking" : "Missing"),
                color: codexAuthOK ? .systemGreen : (authStillChecking ? .systemOrange : .systemRed)
            ),
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
            clearArmedSwitch()
            accountPanelMode = .usage
        case .settingsView:
            accountPanelMode = .settings
        case .routeBView:
            accountPanelMode = .routeB
        case .resetCreditsView:
            accountPanelMode = .resets
            refreshResetCreditsIfNeeded(force: false)
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
            refreshUI()
        case .usageFiveHour:
            usageMode = .fiveHour
            refreshUI()
        case .styleDetailed:
            toolbarDisplayStyle = .detailed
            refreshUI()
        case .styleCompact:
            toolbarDisplayStyle = .compact
            refreshUI()
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
        case .diagnostics:
            showDiagnostics()
        case .quit:
            NSApp.terminate(nil)
        }
        if accountPanel?.isVisible == true {
            refreshAccountPanelContentIfVisible()
        }
    }

    private func selectRouteBProfile(_ profileID: String) {
        guard routeBProviderProfiles.contains(where: { $0.id == profileID }) else { return }
        UserDefaults.standard.set(profileID, forKey: selectedRouteBProfileDefaultsKey)
        if accountPanel?.isVisible == true {
            refreshAccountPanelContentIfVisible()
        }
    }

    private func showResetCreditsPanel() {
        accountPanelMode = .resets
        refreshAccountPanelContentIfVisible()
        refreshResetCreditsIfNeeded(force: false)
    }

    private func refreshResetCreditsIfNeeded(force: Bool) {
        guard !demoMode, !isRedeemingReset, !isRefreshingResetCredits else { return }
        guard ResetRefreshPolicy.shouldRefresh(
            lastRefresh: lastResetCreditsRefreshAt,
            ttl: resetCreditsRefreshInterval,
            force: force
        ) else { return }

        let accountSnapshot = accounts
        guard !accountSnapshot.isEmpty else { return }
        isRefreshingResetCredits = true
        Task {
            let refreshed = await fetchResetCredits(for: accountSnapshot)
            await MainActor.run {
                self.isRefreshingResetCredits = false
                self.lastResetCreditsRefreshAt = Date()
                self.resetCreditsByEmail = refreshed
                self.refreshUI()
            }
        }
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











    private func confirmAndRedeemResetCredit(account: CodexAccount, credit: ResetCredit) {
        guard !isRedeemingReset else {
            showAlert(title: "Reset already running", message: "Wait for the current reset verification to finish before using another credit.")
            return
        }
        let expires = credit.expiresAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown expiry"
        let alert = NSAlert()
        alert.messageText = "Redeem reset for \(toolbarLabel(for: account))?"
        alert.informativeText = "This will spend one Codex reset credit for \(compactEmail(account.email)) and refresh the account's rate-limit window.\n\nExpires: \(expires)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Redeem Reset")
        alert.addButton(withTitle: "Cancel")

        // The account panel deliberately sits at status-bar level, above a normal
        // modal alert. Hide it before presenting the spending confirmation so the
        // confirmation cannot be obscured underneath the menu-bar panel.
        closeAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .modalPanel
        alert.window.center()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        redeemResetCredit(account: account, credit: credit)
    }

    private func redeemResetCredit(account: CodexAccount, credit: ResetCredit) {
        guard !isRedeemingReset else { return }
        guard case .success(let auth) = savedAuth(forEmail: account.email) else {
            showAlert(title: "Reset failed", message: "The saved ChatGPT session for this account could not be read.")
            return
        }

        closeAccountPanel()
        let label = toolbarLabel(for: account)
        let creditBefore = resetCreditsByEmail[account.email]?.displayCount
        isRedeemingReset = true
        beginStatusAnimation(title: "Resetting")

        Task {
            let result = await self.consumeResetCredit(using: auth, creditID: credit.id)
            switch result {
            case .failure(let message):
                await MainActor.run {
                    self.isRedeemingReset = false
                    self.endStatusAnimation()
                    self.setResetStatus("\(label) · reset failed")
                    self.recordReset(
                        label: label,
                        result: "failed",
                        creditBefore: creditBefore,
                        creditAfter: nil,
                        usage: nil,
                        detail: message
                    )
                    self.showAlert(title: "Reset failed", message: message)
                    self.setResetStatus(nil)
                    self.refreshUI()
                }

            case .success(let receipt):
                await MainActor.run {
                    _ = self.beginStatusAnimation(title: "Verifying")
                }

                let verification = await self.verifyResetRedemption(
                    auth: auth,
                    previousCreditCount: creditBefore,
                    receipt: receipt
                )

                await MainActor.run {
                    if let resetSnapshot = verification.resetSnapshot {
                        self.resetCreditsByEmail[account.email] = resetSnapshot
                        self.lastResetCreditsRefreshAt = Date()
                    }
                    if let usageSnapshot = verification.usageSnapshot {
                        self.applyDirectUsage(usageSnapshot, toEmail: account.email)
                    }
                    self.lastUpdatedAt = Date()
                    self.lastError = nil
                    self.isRedeemingReset = false

                    let creditAfter = verification.resetSnapshot?.displayCount
                    let confirmed = verification.creditConfirmed && verification.usageConfirmed
                    let resultName = confirmed ? "confirmed" : "pending"
                    self.endStatusAnimation()
                    self.setResetStatus(confirmed ? "\(label) · reset ✓" : "\(label) · pending")
                    self.recordReset(
                        label: label,
                        result: resultName,
                        creditBefore: creditBefore,
                        creditAfter: creditAfter,
                        usage: verification.usageSnapshot,
                        detail: verification.detail
                    )
                    self.refreshUI()

                    if confirmed {
                        self.showAlert(
                            title: "Reset confirmed",
                            message: self.resetConfirmationMessage(
                                label: label,
                                creditBefore: creditBefore,
                                creditAfter: creditAfter,
                                usage: verification.usageSnapshot,
                                attempts: verification.attempts
                            )
                        )
                    } else {
                        self.scheduleResetFollowUps(
                            auth: auth,
                            label: label,
                            previousCreditCount: creditBefore,
                            receipt: receipt
                        )
                        self.showAlert(
                            title: "Reset accepted — verification pending",
                            message: self.resetPendingMessage(
                                label: label,
                                creditBefore: creditBefore,
                                creditAfter: creditAfter,
                                usage: verification.usageSnapshot,
                                detail: verification.detail
                            )
                        )
                    }

                    self.setResetStatus(nil)
                    self.refreshUI()
                    self.scheduleAllResetCreditsRefresh()
                }
            }
        }
    }

    private func verifyResetRedemption(
        auth: SavedAccountAuth,
        previousCreditCount: Int?,
        receipt: ResetConsumeReceipt
    ) async -> ResetVerificationOutcome {
        let delays: [TimeInterval] = [0, 0.8, 1.5, 3.0]
        var latestReset: ResetCreditsSnapshot?
        var latestUsage: DirectUsageSnapshot?
        var creditConfirmed = false
        var usageConfirmed = false
        var details: [String] = []

        for (index, delay) in delays.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            async let resetResult = fetchResetCredits(using: auth)
            async let usageResult = fetchDirectUsage(using: auth)
            let (resolvedReset, resolvedUsage) = await (resetResult, usageResult)

            switch resolvedReset {
            case .success(let snapshot):
                latestReset = snapshot
                if let before = previousCreditCount, let after = snapshot.displayCount {
                    creditConfirmed = after < before
                } else if previousCreditCount == nil {
                    creditConfirmed = receipt.windowsReset > 0
                }
            case .failure(let message):
                details.append("credit check \(index + 1): \(message)")
            }

            switch resolvedUsage {
            case .success(let snapshot):
                latestUsage = snapshot
                let primaryReady = snapshot.fiveHour.remainingPercent >= 95
                let weeklyReady = receipt.windowsReset <= 1 || snapshot.weekly.remainingPercent >= 95
                usageConfirmed = primaryReady && weeklyReady
            case .failure(let message):
                details.append("usage check \(index + 1): \(message)")
            }

            if creditConfirmed && usageConfirmed {
                return ResetVerificationOutcome(
                    resetSnapshot: latestReset,
                    usageSnapshot: latestUsage,
                    creditConfirmed: true,
                    usageConfirmed: true,
                    attempts: index + 1,
                    detail: "Backend credit and usage windows confirmed."
                )
            }
        }

        let status = [
            creditConfirmed ? "credit confirmed" : "credit not yet confirmed",
            usageConfirmed ? "usage confirmed" : "usage not yet confirmed"
        ].joined(separator: "; ")
        let detail = details.isEmpty ? status : "\(status). \(details.suffix(2).joined(separator: "; "))"
        return ResetVerificationOutcome(
            resetSnapshot: latestReset,
            usageSnapshot: latestUsage,
            creditConfirmed: creditConfirmed,
            usageConfirmed: usageConfirmed,
            attempts: delays.count,
            detail: detail
        )
    }

    private func applyDirectUsage(_ usage: DirectUsageSnapshot, toEmail email: String) {
        directUsageSnapshotsByEmail[email] = usage
        accounts = accounts.map { account in
            guard account.email == email else { return account }
            return CodexAccount(
                selector: account.selector,
                email: account.email,
                plan: account.plan,
                fiveHourUsage: directUsageText(usage.fiveHour, weekly: false),
                weeklyUsage: directUsageText(usage.weekly, weekly: true),
                fiveHourUsedPercent: usage.fiveHour.remainingPercent,
                weeklyUsedPercent: usage.weekly.remainingPercent,
                lastActivity: account.lastActivity,
                isActive: account.isActive
            )
        }
    }

    private func applyingDirectUsageSnapshots(to source: [CodexAccount]) -> [CodexAccount] {
        return source.map { account in
            guard let snapshot = directUsageSnapshotsByEmail[account.email] else { return account }
            return CodexAccount(
                selector: account.selector,
                email: account.email,
                plan: account.plan,
                fiveHourUsage: directUsageText(snapshot.fiveHour, weekly: false),
                weeklyUsage: directUsageText(snapshot.weekly, weekly: true),
                fiveHourUsedPercent: snapshot.fiveHour.remainingPercent,
                weeklyUsedPercent: snapshot.weekly.remainingPercent,
                lastActivity: account.lastActivity,
                isActive: account.isActive
            )
        }
    }

    private func directUsageText(_ window: UsageLimitWindowSnapshot, weekly: Bool) -> String {
        guard let resetAt = window.resetAt else {
            return "\(window.remainingPercent)%"
        }
        let formatter = weekly ? DateFormatter.directWeeklyUsage : DateFormatter.directFiveHourUsage
        return "\(window.remainingPercent)% (\(formatter.string(from: resetAt)))"
    }

    private func resetConfirmationMessage(
        label: String,
        creditBefore: Int?,
        creditAfter: Int?,
        usage: DirectUsageSnapshot?,
        attempts: Int
    ) -> String {
        let creditText = resetCreditChangeText(before: creditBefore, after: creditAfter)
        let usageText = resetUsageSummary(usage)
        return "ChatGPT confirmed the reset for account \(label).\n\n\(usageText)\n\(creditText)\nVerified after \(attempts) check\(attempts == 1 ? "" : "s")."
    }

    private func resetPendingMessage(
        label: String,
        creditBefore: Int?,
        creditAfter: Int?,
        usage: DirectUsageSnapshot?,
        detail: String
    ) -> String {
        "ChatGPT accepted the reset request for account \(label), but both the credit count and live usage window have not agreed yet.\n\n\(resetUsageSummary(usage))\n\(resetCreditChangeText(before: creditBefore, after: creditAfter))\n\nThe switcher will retry silently. \(detail)"
    }

    private func resetCreditChangeText(before: Int?, after: Int?) -> String {
        switch (before, after) {
        case let (before?, after?):
            return "Reset credits: \(before) → \(after)"
        case let (nil, after?):
            return "Reset credits now available: \(after)"
        default:
            return "Reset-credit count is still being checked."
        }
    }

    private func resetUsageSummary(_ usage: DirectUsageSnapshot?) -> String {
        guard let usage else { return "Live usage is still being checked." }
        return "5-hour: \(usage.fiveHour.remainingPercent)% remaining · Weekly: \(usage.weekly.remainingPercent)% remaining"
    }

    private func scheduleResetFollowUps(
        auth: SavedAccountAuth,
        label: String,
        previousCreditCount: Int?,
        receipt: ResetConsumeReceipt
    ) {
        runResetFollowUp(
            auth: auth,
            label: label,
            previousCreditCount: previousCreditCount,
            receipt: receipt,
            remainingDelays: [8, 22, 60, 120]
        )
    }

    private func runResetFollowUp(
        auth: SavedAccountAuth,
        label: String,
        previousCreditCount: Int?,
        receipt: ResetConsumeReceipt,
        remainingDelays: [TimeInterval]
    ) {
        guard let delay = remainingDelays.first else { return }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            async let pendingReset = self.fetchResetCredits(using: auth)
            async let pendingUsage = self.fetchDirectUsage(using: auth)
            let (resetResult, usageResult) = await (pendingReset, pendingUsage)
            let resetSnapshot: ResetCreditsSnapshot?
            let usageSnapshot: DirectUsageSnapshot?

            switch resetResult {
            case .success(let snapshot): resetSnapshot = snapshot
            case .failure: resetSnapshot = nil
            }
            switch usageResult {
            case .success(let snapshot): usageSnapshot = snapshot
            case .failure: usageSnapshot = nil
            }

            let creditConfirmed: Bool
            if let before = previousCreditCount, let after = resetSnapshot?.displayCount {
                creditConfirmed = after < before
            } else {
                creditConfirmed = previousCreditCount == nil && receipt.windowsReset > 0
            }
            let usageConfirmed: Bool
            if let usageSnapshot {
                usageConfirmed = usageSnapshot.fiveHour.remainingPercent >= 95
                    && (receipt.windowsReset <= 1 || usageSnapshot.weekly.remainingPercent >= 95)
            } else {
                usageConfirmed = false
            }

            await MainActor.run {
                if let resetSnapshot {
                    self.resetCreditsByEmail[auth.email] = resetSnapshot
                    self.lastResetCreditsRefreshAt = Date()
                }
                if let usageSnapshot {
                    self.applyDirectUsage(usageSnapshot, toEmail: auth.email)
                    self.lastUpdatedAt = Date()
                }
                self.refreshUI()

                if creditConfirmed && usageConfirmed {
                    self.recordReset(
                        label: label,
                        result: "confirmed-later",
                        creditBefore: previousCreditCount,
                        creditAfter: resetSnapshot?.displayCount,
                        usage: usageSnapshot,
                        detail: "Silent follow-up confirmed the backend credit and usage windows."
                    )
                } else {
                    self.runResetFollowUp(
                        auth: auth,
                        label: label,
                        previousCreditCount: previousCreditCount,
                        receipt: receipt,
                        remainingDelays: Array(remainingDelays.dropFirst())
                    )
                }
            }
        }
    }

    private func scheduleAllResetCreditsRefresh() {
        let accountSnapshot = accounts
        Task {
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            let refreshed = await self.fetchResetCredits(for: accountSnapshot)
            await MainActor.run {
                for (email, snapshot) in refreshed where snapshot.lastError == nil {
                    self.resetCreditsByEmail[email] = snapshot
                }
                self.lastResetCreditsRefreshAt = Date()
                self.refreshUI()
            }
        }
    }

    private func updateStatusTitle() {
        let titleKey = statusTitleKey()
        guard titleKey != currentStatusTitleKey else { return }
        currentStatusTitleKey = titleKey
        guard let button = statusItem.button else { return }
        let content = statusItemContent()
        button.title = ""
        button.image = content.image
        button.imagePosition = content.image == nil ? .noImage : (content.title.length == 0 ? .imageOnly : .imageLeading)
        button.attributedTitle = content.title
        button.setAccessibilityLabel(content.accessibilityLabel)
        statusItem.length = NSStatusItem.variableLength
        button.needsDisplay = true
    }

    private func clearStatusTitle() {
        currentStatusTitleKey = ""
        guard let button = statusItem.button else { return }
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = MenuBarGlyph.symbol("arrow.left.arrow.right", color: nil)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("Codex Account Switcher")
        statusItem.length = NSStatusItem.variableLength
        button.needsDisplay = true
    }

    private func statusItemContent() -> (image: NSImage?, title: NSAttributedString, accessibilityLabel: String) {
        let compact = toolbarDisplayStyle == .compact
        let fontSize: CGFloat = compact ? 11 : 12.5
        let diameter: CGFloat = compact ? 11 : 13
        if let resetStatusText {
            let color: NSColor = resetStatusText.hasPrefix("Switching") ? .systemBlue : .systemOrange
            let image = statusSpinnerFrame.map { MenuBarGlyph.spinner(frame: $0, color: color, diameter: diameter) }
            return (image, statusTitle(resetStatusText, size: fontSize, color: nil), resetStatusText)
        }
        guard let account = toolbarStatusAccounts().first else {
            return (MenuBarGlyph.symbol("arrow.left.arrow.right", color: nil), NSAttributedString(string: ""), "Codex Account Switcher")
        }
        let label = toolbarLabel(for: account)
        if accountNeedsLogin(account) {
            return (
                MenuBarGlyph.symbol("exclamationmark.triangle.fill", color: .systemRed, pointSize: fontSize - 1.5),
                statusTitle("\(label) Sign in", size: fontSize, color: .systemRed),
                "Account \(label) needs a fresh sign-in"
            )
        }
        let percent = toolbarUsagePercent(for: account)
        let image = MenuBarGlyph.ring(percent: percent, color: usageStatusColor(for: percent), diameter: diameter, lineWidth: compact ? 2 : 2.2)
        let isLow = (percent ?? 100) < 10
        let window = usageMode == .fiveHour ? "5-hour" : "weekly"
        return (
            image,
            statusTitle(toolbarStatusText(for: account), size: fontSize, color: isLow ? .systemRed : nil),
            "Account \(label), \(remainingPercentText(fromUsed: percent)) of the \(window) window left"
        )
    }

    private func statusTitle(_ text: String, size: CGFloat, color: NSColor?) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color ?? NSColor.labelColor
        ])
    }

    private func statusTitleKey() -> String {
        if let resetStatusText {
            return "reset|\(resetStatusText)|\(statusSpinnerFrame.map { String($0 % 12) } ?? "-")|\(toolbarDisplayStyle.rawValue)"
        }
        return toolbarStatusAccounts().map { account in
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

    private func setResetStatus(_ text: String?) {
        resetStatusText = text
        currentStatusTitleKey = ""
        updateStatusTitle()
    }

    private func toolbarStatusText(for account: CodexAccount) -> String {
        let label = toolbarLabel(for: account)
        let percent = toolbarUsagePercent(for: account)
        switch toolbarDisplayStyle {
        case .detailed:
            return "\(label) \(remainingPercentText(fromUsed: percent))"
        case .compact:
            return "\(label)\(remainingPercentNumberText(fromUsed: percent))"
        }
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

    // ChatGPT now contains the Codex desktop surface on this installation.
    private var codexDesktopAppPath: String {
        return "/Applications/ChatGPT.app"
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


    private func remainingPercentText(fromUsed used: Int?) -> String {
        guard let used else { return "--%" }
        return "\(max(0, min(100, used)))%"
    }

    private func remainingPercentNumberText(fromUsed used: Int?) -> String {
        guard let used else { return "--" }
        return "\(max(0, min(100, used)))"
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




    private func accountNeedsLogin(_ account: CodexAccount) -> Bool {
        account.fiveHourUsage == "Login expired" || account.weeklyUsage == "Login expired"
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
            refreshUI()
        } else if response == .alertSecondButtonReturn {
            clearCustomLabel(forEmail: email)
            refreshUI()
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

    private func confirmLogoutAccount(_ email: String) {
        guard let account = accounts.first(where: { $0.email == email }) else { return }

        let alert = NSAlert()
        alert.messageText = "Log out of this account?"
        alert.informativeText = "This removes \(account.email) from Codex Account Switcher on this Mac. You can add it again later by signing in."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Log out")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            runAccountMaintenance(title: "Logging out", args: ["remove", email])
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
        refreshUI()
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
        refreshUI()
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
        refreshUI()
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
            refreshUI()
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
        refreshUI()
    }

    @objc private func toggleAutoSwitch() {
        autoSwitchEnabled.toggle()
        if autoSwitchEnabled {
            configureNotifications()
            checkAutoSwitch()
        }
        refreshUI()
    }

    @objc private func toggleConfirmBeforeSwitching() {
        confirmBeforeSwitching.toggle()
        clearArmedSwitch()
        refreshUI()
    }

    @objc private func toggleProtectFrontmostCodex() {
        protectFrontmostCodex.toggle()
        refreshUI()
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
        refreshUI()
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
        let previous = accounts.first(where: { $0.isActive })
        let automatic = allowAutoResume
        let switchStatusAnimationGeneration = beginStatusAnimation(title: "Switching")
        refreshAccountPanelContentIfVisible()

        DispatchQueue.global(qos: .userInitiated).async {
            if let syncError = self.syncActiveAuthSnapshot() {
                DispatchQueue.main.async {
                    self.isSwitching = false
                    self.endStatusAnimation()
                    self.updateStatusTitle()
                    self.showAlert(title: "Could not save active token", message: syncError)
                    self.refreshAccounts(force: true)
                }
                return
            }

            let switchResult = self.runCodexAuth(["switch", query])
            if switchResult.status != 0 {
                DispatchQueue.main.async {
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: "auth switch", result: "failed")
                    self.isSwitching = false
                    self.endStatusAnimation()
                    self.updateStatusTitle()
                    self.showAlert(title: "Switch failed", message: switchResult.output)
                    self.refreshAccounts(force: true)
                }
                return
            }

            let verification = self.verifyActiveAccount(expectedEmail: target?.email ?? query)
            guard verification.status == 0 else {
                var rollbackMessage = "Verification failed: \(verification.output)"
                if let previous {
                    let rollback = self.runCodexAuth(["switch", previous.email])
                    rollbackMessage += rollback.status == 0 ? "\nThe previous account was restored." : "\nRollback also failed: \(rollback.output)"
                }
                DispatchQueue.main.async {
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: "verification", result: "rolled back")
                    self.isSwitching = false
                    self.endStatusAnimation()
                    self.updateStatusTitle()
                    self.showAlert(title: "Switch could not be verified", message: rollbackMessage)
                    self.refreshAccounts(force: true)
                }
                return
            }

            DispatchQueue.main.sync {
                self.isSwitching = false
                self.refreshAccounts(force: true, refreshResets: false)
            }

            let restartResult = self.restartCodexApp()
            if restartResult.status == 0, allowAutoResume, self.autoResumeMode != .off {
                // The relaunch now returns as soon as ChatGPT is up; give its window a
                // moment to finish loading before an automatic resume pastes into it.
                Thread.sleep(forTimeInterval: 3)
            }
            DispatchQueue.main.async {
                if restartResult.status != 0 {
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: "desktop relaunch", result: "account changed; relaunch failed")
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
                } else {
                    UserDefaults.standard.set(Date(), forKey: self.lastSwitchDateDefaultsKey)
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: automatic ? "automatic best account" : "manual", result: "verified")
                    if allowAutoResume {
                        self.handleAutoResumeAfterSwitch(to: target)
                    }
                }
                self.refreshAccounts(force: true, refreshResets: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self, !self.isSwitching else { return }
                    self.endStatusAnimation(expectedGeneration: switchStatusAnimationGeneration)
                    self.updateStatusTitle()
                }
            }
        }
    }

    private func verifyActiveAccount(expectedEmail: String) -> CommandResult {
        for attempt in 1...3 {
            let result = runCodexAuth(["list", "--skip-api"])
            if result.status == 0 {
                let parsed = parseAccounts(result.output, usageIsLive: false)
                if parsed.contains(where: { $0.isActive && $0.email.caseInsensitiveCompare(expectedEmail) == .orderedSame }) {
                    return CommandResult(status: 0, output: "active account verified")
                }
            }
            if attempt < 3 { Thread.sleep(forTimeInterval: 0.6) }
        }
        return CommandResult(status: 1, output: "codex-auth did not report the requested account as active after three checks")
    }

    @discardableResult
    private func beginStatusAnimation(title: String) -> Int {
        switchAnimationTimer?.invalidate()
        statusAnimationGeneration += 1
        switchAnimationFrame = 0
        statusAnimationTitle = title
        updateStatusAnimationTitle()
        let animationTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.switchAnimationFrame += 1
            self.updateStatusAnimationTitle()
        }
        animationTimer.tolerance = 0.02
        RunLoop.main.add(animationTimer, forMode: .common)
        switchAnimationTimer = animationTimer
        return statusAnimationGeneration
    }

    private func updateStatusAnimationTitle() {
        statusSpinnerFrame = switchAnimationFrame
        setResetStatus("\(statusAnimationTitle)…")
    }

    private func endStatusAnimation(expectedGeneration: Int? = nil) {
        if let expectedGeneration, expectedGeneration != statusAnimationGeneration {
            return
        }
        switchAnimationTimer?.invalidate()
        switchAnimationTimer = nil
        statusSpinnerFrame = nil
        setResetStatus(nil)
    }

    private func refreshAccountPanelContentIfVisible() {
        guard accountPanel?.isVisible == true, !panelRefreshScheduled else { return }
        panelRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panelRefreshScheduled = false
            guard self.accountPanel?.isVisible == true else { return }
            self.refreshAccountPanelContent()
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
              Date().timeIntervalSince(UserDefaults.standard.object(forKey: lastSwitchDateDefaultsKey) as? Date ?? .distantPast) >= switchCooldown,
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
            .filter { !accountNeedsLogin($0) }
            .sorted { accountScore($0) > accountScore($1) }
            .first
    }

    private func accountScore(_ account: CodexAccount) -> Int {
        let fiveHour = account.fiveHourUsedPercent ?? -100
        let weekly = account.weeklyUsedPercent ?? -100
        let resets = resetCreditsByEmail[account.email]?.displayCount ?? 0
        return (fiveHour * 3) + weekly + min(resets, 5) * 4
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
        let monitorPath = Bundle.main.resourceURL!
            .appendingPathComponent("CodexLifecycleMonitor")
            .path
        guard FileManager.default.isExecutableFile(atPath: monitorPath) else {
            throw NSError(
                domain: "CodexAccountSwitcher",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The lifecycle monitor is missing from the app bundle. Reinstall Codex Account Switcher."]
            )
        }
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(launchAgentIdentifier)</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(monitorPath)</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
            <key>PATH</key>
            <string>/usr/bin:/bin:/usr/sbin:/sbin</string>
            <key>HOME</key>
            <string>\(NSHomeDirectory())</string>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>ThrottleInterval</key>
          <integer>5</integer>
        </dict>
        </plist>
        """
        let url = launchAgentURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plist.write(to: url, atomically: true, encoding: .utf8)
        let userDomain = "gui/\(getuid())"
        _ = run("/bin/launchctl", ["bootout", userDomain, url.path])
        let bootstrap = run("/bin/launchctl", ["bootstrap", userDomain, url.path])
        guard bootstrap.status == 0 else {
            throw NSError(
                domain: "CodexAccountSwitcher",
                code: Int(bootstrap.status),
                userInfo: [NSLocalizedDescriptionKey: "Could not start the lifecycle monitor: \(bootstrap.output)"]
            )
        }
    }

    private func removeLaunchAgent() throws {
        let url = launchAgentURL()
        let userDomain = "gui/\(getuid())"
        _ = run("/bin/launchctl", ["bootout", userDomain, url.path])
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
        savedClipboardString = NSPasteboard.general.string(forType: .string)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.restoreClipboardAfterResume()
            }
        }
    }

    private func copyResumePromptToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(autoResumePrompt, forType: .string)
    }

    private func restoreClipboardAfterResume() {
        guard let savedClipboardString else { return }
        if NSPasteboard.general.string(forType: .string) == autoResumePrompt {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(savedClipboardString, forType: .string)
        }
        self.savedClipboardString = nil
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
            _ = AuthBackupPruner.prune(in: accountAuthURL.deletingLastPathComponent(), keepingPerAccount: 10)
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
        statusItem.button?.image = nil
        statusItem.button?.imagePosition = .noImage
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        statusItem.button?.title = title
        currentStatusTitleKey = ""
        refreshUI()

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

        // Ask politely first, then force; each step returns as soon as the processes are gone.
        for (signal, timeout) in [("-TERM", 4.0), ("-KILL", 2.0), ("-KILL", 1.0)] {
            let pids = codexAppPIDs()
            if pids.isEmpty { break }
            _ = run("/bin/kill", [signal] + pids)
            if waitUntil(timeout: timeout, { self.codexAppPIDs().isEmpty }) { break }
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

        let mainExecutablePattern = "\(NSRegularExpression.escapedPattern(for: codexDesktopAppPath))/Contents/MacOS/"
        let launched = waitUntil(timeout: 10) {
            self.run("/usr/bin/pgrep", ["-f", mainExecutablePattern]).status == 0
        }
        guard launched else {
            transcript.append("\(codexDesktopAppName) did not report as running after launch.")
            return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
        }
        return CommandResult(status: 0, output: transcript.joined(separator: "\n"))
    }

    /// Polls `condition` every 0.2 s until it is true or `timeout` passes. Background threads only.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
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

            if let computerUseApp = ComputerUsePluginLocator.latestApp(homeDirectory: home) {
                let codePathLine = "CODEX_CLI_PATH = \"\(codexDesktopResourcesPath)/codex\""
                let servicePathLine = "SKY_CUA_SERVICE_PATH = \"\(computerUseApp.path)\""
                let pattern = #"(?m)^SKY_CUA_SERVICE_PATH = ".*"$"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: config, range: NSRange(config.startIndex..., in: config)),
                   let range = Range(match.range, in: config) {
                    if config[range] != servicePathLine {
                        config.replaceSubrange(range, with: servicePathLine)
                        changed = true
                    }
                } else if config.contains(codePathLine) {
                    config = config.replacingOccurrences(of: codePathLine, with: "\(servicePathLine)\n\(codePathLine)")
                    changed = true
                }
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

    /// Demo-only screenshot scenarios: "two" (default look for most users) or "four".
    private var demoScenario: String? {
        guard demoMode else { return nil }
        return ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO_SCENARIO"]
    }

    private func demoAccounts() -> [CodexAccount] {
        func account(_ selector: String, _ email: String, five: Int?, weekly: Int?, fiveReset: String, weeklyReset: String, active: Bool, expired: Bool = false) -> CodexAccount {
            CodexAccount(
                selector: selector,
                email: email,
                plan: "plus",
                fiveHourUsage: expired ? "Login expired" : "\(five ?? 0)% (\(fiveReset))",
                weeklyUsage: expired ? "Login expired" : "\(weekly ?? 0)% (\(weeklyReset))",
                fiveHourUsedPercent: expired ? nil : five,
                weeklyUsedPercent: expired ? nil : weekly,
                lastActivity: active ? "Just now" : "1h ago",
                isActive: active
            )
        }
        let alpha = account("01", "alpha@example.com", five: 31, weekly: 82, fiveReset: "16:40", weeklyReset: "Fri 09:00", active: true)
        let beta = account("02", "beta@example.com", five: 92, weekly: 64, fiveReset: "18:15", weeklyReset: "Fri 09:00", active: false)
        switch demoScenario {
        case "two":
            return [alpha, beta]
        case "four":
            return [
                alpha,
                account("02", "builds@example.com", five: 92, weekly: 64, fiveReset: "18:15", weeklyReset: "Fri 09:00", active: false),
                account("03", "creative@example.com", five: 68, weekly: 18, fiveReset: "20:25", weeklyReset: "Fri 09:00", active: false),
                account("04", "demo@example.com", five: nil, weekly: nil, fiveReset: "", weeklyReset: "", active: false, expired: true)
            ]
        default:
            return [
                alpha,
                beta,
                account("03", "gamma@example.com", five: 68, weekly: 41, fiveReset: "20:25", weeklyReset: "Fri 09:00", active: false)
            ]
        }
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


    private func fetchResetCreditsForRefresh(
        accounts: [CodexAccount],
        shouldRefresh: Bool
    ) async -> [String: ResetCreditsSnapshot] {
        guard shouldRefresh else { return [:] }
        return await fetchResetCredits(for: accounts)
    }

    private func fetchDirectUsageForRefresh(
        accounts: [CodexAccount],
        shouldRefresh: Bool
    ) async -> [String: DirectUsageSnapshot] {
        guard shouldRefresh, !accounts.isEmpty else { return [:] }
        let refreshed = await withTaskGroup(of: (String, DirectUsageSnapshot)?.self) { group in
            for account in accounts {
                group.addTask {
                    guard case .success(let auth) = self.savedAuth(forEmail: account.email) else { return nil }
                    guard case .success(let usage) = await self.fetchDirectUsage(using: auth) else { return nil }
                    return (account.email, usage)
                }
            }
            var resolved: [(String, DirectUsageSnapshot)] = []
            for await result in group {
                if let result { resolved.append(result) }
            }
            return resolved
        }
        return Dictionary(uniqueKeysWithValues: refreshed)
    }

    private func fetchDirectUsage(using auth: SavedAccountAuth) async -> DirectUsageFetchResult {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            return .failure("usage endpoint URL is invalid")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("codex-1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")

        let payload: HTTPPayload
        do {
            payload = try await CodexHTTPClient.send(request, retries: 1)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard payload.statusCode == 200 else {
            return .failure("usage endpoint returned \(payload.statusCode)")
        }
        return parseDirectUsageResponse(payload.data)
    }

    private func parseDirectUsageResponse(_ responseData: Data) -> DirectUsageFetchResult {
        guard
            let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let rateLimit = object["rate_limit"] as? [String: Any]
        else {
            return .failure("usage endpoint returned incomplete rate-limit data")
        }

        typealias ParsedWindow = (snapshot: UsageLimitWindowSnapshot, duration: Int?)
        func parsedWindow(_ raw: Any?) -> ParsedWindow? {
            guard
                let window = raw as? [String: Any],
                let usedPercent = integerValue(window["used_percent"])
            else {
                return nil
            }
            let resetAt = integerValue(window["reset_at"]).map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            return (
                UsageLimitWindowSnapshot(
                    remainingPercent: max(0, min(100, 100 - usedPercent)),
                    resetAt: resetAt
                ),
                integerValue(window["limit_window_seconds"])
            )
        }

        let primary = parsedWindow(rateLimit["primary_window"])
        let secondary = parsedWindow(rateLimit["secondary_window"])
        guard primary != nil || secondary != nil else {
            return .failure("usage endpoint returned incomplete rate-limit data")
        }

        let fullUnusedWindow = UsageLimitWindowSnapshot(remainingPercent: 100, resetAt: nil)
        let fiveHour: UsageLimitWindowSnapshot
        let weekly: UsageLimitWindowSnapshot

        if let primary, let secondary {
            if let primaryDuration = primary.duration, let secondaryDuration = secondary.duration {
                if primaryDuration <= secondaryDuration {
                    fiveHour = primary.snapshot
                    weekly = secondary.snapshot
                } else {
                    fiveHour = secondary.snapshot
                    weekly = primary.snapshot
                }
            } else {
                // Preserve the established backend ordering when duration metadata
                // is unavailable: primary is the short window, secondary is weekly.
                fiveHour = primary.snapshot
                weekly = secondary.snapshot
            }
        } else if let only = primary ?? secondary {
            // Directly after a reset ChatGPT may omit a window until that window is
            // first used. An absent window is therefore full, not an error or stale 0%.
            if let duration = only.duration, duration >= 86_400 {
                fiveHour = fullUnusedWindow
                weekly = only.snapshot
            } else {
                fiveHour = only.snapshot
                weekly = fullUnusedWindow
            }
        } else {
            return .failure("usage endpoint returned incomplete rate-limit data")
        }

        return .success(DirectUsageSnapshot(
            fiveHour: fiveHour,
            weekly: weekly
        ))
    }

    private func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func resetLogicSelfTest() -> String {
        let usageFixture: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 1, "limit_window_seconds": 18_000, "reset_at": 1_800_000_000],
                "secondary_window": ["used_percent": 17, "limit_window_seconds": 604_800, "reset_at": 1_800_604_800]
            ]
        ]
        guard
            let usageData = try? JSONSerialization.data(withJSONObject: usageFixture),
            case .success(let usage) = parseDirectUsageResponse(usageData),
            usage.fiveHour.remainingPercent == 99,
            usage.weekly.remainingPercent == 83
        else {
            return "Reset logic self-test FAILED: usage conversion"
        }

        let postResetUsageFixture: [String: Any] = [
            "rate_limit": [
                "primary_window": ["used_percent": 0, "limit_window_seconds": 604_800, "reset_at": 1_800_604_800],
                "secondary_window": NSNull()
            ]
        ]
        guard
            let postResetUsageData = try? JSONSerialization.data(withJSONObject: postResetUsageFixture),
            case .success(let postResetUsage) = parseDirectUsageResponse(postResetUsageData),
            postResetUsage.fiveHour.remainingPercent == 100,
            postResetUsage.weekly.remainingPercent == 100
        else {
            return "Reset logic self-test FAILED: post-reset missing window"
        }

        let consumeFixture: [String: Any] = ["code": "reset", "windows_reset": 2]
        guard
            let consumeData = try? JSONSerialization.data(withJSONObject: consumeFixture),
            case .success(let receipt) = parseResetConsumeResponse(consumeData),
            receipt.windowsReset == 2
        else {
            return "Reset logic self-test FAILED: consume confirmation"
        }

        let rejectedFixture: [String: Any] = ["code": "noop", "windows_reset": 0]
        guard
            let rejectedData = try? JSONSerialization.data(withJSONObject: rejectedFixture),
            case .failure = parseResetConsumeResponse(rejectedData)
        else {
            return "Reset logic self-test FAILED: false-success rejection"
        }
        return "Reset logic self-test passed"
    }

    private func fetchResetCredits(for accounts: [CodexAccount]) async -> [String: ResetCreditsSnapshot] {
        var results: [String: ResetCreditsSnapshot] = [:]
        let batchSize = 3
        var startIndex = 0

        while startIndex < accounts.count {
            let endIndex = min(startIndex + batchSize, accounts.count)
            let batch = Array(accounts[startIndex..<endIndex])
            let batchResults = await withTaskGroup(of: (String, ResetCreditsSnapshot).self) { group in
                for account in batch {
                    group.addTask {
                        let snapshot: ResetCreditsSnapshot
                        switch self.savedAuth(forEmail: account.email) {
                        case .success(let auth):
                            switch await self.fetchResetCredits(using: auth) {
                            case .success(let fetched):
                                snapshot = fetched
                            case .failure(let message):
                                snapshot = ResetCreditsSnapshot(availableCount: nil, credits: [], lastUpdatedText: "just now", lastError: message)
                            }
                        case .failure(let message):
                            snapshot = ResetCreditsSnapshot(availableCount: nil, credits: [], lastUpdatedText: "never", lastError: message)
                        }
                        return (account.email, snapshot)
                    }
                }
                var resolved: [(String, ResetCreditsSnapshot)] = []
                for await result in group { resolved.append(result) }
                return resolved
            }
            for (email, snapshot) in batchResults { results[email] = snapshot }
            startIndex = endIndex
        }
        return results
    }

    private func fetchResetCredits(using auth: SavedAccountAuth) async -> ResetCreditsFetchResult {
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

        let payload: HTTPPayload
        do {
            payload = try await CodexHTTPClient.send(request, retries: 1)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard payload.statusCode == 200 else {
            return .failure("reset endpoint returned \(payload.statusCode)")
        }
        guard let object = try? JSONSerialization.jsonObject(with: payload.data) as? [String: Any] else {
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

    private func consumeResetCredit(using auth: SavedAccountAuth, creditID: String) async -> ResetCreditRedemptionResult {
        guard !creditID.isEmpty else {
            return .failure("The selected reset credit is missing its backend id.")
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

        let payload: HTTPPayload
        do {
            // A reset POST is deliberately never retried: an ambiguous response must not spend two credits.
            payload = try await CodexHTTPClient.send(request, retries: 0)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard payload.statusCode == 200 else {
            return .failure("Reset endpoint returned \(payload.statusCode). No credit was treated as redeemed.")
        }
        return parseResetConsumeResponse(payload.data)
    }

    private func parseResetConsumeResponse(_ responseData: Data) -> ResetCreditRedemptionResult {
        guard let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return .failure("Reset endpoint returned HTTP 200 but did not provide readable confirmation.")
        }
        let code = (object["code"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let windows: Int
        if let value = integerValue(object["windows_reset"]) {
            windows = value
        } else if let values = object["windows_reset"] as? [Any] {
            windows = values.count
        } else {
            windows = 0
        }
        let successFlag = object["success"] as? Bool ?? false
        let acceptedCodes = ["ok", "reset", "success", "rate_limits_reset", "reset_applied"]
        let codeAccepted = acceptedCodes.contains(code.lowercased())
        guard successFlag || windows > 0 || codeAccepted else {
            return .failure("Reset endpoint returned HTTP 200 without confirming that any rate-limit window was reset.")
        }

        let displayCode = code.isEmpty ? "confirmed" : code
        return .success(ResetConsumeReceipt(
            code: displayCode,
            windowsReset: max(1, windows),
            message: "ChatGPT accepted the reset request (\(displayCode); \(max(1, windows)) window\(max(1, windows) == 1 ? "" : "s"))."
        ))
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
        let modified = (try? root.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        authIndexLock.lock()
        if let cache = authIndexCache, cache.modified == modified, let url = cache.index[accountID] {
            authIndexLock.unlock()
            return url
        }
        authIndexLock.unlock()

        guard let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return nil
        }
        var index: [String: URL] = [:]
        for url in urls where url.lastPathComponent.hasSuffix(".auth.json") {
            guard
                let data = try? Data(contentsOf: url),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tokens = object["tokens"] as? [String: Any],
                let candidate = tokens["account_id"] as? String
            else {
                continue
            }
            index[candidate] = url
        }
        authIndexLock.lock()
        authIndexCache = (modified, index)
        authIndexLock.unlock()
        return index[accountID]
    }





    private func deleteKeychainSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiTokenUsageService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }



    private func runCodexAuth(_ args: [String]) -> CommandResult {
        guard let path = codexAuthPath() else {
            return CommandResult(status: 127, output: "codex-auth was not found in known locations.")
        }
        let result = run(path, args)
        if result.status == 127 {
            invalidateCodexAuthPath()
        }
        return result
    }

    private func codexAuthPath() -> String? {
        codexAuthPathLock.lock()
        let cached = cachedCodexAuthPath
        codexAuthPathLock.unlock()
        if let cached, FileManager.default.isExecutableFile(atPath: cached) {
            return cached
        }
        let resolved = resolveCodexAuthPath()
        codexAuthPathLock.lock()
        cachedCodexAuthPath = resolved
        codexAuthPathLock.unlock()
        return resolved
    }

    private func resolveCodexAuthPathInBackground() {
        guard !isResolvingCodexAuthPath else { return }
        isResolvingCodexAuthPath = true
        DispatchQueue.global(qos: .utility).async {
            _ = self.codexAuthPath()
            DispatchQueue.main.async {
                self.isResolvingCodexAuthPath = false
                self.codexAuthResolveFinished = true
                self.refreshAccountPanelContentIfVisible()
            }
        }
    }

    private func invalidateCodexAuthPath() {
        codexAuthPathLock.lock()
        cachedCodexAuthPath = nil
        codexAuthPathLock.unlock()
    }

    private func resolveCodexAuthPath() -> String? {
        let home = NSHomeDirectory()
        let stableCandidates = [
            "\(home)/.local/bin/codex-auth",
            "/opt/homebrew/bin/codex-auth",
            "/usr/local/bin/codex-auth"
        ]
        if let path = stableCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }),
           ProcessRunner.run(path, ["--version"], environment: augmentedEnvironment(), timeout: 4).status == 0 {
            return path
        }

        let nvmNodeDir = URL(fileURLWithPath: "\(home)/.nvm/versions/node")
        if let versions = try? FileManager.default.contentsOfDirectory(at: nvmNodeDir, includingPropertiesForKeys: nil) {
            let orderedVersions = versions.sorted {
                $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending
            }
            for versionDir in orderedVersions {
                let path = versionDir.appendingPathComponent("bin/codex-auth").path
                if FileManager.default.isExecutableFile(atPath: path),
                   ProcessRunner.run(path, ["--version"], environment: augmentedEnvironment(), timeout: 4).status == 0 {
                    return path
                }
            }
        }

        let fallback = ProcessRunner.run(
            "/bin/zsh",
            ["-l", "-c", "which codex-auth"],
            environment: augmentedEnvironment(),
            timeout: 5
        )
        if fallback.status == 0 {
            let path = fallback.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func run(_ executable: String, _ args: [String]) -> CommandResult {
        var environment = augmentedEnvironment()
        let bundledNode = "\(codexDesktopResourcesPath)/node"
        if FileManager.default.isExecutableFile(atPath: bundledNode) {
            environment["CODEX_AUTH_NODE_EXECUTABLE"] = bundledNode
        }
        let bundledCodex = "\(codexDesktopResourcesPath)/codex"
        if FileManager.default.isExecutableFile(atPath: bundledCodex) {
            environment["CODEX_CLI_PATH"] = bundledCodex
        }
        return ProcessRunner.run(executable, args, environment: environment, timeout: commandTimeout(for: executable, arguments: args))
    }


    private func commandTimeout(for executable: String, arguments: [String]) -> TimeInterval {
        let command = URL(fileURLWithPath: executable).lastPathComponent
        if command == "codex-auth" {
            return arguments.first == "login" ? 180 : 20
        }
        if command == "open" || command == "osascript" { return 15 }
        return 12
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

    private func recordSwitch(from: CodexAccount?, to: CodexAccount?, automatic: Bool, reason: String, result: String) {
        let entry = SwitchHistoryEntry(
            date: Date(),
            fromLabel: from.map(displayLabel(for:)) ?? "?",
            toLabel: to.map(displayLabel(for:)) ?? "?",
            automatic: automatic,
            reason: reason,
            result: result
        )
        var entries = switchHistory()
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(30))
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: switchHistoryDefaultsKey)
        }
    }

    private func switchHistory() -> [SwitchHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: switchHistoryDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([SwitchHistoryEntry].self, from: data)) ?? []
    }

    private func recordReset(
        label: String,
        result: String,
        creditBefore: Int?,
        creditAfter: Int?,
        usage: DirectUsageSnapshot?,
        detail: String
    ) {
        let entry = ResetHistoryEntry(
            date: Date(),
            accountLabel: label,
            result: result,
            creditBefore: creditBefore,
            creditAfter: creditAfter,
            fiveHourRemaining: usage?.fiveHour.remainingPercent,
            weeklyRemaining: usage?.weekly.remainingPercent,
            detail: detail
        )
        var entries = resetHistory()
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(30))
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: resetHistoryDefaultsKey)
        }
    }

    private func resetHistory() -> [ResetHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: resetHistoryDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([ResetHistoryEntry].self, from: data)) ?? []
    }

    private func diagnosticsText() -> String {
        let version = currentAppVersion()
        let auth = codexAuthPath() == nil ? "missing" : "available"
        let desktop = FileManager.default.fileExists(atPath: codexDesktopAppPath) ? codexDesktopAppName : "missing"
        let entries = switchHistory().prefix(12).map { entry in
            let stamp = DateFormatter.diagnosticStamp.string(from: entry.date)
            return "\(stamp) | \(entry.fromLabel)->\(entry.toLabel) | \(entry.automatic ? "automatic" : "manual") | \(entry.reason) | \(entry.result)"
        }
        let resetEntries = resetHistory().prefix(8).map { entry in
            let stamp = DateFormatter.diagnosticStamp.string(from: entry.date)
            let credits = resetCreditChangeText(before: entry.creditBefore, after: entry.creditAfter)
            let usage = entry.fiveHourRemaining.map { "5h \($0)%" } ?? "5h ?"
            let weekly = entry.weeklyRemaining.map { "weekly \($0)%" } ?? "weekly ?"
            return "\(stamp) | reset \(entry.accountLabel) | \(entry.result) | \(credits) | \(usage), \(weekly) | \(entry.detail)"
        }
        return ([
            "Codex Account Switcher \(version)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "codex-auth: \(auth)",
            "desktop: \(desktop)",
            "saved accounts: \(accounts.count)",
            "auto switch: \(autoSwitchMode.rawValue)",
            "auto resume: \(autoResumeMode.rawValue)",
            "refresh: \(lastUpdatedText())",
            "switch history:"
        ] + (entries.isEmpty ? ["none"] : entries) + [
            "reset history:"
        ] + (resetEntries.isEmpty ? ["none"] : resetEntries)).joined(separator: "\n")
    }

    private func showDiagnostics() {
        let text = diagnosticsText()
        let alert = NSAlert()
        alert.messageText = "Reliability diagnostics"
        alert.informativeText = text
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
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


    private func customLabel(forEmail email: String) -> String? {
        accountLabels()[email]
    }

    private func setCustomLabel(_ label: String, forEmail email: String) {
        var labels = accountLabels()
        labels[email] = label
        UserDefaults.standard.set(labels, forKey: labelsDefaultsKey)
        labelsCache = labels
    }

    private func clearCustomLabel(forEmail email: String) {
        var labels = accountLabels()
        labels.removeValue(forKey: email)
        UserDefaults.standard.set(labels, forKey: labelsDefaultsKey)
        labelsCache = labels
    }

    private func accountLabels() -> [String: String] {
        if let labelsCache { return labelsCache }
        let labels = UserDefaults.standard.dictionary(forKey: labelsDefaultsKey) as? [String: String] ?? [:]
        labelsCache = labels
        return labels
    }

    private func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
