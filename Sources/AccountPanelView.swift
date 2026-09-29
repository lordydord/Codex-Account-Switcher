import AppKit
import Foundation

/// The menu-bar panel: Accounts, Resets, Settings and the Route B preview,
/// drawn as a single Liquid Glass sheet with a uniform toolbar and tab control.
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
    private let autoSwitchThreshold: Int
    private let autoSwitchMode: AutoSwitchMode
    private let autoResumeMode: AutoResumeMode
    private let confirmBeforeSwitching: Bool
    private let armedSwitchEmail: String?
    private let resetCreditsByEmail: [String: ResetCreditsSnapshot]
    private let healthStatuses: [HealthStatus]
    private let routeBProfiles: [RouteBProviderProfile]
    private let selectedRouteBProfileID: String?
    private let usageMode: UsageDisplayMode
    private let toolbarDisplayStyle: ToolbarDisplayStyle
    private let activeRefreshInterval: Int
    private let idleRefreshInterval: Int
    private let labelForAccount: (CodexAccount) -> String
    private let switchAccount: (String) -> Void
    private let logoutAccount: (String) -> Void
    private let refresh: () -> Void
    private let checkUpdates: () -> Void
    private let editAccountLabel: (String) -> Void
    private let showResetCredits: () -> Void
    private let redeemResetCredit: (String, String) -> Void
    private let selectRouteBProfile: (String) -> Void
    private let performSettingsAction: (SettingsPanelAction) -> Void
    private let close: () -> Void
    private let toggleLaunchAtLogin: () -> Void

    static let panelWidth: CGFloat = 372
    private let inset: CGFloat = 12
    private var contentWidth: CGFloat { Self.panelWidth - inset * 2 }
    private var builtForDark: Bool?
    private var theme: PanelTheme { PanelTheme.current(for: effectiveAppearance) }

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
        autoSwitchThreshold: Int,
        autoSwitchMode: AutoSwitchMode,
        autoResumeMode: AutoResumeMode,
        confirmBeforeSwitching: Bool,
        armedSwitchEmail: String?,
        resetCreditsByEmail: [String: ResetCreditsSnapshot],
        healthStatuses: [HealthStatus],
        routeBProfiles: [RouteBProviderProfile],
        selectedRouteBProfileID: String?,
        usageMode: UsageDisplayMode,
        toolbarDisplayStyle: ToolbarDisplayStyle,
        activeRefreshInterval: Int,
        idleRefreshInterval: Int,
        labelForAccount: @escaping (CodexAccount) -> String,
        switchAccount: @escaping (String) -> Void,
        logoutAccount: @escaping (String) -> Void,
        refresh: @escaping () -> Void,
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
        self.autoSwitchThreshold = autoSwitchThreshold
        self.autoSwitchMode = autoSwitchMode
        self.autoResumeMode = autoResumeMode
        self.confirmBeforeSwitching = confirmBeforeSwitching
        self.armedSwitchEmail = armedSwitchEmail
        self.resetCreditsByEmail = resetCreditsByEmail
        self.healthStatuses = healthStatuses
        self.routeBProfiles = routeBProfiles
        self.selectedRouteBProfileID = selectedRouteBProfileID
        self.usageMode = usageMode
        self.toolbarDisplayStyle = toolbarDisplayStyle
        self.activeRefreshInterval = activeRefreshInterval
        self.idleRefreshInterval = idleRefreshInterval
        self.labelForAccount = labelForAccount
        self.switchAccount = switchAccount
        self.logoutAccount = logoutAccount
        self.refresh = refresh
        self.checkUpdates = checkUpdates
        self.editAccountLabel = editAccountLabel
        self.showResetCredits = showResetCredits
        self.redeemResetCredit = redeemResetCredit
        self.selectRouteBProfile = selectRouteBProfile
        self.performSettingsAction = performSettingsAction
        self.close = close
        self.toggleLaunchAtLogin = toggleLaunchAtLogin
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(mode: mode, accountCount: accounts.count)))
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    /// An estimate used before the first build; the real height comes from the built content.
    static func preferredSize(mode: AccountPanelMode, accountCount: Int) -> NSSize {
        switch mode {
        case .usage:
            return NSSize(width: panelWidth, height: CGFloat(330 + max(0, accountCount - 1) * 74))
        case .settings:
            return NSSize(width: panelWidth, height: 680)
        case .resets:
            return NSSize(width: panelWidth, height: 560)
        case .routeB:
            return NSSize(width: panelWidth, height: 520)
        }
    }

    static func maximumPanelHeight() -> CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(420, visible - 24)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if builtForDark != theme.isDark {
            build()
        }
    }

    // MARK: - Build

    private var showsTabs: Bool { mode != .routeB }

    private func build() {
        subviews.forEach { $0.removeFromSuperview() }
        let theme = self.theme
        builtForDark = theme.isDark

        let header = FlippedContainerView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 0))
        var headerHeight = buildToolbar(into: header, theme: theme)
        if showsTabs {
            headerHeight = buildTabs(into: header, y: headerHeight, theme: theme)
        }
        header.frame.size.height = headerHeight

        let body = FlippedContainerView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 0))
        let bodyHeight: CGFloat
        switch mode {
        case .usage:
            bodyHeight = buildAccountsBody(into: body, theme: theme)
        case .settings:
            bodyHeight = buildSettingsBody(into: body, theme: theme)
        case .resets:
            bodyHeight = buildResetsBody(into: body, theme: theme)
        case .routeB:
            bodyHeight = buildRouteBBody(into: body, theme: theme)
        }
        body.frame.size.height = bodyHeight

        let footer = FlippedContainerView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 0))
        let footerHeight = buildFooter(into: footer, theme: theme)
        footer.frame.size.height = footerHeight

        let availableBody = Self.maximumPanelHeight() - headerHeight - footerHeight
        let visibleBody = min(bodyHeight, availableBody)
        setFrameSize(NSSize(width: Self.panelWidth, height: ceil(headerHeight + visibleBody + footerHeight)))

        let background = GlassPanelBackground(frame: bounds, theme: theme)
        addSubview(background)
        let content = background.contentView

        content.addSubview(header)
        if bodyHeight > availableBody {
            let scroll = NSScrollView(frame: NSRect(x: 0, y: headerHeight, width: Self.panelWidth, height: visibleBody))
            scroll.drawsBackground = false
            scroll.contentView.drawsBackground = false
            scroll.borderType = .noBorder
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.scrollerStyle = .overlay
            scroll.documentView = body
            content.addSubview(scroll)
            if ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO"] == "1",
               ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SCROLL_TO_END"] == "1" {
                body.scroll(NSPoint(x: 0, y: bodyHeight - visibleBody))
            }
        } else {
            body.frame.origin = NSPoint(x: 0, y: headerHeight)
            content.addSubview(body)
        }
        footer.frame.origin = NSPoint(x: 0, y: headerHeight + visibleBody)
        content.addSubview(footer)
    }

    // MARK: - Toolbar and tabs

    private func buildToolbar(into view: NSView, theme: PanelTheme) -> CGFloat {
        let glyph = TileView(frame: NSRect(x: 16, y: 14, width: 28, height: 28), fill: theme.controlFill, border: theme.controlBorder, cornerRadius: 8)
        glyph.place(SymbolIconView(frame: .zero, symbol: mode == .routeB ? "point.3.connected.trianglepath.dotted" : "arrow.left.arrow.right", color: theme.primaryText, pointSize: 12), x: 6, y: 6, width: 16, height: 16)
        view.addSubview(glyph)

        var rightEdge = Self.panelWidth - 14
        if mode == .routeB {
            let back = GlassButton(title: "Settings", style: .secondary, theme: theme) { [weak self] in
                self?.performSettingsAction(.settingsView)
            }
            rightEdge -= back.frame.width
            view.place(back, x: rightEdge, y: 14)
        } else {
            let more = GlassButton(symbol: "ellipsis", style: .icon, theme: theme, accessibilityLabel: "More options") {}
            more.target = self
            more.action = #selector(showMoreMenu(_:))
            rightEdge -= more.frame.width
            view.place(more, x: rightEdge, y: 14)

            let refreshButton = GlassButton(symbol: "arrow.clockwise", style: .icon, theme: theme, accessibilityLabel: mode == .resets ? "Refresh reset credits" : "Refresh all accounts") { [weak self] in
                guard let self else { return }
                if self.mode == .resets {
                    self.performSettingsAction(.resetCreditsView)
                }
                self.refresh()
            }
            rightEdge -= refreshButton.frame.width + 8
            view.place(refreshButton, x: rightEdge, y: 14)
        }

        let textWidthAvailable = rightEdge - 10 - 54
        let title = makeLabel(mode == .routeB ? "Route B" : "Codex Accounts", size: 13, weight: .semibold, color: theme.primaryText)
        view.place(title, x: 54, y: 12, width: textWidthAvailable)

        let (subtitle, isWarning) = toolbarSubtitle()
        let subtitleLabel = makeLabel(subtitle, size: 11, color: isWarning ? theme.text(.orange) : theme.secondaryText, monospacedDigits: true)
        subtitleLabel.toolTip = subtitle
        view.place(subtitleLabel, x: 54, y: 29, width: textWidthAvailable)
        return 54
    }

    private func toolbarSubtitle() -> (String, Bool) {
        switch mode {
        case .usage:
            if let lastError, !lastError.isEmpty, activeAccount == nil {
                return (lastError, true)
            }
            if isSwitching {
                return ("Switching accounts…", false)
            }
            return (lastUpdatedText == "refreshing..." ? "Refreshing…" : "Updated \(lastUpdatedText)", lastUpdatedText.hasPrefix("stale"))
        case .settings:
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
            return ("Version \(version)", false)
        case .resets:
            return (resetCreditsSubtitle(), resetCreditsSummaryState().hasError)
        case .routeB:
            return ("Secondary profiles · preview", false)
        }
    }

    private func buildTabs(into view: NSView, y: CGFloat, theme: PanelTheme) -> CGFloat {
        let state = resetCreditsSummaryState()
        let badge: String? = state.knownTotal > 0 ? "\(state.knownTotal)" : nil
        let tabs = SegmentedTabsView(
            frame: NSRect(x: inset, y: y, width: contentWidth, height: 28),
            theme: theme,
            segments: [
                .init(title: "Accounts", badge: nil, isSelected: mode == .usage) { [weak self] in
                    self?.performSettingsAction(.usageView)
                },
                .init(title: "Resets", badge: badge, isSelected: mode == .resets) { [weak self] in
                    self?.performSettingsAction(.resetCreditsView)
                },
                .init(title: "Settings", badge: nil, isSelected: mode == .settings) { [weak self] in
                    self?.performSettingsAction(.settingsView)
                }
            ]
        )
        view.addSubview(tabs)
        return y + 28 + 12
    }

    @objc private func showMoreMenu(_ sender: NSButton) {
        let menu = NSMenu()
        func add(_ title: String, _ action: SettingsPanelAction) {
            let item = NSMenuItem(title: title, action: #selector(moreMenuItemChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action.rawValue
            menu.addItem(item)
        }
        add("Add Account…", .addAccount)
        add("Device Login…", .addDeviceAccount)
        add("Rename Accounts…", .editLabels)
        menu.addItem(.separator())
        add("Refresh Rate…", .editRefresh)
        add("Check for Updates…", .checkUpdates)
        add("Diagnostics…", .diagnostics)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Account Switcher", action: #selector(quitPressed), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func moreMenuItemChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = SettingsPanelAction(rawValue: raw) else { return }
        performSettingsAction(action)
    }

    @objc private func quitPressed() {
        close()
    }

    // MARK: - Footer

    private func buildFooter(into view: NSView, theme: PanelTheme) -> CGFloat {
        let height: CGFloat = 48
        view.addSubview(HairlineView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 0.5), color: theme.hairline))

        let quit = GlassButton(symbol: "power", style: .icon, theme: theme, accessibilityLabel: "Quit Account Switcher") { [weak self] in
            self?.close()
        }
        quit.toolTip = "Quit Account Switcher"
        var rightEdge = Self.panelWidth - 12 - quit.frame.width
        view.place(quit, x: rightEdge, y: 10)

        switch mode {
        case .usage:
            let autoTitle = autoSwitchMode == .off ? "Auto-switch off" : autoSwitchFooterText()
            let auto = GlassButton(title: autoTitle, style: .text(theme.secondaryText), theme: theme, height: 22, fontSize: 11) { [weak self] in
                self?.performSettingsAction(.editAutoSwitch)
            }
            auto.toolTip = "Change automatic switching"
            rightEdge -= auto.frame.width + 6
            view.place(auto, x: rightEdge, y: 13)

            let state = resetCreditsSummaryState()
            if state.knownTotal > 0 {
                let text = state.knownTotal == 1 ? "1 reset available" : "\(state.knownTotal) resets available"
                let link = GlassButton(title: text, symbol: "chevron.right", style: .text(theme.text(.blue)), theme: theme, height: 24) { [weak self] in
                    self?.showResetCredits()
                }
                view.place(link, x: 9, y: 12)
            } else {
                let text = state.knownAccounts == 0 ? (state.hasError ? "Resets unavailable" : "Checking resets…") : "No resets available"
                view.place(makeLabel(text, size: 12, color: theme.tertiaryText), x: 16, y: 16, width: rightEdge - 24)
            }
        case .settings:
            view.place(makeLabel("Changes apply instantly", size: 11, color: theme.tertiaryText), x: 16, y: 17, width: rightEdge - 24)
        case .resets:
            view.place(makeLabel("Using a reset asks for confirmation first", size: 11, color: theme.tertiaryText), x: 16, y: 17, width: rightEdge - 24)
        case .routeB:
            view.place(makeLabel("Profile selection only · execution disabled", size: 11, color: theme.tertiaryText), x: 16, y: 17, width: rightEdge - 24)
        }
        return height
    }

    private func autoSwitchFooterText() -> String {
        switch autoSwitchMode {
        case .off: return "Auto-switch off"
        case .ask: return "Auto-switch asks at \(autoSwitchThreshold)%"
        case .threshold: return "Auto-switch at \(autoSwitchThreshold)%"
        case .zero: return "Auto-switch asks at 0%"
        }
    }

    // MARK: - Accounts

    private func buildAccountsBody(into body: NSView, theme: PanelTheme) -> CGFloat {
        var y: CGFloat = 0
        guard !accounts.isEmpty else {
            let tile = emptyAccountsTile(theme: theme, y: y)
            body.addSubview(tile)
            return tile.frame.maxY + 12
        }

        let active = activeAccount ?? accounts.first(where: { $0.isActive })
        if let active {
            let hero = activeAccountTile(active, theme: theme, y: y)
            body.addSubview(hero)
            y = hero.frame.maxY + 12
        } else {
            let notice = noticeTile(title: "No active account", detail: lastError ?? "Choose an account below to make it active.", tone: .orange, theme: theme, y: y)
            body.addSubview(notice)
            y = notice.frame.maxY + 12
        }

        let others = orderedAccounts().filter { $0.email != active?.email }
        guard !others.isEmpty else { return y }

        let sectionTitle = makeLabel("Switch to", size: 11, weight: .semibold, color: theme.secondaryText)
        body.place(sectionTitle, x: inset + 4, y: y, width: 120)
        let hint = makeLabel("Relaunches ChatGPT", size: 11, color: theme.tertiaryText, alignment: .right)
        body.place(hint, x: Self.panelWidth - inset - 4 - 160, y: y, width: 160)
        y += sectionTitle.frame.height + 6

        let best = bestNextAccount(among: others, active: active)
        for account in others {
            let row = accountRowTile(account, isBest: account.email == best?.email, theme: theme, y: y)
            body.addSubview(row)
            y = row.frame.maxY + 8
        }
        return y + 4
    }

    private func activeAccountTile(_ account: CodexAccount, theme: PanelTheme, y: CGFloat) -> NSView {
        let fiveHour = account.fiveHourUsedPercent
        let weekly = account.weeklyUsedPercent
        let needsLogin = accountNeedsLogin(account)
        let fiveTone: PanelTheme.Tone = needsLogin ? .red : PanelTheme.usageTone(for: fiveHour)
        let weeklyTone: PanelTheme.Tone = needsLogin ? .red : PanelTheme.usageTone(for: weekly)
        let tile = TileView(
            frame: NSRect(x: inset, y: y, width: contentWidth, height: 166),
            fill: theme.tileFill,
            border: theme.color(fiveTone).withAlphaComponent(theme.isDark ? 0.34 : 0.45),
            borderWidth: 1
        )
        let label = labelForAccount(account)
        tile.addSubview(MonogramView(frame: NSRect(x: 12, y: 12, width: 32, height: 32), text: label, fill: theme.tint(fiveTone), textColor: theme.text(fiveTone)))

        let tag = needsLogin
            ? CapsuleTagView(text: "Signed out", theme: theme, foreground: theme.text(.red), background: theme.tint(.red))
            : CapsuleTagView(text: "Active", theme: theme, foreground: theme.primaryText, background: theme.controlFill, dot: theme.color(.green))
        tile.place(tag, x: contentWidth - 12 - tag.frame.width, y: 19)

        let identityWidth = contentWidth - 52 - tag.frame.width - 22
        let email = makeLabel(account.email, size: 13, weight: .semibold, color: theme.primaryText)
        email.toolTip = account.email
        tile.place(email, x: 52, y: 11, width: identityWidth)
        let plan = makeLabel(planText(account.plan), size: 11, color: theme.secondaryText)
        tile.place(plan, x: 52, y: 29, width: identityWidth)

        let editLabel = NSButton(frame: NSRect(x: 12, y: 12, width: identityWidth + 40, height: 34))
        editLabel.title = ""
        editLabel.isBordered = false
        editLabel.isTransparent = true
        editLabel.toolTip = "Rename this account"
        editLabel.setAccessibilityLabel("Rename \(account.email)")
        editLabel.identifier = NSUserInterfaceItemIdentifier(account.email)
        editLabel.target = self
        editLabel.action = #selector(editLabelPressed(_:))
        tile.addSubview(editLabel)

        tile.addSubview(ActivityRingsView(
            frame: NSRect(x: 12, y: 58, width: 96, height: 96),
            outerPercent: fiveHour,
            outerColor: theme.color(fiveTone),
            innerPercent: weekly,
            innerColor: theme.color(weeklyTone)
        ))

        let metricsX: CGFloat = 126
        let metricsWidth = contentWidth - metricsX - 12
        addMetric(to: tile, title: "5-hour window", percent: fiveHour, detail: needsLogin ? "sign in to refresh" : "left · resets \(fiveHourResetText(from: account.fiveHourUsage))", tone: fiveTone, theme: theme, x: metricsX, y: 58, width: metricsWidth)
        addMetric(to: tile, title: "Weekly", percent: weekly, detail: needsLogin ? "sign in to refresh" : "left · resets \(weeklyResetText(from: account.weeklyUsage))", tone: weeklyTone, theme: theme, x: metricsX, y: 108, width: metricsWidth)
        return tile
    }

    private func addMetric(to tile: NSView, title: String, percent: Int?, detail: String, tone: PanelTheme.Tone, theme: PanelTheme, x: CGFloat, y: CGFloat, width: CGFloat) {
        tile.addSubview(DotView(frame: NSRect(x: x, y: y + 3.5, width: 8, height: 8), color: theme.color(tone)))
        tile.place(makeLabel(title, size: 11, color: theme.secondaryText), x: x + 14, y: y, width: width - 14)

        let number = makeLabel(percentText(percent), size: 26, weight: .semibold, color: theme.text(tone), monospacedDigits: true, kern: -0.6)
        tile.place(number, x: x - 1, y: y + 15)
        let detailX = number.frame.maxX + 6
        let detailLabel = makeLabel(detail, size: 11, color: theme.secondaryText, monospacedDigits: true)
        tile.place(detailLabel, x: detailX, y: number.frame.maxY - detailLabel.frame.height - 3, width: max(20, x + width - detailX))
    }

    private func accountRowTile(_ account: CodexAccount, isBest: Bool, theme: PanelTheme, y: CGFloat) -> NSView {
        let label = labelForAccount(account)
        let needsLogin = accountNeedsLogin(account)
        let isArmed = confirmBeforeSwitching && armedSwitchEmail == account.email && !isSwitching
        let height: CGFloat = isArmed ? 110 : 64
        let canSwitch = !isSwitching && !needsLogin

        let tile = TileView(
            frame: NSRect(x: inset, y: y, width: contentWidth, height: height),
            fill: isArmed ? theme.accent.withAlphaComponent(theme.isDark ? 0.14 : 0.10) : theme.tileFill,
            border: isArmed ? theme.accent.withAlphaComponent(0.55) : theme.tileBorder,
            borderWidth: isArmed ? 1 : 0.5,
            hoverFill: canSwitch && !isArmed ? theme.tileHoverFill : nil,
            accessibilityLabel: "Switch to \(account.email)",
            action: canSwitch && !isArmed ? { [weak self] in self?.switchAccount(account.email) } : nil
        )
        tile.toolTip = switchPreviewText(for: account)

        let monoTone: PanelTheme.Tone = needsLogin ? .red : .neutral
        tile.addSubview(MonogramView(
            frame: NSRect(x: 12, y: 16, width: 32, height: 32),
            text: label,
            fill: needsLogin ? theme.tint(.red) : theme.controlFill,
            textColor: needsLogin ? theme.text(.red) : theme.text(monoTone)
        ))

        var rightEdge = contentWidth - 12
        if needsLogin {
            let signIn = GlassButton(title: "Sign In…", style: .secondary, theme: theme) { [weak self] in
                self?.performSettingsAction(.addAccount)
            }
            rightEdge -= signIn.frame.width
            tile.place(signIn, x: rightEdge, y: 18)
        } else if !isArmed {
            let switchButton = GlassButton(title: isSwitching ? "Switching…" : "Switch", style: .primary, theme: theme, accessibilityLabel: "Switch to \(account.email)") { [weak self] in
                self?.switchAccount(account.email)
            }
            switchButton.isEnabled = canSwitch
            rightEdge -= switchButton.frame.width
            tile.place(switchButton, x: rightEdge, y: 18)
        }

        let textX: CGFloat = 52
        let availableWidth = rightEdge - 10 - textX
        var tagView: CapsuleTagView?
        if needsLogin {
            tagView = CapsuleTagView(text: "Signed out", theme: theme, foreground: theme.text(.red), background: theme.tint(.red))
        } else if isBest {
            tagView = CapsuleTagView(text: "Best next", theme: theme, foreground: theme.text(.blue), background: theme.tint(.blue))
        }
        let tagSpace = tagView.map { $0.frame.width + 6 } ?? 0
        let email = makeLabel(account.email, size: 13, weight: .semibold, color: theme.primaryText)
        let emailWidth = min(email.frame.width, availableWidth - tagSpace)
        email.toolTip = account.email
        let emailY: CGFloat = needsLogin ? 13 : 10
        tile.place(email, x: textX, y: emailY, width: emailWidth)
        if let tagView {
            tile.place(tagView, x: textX + emailWidth + 6, y: emailY + (email.frame.height - tagView.frame.height) / 2)
        }

        if needsLogin {
            tile.place(makeLabel("Session expired · usage unavailable", size: 11, color: theme.secondaryText), x: textX, y: 32, width: availableWidth)
        } else {
            let meterWidth = (availableWidth - 12) / 2
            let fiveTone = PanelTheme.usageTone(for: account.fiveHourUsedPercent)
            let weeklyTone = PanelTheme.usageTone(for: account.weeklyUsedPercent)
            tile.addSubview(MeterView(frame: NSRect(x: textX, y: 33, width: meterWidth, height: 20), title: "5-hour", percent: account.fiveHourUsedPercent, color: theme.color(fiveTone), theme: theme))
            tile.addSubview(MeterView(frame: NSRect(x: textX + meterWidth + 12, y: 33, width: meterWidth, height: 20), title: "Weekly", percent: account.weeklyUsedPercent, color: theme.color(weeklyTone), theme: theme))
        }

        if isArmed {
            tile.addSubview(HairlineView(frame: NSRect(x: 12, y: 64, width: contentWidth - 24, height: 0.5), color: theme.accent.withAlphaComponent(0.35)))
            let confirm = GlassButton(title: "Confirm", style: .primary, theme: theme, accessibilityLabel: "Confirm switch to \(account.email)") { [weak self] in
                self?.switchAccount(account.email)
            }
            let cancel = GlassButton(title: "Cancel", style: .secondary, theme: theme) { [weak self] in
                self?.performSettingsAction(.usageView)
            }
            let confirmX = contentWidth - 12 - confirm.frame.width
            let cancelX = confirmX - 8 - cancel.frame.width
            tile.place(confirm, x: confirmX, y: 73)
            tile.place(cancel, x: cancelX, y: 73)
            let prompt = makeLabel("Relaunch ChatGPT as \(label)?", size: 12, weight: .medium, color: theme.primaryText)
            tile.place(prompt, x: 12, y: 79, width: cancelX - 20)
        }
        return tile
    }

    private func emptyAccountsTile(theme: PanelTheme, y: CGFloat) -> NSView {
        let tile = TileView(frame: NSRect(x: inset, y: y, width: contentWidth, height: 150), fill: theme.tileFill, border: theme.tileBorder)
        tile.addSubview(MonogramView(frame: NSRect(x: 12, y: 14, width: 32, height: 32), text: "", fill: theme.tint(.blue), textColor: theme.text(.blue), symbol: "person.crop.circle.badge.plus"))
        tile.place(makeLabel("No saved accounts", size: 13, weight: .semibold, color: theme.primaryText), x: 52, y: 15, width: contentWidth - 64)
        tile.place(makeLabel("Sign in once for each ChatGPT account.", size: 11, color: theme.secondaryText), x: 52, y: 33, width: contentWidth - 64)
        if let lastError, !lastError.isEmpty {
            let error = makeLabel(lastError, size: 11, color: theme.text(.orange))
            error.toolTip = lastError
            tile.place(error, x: 12, y: 64, width: contentWidth - 24)
        }
        let add = GlassButton(title: "Add Account…", style: .primary, theme: theme) { [weak self] in
            self?.performSettingsAction(.addAccount)
        }
        tile.place(add, x: 12, y: 108)
        let device = GlassButton(title: "Device Login…", style: .secondary, theme: theme) { [weak self] in
            self?.performSettingsAction(.addDeviceAccount)
        }
        tile.place(device, x: 12 + add.frame.width + 8, y: 108)
        return tile
    }

    private func noticeTile(title: String, detail: String, tone: PanelTheme.Tone, theme: PanelTheme, y: CGFloat) -> NSView {
        let tile = TileView(frame: NSRect(x: inset, y: y, width: contentWidth, height: 60), fill: theme.tint(tone), border: theme.color(tone).withAlphaComponent(0.35))
        tile.place(makeLabel(title, size: 13, weight: .semibold, color: theme.text(tone)), x: 12, y: 11, width: contentWidth - 24)
        let detailLabel = makeLabel(detail, size: 11, color: theme.secondaryText)
        detailLabel.toolTip = detail
        tile.place(detailLabel, x: 12, y: 31, width: contentWidth - 24)
        return tile
    }

    @objc private func editLabelPressed(_ sender: NSButton) {
        guard let email = sender.identifier?.rawValue else { return }
        editAccountLabel(email)
    }

    private func bestNextAccount(among others: [CodexAccount], active: CodexAccount?) -> CodexAccount? {
        let candidates = others.filter { !accountNeedsLogin($0) && $0.fiveHourUsedPercent != nil }
        let best = candidates.max { score($0) < score($1) }
        guard let best else { return nil }
        if let active, let activeFive = active.fiveHourUsedPercent, let bestFive = best.fiveHourUsedPercent, bestFive <= activeFive {
            return nil
        }
        return best
    }

    private func score(_ account: CodexAccount) -> Int {
        let five = account.fiveHourUsedPercent ?? 0
        let weekly = account.weeklyUsedPercent ?? five
        return min(five, weekly) * 2 + five
    }

    // MARK: - Resets

    private func buildResetsBody(into body: NSView, theme: PanelTheme) -> CGFloat {
        var y: CGFloat = 0
        let summary = resetSummaryTile(theme: theme, y: y)
        body.addSubview(summary)
        y = summary.frame.maxY + 14

        guard !accounts.isEmpty else { return y }
        body.place(makeLabel("By account", size: 11, weight: .semibold, color: theme.secondaryText), x: inset + 4, y: y, width: 200)
        y += 20

        for account in orderedAccounts() {
            let group = resetAccountGroup(account, theme: theme, y: y)
            body.addSubview(group)
            y = group.frame.maxY + 10
        }
        return y + 2
    }

    private func resetSummaryTile(theme: PanelTheme, y: CGFloat) -> NSView {
        let state = resetCreditsSummaryState()
        let credits = accounts.flatMap { account in
            resetCreditsByEmail[account.email].map { sortedAvailableResetCredits($0) } ?? []
        }
        let days = credits.compactMap { resetCreditDaysLeft($0) }
        let urgent = days.filter { $0 <= 7 }.count
        let soon = days.filter { $0 > 7 && $0 <= 20 }.count
        let later = credits.count - urgent - soon
        let hasBreakdown = !credits.isEmpty

        let height: CGFloat = hasBreakdown ? 118 : 76
        let tile = TileView(frame: NSRect(x: inset, y: y, width: contentWidth, height: height), fill: theme.tileFill, border: theme.tileBorder)
        tile.place(makeLabel("Available resets", size: 11, color: theme.secondaryText), x: 14, y: 13, width: 160)

        let countText = state.knownAccounts == 0 && !state.hasError ? "…" : "\(state.knownTotal)"
        let count = makeLabel(countText, size: 34, weight: .semibold, color: theme.primaryText, monospacedDigits: true, kern: -1)
        tile.place(count, x: 13, y: 28)
        let accountsWithCredits = accounts.filter { (resetCreditsByEmail[$0.email]?.displayCount ?? 0) > 0 }.count
        let across = state.knownTotal == 0
            ? (state.hasError ? "some accounts could not be checked" : "none right now")
            : (accountsWithCredits == 1 ? "on 1 account" : "across \(accountsWithCredits) accounts")
        let acrossLabel = makeLabel(across, size: 12, color: theme.secondaryText)
        tile.place(acrossLabel, x: count.frame.maxX + 8, y: count.frame.maxY - acrossLabel.frame.height - 5, width: 170)

        if let next = credits.min(by: { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }), let nextDays = resetCreditDaysLeft(next) {
            let tone = urgencyTone(days: nextDays)
            let dateText = next.expiresAt.map { DateFormatter.resetCreditShortDate.string(from: $0) } ?? ""
            let capsule = CapsuleTagView(text: "\(dateText) · \(daysLeftText(nextDays))", theme: theme, foreground: theme.text(tone), background: theme.tint(tone), height: 20, fontSize: 11)
            tile.place(capsule, x: contentWidth - 14 - capsule.frame.width, y: 38)
            let caption = makeLabel("Next expiry", size: 11, color: theme.secondaryText, alignment: .right)
            tile.place(caption, x: contentWidth - 14 - 120, y: 13, width: 120)
        }

        if hasBreakdown {
            let bar = StackedBarView(frame: NSRect(x: 14, y: 78, width: contentWidth - 28, height: 6), segments: [
                (CGFloat(urgent), theme.color(.red)),
                (CGFloat(soon), theme.color(.orange)),
                (CGFloat(later), theme.color(.green))
            ])
            tile.addSubview(bar)
            var x: CGFloat = 14
            for (value, text, tone) in [(urgent, "within a week", PanelTheme.Tone.red), (soon, "within 20 days", .orange), (later, "later", .green)] where value > 0 {
                tile.addSubview(DotView(frame: NSRect(x: x, y: 96, width: 7, height: 7), color: theme.color(tone)))
                let legend = makeLabel("\(value) \(text)", size: 10.5, color: theme.secondaryText, monospacedDigits: true)
                tile.place(legend, x: x + 11, y: 92)
                x += 11 + legend.frame.width + 14
            }
        }
        return tile
    }

    private func resetAccountGroup(_ account: CodexAccount, theme: PanelTheme, y: CGFloat) -> NSView {
        let snapshot = resetCreditsByEmail[account.email]
        let credits = snapshot.map { sortedAvailableResetCredits($0) } ?? []
        let rowHeight: CGFloat = 40
        let bodyRows = max(1, credits.count)
        let group = TileView(frame: NSRect(x: inset, y: y, width: contentWidth, height: rowHeight * CGFloat(1 + bodyRows)), fill: theme.tileFill, border: theme.tileBorder)

        let tone: PanelTheme.Tone = account.isActive ? PanelTheme.usageTone(for: account.fiveHourUsedPercent) : .neutral
        group.addSubview(MonogramView(frame: NSRect(x: 12, y: 8, width: 24, height: 24), text: labelForAccount(account), fill: account.isActive ? theme.tint(tone) : theme.controlFill, textColor: theme.text(tone)))
        let countText: String
        if let count = snapshot?.displayCount {
            countText = account.isActive ? "Active · \(count)" : "\(count)"
        } else {
            countText = snapshot?.lastError != nil ? "Unavailable" : "Checking…"
        }
        let tag = CapsuleTagView(text: countText, theme: theme, foreground: theme.secondaryText, background: theme.controlFill)
        group.place(tag, x: contentWidth - 12 - tag.frame.width, y: 11)
        group.place(makeLabel(account.email, size: 12.5, weight: .semibold, color: theme.primaryText), x: 44, y: 12, width: contentWidth - 44 - tag.frame.width - 22)

        var rowY = rowHeight
        group.addSubview(HairlineView(frame: NSRect(x: 12, y: rowY, width: contentWidth - 24, height: 0.5), color: theme.hairline))

        if let error = snapshot?.lastError {
            let label = makeLabel("Couldn’t check · \(error)", size: 11.5, color: theme.text(.orange))
            label.toolTip = error
            group.place(label, x: 12, y: rowY + 12, width: contentWidth - 24)
            return group
        }
        guard snapshot != nil else {
            group.place(makeLabel("Checking reset credits…", size: 11.5, color: theme.secondaryText), x: 12, y: rowY + 12, width: contentWidth - 24)
            return group
        }
        guard !credits.isEmpty else {
            group.place(makeLabel("No resets available", size: 11.5, color: theme.secondaryText), x: 12, y: rowY + 12, width: contentWidth - 24)
            return group
        }

        for (index, credit) in credits.enumerated() {
            if index > 0 {
                group.addSubview(HairlineView(frame: NSRect(x: 12, y: rowY, width: contentWidth - 24, height: 0.5), color: theme.hairline))
            }
            let days = resetCreditDaysLeft(credit)
            let tone = days.map { urgencyTone(days: $0) } ?? .blue
            let due = CapsuleTagView(text: days.map { daysLeftText($0) } ?? "unknown", theme: theme, foreground: theme.text(tone), background: theme.tint(tone), height: 20, fontSize: 11, fixedWidth: 64)
            group.place(due, x: 12, y: rowY + 10)

            let use = GlassButton(title: "Use", style: .use, theme: theme, height: 24, fontSize: 11.5, accessibilityLabel: "Use reset expiring \(resetCreditExpiryText(credit))") { [weak self] in
                self?.redeemResetCredit(account.email, credit.id)
            }
            use.toolTip = "Redeem this reset credit after confirmation"
            use.isEnabled = !isSwitching
            let useX = contentWidth - 12 - use.frame.width
            group.place(use, x: useX, y: rowY + 8)

            let date = makeLabel(resetCreditExpiryText(credit), size: 12, color: theme.primaryText, monospacedDigits: true)
            date.toolTip = "Granted \(credit.grantedAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "unknown")"
            group.place(date, x: 86, y: rowY + 12, width: useX - 96)
            rowY += rowHeight
        }
        return group
    }

    private func resetCreditsSubtitle() -> String {
        let state = resetCreditsSummaryState()
        if state.knownAccounts == 0 {
            return state.hasError ? "Some accounts could not be checked" : "Checking saved accounts…"
        }
        if state.hasError {
            return "Some accounts could not be checked"
        }
        return "Reset credits for \(accounts.count == 1 ? "1 account" : "\(accounts.count) accounts")"
    }

    private func urgencyTone(days: Int) -> PanelTheme.Tone {
        if days <= 7 { return .red }
        if days <= 20 { return .orange }
        return .green
    }

    private func daysLeftText(_ days: Int) -> String {
        if days <= 0 { return "today" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func resetCreditExpiryText(_ credit: ResetCredit) -> String {
        credit.expiresAt.map { DateFormatter.resetCreditDisplay.string(from: $0) } ?? "Unknown expiry"
    }

    private func resetCreditDaysLeft(_ credit: ResetCredit) -> Int? {
        guard let expiresAt = credit.expiresAt else { return nil }
        return max(0, Int(ceil(expiresAt.timeIntervalSince(Date()) / 86_400)))
    }

    private func sortedAvailableResetCredits(_ snapshot: ResetCreditsSnapshot) -> [ResetCredit] {
        snapshot.availableCredits.sorted { left, right in
            switch (left.expiresAt, right.expiresAt) {
            case let (left?, right?): return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
        }
    }

    private func resetCreditsSummaryState() -> (knownTotal: Int, knownAccounts: Int, hasError: Bool) {
        let snapshots = accounts.compactMap { resetCreditsByEmail[$0.email] }
        let knownCounts = snapshots.compactMap { $0.displayCount }
        return (knownCounts.reduce(0, +), knownCounts.count, snapshots.contains { $0.lastError != nil })
    }

    // MARK: - Settings

    private struct SettingsRow {
        let height: CGFloat
        let build: (NSView, CGFloat) -> Void
    }

    private func buildSettingsBody(into body: NSView, theme: PanelTheme) -> CGFloat {
        var y: CGFloat = 0

        y = addSection("Menu bar", rows: [
            segmentedRow("Show", options: [
                ("5-hour", usageMode == .fiveHour, .usageFiveHour),
                ("Weekly", usageMode == .weekly, .usageWeekly)
            ], theme: theme),
            segmentedRow("Size", options: [
                ("Large", toolbarDisplayStyle == .detailed, .styleDetailed),
                ("Small", toolbarDisplayStyle == .compact, .styleCompact)
            ], theme: theme),
            menuBarPreviewRow(theme: theme)
        ], into: body, y: y, theme: theme)

        y = addSection("Automation", rows: [
            toggleRow("Follow ChatGPT", detail: "Show only while ChatGPT is open", isOn: launchAtLoginEnabled, action: .toggleLaunchAtLogin, theme: theme),
            toggleRow("Usage reminder", detail: "Alert when usage runs low", isOn: remindersEnabled, action: .toggleUsageReminder, popup: ("at \(reminderThreshold)%", .editUsageReminder), theme: theme),
            toggleRow("Auto-switch", detail: "Pick the best account for you", isOn: autoSwitchMode != .off, action: .toggleAutoSwitch, popup: (autoSwitchPopupText(), .editAutoSwitch), theme: theme),
            popupRow("Auto-resume", detail: "Continue the task after a switch", value: autoResumeText(), action: .editAutoResume, theme: theme),
            toggleRow("Confirm before switching", detail: "Click once to arm, again to relaunch", isOn: confirmBeforeSwitching, action: .toggleConfirmSwitch, theme: theme)
        ], into: body, y: y, theme: theme)

        var accountRows = orderedAccounts().map { settingsAccountRow($0, theme: theme) }
        accountRows.append(navRow("Add Account…", value: "Browser sign-in", symbol: "plus", tint: .blue, action: .addAccount, theme: theme))
        accountRows.append(navRow("Device Login…", value: "Code on another device", symbol: "desktopcomputer", tint: .neutral, action: .addDeviceAccount, theme: theme))
        y = addSection("Accounts", rows: accountRows, into: body, y: y, theme: theme)

        y = addSection("Health", rows: [healthRow(theme: theme)], into: body, y: y, theme: theme)

        y = addSection("General", rows: [
            navRow("Refresh rate", value: "\(activeRefreshInterval)s active · \(idleRefreshInterval)s idle", action: .editRefresh, theme: theme),
            updatesRow(theme: theme),
            navRow("Diagnostics", value: "Privacy-safe report", action: .diagnostics, theme: theme),
            navRow("Route B profiles", value: nil, tag: "Preview", action: .routeBView, theme: theme)
        ], into: body, y: y, theme: theme)
        return y
    }

    private func addSection(_ title: String, rows: [SettingsRow], into body: NSView, y: CGFloat, theme: PanelTheme) -> CGFloat {
        let header = makeLabel(title, size: 11, weight: .semibold, color: theme.secondaryText)
        body.place(header, x: inset + 4, y: y, width: 200)
        let groupY = y + header.frame.height + 6
        let height = rows.reduce(0) { $0 + $1.height }
        let group = TileView(frame: NSRect(x: inset, y: groupY, width: contentWidth, height: height), fill: theme.tileFill, border: theme.tileBorder)
        var rowY: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let container = FlippedContainerView(frame: NSRect(x: 0, y: rowY, width: contentWidth, height: row.height))
            row.build(container, contentWidth)
            if index > 0 {
                container.addSubview(HairlineView(frame: NSRect(x: 12, y: 0, width: contentWidth - 12, height: 0.5), color: theme.hairline))
            }
            group.addSubview(container)
            rowY += row.height
        }
        body.addSubview(group)
        return group.frame.maxY + 16
    }

    private func segmentedRow(_ title: String, options: [(String, Bool, SettingsPanelAction)], theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 40) { [weak self] row, width in
            let label = makeLabel(title, size: 12.5, weight: .medium, color: theme.primaryText)
            row.place(label, x: 12, y: (40 - label.frame.height) / 2, width: width - 180)
            let segments = options.map { option in
                SegmentedTabsView.Segment(title: option.0, badge: nil, isSelected: option.1) { self?.performSettingsAction(option.2) }
            }
            row.addSubview(SegmentedTabsView(frame: NSRect(x: width - 12 - 150, y: 8, width: 150, height: 24), theme: theme, segments: segments, fontSize: 11.5))
        }
    }

    private func menuBarPreviewRow(theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 40) { [weak self] row, width in
            guard let self else { return }
            let label = makeLabel("Preview", size: 12.5, weight: .medium, color: theme.primaryText)
            row.place(label, x: 12, y: (40 - label.frame.height) / 2, width: 120)

            let account = self.activeAccount ?? self.accounts.first
            let percent = account.map { self.usageMode == .fiveHour ? $0.fiveHourUsedPercent : $0.weeklyUsedPercent } ?? nil
            let text = account.map { self.menuBarPreviewText(label: self.labelForAccount($0), percent: percent) } ?? "–"
            let compact = self.toolbarDisplayStyle == .compact
            let font = NSFont.monospacedDigitSystemFont(ofSize: compact ? 11 : 12.5, weight: .semibold)
            let diameter: CGFloat = compact ? 11 : 13
            let chipWidth = diameter + 5 + textWidth(text, font: font) + 16
            let chip = TileView(frame: NSRect(x: width - 12 - chipWidth, y: 9, width: chipWidth, height: 22), fill: theme.isDark ? NSColor.black.withAlphaComponent(0.30) : NSColor.black.withAlphaComponent(0.07), cornerRadius: 6)
            let tone = PanelTheme.usageTone(for: percent)
            let ring = NSImageView(frame: NSRect(x: 8, y: (22 - diameter) / 2, width: diameter, height: diameter))
            ring.image = MenuBarGlyph.ring(percent: percent, color: theme.color(tone), diameter: diameter)
            chip.addSubview(ring)
            let lowText = (percent ?? 100) < 10
            let chipLabel = makeLabel(text, size: compact ? 11 : 12.5, weight: .semibold, color: lowText ? theme.text(.red) : theme.primaryText, monospacedDigits: true)
            chip.place(chipLabel, x: 8 + diameter + 5, y: (22 - chipLabel.frame.height) / 2)
            row.addSubview(chip)
        }
    }

    private func menuBarPreviewText(label: String, percent: Int?) -> String {
        let value = percent.map { "\(max(0, min(100, $0)))" } ?? "--"
        return toolbarDisplayStyle == .compact ? "\(label)\(value)" : "\(label) \(value)%"
    }

    private func toggleRow(_ title: String, detail: String, isOn: Bool, action: SettingsPanelAction, popup: (String, SettingsPanelAction)? = nil, theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 50) { [weak self] row, width in
            let toggle = ToggleSwitch(isOn: isOn, theme: theme, accessibilityLabel: title) { self?.performSettingsAction(action) }
            var rightEdge = width - 12 - toggle.frame.width
            row.place(toggle, x: rightEdge, y: 15)
            if let popup {
                let button = GlassButton(title: popup.0, style: .popup, theme: theme, height: 22, fontSize: 11.5) { self?.performSettingsAction(popup.1) }
                rightEdge -= button.frame.width + 10
                row.place(button, x: rightEdge, y: 14)
            }
            row.place(makeLabel(title, size: 12.5, weight: .medium, color: theme.primaryText), x: 12, y: 8, width: rightEdge - 22)
            row.place(makeLabel(detail, size: 11, color: theme.secondaryText), x: 12, y: 26, width: rightEdge - 22)
        }
    }

    private func popupRow(_ title: String, detail: String, value: String, action: SettingsPanelAction, theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 50) { [weak self] row, width in
            let button = GlassButton(title: value, style: .popup, theme: theme, height: 22, fontSize: 11.5) { self?.performSettingsAction(action) }
            let rightEdge = width - 12 - button.frame.width
            row.place(button, x: rightEdge, y: 14)
            row.place(makeLabel(title, size: 12.5, weight: .medium, color: theme.primaryText), x: 12, y: 8, width: rightEdge - 22)
            row.place(makeLabel(detail, size: 11, color: theme.secondaryText), x: 12, y: 26, width: rightEdge - 22)
        }
    }

    private func settingsAccountRow(_ account: CodexAccount, theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 42) { [weak self] row, width in
            guard let self else { return }
            let tone: PanelTheme.Tone = account.isActive ? PanelTheme.usageTone(for: account.fiveHourUsedPercent) : .neutral
            row.addSubview(MonogramView(frame: NSRect(x: 12, y: 9, width: 24, height: 24), text: self.labelForAccount(account), fill: account.isActive ? theme.tint(tone) : theme.controlFill, textColor: theme.text(tone)))

            let logout = GlassButton(title: "Log Out", style: .text(theme.text(.red)), theme: theme, height: 24) { [weak self] in self?.logoutAccount(account.email) }
            logout.isEnabled = !self.isSwitching
            var rightEdge = width - 8 - logout.frame.width
            row.place(logout, x: rightEdge, y: 9)
            let rename = GlassButton(title: "Rename", style: .text(theme.text(.blue)), theme: theme, height: 24) { [weak self] in self?.editAccountLabel(account.email) }
            rightEdge -= rename.frame.width + 2
            row.place(rename, x: rightEdge, y: 9)

            let dotSpace: CGFloat = account.isActive ? 14 : 0
            let email = makeLabel(account.email, size: 12.5, weight: .medium, color: theme.primaryText)
            let emailWidth = min(email.frame.width, rightEdge - 8 - 44 - dotSpace)
            email.toolTip = account.email
            row.place(email, x: 44, y: (42 - email.frame.height) / 2, width: emailWidth)
            if account.isActive {
                let dot = DotView(frame: NSRect(x: 44 + emailWidth + 7, y: 18, width: 7, height: 7), color: theme.color(.green))
                dot.toolTip = "Active account"
                row.addSubview(dot)
            }
        }
    }

    private func navRow(_ title: String, value: String?, symbol: String? = nil, tint: PanelTheme.Tone = .neutral, tag: String? = nil, action: SettingsPanelAction, theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 40) { [weak self] row, width in
            let tile = TileView(frame: row.bounds, fill: .clear, cornerRadius: 0, hoverFill: theme.controlFill.withAlphaComponent(0.5), accessibilityLabel: title) {
                self?.performSettingsAction(action)
            }
            row.addSubview(tile)
            var textX: CGFloat = 12
            if let symbol {
                tile.addSubview(MonogramView(frame: NSRect(x: 12, y: 8, width: 24, height: 24), text: "", fill: theme.tint(tint), textColor: theme.text(tint), symbol: symbol))
                textX = 44
            }
            let chevron = SymbolIconView(frame: .zero, symbol: "chevron.right", color: theme.tertiaryText, pointSize: 10, weight: .bold)
            tile.place(chevron, x: width - 12 - 8, y: 14, width: 8, height: 12)
            var rightEdge = width - 12 - 8 - 8
            if let tag {
                let tagView = CapsuleTagView(text: tag, theme: theme, foreground: theme.text(.indigo), background: theme.tint(.indigo))
                rightEdge -= tagView.frame.width
                tile.place(tagView, x: rightEdge, y: 11)
                rightEdge -= 8
            }
            let titleLabel = makeLabel(title, size: 12.5, weight: .medium, color: symbol != nil && tint == .blue ? theme.text(.blue) : theme.primaryText)
            tile.place(titleLabel, x: textX, y: (40 - titleLabel.frame.height) / 2, width: min(titleLabel.frame.width + 2, rightEdge - textX))
            if let value {
                let valueLabel = makeLabel(value, size: 11, color: theme.secondaryText, alignment: .right, monospacedDigits: true)
                let valueX = textX + titleLabel.frame.width + 12
                tile.place(valueLabel, x: valueX, y: (40 - valueLabel.frame.height) / 2, width: max(0, rightEdge - valueX))
            }
        }
    }

    private func updatesRow(theme: PanelTheme) -> SettingsRow {
        SettingsRow(height: 40) { [weak self] row, width in
            guard let self else { return }
            let check = GlassButton(title: "Check", style: .popup, theme: theme, height: 22, fontSize: 11.5) { [weak self] in self?.checkUpdates() }
            check.image = nil
            check.setFrameSize(NSSize(width: check.frame.width - 12, height: 22))
            let rightEdge = width - 12 - check.frame.width
            row.place(check, x: rightEdge, y: 9)
            let title = makeLabel("Updates", size: 12.5, weight: .medium, color: theme.primaryText)
            row.place(title, x: 12, y: (40 - title.frame.height) / 2, width: 100)
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
            let update = self.healthStatuses.first { $0.title == "Update" }?.value ?? ""
            let status: String?
            switch update {
            case "Current": status = "up to date"
            case "Checking": status = "checking…"
            case "", "Check", "Error", "Unknown": status = nil
            default: status = "\(update) available"
            }
            let value = makeLabel(status.map { "\(version) · \($0)" } ?? version, size: 11, color: theme.secondaryText, alignment: .right, monospacedDigits: true)
            row.place(value, x: 12 + title.frame.width + 12, y: (40 - value.frame.height) / 2, width: rightEdge - 10 - (12 + title.frame.width + 12))
        }
    }

    private func healthRow(theme: PanelTheme) -> SettingsRow {
        let statuses = Array(healthStatuses.prefix(6))
        let columns = 2
        let rows = Int(ceil(Double(statuses.count) / Double(columns)))
        return SettingsRow(height: CGFloat(rows) * 22 + 18) { row, width in
            let columnWidth = (width - 24 - 24) / CGFloat(columns)
            for (index, status) in statuses.enumerated() {
                let x = 12 + CGFloat(index % columns) * (columnWidth + 24)
                let y = 10 + CGFloat(index / columns) * 22
                row.addSubview(DotView(frame: NSRect(x: x, y: y + 5, width: 7, height: 7), color: status.color))
                let title = makeLabel(status.title, size: 11, color: theme.secondaryText)
                row.place(title, x: x + 12, y: y, width: 52)
                let value = makeLabel(status.value, size: 11, weight: .semibold, color: theme.primaryText, alignment: .right)
                value.toolTip = status.value
                row.place(value, x: x + 12 + title.frame.width + 4, y: y, width: max(0, columnWidth - 12 - title.frame.width - 4))
            }
        }
    }

    private func autoSwitchPopupText() -> String {
        switch autoSwitchMode {
        case .off: return "Off"
        case .ask: return "Ask at \(autoSwitchThreshold)%"
        case .threshold: return "At \(autoSwitchThreshold)%"
        case .zero: return "Ask at 0%"
        }
    }

    private func autoResumeText() -> String {
        switch autoResumeMode {
        case .off: return "Off"
        case .ask: return "Ask first"
        case .idle5: return "Idle 5s"
        case .idle10: return "Idle 10s"
        case .always: return "Always"
        }
    }

    // MARK: - Route B

    private func buildRouteBBody(into body: NSView, theme: PanelTheme) -> CGFloat {
        var y: CGFloat = 0
        let banner = TileView(frame: NSRect(x: inset, y: y, width: contentWidth, height: 64), fill: theme.tint(.indigo), border: theme.color(.indigo).withAlphaComponent(0.35))
        banner.place(makeLabel("Secondary lane only", size: 12.5, weight: .semibold, color: theme.text(.indigo)), x: 12, y: 10, width: contentWidth - 24)
        banner.place(makeLabel("No requests or keys in this preview. Native Codex stays the", size: 11, color: theme.secondaryText), x: 12, y: 28, width: contentWidth - 24)
        banner.place(makeLabel("default for sends, uploads, accounts and live operations.", size: 11, color: theme.secondaryText), x: 12, y: 43, width: contentWidth - 24)
        body.addSubview(banner)
        y = banner.frame.maxY + 12

        for profile in routeBProfiles.prefix(2) {
            let isSelected = profile.id == selectedRouteBProfileID
            let capabilityHeight = routeBCapabilityRowsHeight(profile.capabilities, width: contentWidth - 24)
            let tile = TileView(
                frame: NSRect(x: inset, y: y, width: contentWidth, height: 78 + capabilityHeight + 12),
                fill: theme.tileFill,
                border: isSelected ? theme.color(.green).withAlphaComponent(0.5) : theme.tileBorder,
                borderWidth: isSelected ? 1 : 0.5
            )
            let button = GlassButton(title: isSelected ? "Selected" : "Select", style: isSelected ? .secondary : .primary, theme: theme) { [weak self] in
                self?.selectRouteBProfile(profile.id)
            }
            button.isEnabled = !isSelected
            let buttonX = contentWidth - 12 - button.frame.width
            tile.place(button, x: buttonX, y: 12)
            tile.place(makeLabel(profile.name, size: 13, weight: .semibold, color: theme.primaryText), x: 12, y: 12, width: buttonX - 20)
            tile.place(makeLabel("\(profile.provider) · \(profile.model)", size: 11, color: theme.secondaryText), x: 12, y: 30, width: buttonX - 20)
            tile.place(makeLabel(profile.summary, size: 11, color: theme.secondaryText), x: 12, y: 50, width: contentWidth - 24)

            var x: CGFloat = 12
            var rowY: CGFloat = 76
            for capability in profile.capabilities {
                let (tone, symbol): (PanelTheme.Tone, String) = {
                    switch capability.state {
                    case .ready: return (.green, "✓")
                    case .testRequired: return (.orange, "!")
                    case .blocked: return (.red, "×")
                    }
                }()
                let tag = CapsuleTagView(text: "\(symbol) \(capability.label)", theme: theme, foreground: theme.text(tone), background: theme.tint(tone), height: 20, fontSize: 10.5)
                if x + tag.frame.width > contentWidth - 12 {
                    x = 12
                    rowY += 26
                }
                tile.place(tag, x: x, y: rowY)
                x += tag.frame.width + 6
            }
            body.addSubview(tile)
            y = tile.frame.maxY + 10
        }
        return y + 2
    }

    private func routeBCapabilityRowsHeight(_ capabilities: [RouteBCapability], width: CGFloat) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        var x: CGFloat = 0
        var rows: CGFloat = capabilities.isEmpty ? 0 : 1
        for capability in capabilities {
            let tagWidth = textWidth("✓ \(capability.label)", font: font) + 14
            if x + tagWidth > width {
                rows += 1
                x = 0
            }
            x += tagWidth + 6
        }
        return rows * 26
    }

    // MARK: - Shared helpers

    private func orderedAccounts() -> [CodexAccount] {
        accounts.sorted { left, right in
            let leftPriority = sortPriority(for: left)
            let rightPriority = sortPriority(for: right)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return labelForAccount(left).localizedCaseInsensitiveCompare(labelForAccount(right)) == .orderedAscending
        }
    }

    private func sortPriority(for account: CodexAccount) -> Int {
        switch labelForAccount(account) {
        case "L": return 0
        case "A": return 1
        default: return 10
        }
    }

    private func accountNeedsLogin(_ account: CodexAccount) -> Bool {
        account.fiveHourUsage == "Login expired" || account.weeklyUsage == "Login expired"
    }

    private func planText(_ plan: String) -> String {
        guard !plan.isEmpty else { return "ChatGPT" }
        return "ChatGPT \(plan.prefix(1).uppercased())\(plan.dropFirst().lowercased())"
    }

    private func percentText(_ percent: Int?) -> String {
        guard let percent else { return "--" }
        return "\(max(0, min(100, percent)))%"
    }

    private func switchPreviewText(for account: CodexAccount) -> String {
        "Switch to \(labelForAccount(account)) · 5-hour \(percentText(account.fiveHourUsedPercent)) · weekly \(percentText(account.weeklyUsedPercent))"
    }

    private func fiveHourResetText(from usage: String) -> String {
        guard let inner = parenthesizedValue(from: usage) else { return "--:--" }
        return Self.firstClockText(in: inner) ?? inner
    }

    private func weeklyResetText(from usage: String) -> String {
        guard let inner = parenthesizedValue(from: usage) else { return "--" }
        let time = Self.firstClockText(in: inner)
        let day = Self.firstWeekdayText(in: inner) ?? Self.inferredWeekdayText(from: inner)
        switch (time, day) {
        case let (time?, day?): return "\(day) \(time)"
        case let (time?, nil): return time
        case let (nil, day?): return day
        default: return inner
        }
    }

    private func parenthesizedValue(from usage: String) -> String? {
        guard let open = usage.firstIndex(of: "("), let close = usage.firstIndex(of: ")"), open < close else { return nil }
        return String(usage[usage.index(after: open)..<close])
    }

    private static let clockRegex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#)

    private static func firstClockText(in text: String) -> String? {
        guard let regex = clockRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hour = Int(text[hourRange]) else {
            return nil
        }
        return String(format: "%02d:%@", hour, String(text[minuteRange]))
    }

    private static let weekdayNames: [String: String] = [
        "monday": "Mon", "mon": "Mon",
        "tuesday": "Tue", "tue": "Tue", "tues": "Tue",
        "wednesday": "Wed", "wed": "Wed",
        "thursday": "Thu", "thu": "Thu", "thur": "Thu", "thurs": "Thu",
        "friday": "Fri", "fri": "Fri",
        "saturday": "Sat", "sat": "Sat",
        "sunday": "Sun", "sun": "Sun"
    ]

    private static func firstWeekdayText(in text: String) -> String? {
        for token in text.split(whereSeparator: { !$0.isLetter }) {
            if let day = weekdayNames[token.lowercased()] { return day }
        }
        return nil
    }

    private static let inferenceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    private static let inferenceFormats = [
        "HH:mm MMM d yyyy", "HH:mm MMMM d yyyy", "HH:mm d MMM yyyy", "HH:mm d MMMM yyyy",
        "MMM d HH:mm yyyy", "MMMM d HH:mm yyyy", "d MMM HH:mm yyyy", "d MMMM HH:mm yyyy",
        "yyyy HH:mm MMM d", "yyyy HH:mm MMMM d", "yyyy HH:mm d MMM", "yyyy HH:mm d MMMM",
        "yyyy MMM d HH:mm", "yyyy MMMM d HH:mm", "yyyy d MMM HH:mm", "yyyy d MMMM HH:mm"
    ]

    private static func inferredWeekdayText(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: " on ", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let year = Calendar.current.component(.year, from: Date())
        let formatter = inferenceFormatter
        for candidate in [cleaned, "\(cleaned) \(year)", "\(year) \(cleaned)"] {
            for format in inferenceFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: candidate) {
                    let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    return symbols[Calendar.current.component(.weekday, from: date) - 1]
                }
            }
        }
        return nil
    }
}
