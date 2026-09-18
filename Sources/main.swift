import AppKit
import ApplicationServices
import Charts
import CryptoKit
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

private enum AccountPanelLayout {
    static let usageWidth: CGFloat = 520
    static let usageInset: CGFloat = 14
    static let bottomBarTopGap: CGFloat = 10
    static let controlBarHeight = CGFloat(UsagePanelLayoutMetrics.controlBarHeight)
    static let bottomBarHeight = controlBarHeight
    static let rowHeight = CGFloat(UsagePanelLayoutMetrics.accountRowHeight)
    static let confirmationRowHeight: CGFloat = 78
    static let rowGap = CGFloat(UsagePanelLayoutMetrics.accountRowGap)
    static let accountListEdgeAllowance = CGFloat(UsagePanelLayoutMetrics.accountListEdgeAllowance)
    static let paceTopGap: CGFloat = 8
    static let paceChartHeight: CGFloat = 104
    static let verdictTopGap: CGFloat = 8
    static let verdictCardHeight = CGFloat(UsagePanelLayoutMetrics.verdictCardHeight)
    static let verdictResetGap = CGFloat(UsagePanelLayoutMetrics.verdictResetGap)
    static var verdictSectionHeight: CGFloat { verdictTopGap + verdictCardHeight + verdictResetGap }
    static var paceSectionHeight: CGFloat { paceChartHeight }
    static let resetChanceTopGap: CGFloat = 10
    static let resetChanceHeight = controlBarHeight
    static var resetChanceSectionHeight: CGFloat {
        resetChanceTopGap + resetChanceHeight
    }
}

// MARK: - Pool pace chart (Swift Charts inside the AppKit panel)

struct PoolPaceChartData {
    let points: [DailyPoolSpendPoint]
    let gridLine: Color
    let labelText: Color
    let language: AppLanguage
}

/// Fourteen daily gross-spend bars over a normalized full-pool track.

struct PoolPaceChartView: View {
    struct Bar: Identifiable {
        let index: Int
        let point: DailyPoolSpendPoint
        var id: Date { point.date }
    }

    let data: PoolPaceChartData
    @State private var hoveredIndex: Int?
    @State private var hoverLocation: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxDailyBars = 14
    private static let maxAxisLabels = 4
    private static let dailyBarWidth: CGFloat = 18
    private static let popoverWidth = CGFloat(PoolChartPopoverMetrics.width)
    private static let popoverHeight = CGFloat(PoolChartPopoverMetrics.minimumHeight)
    private static let popoverGap: CGFloat = 12

    private var bars: [Bar] {
        Array(data.points.suffix(Self.maxDailyBars)).enumerated().map { offset, point in
            Bar(index: offset, point: point)
        }
    }

    var body: some View {
        chart
    }

    private var chart: some View {
        let semanticLabels = PoolChartLocalization.semanticLabels(language: data.language)
        return Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value(semanticLabels.index, Double(bar.index)),
                    yStart: .value(semanticLabels.base, 0),
                    yEnd: .value(semanticLabels.capacity, 100),
                    width: .fixed(Self.dailyBarWidth)
                )
                .foregroundStyle(data.gridLine.opacity(0.28))
                .cornerRadius(3)
                .accessibilityLabel(PoolChartLocalization.axisDate(bar.point.date, language: data.language))
                .accessibilityValue(PoolChartLocalization.accessibilityValue(for: bar.point, language: data.language))

                if let spentPercent = bar.point.spentPercent {
                    BarMark(
                        x: .value(semanticLabels.index, Double(bar.index)),
                        yStart: .value(semanticLabels.base, 0),
                        yEnd: .value(semanticLabels.pool, PoolChartVisualScale.barHeight(for: spentPercent)),
                        width: .fixed(Self.dailyBarWidth)
                    )
                    .foregroundStyle(barStyle(for: spentPercent))
                    .opacity(barOpacity(for: bar.index))
                    .cornerRadius(3)

                    if hoveredIndex == bar.index {
                        BarMark(
                            x: .value(semanticLabels.index, Double(bar.index)),
                            yStart: .value(semanticLabels.base, 0),
                            yEnd: .value(semanticLabels.pool, PoolChartVisualScale.barHeight(for: spentPercent)),
                            width: .fixed(Self.dailyBarWidth + 4)
                        )
                        .foregroundStyle(barStyle(for: spentPercent))
                        .opacity(0.24)
                        .cornerRadius(5)
                    }
                }
            }
            RuleMark(y: .value(semanticLabels.pool, PoolChartVisualScale.guidePercent))
                .foregroundStyle(Color(.nativeGold).opacity(0.38))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .accessibilityHidden(true)
        }
        .chartXScale(domain: -0.5...(Double(bars.count) - 0.5))
        .chartYScale(domain: 0...100)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisIndexes) { axisValue in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel(collisionResolution: .disabled) {
                    if let raw = axisValue.as(Double.self) {
                        let index = Int(raw.rounded())
                        if bars.indices.contains(index) {
                            Text(PoolChartLocalization.axisDate(bars[index].point.date, language: data.language))
                                .font(.system(size: 7))
                                .foregroundStyle(data.labelText.opacity(0.7))
                        }
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoverLocation = location
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                let x = location.x - frame.minX
                                guard let xValue = proxy.value(atX: x, as: Double.self) else { return }
                                hoveredIndex = PoolChartHoverPolicy.nearestIndex(to: xValue, count: bars.count)
                            case .ended:
                                hoveredIndex = nil
                                hoverLocation = nil
                            }
                        }

                    if let hoveredIndex, bars.indices.contains(hoveredIndex) {
                        let placement = popoverPlacement(
                            for: bars[hoveredIndex],
                            proxy: proxy,
                            geometry: geometry
                        )
                        hoverPopover(for: bars[hoveredIndex].point)
                            .position(x: placement.centerX, y: placement.centerY)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(height: AccountPanelLayout.paceChartHeight)
        .accessibilityLabel(PoolChartLocalization.chartSummary(language: data.language))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hoveredIndex)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: bars.map { $0.point.spentPercent ?? -1 }
        )
    }

    private func barStyle(for spentPercent: Double) -> AnyShapeStyle {
        let colors: [Color]
        switch DailyPoolSpendBand.classify(spentPercent) {
        case .withinReference:
            colors = [Color(.nativeMint), Color(.nativeBlue)]
        case .aboveReference:
            colors = [Color(.nativeGold), Color(.nativeOrange)]
        case .high:
            colors = [Color(.nativeCoral), Color(.nativeRed)]
        case .unknown:
            colors = [.secondary.opacity(0.55), .secondary]
        }
        return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top))
    }

    private func barOpacity(for index: Int) -> Double {
        guard let hoveredIndex else { return 0.86 }
        return hoveredIndex == index ? 1 : 0.42
    }

    private var axisIndexes: [Double] {
        guard !bars.isEmpty else { return [] }
        let budget = max(1, min(Self.maxAxisLabels, bars.count))
        if budget == 1 { return [0] }
        let step = Double(bars.count - 1) / Double(budget - 1)
        var indexes = (0..<budget).map { position in
            Int((Double(position) * step).rounded())
        }
        if !indexes.contains(bars.count - 1) {
            indexes.append(bars.count - 1)
        }
        return indexes.sorted().map(Double.init)
    }

    private func hoverPopover(for point: DailyPoolSpendPoint) -> some View {
        let lines = PoolChartLocalization.detailLines(for: point, language: data.language)
        return VStack(alignment: .leading, spacing: 3) {
            if let date = lines.first {
                Text(date)
                    .font(.system(
                        size: CGFloat(PoolChartPopoverMetrics.dateFontSize),
                        weight: .semibold,
                        design: .rounded
                    ))
            }
            ForEach(Array(lines.dropFirst()), id: \.self) { line in
                Text(line)
                    .font(.system(
                        size: CGFloat(PoolChartPopoverMetrics.bodyFontSize),
                        weight: .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(data.labelText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, CGFloat(PoolChartPopoverMetrics.horizontalPadding))
        .padding(.vertical, CGFloat(PoolChartPopoverMetrics.verticalPadding))
        .frame(
            minWidth: Self.popoverWidth,
            maxWidth: Self.popoverWidth,
            minHeight: Self.popoverHeight,
            alignment: .leading
        )
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(data.gridLine.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 4)
    }

    private func popoverPlacement(
        for bar: Bar,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> PoolChartPopoverPlacement {
        guard let plotFrame = proxy.plotFrame else {
            return PoolChartPopoverPolicy.placement(
                anchorX: geometry.size.width / 2,
                preferredCenterY: Self.popoverHeight / 2 + 2,
                containerWidth: geometry.size.width,
                containerHeight: geometry.size.height,
                popoverWidth: Self.popoverWidth,
                popoverHeight: Self.popoverHeight
            )
        }
        let frame = geometry[plotFrame]
        let plotX = proxy.position(forX: Double(bar.index)) ?? frame.width / 2
        let barCenterX = frame.minX + plotX
        let cursor = hoverLocation ?? CGPoint(x: barCenterX, y: frame.midY)
        let placeLeft = PoolChartPopoverPolicy.shouldPlaceLeft(index: bar.index, count: bars.count)
        let horizontalOffset = Self.dailyBarWidth / 2 + Self.popoverGap + Self.popoverWidth / 2
        return PoolChartPopoverPolicy.placement(
            anchorX: barCenterX + (placeLeft ? -horizontalOffset : horizontalOffset),
            preferredCenterY: cursor.y,
            containerWidth: geometry.size.width,
            containerHeight: geometry.size.height,
            popoverWidth: Self.popoverWidth,
            popoverHeight: Self.popoverHeight
        )
    }
}
struct PaceDisplayState {
    let history: [PoolHistorySample]
    let now: Date
    let forecast: PoolSufficiencyForecast
}

final class AccountSwitcherPanelView: NSView {
    private let accounts: [CodexAccount]
    private let warmupStates: [String: LimitWarmupState]
    private let isWarmingUp: Bool
    private let activeAccount: CodexAccount?
    private let mode: AccountPanelMode
    private let language: AppLanguage
    private let lastUpdatedText: String
    private let lastError: String?
    private let isSwitching: Bool
    private let launchAtLoginEnabled: Bool
    private let remindersEnabled: Bool
    private let creditExpiryNotificationsEnabled: Bool
    private let reminderThreshold: Int
    private let creditExpiryLeadDays: Int
    private let autoSwitchEnabled: Bool
    private let autoSwitchThreshold: Int
    private let autoSwitchMode: AutoSwitchMode
    private let armedSwitchEmail: String?
    private let quitConfirmationArmed: Bool
    private let protectFrontmostCodex: Bool
    private let resetCreditsByEmail: [String: ResetCreditsSnapshot]
    private let healthStatuses: [HealthStatus]
    private let usageMode: UsageDisplayMode
    private let activeRefreshInterval: Int
    private let idleRefreshInterval: Int
    private let labelForAccount: (CodexAccount) -> String
    private let compactEmail: (String) -> String
    private let switchAccount: (String) -> Void
    private let removeAccountRequested: (String) -> Void
    private let cancelSwitchConfirmation: () -> Void
    private let refresh: () -> Void
    private let showSettings: () -> Void
    private let checkUpdates: () -> Void
    private let editAccountLabel: (String) -> Void
    private let showResetCredits: () -> Void
    private let redeemResetCredit: (String, String) -> Void
    private let performSettingsAction: (SettingsPanelAction) -> Void
    private let close: () -> Void
    private let toggleLaunchAtLogin: () -> Void
    private let commitReminderThreshold: (String) -> Bool
    private let commitCreditExpiryLeadDays: (String) -> Bool
    private let updateActiveRefreshInterval: (Int) -> Void
    private let updateIdleRefreshInterval: (Int) -> Void
    private let pace: PaceDisplayState?
    private let resetChance: ResetChanceForecast?
    private var theme: PanelTheme { PanelTheme.current(for: effectiveAppearance) }

    private let outerInset: CGFloat = 18
    private let usageInset: CGFloat = 14
    private let cardGap: CGFloat = 10
    private let bottomBarTopGap: CGFloat = 10
    private let bottomBarHeight: CGFloat = 40

    init(
        accounts: [CodexAccount],
        warmupStates: [String: LimitWarmupState] = [:],
        isWarmingUp: Bool = false,
        activeAccount: CodexAccount?,
        mode: AccountPanelMode,
        language: AppLanguage,
        lastUpdatedText: String,
        lastError: String?,
        isSwitching: Bool,
        launchAtLoginEnabled: Bool,
        remindersEnabled: Bool,
        creditExpiryNotificationsEnabled: Bool,
        reminderThreshold: Int,
        creditExpiryLeadDays: Int,
        autoSwitchEnabled: Bool,
        autoSwitchThreshold: Int,
        autoSwitchMode: AutoSwitchMode,
        armedSwitchEmail: String?,
        quitConfirmationArmed: Bool,
        protectFrontmostCodex: Bool,
        resetCreditsByEmail: [String: ResetCreditsSnapshot],
        healthStatuses: [HealthStatus],
        usageMode: UsageDisplayMode,
        activeRefreshInterval: Int,
        idleRefreshInterval: Int,
        labelForAccount: @escaping (CodexAccount) -> String,
        compactEmail: @escaping (String) -> String,
        switchAccount: @escaping (String) -> Void,
        removeAccountRequested: @escaping (String) -> Void,
        cancelSwitchConfirmation: @escaping () -> Void,
        refresh: @escaping () -> Void,
        showSettings: @escaping () -> Void,
        checkUpdates: @escaping () -> Void,
        editAccountLabel: @escaping (String) -> Void,
        showResetCredits: @escaping () -> Void,
        redeemResetCredit: @escaping (String, String) -> Void,
        performSettingsAction: @escaping (SettingsPanelAction) -> Void,
        close: @escaping () -> Void,
        toggleLaunchAtLogin: @escaping () -> Void,
        commitReminderThreshold: @escaping (String) -> Bool,
        commitCreditExpiryLeadDays: @escaping (String) -> Bool,
        updateActiveRefreshInterval: @escaping (Int) -> Void,
        updateIdleRefreshInterval: @escaping (Int) -> Void,
        pace: PaceDisplayState?,
        resetChance: ResetChanceForecast?,
        maximumPanelHeight: CGFloat
    ) {
        self.warmupStates = warmupStates
        self.isWarmingUp = isWarmingUp
        self.accounts = accounts
        self.activeAccount = activeAccount
        self.mode = mode
        self.language = language
        self.lastUpdatedText = lastUpdatedText
        self.lastError = lastError
        self.isSwitching = isSwitching
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.remindersEnabled = remindersEnabled
        self.creditExpiryNotificationsEnabled = creditExpiryNotificationsEnabled
        self.reminderThreshold = reminderThreshold
        self.creditExpiryLeadDays = creditExpiryLeadDays
        self.autoSwitchEnabled = autoSwitchEnabled
        self.autoSwitchThreshold = autoSwitchThreshold
        self.autoSwitchMode = autoSwitchMode
        self.armedSwitchEmail = armedSwitchEmail
        self.quitConfirmationArmed = quitConfirmationArmed
        self.protectFrontmostCodex = protectFrontmostCodex
        self.resetCreditsByEmail = resetCreditsByEmail
        self.healthStatuses = healthStatuses
        self.usageMode = usageMode
        self.activeRefreshInterval = activeRefreshInterval
        self.idleRefreshInterval = idleRefreshInterval
        self.labelForAccount = labelForAccount
        self.compactEmail = compactEmail
        self.switchAccount = switchAccount
        self.removeAccountRequested = removeAccountRequested
        self.cancelSwitchConfirmation = cancelSwitchConfirmation
        self.refresh = refresh
        self.showSettings = showSettings
        self.checkUpdates = checkUpdates
        self.editAccountLabel = editAccountLabel
        self.showResetCredits = showResetCredits
        self.redeemResetCredit = redeemResetCredit
        self.performSettingsAction = performSettingsAction
        self.close = close
        self.toggleLaunchAtLogin = toggleLaunchAtLogin
        self.commitReminderThreshold = commitReminderThreshold
        self.commitCreditExpiryLeadDays = commitCreditExpiryLeadDays
        self.updateActiveRefreshInterval = updateActiveRefreshInterval
        self.updateIdleRefreshInterval = updateIdleRefreshInterval
        self.pace = pace
        self.resetChance = resetChance
        let panelSize = AccountSwitcherPanelView.preferredSize(
            mode: mode,
            accountCount: accounts.count,
            showsPace: pace != nil,
            maximumHeight: maximumPanelHeight
        )
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

    static func preferredSize(
        mode: AccountPanelMode,
        accountCount: Int,
        showsPace: Bool,
        maximumHeight: CGFloat
    ) -> NSSize {
        if mode == .usage {
            let forecastHeight = showsPace
                ? AccountPanelLayout.paceTopGap
                    + AccountPanelLayout.paceSectionHeight
                    + AccountPanelLayout.verdictSectionHeight
                : 0
            let fixedHeight = AccountPanelLayout.usageInset * 2
                + AccountPanelLayout.bottomBarTopGap + AccountPanelLayout.bottomBarHeight
                + AccountPanelLayout.resetChanceTopGap + AccountPanelLayout.resetChanceHeight
                + forecastHeight
            let availableListHeight = max(AccountPanelLayout.rowHeight, maximumHeight - fixedHeight)
            let rowCapacity = max(
                1,
                Int((availableListHeight - AccountPanelLayout.accountListEdgeAllowance + AccountPanelLayout.rowGap)
                    / (AccountPanelLayout.rowHeight + AccountPanelLayout.rowGap))
            )
            let visibleRows = AccountListPresentationPolicy.visibleRowCount(
                accountCount: accountCount,
                availableRowCapacity: rowCapacity
            )
            let desiredListHeight: CGFloat
            if accountCount == 0 {
                desiredListHeight = min(156, availableListHeight)
            } else {
                desiredListHeight = CGFloat(visibleRows) * AccountPanelLayout.rowHeight
                    + CGFloat(max(0, visibleRows - 1)) * AccountPanelLayout.rowGap
                    + AccountPanelLayout.accountListEdgeAllowance
            }
            return NSSize(
                width: AccountPanelLayout.usageWidth,
                height: min(maximumHeight, fixedHeight + desiredListHeight)
            )
        }
        if mode == .settings {
            return NSSize(width: 432, height: 590)
        }
        if mode == .resets && accountCount >= 3 {
            return NSSize(width: 468, height: 640)
        }
        return NSSize(width: 432, height: 520)
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
        case .resets:
            buildResetCreditsContent()
        }
    }

    private func buildUsageContent() {
        let contentWidth = bounds.width - (usageInset * 2)
        let bottomBarY = bounds.height - usageInset - bottomBarHeight
        addSubview(bottomBar(frame: NSRect(x: usageInset, y: bottomBarY, width: contentWidth, height: bottomBarHeight)))

        let resetChanceY = bottomBarY - AccountPanelLayout.resetChanceTopGap - AccountPanelLayout.resetChanceHeight
        addSubview(resetChanceSection(frame: NSRect(x: usageInset, y: resetChanceY, width: contentWidth, height: AccountPanelLayout.resetChanceHeight)))

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
            addSubview(paceSection(pace, frame: NSRect(x: usageInset, y: paceTop, width: contentWidth, height: AccountPanelLayout.paceSectionHeight)))
            listBottom = paceTop
        }

        let listFrame = NSRect(
            x: usageInset,
            y: usageInset,
            width: contentWidth,
            height: max(0, listBottom - usageInset)
        )
        if accounts.isEmpty {
            addSubview(usageEmptyStateCard(frame: listFrame))
        } else {
            addSubview(accountListSection(orderedSettingsAccounts(), frame: listFrame))
        }
    }

    private func accountListSection(_ orderedAccounts: [CodexAccount], frame: NSRect) -> NSView {
        let section = FlippedContainerView(frame: frame)
        let rowCapacity = max(
            1,
            Int((frame.height - AccountPanelLayout.accountListEdgeAllowance + AccountPanelLayout.rowGap)
                / (AccountPanelLayout.rowHeight + AccountPanelLayout.rowGap))
        )
        let visibleRows = AccountListPresentationPolicy.visibleRowCount(
            accountCount: orderedAccounts.count,
            availableRowCapacity: rowCapacity
        )
        let viewportHeight = min(frame.height, CGFloat(AccountListPresentationPolicy.viewportHeight(
            accountCount: orderedAccounts.count,
            visibleRowCount: visibleRows,
            maximumHeight: Double(frame.height),
            rowHeight: Double(AccountPanelLayout.rowHeight),
            confirmationRowHeight: Double(AccountPanelLayout.confirmationRowHeight),
            rowGap: Double(AccountPanelLayout.rowGap),
            showsConfirmation: armedSwitchEmail != nil
        )) + AccountPanelLayout.accountListEdgeAllowance)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: frame.width, height: viewportHeight))
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let policyRequiresScrolling = AccountListPresentationPolicy.requiresScrolling(
            accountCount: orderedAccounts.count,
            availableRowCapacity: rowCapacity
        )

        let rowHeights = orderedAccounts.map { account in
            armedSwitchEmail == account.email && !account.isActive
                ? AccountPanelLayout.confirmationRowHeight
                : AccountPanelLayout.rowHeight
        }
        let contentHeight = rowHeights.reduce(0, +)
            + CGFloat(max(0, orderedAccounts.count - 1)) * AccountPanelLayout.rowGap
            + AccountPanelLayout.accountListEdgeAllowance
        scrollView.hasVerticalScroller = policyRequiresScrolling || contentHeight > viewportHeight
        let table = AccountListTableView(frame: NSRect(
            x: 0,
            y: 0,
            width: frame.width,
            height: max(viewportHeight, contentHeight)
        ),
            accounts: orderedAccounts,
            isInteractionEnabled: !isSwitching,
            armedEmail: armedSwitchEmail,
            deleteTitle: LocalizedText.value(.deleteAccountButton, language: language),
            rowSpacing: AccountPanelLayout.rowGap,
            rowHeightProvider: { [weak self] account in
                self?.armedSwitchEmail == account.email && !account.isActive
                    ? AccountPanelLayout.confirmationRowHeight
                    : AccountPanelLayout.rowHeight
            },
            rowViewProvider: { [weak self] account, rowFrame in
                guard let self else { return NSView(frame: rowFrame) }
                let index = orderedAccounts.firstIndex(where: { $0.email == account.email }) ?? 0
                return self.accountListRowContent(account, displayIndex: index + 1, frame: rowFrame)
            },
            onSelect: { [weak self] account in
                self?.switchAccount(account.email)
            },
            onDelete: { [weak self] account in
                self?.removeAccountRequested(account.email)
            }
        )
        scrollView.documentView = table
        if let armedRow = orderedAccounts.firstIndex(where: { $0.email == armedSwitchEmail }) {
            table.scrollRowToVisible(armedRow)
        }
        section.addSubview(scrollView)
        return section
    }

    private func buildSettingsContent() {
        let content = SettingsScreenView(
            language: language,
            theme: theme,
            followsCodex: launchAtLoginEnabled,
            remindersEnabled: remindersEnabled,
            creditExpiryEnabled: creditExpiryNotificationsEnabled,
            reminderThreshold: reminderThreshold,
            creditExpiryLeadDays: creditExpiryLeadDays,
            autoSwitchSummary: autoSwitchDetailText(),
            activeRefreshInterval: activeRefreshInterval,
            idleRefreshInterval: idleRefreshInterval,
            onLanguageChanged: { [weak self] language in
                guard let self else { return }
                self.performSettingsAction(language == .russian ? .languageRussian : .languageEnglish)
            },
            onFollowChanged: { [weak self] _ in self?.toggleLaunchAtLogin() },
            onRemindersChanged: { [weak self] _ in self?.performSettingsAction(.toggleUsageReminder) },
            onCreditExpiryChanged: { [weak self] _ in self?.performSettingsAction(.toggleCreditExpiryNotifications) },
            onAutoSwitch: { [weak self] in self?.performSettingsAction(.editAutoSwitch) },
            onReminderThresholdCommit: commitReminderThreshold,
            onCreditExpiryLeadDaysCommit: commitCreditExpiryLeadDays,
            onActiveRefreshChanged: updateActiveRefreshInterval,
            onIdleRefreshChanged: updateIdleRefreshInterval,
            onCheckUpdates: { [weak self] in self?.checkUpdates() },
            onSavePlugins: { [weak self] in self?.performSettingsAction(.saveReferencePlugins) },
            onDiagnostics: { [weak self] in self?.performSettingsAction(.diagnostics) },
            onDone: { [weak self] in self?.performSettingsAction(.usageView) }
        )
        let hosting = NSHostingView(rootView: content)
        hosting.frame = bounds.insetBy(dx: 2, dy: 2)
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
    }

    private func buildResetCreditsContent() {
        let contentWidth = bounds.width - (outerInset * 2)
        addSubview(resetCreditsHeader(frame: NSRect(x: outerInset, y: outerInset, width: contentWidth, height: 44)))

        if accounts.isEmpty {
            let empty = emptyStateCard(frame: NSRect(x: outerInset, y: 74, width: contentWidth, height: bounds.height - 74 - outerInset))
            addSubview(empty)
            return
        }

        let orderedAccounts = orderedSettingsAccounts()
        let areaY: CGFloat = 74
        let areaHeight = bounds.height - areaY - outerInset
        let columns = orderedAccounts.count >= 4 ? 2 : 1
        let cardWidth = columns == 1 ? contentWidth : (contentWidth - cardGap) / 2

        if columns == 1 {
            var y = areaY
            for account in orderedAccounts {
                let creditCount = resetCreditsByEmail[account.email]?.availableCredits.count ?? 0
                let cardHeight = min(188, 132 + CGFloat(max(0, creditCount - 1)) * 19)
                addSubview(resetCreditAccountCard(account, frame: NSRect(x: outerInset, y: y, width: cardWidth, height: cardHeight)))
                y += cardHeight + cardGap
            }
            return
        }

        let rows = Int(ceil(Double(orderedAccounts.count) / Double(columns)))
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
        header.addSubview(label(LocalizedText.value(.resetVaultTitle, language: language), frame: NSRect(x: 2, y: 0, width: 150, height: 14), size: 9.5, weight: .bold, color: theme.tertiaryText))
        header.addSubview(label(LocalizedText.value(.usageResetsTitle, language: language), frame: NSRect(x: 2, y: 13, width: 210, height: 28), size: 24, weight: .bold, color: theme.primaryText))
        header.addSubview(label(resetCreditsHeaderSubtitle(), frame: NSRect(x: 196, y: 21, width: frame.width - 302, height: 15), size: 10.5, weight: .medium, color: theme.secondaryText, alignment: .right))

        let back = SettingsActionButton(frame: NSRect(x: frame.width - 92, y: 7, width: 92, height: 30), title: LocalizedText.value(.accountsButton, language: language), color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func resetCreditsHeaderSubtitle() -> String {
        let state = resetCreditsSummaryState()
        if state.knownAccounts == 0 {
            return LocalizedText.value(.checkingAccounts, language: language)
        }
        if state.knownTotal == 0 {
            return state.hasError ? LocalizedText.value(.unavailable, language: language) : LocalizedText.value(.noAvailableResetCredits, language: language)
        }
        let suffix = state.hasError ? " plus unchecked accounts" : ""
            return "\(state.knownTotal) \(LocalizedText.value(.usageResetsTitle, language: language).lowercased())\(suffix)"
    }

    private func resetCreditAccountCard(_ account: CodexAccount, frame: NSRect) -> NSView {
        let snapshot = resetCreditsByEmail[account.email]
        let count = snapshot?.displayCount
        let countText: String
        if let count {
            countText = "\(count) \(LocalizedText.value(.usageResetsTitle, language: language).uppercased())"
        } else {
            countText = LocalizedText.value(.checkingAccounts, language: language).uppercased()
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
            card.addSubview(label(LocalizedText.value(.unavailable, language: language), frame: NSRect(x: 16, y: 64, width: frame.width - 32, height: 18), size: 12, weight: .semibold, color: NSColor.systemOrange))
            card.addSubview(label(error, frame: NSRect(x: 16, y: 86, width: frame.width - 32, height: 36), size: 10, weight: .medium, color: theme.secondaryText))
            return card
        }

        guard let snapshot else {
            card.addSubview(label(LocalizedText.value(.checkingResetCredits, language: language), frame: NSRect(x: 16, y: 72, width: frame.width - 32, height: 18), size: 11.5, weight: .semibold, color: theme.secondaryText))
            return card
        }

        let credits = sortedAvailableResetCredits(snapshot)
        if credits.isEmpty {
            card.addSubview(label(LocalizedText.value(.noAvailableResetCredits, language: language), frame: NSRect(x: 16, y: 72, width: frame.width - 32, height: 18), size: 11.5, weight: .semibold, color: theme.secondaryText))
            let updated = "\(LocalizedText.value(.updatedPrefix, language: language)) \(snapshot.lastUpdatedText)"
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

        let redeem = SettingsActionButton(frame: NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight), title: LocalizedText.value(.useResetButton, language: language), color: urgencyColor.withAlphaComponent(theme.isDark ? 0.42 : 0.22), textColor: urgencyColor)
        redeem.identifier = NSUserInterfaceItemIdentifier(resetCreditActionPayload(email: account.email, creditID: credit.id))
        redeem.target = self
        redeem.action = #selector(resetCreditRedeemPressed(_:))
        redeem.toolTip = LocalizedText.value(.redeemResetTooltip, language: language)
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

    private func settingsHeader(frame: NSRect) -> NSView {
        let header = FlippedContainerView(frame: frame)
        header.addSubview(label(LocalizedText.value(.settingsTitle, language: language), frame: NSRect(x: 2, y: 14, width: 160, height: 28), size: 24, weight: .bold, color: theme.primaryText))
        let back = SettingsActionButton(frame: NSRect(x: frame.width - 86, y: 13, width: 86, height: 30), title: LocalizedText.value(.backButton, language: language), color: theme.inactiveButtonFill, textColor: theme.primaryText)
        back.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.usageView.rawValue)
        back.target = self
        back.action = #selector(settingsActionPressed(_:))
        header.addSubview(back)
        return header
    }

    private func settingsSection(frame: NSRect, title: String) -> NSView {
        let section = RoundedPanelView(frame: frame, fillColor: cardFillColor(isActive: false), borderColor: cardBorderColor(isActive: false), cornerRadius: 18, shadowOpacity: 0.07, shadowRadius: 10)
        section.addSubview(label(title, frame: NSRect(x: 16, y: 12, width: frame.width - 32, height: 18), size: 12.5, weight: .bold, color: theme.primaryText))
        return section
    }

    private func healthSection(frame: NSRect) -> NSView {
        let section = settingsSection(frame: frame, title: LocalizedText.value(.healthSection, language: language))
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

        let switchTitle = account.isActive ? LocalizedText.value(.activeButton, language: language) : LocalizedText.value(.switchButtonShort, language: language)
        let switchButton = SettingsActionButton(frame: NSRect(x: frame.width - 150, y: 1, width: 58, height: 22), title: switchTitle, color: account.isActive ? NSColor.systemGreen : theme.inactiveButtonFill, textColor: account.isActive ? .white : theme.primaryText)
        switchButton.identifier = NSUserInterfaceItemIdentifier("switch|\(account.email)")
        switchButton.target = self
        switchButton.action = #selector(accountSettingsActionPressed(_:))
        switchButton.isEnabled = !account.isActive && !isSwitching
        row.addSubview(switchButton)

        let labelButton = SettingsActionButton(frame: NSRect(x: frame.width - 84, y: 1, width: 40, height: 22), title: LocalizedText.value(.labelButton, language: language), color: theme.bottomBarFill, textColor: theme.primaryText)
        labelButton.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.editLabels.rawValue)
        labelButton.target = self
        labelButton.action = #selector(settingsActionPressed(_:))
        row.addSubview(labelButton)

        let removeButton = SettingsActionButton(frame: NSRect(x: frame.width - 38, y: 1, width: 38, height: 22), title: LocalizedText.value(.deleteButtonShort, language: language), color: theme.bottomBarFill, textColor: NSColor.systemRed)
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
            button.setAccessibilityLabel(option.0)
            button.setAccessibilityValue(option.1)
            row.addSubview(button)
        }
        return row
    }

    private func settingToggleRow(title: String, detail: String, isOn: Bool, action: SettingsPanelAction, frame: NSRect) -> NSView {
        let row = FlippedContainerView(frame: frame)
        row.addSubview(label(title, frame: NSRect(x: 0, y: 1, width: frame.width - 52, height: 16), size: 11.5, weight: .semibold, color: theme.primaryText))
        row.addSubview(label(detail, frame: NSRect(x: 0, y: 18, width: frame.width - 52, height: 14), size: 9.5, weight: .medium, color: theme.secondaryText))
        let toggle = MiniSwitchButton(frame: NSRect(x: frame.width - 40, y: 6, width: 38, height: 24), isOn: isOn, offColor: theme.switchOffFill)
        toggle.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
        toggle.target = self
        toggle.action = #selector(settingsActionPressed(_:))
        row.addSubview(toggle)
        return row
    }

    private func settingsFooter(frame: NSRect) -> NSView {
        let footer = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 18, shadowOpacity: 0.06)
        let actions: [(String, SettingsPanelAction)] = [
            (LocalizedText.value(.settingsAddAccount, language: language), .addAccount),
            (LocalizedText.value(.settingsReminder, language: language), .editUsageReminder),
            (LocalizedText.value(.settingsRefreshRate, language: language), .editRefresh),
            (LocalizedText.value(.settingsCheckUpdate, language: language), .checkUpdates),
            (LocalizedText.value(.settingsSavePlugins, language: language), .saveReferencePlugins),
            (LocalizedText.value(.diagnosticsButton, language: language), .diagnostics)
        ]
        let inset: CGFloat = 10
        let gap: CGFloat = 8
        let buttonWidth = (frame.width - (inset * 2) - (gap * 2)) / 3
        for (index, action) in actions.enumerated() {
            let column = index % 3
            let row = index / 3
            let x = inset + CGFloat(column) * (buttonWidth + gap)
            let y = 8 + CGFloat(row) * 32
            let button = SettingsActionButton(frame: NSRect(x: x, y: y, width: buttonWidth, height: 26), title: action.0, color: theme.inactiveButtonFill, textColor: theme.primaryText)
            button.identifier = NSUserInterfaceItemIdentifier(action.1.rawValue)
            button.target = self
            button.action = #selector(settingsActionPressed(_:))
            footer.addSubview(button)
        }
        return footer
    }

    private func makeHeader() -> NSView {
        let view = FlippedContainerView(frame: NSRect(x: 0, y: 0, width: 520, height: 88))

        let icon = CircleIconView(frame: NSRect(x: 38, y: 24, width: 42, height: 42), color: .systemIndigo, symbol: "chevron.left.forwardslash.chevron.right")
        view.addSubview(icon)

        let title = label("Codex Control", frame: NSRect(x: 98, y: 23, width: 250, height: 28), size: 22, weight: .semibold, color: .white.withAlphaComponent(0.94))
        view.addSubview(title)

        let subtitleText = activeAccount.map { LocalizedText.activeAccount(labelForAccount($0), language: language) } ?? (lastError ?? LocalizedText.value(.noActiveAccount, language: language))
        let subtitle = label(subtitleText, frame: NSRect(x: 99, y: 52, width: 260, height: 19), size: 13, weight: .medium, color: activeAccount == nil ? .systemOrange : .white.withAlphaComponent(0.58))
        subtitle.lineBreakMode = .byTruncatingTail
        view.addSubview(subtitle)

        let refreshButton = iconButton(symbol: "arrow.clockwise", frame: NSRect(x: 377, y: 29, width: 32, height: 32), action: #selector(refreshPressed), toolTip: "Refresh usage for all saved accounts")
        view.addSubview(refreshButton)

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: 421, y: 28, width: 34, height: 34), action: #selector(settingsPressed(_:)), toolTip: "Open settings")
        view.addSubview(settingsButton)

        let closeButton = iconButton(symbol: "xmark", frame: NSRect(x: 465, y: 29, width: 32, height: 32), action: #selector(closePressed), toolTip: "Quit Account Switcher")
        view.addSubview(closeButton)

        return view
    }

    private func accountListRowContent(_ account: CodexAccount, displayIndex: Int, frame: NSRect) -> NSView {
        let isArmed = armedSwitchEmail == account.email && !account.isActive
        let content = AccountRowView(
            account: account,
            displayIndex: displayIndex,
            isArmed: isArmed,
            language: language,
            theme: theme,
            warmupState: warmupStates[account.email],
            onCancel: { [weak self] in self?.cancelSwitchConfirmation() },
            onSwitch: { [weak self] in self?.switchAccount(account.email) }
        )
        return AccountRowHostingView(
            frame: frame,
            rootView: content,
            passesGesturesToTable: !isArmed
        )
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

    private func usageEmptyStateCard(frame: NSRect) -> NSView {
        emptyStateCard(
            frame: frame,
            title: LocalizedText.value(.noAccountsTitle, language: language),
            detail: LocalizedText.value(.noAccountsDetail, language: language),
            settingsTitle: LocalizedText.value(.settingsButton, language: language),
            refreshTitle: LocalizedText.value(.refreshButton, language: language)
        )
    }

    private func emptyStateCard(frame: NSRect) -> NSView {
        emptyStateCard(
            frame: frame,
            title: "No accounts available",
            detail: "Open settings to add an account.",
            settingsTitle: "Settings",
            refreshTitle: "Refresh"
        )
    }

    private func emptyStateCard(
        frame: NSRect,
        title: String,
        detail: String,
        settingsTitle: String,
        refreshTitle: String
    ) -> NSView {
        let card = RoundedPanelView(frame: frame, fillColor: cardFillColor(isActive: false), borderColor: cardBorderColor(isActive: false))
        card.addSubview(label(title, frame: NSRect(x: 22, y: 28, width: 240, height: 24), size: 18, weight: .semibold, color: theme.primaryText))
        card.addSubview(label(lastError ?? detail, frame: NSRect(x: 22, y: 62, width: 276, height: 40), size: 12, weight: .medium, color: theme.secondaryText))
        let settingsButton = SettingsActionButton(frame: NSRect(x: 22, y: 118, width: 92, height: 28), title: settingsTitle, color: theme.inactiveButtonFill, textColor: theme.primaryText)
        settingsButton.target = self
        settingsButton.action = #selector(settingsPressedFromEmptyState)
        card.addSubview(settingsButton)

        let refreshButton = SettingsActionButton(frame: NSRect(x: 126, y: 118, width: 86, height: 28), title: refreshTitle, color: theme.bottomBarFill, textColor: theme.primaryText)
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

    // MARK: - Reset chance section

    private func resetChanceSection(frame: NSRect) -> NSView {
        let card = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 16, clickAction: {
            guard let url = URL(string: "https://codex-reset.com") else { return }
            NSWorkspace.shared.open(url)
        })
        let iconSize: CGFloat = 16
        let icon = SymbolIconView(frame: NSRect(x: 14, y: (frame.height - iconSize) / 2, width: iconSize, height: iconSize), symbol: "bolt.fill", color: NSColor.systemYellow.withAlphaComponent(0.9))
        card.addSubview(icon)
        card.addSubview(label(LocalizedText.value(.resetChanceTitle, language: language), frame: NSRect(x: 40, y: (frame.height - 17) / 2, width: 190, height: 17), size: 12, weight: .bold, color: theme.primaryText))

        let first = resetChance.map { "24h \($0.rounded24h)%" } ?? "—"
        let second = resetChance.map { "48h \($0.rounded48h)%" } ?? "—"
        let secondWidth: CGFloat = 64
        let secondX = frame.width - 16 - secondWidth
        let firstWidth: CGFloat = 68
        let firstX = secondX - 10 - firstWidth
        let valueY = (frame.height - 17) / 2
        card.addSubview(label(first, frame: NSRect(x: firstX, y: valueY, width: firstWidth, height: 17), size: 12, weight: .medium, color: theme.secondaryText, alignment: .right))
        card.addSubview(label(second, frame: NSRect(x: secondX, y: valueY, width: secondWidth, height: 17), size: 12, weight: .semibold, color: theme.primaryText, alignment: .right))

        let divider = NSView(frame: NSRect(x: secondX - 6, y: 10, width: 1, height: frame.height - 20))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = theme.divider.cgColor
        card.addSubview(divider)
        return card
    }

    // MARK: - Pool pace section

    private func paceSection(_ state: PaceDisplayState, frame: NSRect) -> NSView {
        let container = NSView(frame: frame)
        let chart = NSHostingView(rootView: PoolPaceChartView(data: paceChartData(state)))
        chart.frame = NSRect(x: 2, y: 0, width: frame.width - 4, height: frame.height)
        container.addSubview(chart)
        return container
    }

    private func pacePresentation(_ state: PaceDisplayState) -> PoolVerdictPresentation {
        PoolVerdictPresenter.make(forecast: state.forecast, language: language, now: state.now)
    }

    private func verdictSection(_ state: PaceDisplayState, frame: NSRect) -> NSView {
        PoolVerdictCardView(frame: frame, presentation: pacePresentation(state), theme: theme)
    }

    private func paceChartData(_ state: PaceDisplayState) -> PoolPaceChartData {
        return PoolPaceChartData(
            points: DailyPoolSpendAggregator.dailyPoints(from: state.history, now: state.now),
            gridLine: Color(theme.divider),
            labelText: Color(theme.secondaryText),
            language: language
        )
    }

    private func bottomBar(frame: NSRect) -> NSView {
        let bar = RoundedPanelView(frame: frame, fillColor: theme.bottomBarFill, borderColor: theme.inactiveCardBorder, cornerRadius: 16)
        let toolbarInset: CGFloat = 12
        let iconSize: CGFloat = 28
        let iconY = (frame.height - iconSize) / 2

        let settingsButton = iconButton(symbol: "gearshape", frame: NSRect(x: toolbarInset, y: iconY, width: iconSize, height: iconSize), action: #selector(settingsPressed(_:)), toolTip: LocalizedText.value(.settingsTooltip, language: language), pointSize: 17)
        bar.addSubview(settingsButton)

        let addX: CGFloat = 46
        let addWidth: CGFloat = 68
        let addButton = SettingsActionButton(frame: NSRect(x: addX, y: 7, width: addWidth, height: 26), title: LocalizedText.value(.addButton, language: language), color: theme.inactiveButtonFill, textColor: theme.primaryText)
        addButton.target = self
        addButton.action = #selector(addAccountPressed(_:))
        addButton.toolTip = LocalizedText.value(.addTooltip, language: language)
        bar.addSubview(addButton)

        let leftDividerX = addX + addWidth + 9
        let leftDivider = NSView(frame: NSRect(x: leftDividerX, y: 9, width: 1, height: frame.height - 18))
        leftDivider.wantsLayer = true
        leftDivider.layer?.backgroundColor = theme.divider.cgColor
        bar.addSubview(leftDivider)

        let quitWidth = CGFloat(UsagePanelLayoutMetrics.quitButtonWidth)
        let refreshWidth = CGFloat(UsagePanelLayoutMetrics.refreshButtonWidth)
        let actionButtonHeight = CGFloat(UsagePanelLayoutMetrics.footerButtonHeight)
        let actionButtonY = (frame.height - actionButtonHeight) / 2
        let quitX = frame.width - toolbarInset - quitWidth
        let refreshX = quitX - 8 - refreshWidth
        let rightDividerX = refreshX - 10
        let resetWidth: CGFloat = 94
        let resetX = rightDividerX - resetWidth - 10
        let warmupX = leftDividerX + 8
        let warmupButton = SettingsActionButton(frame: NSRect(x: warmupX, y: actionButtonY, width: resetX - warmupX - 8, height: actionButtonHeight), title: LocalizedText.value(isWarmingUp ? .warmupRunning : .warmupButton, language: language), color: theme.inactiveButtonFill, textColor: theme.primaryText)
        warmupButton.identifier = NSUserInterfaceItemIdentifier(SettingsPanelAction.warmupLimits.rawValue)
        warmupButton.target = self
        warmupButton.action = #selector(settingsActionPressed(_:))
        warmupButton.toolTip = LocalizedText.value(.warmupTooltip, language: language) + " • " + lastUpdatedText
        warmupButton.setAccessibilityLabel(LocalizedText.value(.warmupButton, language: language))
        warmupButton.isEnabled = !isWarmingUp && !isSwitching && !accounts.isEmpty
        bar.addSubview(warmupButton)

        let resetButton = SettingsActionButton(frame: NSRect(x: resetX, y: 7, width: resetWidth, height: 26), title: resetCreditsButtonTitle(), color: resetCreditsButtonColor(), textColor: resetCreditsButtonTextColor())
        resetButton.target = self
        resetButton.action = #selector(resetCreditsPressed(_:))
        resetButton.toolTip = resetCreditsTooltip()
        bar.addSubview(resetButton)

        let refreshButton = SettingsActionButton(frame: NSRect(x: refreshX, y: actionButtonY, width: refreshWidth, height: actionButtonHeight), title: LocalizedText.value(.refreshButton, language: language), color: theme.inactiveButtonFill, textColor: theme.primaryText)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressed)
        refreshButton.toolTip = LocalizedText.value(.refreshTooltip, language: language)
        bar.addSubview(refreshButton)

        let rightDivider = NSView(frame: NSRect(x: rightDividerX, y: 9, width: 1, height: frame.height - 18))
        rightDivider.wantsLayer = true
        rightDivider.layer?.backgroundColor = theme.divider.cgColor
        bar.addSubview(rightDivider)

        let quitFill = NSColor.systemRed.withAlphaComponent(quitConfirmationArmed ? 0.72 : (theme.isDark ? 0.22 : 0.14))
        let quitText = quitConfirmationArmed ? NSColor.white : NSColor.systemRed
        let quitButton = SettingsActionButton(frame: NSRect(x: quitX, y: actionButtonY, width: quitWidth, height: actionButtonHeight), title: LocalizedText.value(quitConfirmationArmed ? .quitConfirmButton : .quitButton, language: language), color: quitFill, textColor: quitText)
        quitButton.target = self
        quitButton.action = #selector(closePressed)
        quitButton.toolTip = LocalizedText.value(.quitTooltip, language: language)
        bar.addSubview(quitButton)
        return bar
    }

    private func resetCreditsButtonTitle() -> String {
        let state = resetCreditsSummaryState()
        return LocalizedText.resetCreditsButtonTitle(
            knownTotal: state.knownTotal,
            knownAccounts: state.knownAccounts,
            hasError: state.hasError,
            language: language
        )
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
        return LocalizedText.resetCreditsTooltip(
            knownTotal: state.knownTotal,
            knownAccounts: state.knownAccounts,
            hasError: state.hasError,
            language: language
        )
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

    private func statusBarColor(for remaining: Int?) -> NSColor {
        guard let remaining else {
            return theme.secondaryText.withAlphaComponent(0.6)
        }
        if remaining >= 90 {
            return theme.isDark ? NSColor.warmWhite : NSColor(white: 0.22, alpha: 1)
        }
        if remaining > 50 {
            return .warmGreen
        }
        if remaining > 10 {
            return .warmAmber
        }
        return .warmRed
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
        isActive ? NSColor.meterBlue.withAlphaComponent(theme.isDark ? 0.55 : 0.42) : theme.inactiveCardBorder
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

    private func iconButton(symbol: String, frame: NSRect, action: Selector, toolTip: String? = nil, pointSize: CGFloat = 18) -> NSButton {
        let button = NSButton(frame: frame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
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

    @objc private func addAccountPressed(_ sender: NSButton) {
        performSettingsAction(.addAccount)
    }

    @objc private func closePressed() {
        close()
    }

    @objc private func launchAtLoginPressed() {
        toggleLaunchAtLogin()
    }

    @objc private func settingsActionPressed(_ sender: NSControl) {
        guard let rawValue = sender.identifier?.rawValue else { return }
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

final class AccountFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @MainActor UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let languageStore = AppLanguagePreferenceStore()
    private var accountPanel: NSPanel?
    private var accountPanelMode: AccountPanelMode = .usage
    private let timerTickInterval: TimeInterval = 5
    private let labelsDefaultsKey = "accountDisplayLabels"
    private let remindersEnabledDefaultsKey = "usageReminderEnabled"
    private let creditExpiryNotificationsDefaultsKey = "creditExpiryNotificationsEnabled"
    private let creditExpiryLeadDaysDefaultsKey = "creditExpiryLeadDays"
    private let creditExpiryFingerprintDefaultsKey = "resetCreditExpiryFingerprints"
    private let creditExpiryFingerprintLimit = 64
    private let reminderThresholdDefaultsKey = "usageReminderThreshold"
    private let autoSwitchEnabledDefaultsKey = "autoSwitchEnabled"
    private let autoSwitchThresholdDefaultsKey = "autoSwitchThreshold"
    private let autoSwitchModeDefaultsKey = "autoSwitchMode"
    private let refreshIntervalDefaultsKey = "refreshIntervalSeconds"
    private let idleRefreshIntervalDefaultsKey = "idleRefreshIntervalSeconds"
    private let protectFrontmostCodexDefaultsKey = "protectFrontmostCodex"
    private let resetHistoryDefaultsKey = "resetHistoryV1"
    private let autoSwitchNotificationCategory = "AUTO_SWITCH_CONFIRM"
    private let switchNowActionIdentifier = "SWITCH_NOW"
    private let launchAgentIdentifier = "com.mohamedfuad.codexaccountswitcher"
    private let switchHistoryDefaultsKey = "switchHistoryV1"
    private let lastSwitchDateDefaultsKey = "lastSuccessfulSwitchDate"
    private let switchCooldown: TimeInterval = 90
    private let resetCreditsRefreshInterval: TimeInterval = 300
    private let directUsageRefreshInterval: TimeInterval = 30
    private let resetChanceRefreshInterval: TimeInterval = 15 * 60
    private let poolSamplingInterval: TimeInterval = 30 * 60
    private let loginExpiredCooldownDefaultsKey = "loginExpiredNotificationCooldowns"
    private let loginExpiredNotificationCooldown: TimeInterval = 6 * 60 * 60
    private let refreshInFlightLock = NSLock()
    private var refreshInFlightEmails: Set<String> = []
    private var refreshTimer: Timer?
    private var poolSamplingTimer: Timer?
    private var lastPoolSampleAt: Date?
    private var currentStatusTitleKey = ""
    private var currentStatusItemLength: CGFloat = 0
    private var accounts: [CodexAccount] = []
    private var lastError: String?
    private var lastUpdatedAt: Date?
    private var lastRefreshStartedAt: Date?
    private var refreshGeneration = 0
    private var lastResetCreditsRefreshAt: Date?
    private var lastDirectUsageRefreshAt: Date?
    private var resetChanceForecast: ResetChanceForecast?
    private var resetChanceFetchedAt: Date?
    private var resetChanceTask: Task<Void, Never>?
    private var isRefreshing = false
    private var isRefreshingResetCredits = false
    private var pendingForceRefresh = false
    private var isSwitching = false
    private var isWarmingUp = false
    private var warmupStates: [String: LimitWarmupState] = [:]
    private var warmupStatusClearTask: Task<Void, Never>?
    private var isRedeemingReset = false
    private var resetStatusText: String?
    private var directUsageSnapshotsByEmail: [String: DirectUsageSnapshot] = [:]
    private var armedSwitchEmail: String?
    private var armedSwitchClearWorkItem: DispatchWorkItem?
    private var quitConfirmationArmed = false
    private var quitConfirmationClearWorkItem: DispatchWorkItem?
    private var switchAnimationTimer: Timer?
    private var switchAnimationFrame = 0
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var didResignActiveObserver: NSObjectProtocol?
    private var suppressStatusToggleOpenUntil: Date?
    private var panelRefreshScheduled = false
    private var statusAnimationTitle = "Switching"
    private var statusAnimationGeneration = 0
    private let switchAnimationFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var notifiedLowUsageKeys = Set<String>()
    private var notifiedAutoSwitchPauseKeys = Set<String>()
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
    private var creditExpiryNotificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: creditExpiryNotificationsDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: creditExpiryNotificationsDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: creditExpiryNotificationsDefaultsKey)
        }
    }

    private var creditExpiryLeadDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: creditExpiryLeadDaysDefaultsKey)
            return stored == 0
                ? SettingsNumericPolicy.creditExpiryLeadDaysDefault
                : min(max(stored, SettingsNumericPolicy.creditExpiryLeadDaysRange.lowerBound), SettingsNumericPolicy.creditExpiryLeadDaysRange.upperBound)
        }
        set {
            UserDefaults.standard.set(
                min(max(newValue, SettingsNumericPolicy.creditExpiryLeadDaysRange.lowerBound), SettingsNumericPolicy.creditExpiryLeadDaysRange.upperBound),
                forKey: creditExpiryLeadDaysDefaultsKey
            )
        }
    }

    private var creditExpiryWindow: TimeInterval {
        SettingsNumericPolicy.creditExpiryInterval(leadDays: creditExpiryLeadDays)
    }

    private var creditExpiryFingerprints: [String] {
        get { UserDefaults.standard.stringArray(forKey: creditExpiryFingerprintDefaultsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: creditExpiryFingerprintDefaultsKey) }
    }

    private var reminderThreshold: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: reminderThresholdDefaultsKey)
            return stored == 0 ? SettingsNumericPolicy.reminderThresholdDefault : max(SettingsNumericPolicy.reminderThresholdRange.lowerBound, min(SettingsNumericPolicy.reminderThresholdRange.upperBound, stored))
        }
        set {
            UserDefaults.standard.set(max(SettingsNumericPolicy.reminderThresholdRange.lowerBound, min(SettingsNumericPolicy.reminderThresholdRange.upperBound, newValue)), forKey: reminderThresholdDefaultsKey)
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
    private var demoMode: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO"] == "1"
    }
    private var showPanelOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_PANEL"] == "1"
    }
    private var showSettingsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_SETTINGS"] == "1"
    }
    private var showResetsOnLaunch: Bool {
        ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_SHOW_RESETS"] == "1"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        if ProcessInfo.processInfo.arguments.contains("--restore-reference-plugins") {
            var transcript: [String] = []
            if let reference = ReferencePluginStore.load(storeDirectory: referencePluginStoreDirectory()),
               applyReferencePlugins(reference, transcript: &transcript) {
            } else if ReferencePluginStore.load(storeDirectory: referencePluginStoreDirectory()) == nil {
                transcript.append("Reference plugins are not saved or the saved reference is invalid.")
            }
            FileHandle.standardOutput.write(Data("\(transcript.joined(separator: "\n"))\n".utf8))
            NSApp.terminate(nil)
            return
        }
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
            } else if showSettingsOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.showSettingsPanel()
                }
            }
        }
        let timer = Timer(timeInterval: timerTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAccountsIfNeeded() }
        }
        RunLoop.current.add(timer, forMode: .common)
        refreshTimer = timer

        // Quiet pool history sampling: one wham/usage pass every 30 minutes so
        // the pace chart accumulates data even while the panel stays closed.
        let poolTimer = Timer(timeInterval: poolSamplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.runQuietPoolSampling() }
        }
        RunLoop.current.add(poolTimer, forMode: .common)
        poolSamplingTimer = poolTimer

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
            Task { @MainActor in
                guard let self else { return }
                if self.accountPanel?.isVisible == true, self.mouseIsOverStatusButton() {
                    self.suppressStatusToggleOpenUntil = Date().addingTimeInterval(0.5)
                }
                self.closeAccountPanel()
            }
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
        center.setNotificationCategories([switchCategory])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshNotificationHealth(rebuildVisiblePanel: true) }
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
        guard !isSwitching, !isRedeemingReset else { return }
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
        refreshGeneration += 1
        let refreshGeneration = self.refreshGeneration
        lastRefreshStartedAt = Date()
        let shouldRefreshResets = !isRefreshingResetCredits && ResetRefreshPolicy.shouldRefresh(
            lastRefresh: lastResetCreditsRefreshAt,
            ttl: resetCreditsRefreshInterval,
            force: force
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
                guard self.refreshGeneration == refreshGeneration else { return }
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
                // Fresh wham/usage data counts as a pool sample too — the panel
                // is open right now, so capture the moment.
                if completedResult.status == 0, !directUsageResults.isEmpty {
                    self.samplePoolHistory(from: directUsageResults)
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
                    self.rebuildMenu()
                }

                if self.pendingForceRefresh {
                    self.pendingForceRefresh = false
                    self.refreshAccounts(force: true)
                }
                }
            }
        }
    }

    // MARK: - Pool pace sampling

    /// Records one pool-wide sample from freshly fetched wham/usage data.
    /// Accounts that failed to fetch are left out; the sample keeps `n` equal
    /// to the accounts that actually responded, so the pool average stays
    /// normalized when the pool composition changes.
    private func samplePoolHistory(from snapshots: [String: DirectUsageSnapshot], now: Date = Date()) {
        guard let sample = PoolHistorySample.makeLive(snapshots: snapshots, now: now) else { return }
        let url = PoolHistoryStore.fileURL()
        let history = PoolHistoryStore.load(from: url)
        let average = PoolHistoryStore.poolAverage(n: sample.n, poolTotal: sample.poolTotal)
        guard PoolHistoryStore.shouldRecord(lastSample: history.last, poolAverage: average, now: now) else {
            return
        }
        do {
            try PoolHistoryStore.write(history + [sample], to: url, now: now)
        } catch {
            NSLog("Codex Account Switcher pool-history write failed: %@", error.localizedDescription)
            return
        }
        lastPoolSampleAt = now
        if accountPanel?.isVisible == true {
            refreshAccountPanelContent()
            positionAccountPanel()
        }
    }

    /// Quiet background sampling: refetches pool usage and writes a sample with
    /// no UI impact. Skips when no accounts exist, while a switch/reset is in
    /// flight, or when a sample already landed within the last 25 minutes
    /// (coalesces with the manual refresh path).
    private func runQuietPoolSampling() {
        guard !demoMode, !accounts.isEmpty, !isSwitching, !isRedeemingReset else { return }
        let coalesceWindow = poolSamplingInterval - 5 * 60
        if let last = lastPoolSampleAt, Date().timeIntervalSince(last) < coalesceWindow {
            return
        }
        let poolAccounts = accounts
        Task {
            let snapshots = await self.fetchDirectUsageForRefresh(accounts: poolAccounts, shouldRefresh: true)
            guard !snapshots.isEmpty else { return }
            await MainActor.run {
                self.samplePoolHistory(from: snapshots)
            }
        }
    }

    /// Current pool display state for the panel, evaluated from one instant.
    private func poolPaceState(now: Date) -> PaceDisplayState? {
        guard !accounts.isEmpty else { return nil }
        var history = PoolHistoryStore.load()
        if let liveSample = PoolHistorySample.makeCurrent(
            accounts: accounts,
            snapshots: directUsageSnapshotsByEmail,
            now: now
        ) {
            history.append(liveSample)
        }
        guard !history.isEmpty else {
            return PaceDisplayState(
                history: [],
                now: now,
                forecast: .collecting(historyDays: 0, accountCount: accounts.count)
            )
        }
        let forecast = PoolSufficiencyForecaster.forecast(samples: history, now: now)
        return PaceDisplayState(
            history: history,
            now: now,
            forecast: forecast
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let language = languageStore.load()

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

        menu.addItem(headerItem("Updated: \(lastUpdatedText(language: .english))"))
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

        let toggle = NSMenuItem(title: LocalizedText.value(.toggleAccount, language: language), action: #selector(toggleAccount), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = accounts.count == 2 && !isSwitching
        menu.addItem(toggle)

        menu.addItem(.separator())

        let addAccount = NSMenuItem(title: LocalizedText.value(.addAccountMenu, language: language), action: #selector(addAccountBrowser), keyEquivalent: "")
        addAccount.target = self
        addAccount.isEnabled = !isSwitching
        menu.addItem(addAccount)

        if !accounts.isEmpty {
            let labelsItem = NSMenuItem(title: LocalizedText.value(.accountLabelsMenu, language: language), action: #selector(showAccountDisplayLabelsDialog), keyEquivalent: "")
            labelsItem.target = self
            menu.addItem(labelsItem)

            let displayItem = NSMenuItem(title: LocalizedText.value(.menuBarDisplayMenu, language: language), action: #selector(showMenuBarDisplayDialog), keyEquivalent: "")
            displayItem.target = self
            menu.addItem(displayItem)

            let removeItem = NSMenuItem(title: LocalizedText.value(.removeAccountMenu, language: language), action: #selector(showRemoveAccountDialog), keyEquivalent: "")
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

        let refresh = NSMenuItem(title: LocalizedText.value(.forceRefreshMenu, language: language), action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self
        refresh.toolTip = "Refreshes live usage for all saved accounts."
        refresh.isEnabled = !isSwitching
        menu.addItem(refresh)

        let updates = NSMenuItem(title: LocalizedText.value(.checkUpdatesMenu, language: language), action: #selector(checkForUpdatesMenu), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let cleanBackups = NSMenuItem(title: LocalizedText.value(.cleanBackupsMenu, language: language), action: #selector(cleanAccountBackups), keyEquivalent: "")
        cleanBackups.target = self
        cleanBackups.isEnabled = !isSwitching
        menu.addItem(cleanBackups)

        let quit = NSMenuItem(title: LocalizedText.value(.quitAppMenu, language: language), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quit)

        settingsMenu = menu
        statusItem.menu = nil
        if accountPanel?.isVisible == true {
            refreshAccountPanelContentIfVisible()
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
        refreshResetChanceIfNeeded()
        let panel = accountPanel ?? makeAccountPanel()
        accountPanel = panel
        refreshAccountPanelContent()
        positionAccountPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        refreshAccounts(force: true)
    }

    /// Fetches the global reset-chance forecast at most once per 15 minutes.
    /// A successful response replaces the cached forecast; a failure keeps the
    /// previous cache (or leaves the panel showing "—" when there is none).
    private func refreshResetChanceIfNeeded() {
        if let fetchedAt = resetChanceFetchedAt,
           Date().timeIntervalSince(fetchedAt) < resetChanceRefreshInterval {
            return
        }
        guard resetChanceTask == nil else { return }
        resetChanceTask = Task { [weak self] in
            guard let self else { return }
            let result = await Self.performResetChanceFetch()
            await MainActor.run {
                self.resetChanceTask = nil
                if case .success(let forecast) = result {
                    self.resetChanceForecast = forecast
                    self.resetChanceFetchedAt = Date()
                }
                if self.accountPanel?.isVisible == true, self.accountPanelMode == .usage {
                    self.refreshAccountPanelContent()
                    self.positionAccountPanel()
                }
            }
        }
    }

    private nonisolated static func performResetChanceFetch() async -> ResetChanceFetchResult {
        let primaryResult: ResetChanceFetchResult
        do {
            let payload = try await CodexHTTPClient.send(ResetChanceClient.makeRequest(), retries: 1)
            primaryResult = ResetChanceClient.parseResponse(data: payload.data, statusCode: payload.statusCode)
        } catch {
            primaryResult = .failure(error.localizedDescription)
        }
        if case .success = primaryResult {
            return primaryResult
        }

        if case .failure(let message) = primaryResult {
            NSLog("Reset chance primary fetch failed: %@", message)
        }
        let fallback = ProcessRunner.run(
            "/usr/bin/curl",
            [
                "--fail",
                "--silent",
                "--show-error",
                "--http1.1",
                "--max-time",
                "15",
                ResetChanceClient.endpoint.absoluteString
            ],
            environment: ProcessInfo.processInfo.environment,
            timeout: 20
        )
        let fallbackResult = ResetChanceClient.parseCommandResult(fallback)
        if case .failure(let message) = fallbackResult {
            NSLog("Reset chance fallback fetch failed: %@", message)
        }
        return fallbackResult
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

    private func commitReminderThreshold(_ draft: String) -> Bool {
        guard case .success(let value) = SettingsNumericPolicy.normalizedInteger(draft, within: SettingsNumericPolicy.reminderThresholdRange) else { return false }
        reminderThreshold = value
        rebuildMenu()
        return true
    }

    private func commitCreditExpiryLeadDays(_ draft: String) -> Bool {
        guard case .success(let value) = SettingsNumericPolicy.normalizedInteger(draft, within: SettingsNumericPolicy.creditExpiryLeadDaysRange) else { return false }
        creditExpiryLeadDays = value
        checkCreditExpiryNotifications()
        rebuildMenu()
        return true
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
        AccountSwitcherPanelView.preferredSize(
            mode: accountPanelMode,
            accountCount: toolbarAccounts().count,
            showsPace: !accounts.isEmpty,
            maximumHeight: maximumAccountPanelHeight()
        )
    }

    private func maximumAccountPanelHeight() -> CGFloat {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        return max(260, (screen?.visibleFrame.height ?? 800) - 16)
    }

    private func refreshAccountPanelContent(shouldRefreshNotificationHealth: Bool = true) {
        let now = Date()
        let paceState = poolPaceState(now: now)
        if shouldRefreshNotificationHealth {
            refreshNotificationHealth()
        }
        let language = languageStore.load()
        let panel = AccountSwitcherPanelView(
            accounts: toolbarAccounts(),
            warmupStates: warmupStates,
            isWarmingUp: isWarmingUp,
            activeAccount: accounts.first(where: { $0.isActive }),
            mode: accountPanelMode,
            language: language,
            lastUpdatedText: lastUpdatedText(language: language),
            lastError: lastError,
            isSwitching: isSwitching,
            launchAtLoginEnabled: launchAtLoginEnabled(),
            remindersEnabled: remindersEnabled,
            creditExpiryNotificationsEnabled: creditExpiryNotificationsEnabled,
            reminderThreshold: reminderThreshold,
            creditExpiryLeadDays: creditExpiryLeadDays,
            autoSwitchEnabled: autoSwitchEnabled,
            autoSwitchThreshold: autoSwitchThreshold,
            autoSwitchMode: autoSwitchMode,
            armedSwitchEmail: armedSwitchEmail,
            quitConfirmationArmed: quitConfirmationArmed,
            protectFrontmostCodex: protectFrontmostCodex,
            resetCreditsByEmail: resetCreditsByEmail,
            healthStatuses: healthStatusRows(),
            usageMode: usageMode,
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
            removeAccountRequested: { [weak self] email in
                self?.removeAccountFromRowAction(email: email)
            },
            cancelSwitchConfirmation: { [weak self] in
                self?.clearArmedSwitch()
                self?.refreshAccountPanelContentIfVisible()
            },
            refresh: { [weak self] in
                self?.refreshResetChanceIfNeeded()
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
            performSettingsAction: { [weak self] action in
                self?.handleSettingsPanelAction(action)
            },
            close: { [weak self] in
                self?.handleQuitRequest()
            },
            toggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            },
            commitReminderThreshold: { [weak self] draft in
                self?.commitReminderThreshold(draft) ?? false
            },
            commitCreditExpiryLeadDays: { [weak self] draft in
                self?.commitCreditExpiryLeadDays(draft) ?? false
            },
            updateActiveRefreshInterval: { [weak self] seconds in
                self?.activeRefreshInterval = seconds
                self?.rebuildMenu()
            },
            updateIdleRefreshInterval: { [weak self] seconds in
                self?.idleRefreshInterval = seconds
                self?.rebuildMenu()
            },
            pace: paceState,
            resetChance: resetChanceForecast,
            maximumPanelHeight: maximumAccountPanelHeight()
        )
        let controller = NSViewController()
        controller.view = panel
        accountPanel?.contentViewController = controller
        if accountPanel?.isVisible == true {
            positionAccountPanel()
        }
    }

    private func handlePanelSwitchRequest(_ email: String) {
        let target = accounts.first { $0.email == email || $0.selector == email }
        let decision = InlineSwitchConfirmationPolicy.decision(
            armedEmail: armedSwitchEmail,
            requestedEmail: email,
            isActive: target?.isActive ?? false,
            isSwitching: isSwitching
        )
        switch decision {
        case .ignore:
            return
        case .arm:
            armSwitchConfirmation(for: email)
        case .confirm:
            clearArmedSwitch()
            closeAccountPanel()
            switchTo(query: email)
        }
    }

    private func removeAccountFromRowAction(email: String) {
        guard let account = accounts.first(where: { $0.email == email }),
              let arguments = AccountRemovalPolicy.arguments(
                email: account.email,
                isActive: account.isActive
              ) else {
            return
        }
        runAccountMaintenance(title: "Removing account", args: arguments)
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

    private func handleQuitRequest() {
        switch InlineQuitConfirmationPolicy.decision(isArmed: quitConfirmationArmed) {
        case .arm:
            clearArmedSwitch()
            armQuitConfirmation()
        case .confirm:
            clearQuitConfirmation()
            NSApp.terminate(nil)
        }
    }

    private func armQuitConfirmation() {
        quitConfirmationClearWorkItem?.cancel()
        quitConfirmationArmed = true
        refreshAccountPanelContentIfVisible()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.quitConfirmationArmed else { return }
            self.quitConfirmationArmed = false
            self.quitConfirmationClearWorkItem = nil
            self.refreshAccountPanelContentIfVisible()
        }
        quitConfirmationClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    private func clearQuitConfirmation() {
        quitConfirmationClearWorkItem?.cancel()
        quitConfirmationClearWorkItem = nil
        quitConfirmationArmed = false
    }

    private func healthStatusRows() -> [HealthStatus] {
        let codexAuthOK = codexAuthPath() != nil
        let codexAppOK = FileManager.default.fileExists(atPath: codexDesktopAppPath)
        return [
            HealthStatus(title: "Auth", value: codexAuthOK ? "OK" : "Missing", color: codexAuthOK ? .systemGreen : .systemRed),
            HealthStatus(title: "Codex", value: codexAppOK ? "Found" : "Missing", color: codexAppOK ? .systemGreen : .systemRed),
            HealthStatus(title: "Refresh", value: lastUpdatedText(language: .english), color: refreshHealthColor()),
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
        clearQuitConfirmation()
        accountPanel?.orderOut(nil)
    }

    private func handleSettingsPanelAction(_ action: SettingsPanelAction) {
        switch action {
        case .languageRussian:
            setLanguage(.russian)
            return
        case .languageEnglish:
            setLanguage(.english)
            return
        case .usageView:
            accountPanelMode = .usage
        case .settingsView:
            accountPanelMode = .settings
        case .resetCreditsView:
            accountPanelMode = .resets
            refreshResetCreditsIfNeeded(force: false)
        case .addAccount:
            addAccountBrowser()
        case .warmupLimits:
            warmupLimits()
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
        case .toggleLaunchAtLogin:
            toggleLaunchAtLogin()
        case .toggleUsageReminder:
            toggleUsageReminder()
        case .toggleCreditExpiryNotifications:
            toggleCreditExpiryNotifications()
        case .editUsageReminder:
            showUsageReminderDialog()
        case .toggleAutoSwitch:
            toggleAutoSwitch()
        case .editAutoSwitch:
            showAutoSwitchDialog()
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
        case .saveReferencePlugins:
            saveCurrentPluginsAsReference()
        case .diagnostics:
            showDiagnostics()
        case .quit:
            NSApp.terminate(nil)
        }
        if accountPanel?.isVisible == true {
            refreshAccountPanelContentIfVisible()
        }
    }

    private func warmupLimits() {
        guard !isWarmingUp, !isSwitching, !accounts.isEmpty else { return }
        let currentAccounts = accounts
        isWarmingUp = true
        warmupStatusClearTask?.cancel()
        warmupStatusClearTask = nil
        warmupStates = Dictionary(currentAccounts.map { ($0.email, .waiting) }, uniquingKeysWith: { first, _ in first })
        refreshAccountPanelContentIfVisible()
        Task {
            for start in stride(from: 0, to: currentAccounts.count, by: 4) {
                let batch = Array(currentAccounts[start..<min(start + 4, currentAccounts.count)])
                await withTaskGroup(of: Void.self) { group in
                    for account in batch {
                        group.addTask { await self.warmupAccount(email: account.email) }
                    }
                }
            }
            isWarmingUp = false
            refreshAccountPanelContentIfVisible()
            refreshAccounts(force: true)
            warmupStatusClearTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 12_000_000_000)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.warmupStates = [:]
                self.warmupStatusClearTask = nil
                self.refreshAccountPanelContentIfVisible()
            }

        }
    }

    private func warmupAccount(email: String) async {
        warmupStates[email] = .running
        refreshAccountPanelContentIfVisible()
        guard case .success(let saved) = savedAuth(forEmail: email) else {
            warmupStates[email] = .failed
            refreshAccountPanelContentIfVisible()
            return
        }
        if CodexTokenRefresher.shouldRefresh(lastRefresh: saved.lastRefresh) {
            warmupStates[email] = .refreshing
            refreshAccountPanelContentIfVisible()
        }
        var auth = await maybeRefreshAuth(saved)
        warmupStates[email] = .running
        refreshAccountPanelContentIfVisible()
        var payload = await CodexLimitWarmupClient.run(using: auth)
        // Retry only a definite auth rejection, using the exact saved account.
        if payload?.statusCode == 401, let token = auth.refreshToken {
            warmupStates[email] = .refreshing
            refreshAccountPanelContentIfVisible()
            let refreshed = await performTokenRefresh(auth: auth, refreshToken: token)
            if refreshed.accessToken != auth.accessToken {
                auth = refreshed
                payload = await CodexLimitWarmupClient.run(using: auth)
            }
        }
        warmupStates[email] = CodexLimitWarmupClient.resultState(payload)
        refreshAccountPanelContentIfVisible()
    }

    private func setLanguage(_ language: AppLanguage) {
        languageStore.select(language) { [weak self] in
            self?.rebuildMenu()
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
                self.rebuildMenu()
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
        let language = languageStore.load()
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
                let item = NSMenuItem(title: "\(LocalizedText.value(.unavailable, language: language)): \(error)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
                continue
            }

            guard let snapshot else {
                let item = NSMenuItem(title: LocalizedText.value(.checkingResetCredits, language: language), action: nil, keyEquivalent: "")
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
                let item = NSMenuItem(title: LocalizedText.value(.noAvailableResetCredits, language: language), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for (index, credit) in credits.enumerated() {
                    let title = resetCreditMenuTitle(credit, index: index + 1)
                    let item = NSMenuItem(title: title, action: #selector(redeemResetCreditMenuItem(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = resetCreditActionPayload(email: account.email, creditID: credit.id)
                    item.toolTip = LocalizedText.value(.redeemResetTooltip, language: language)
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
                    self.rebuildMenu()
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
                    self.rebuildMenu()

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
                    self.rebuildMenu()
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
                fiveHourUsage: usage.hasFiveHourWindow ? directUsageText(usage.fiveHour, weekly: false) : "--",
                weeklyUsage: directUsageText(usage.weekly, weekly: true),
                fiveHourUsedPercent: usage.hasFiveHourWindow ? usage.fiveHour.remainingPercent : nil,
                weeklyUsedPercent: usage.weekly.remainingPercent,
                lastActivity: account.lastActivity,
                isActive: account.isActive,
                hasFiveHourWindow: usage.hasFiveHourWindow
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
                fiveHourUsage: snapshot.hasFiveHourWindow ? directUsageText(snapshot.fiveHour, weekly: false) : "--",
                weeklyUsage: directUsageText(snapshot.weekly, weekly: true),
                fiveHourUsedPercent: snapshot.hasFiveHourWindow ? snapshot.fiveHour.remainingPercent : nil,
                weeklyUsedPercent: snapshot.weekly.remainingPercent,
                lastActivity: account.lastActivity,
                isActive: account.isActive,
                hasFiveHourWindow: snapshot.hasFiveHourWindow
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
                self.rebuildMenu()

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
                self.rebuildMenu()
            }
        }
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
        if let resetStatusText {
            return NSAttributedString(
                string: resetStatusText,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold),
                    .foregroundColor: NSColor.systemOrange
                ]
            )
        }
        guard let active = toolbarStatusAccounts().first else {
            return NSAttributedString(string: "")
        }
        return NSAttributedString(
            string: toolbarStatusText(for: active),
            attributes: toolbarTitleAttributes(for: active)
        )
    }

    private func statusTitleKey() -> String {
        if let resetStatusText {
            return "reset|\(resetStatusText)"
        }
        return toolbarStatusAccounts().first.map { account in
            "\(account.email)|\(account.toolbarRemainingPercent ?? -1)|\(account.isActive ? "active" : "inactive")|\(accountNeedsLogin(account) ? "login" : "ok")"
        } ?? "empty"
    }

    private func setResetStatus(_ text: String?) {
        resetStatusText = text
        currentStatusTitleKey = ""
        updateStatusTitle()
    }

    private func statusItemLength(for title: NSAttributedString) -> CGFloat {
        max(20, ceil(title.size().width) + 1)
    }

    private func toolbarStatusText(for account: CodexAccount) -> String {
        let percent = toolbarUsagePercent(for: account)
        return ToolbarStatusFormatter.text(
            usage: remainingPercentText(fromUsed: percent)
        )
    }

    private func toolbarTitleAttributes(for account: CodexAccount?) -> [NSAttributedString.Key: Any] {
        let size: CGFloat = 12.5
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
        return account.toolbarRemainingPercent
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
    private nonisolated var codexDesktopAppPath: String {
        return "/Applications/ChatGPT.app"
    }

    private nonisolated var codexDesktopAppName: String {
        URL(fileURLWithPath: codexDesktopAppPath).deletingPathExtension().lastPathComponent
    }

    private nonisolated var codexDesktopResourcesPath: String {
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

    private func usageModeItem(title: String, percent: String, reset: String, mode: UsageDisplayMode) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(setUsageMode(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode.rawValue
        item.state = usageMode == mode ? .on : .off
        item.attributedTitle = usageAttributedTitle(title: title, percent: percent, reset: reset)
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
        if usageRefreshPending(account) {
            parts.append("showing saved usage; live refresh pending")
        }
        return parts.joined(separator: ", ")
    }

    private func usageRefreshPending(_ account: CodexAccount) -> Bool {
        directUsageSnapshotsByEmail[account.email] == nil
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

    private func lastUpdatedText(language: AppLanguage) -> String {
        let now = Date()
        let elapsed = lastUpdatedAt.map { now.timeIntervalSince($0) }
        return LocalizedText.lastUpdated(
            isRefreshing: isRefreshing,
            elapsed: elapsed,
            language: language
        )
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
        guard let url = URL(string: "https://api.github.com/repos/smashlight/Codex-Account-Switcher/releases/latest") else { return }
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

        let alert = NSAlert()
        alert.messageText = "Menu bar display"
        alert.informativeText = "Choose which usage appears in the menu bar. The account panel keeps 5-hour as the main ring and weekly as the top bar."
        alert.accessoryView = usagePopup
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let usageRawValue = usagePopup.selectedItem?.representedObject as? String,
           let selectedUsageMode = UsageDisplayMode(rawValue: usageRawValue) {
            usageMode = selectedUsageMode
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

    @objc private func toggleCreditExpiryNotifications() {
        creditExpiryNotificationsEnabled.toggle()
        if creditExpiryNotificationsEnabled {
            configureNotifications()
            checkCreditExpiryNotifications()
        } else {
            creditExpiryFingerprints.removeAll()
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

    private func switchTo(query: String, automatic: Bool = false) {
        guard !isSwitching else { return }
        clearArmedSwitch()
        let target = accounts.first(where: { $0.email == query || $0.selector == query })
        if let target, accountNeedsLogin(target) {
            showAlert(
                title: "Account needs login",
                message: "Account \(displayLabel(for: target)) has an expired Codex session. Re-login it with Add Account, then refresh."
            )
            refreshAccounts(force: true)
            return
        }
        isSwitching = true
        let previous = accounts.first(where: { $0.isActive })
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

            Task { @MainActor in
                self.refreshAccounts(force: true)
            }

            let restartResult = self.restartCodexApp()
            DispatchQueue.main.async {
                self.isSwitching = false
                if restartResult.status != 0 {
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: "desktop relaunch", result: "account changed; relaunch failed")
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
                } else {
                    UserDefaults.standard.set(Date(), forKey: self.lastSwitchDateDefaultsKey)
                    self.recordSwitch(from: previous, to: target, automatic: automatic, reason: automatic ? "automatic best account" : "manual", result: "verified")
                }
                self.refreshAccounts(force: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self, !self.isSwitching else { return }
                    self.endStatusAnimation(expectedGeneration: switchStatusAnimationGeneration)
                    self.updateStatusTitle()
                }
            }
        }
    }

    private nonisolated func verifyActiveAccount(expectedEmail: String) -> CommandResult {
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
        switchAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard StatusAnimationPolicy.shouldContinue(
                    isSwitching: self.isSwitching,
                    isRedeemingReset: self.isRedeemingReset
                ) else {
                    self.endStatusAnimation()
                    self.updateStatusTitle()
                    return
                }
                self.switchAnimationFrame += 1
                self.updateStatusAnimationTitle()
            }
        }
        return statusAnimationGeneration
    }

    private func updateStatusAnimationTitle() {
        let frame = switchAnimationFrames[switchAnimationFrame % switchAnimationFrames.count]
        setResetStatus("\(statusAnimationTitle) \(frame)")
    }

    private func endStatusAnimation(expectedGeneration: Int? = nil) {
        if let expectedGeneration, expectedGeneration != statusAnimationGeneration {
            return
        }
        switchAnimationTimer?.invalidate()
        switchAnimationTimer = nil
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

    private func rebuildAccountPanelContentIfVisible() {
        guard accountPanel?.isVisible == true else { return }
        refreshAccountPanelContent(shouldRefreshNotificationHealth: false)
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
            switchTo(query: target.email, automatic: true)
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
                        self.showNotificationSettingsAlert(message: message ?? Self.notificationSettingsMessage())
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
                            self.showNotificationSettingsAlert(message: Self.notificationSettingsMessage())
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
                        completion(false, Self.notificationSettingsMessage())
                    } else if granted {
                        completion(true, nil)
                    } else {
                        completion(false, Self.notificationSettingsMessage())
                    }
                }
            case .denied:
                completion(false, Self.notificationSettingsMessage())
            @unknown default:
                completion(false, Self.notificationSettingsMessage())
            }
        }
    }

    private nonisolated static func notificationSettingsMessage() -> String {
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
                self?.switchTo(query: targetEmail, automatic: true)
            }
        default:
            return
        }
    }


    private nonisolated func syncActiveAuthSnapshot() -> String? {
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
            _ = AuthBackupPruner.prune(in: accountAuthURL.deletingLastPathComponent(), keepingPerAccount: 10)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func runAccountMaintenance(title: String, args: [String], restartAfterSuccess: Bool = false) {
        guard !isSwitching else { return }
        isSwitching = true
        let maintenanceStatusAnimationGeneration = beginStatusAnimation(title: title)
        rebuildMenu()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runCodexAuth(args)
            var restartResult: CommandResult?
            if result.status == 0, restartAfterSuccess {
                restartResult = self.restartCodexApp()
            }
            DispatchQueue.main.async {
                self.isSwitching = false
                self.endStatusAnimation(expectedGeneration: maintenanceStatusAnimationGeneration)
                self.updateStatusTitle()
                if result.status != 0 {
                    self.showAlert(title: "\(title) failed", message: result.output)
                } else if let restartResult, restartResult.status != 0 {
                    self.showAlert(title: "Codex relaunch failed", message: restartResult.output)
                }
                self.refreshAccounts(force: true)
            }
        }
    }

    private nonisolated func referencePluginStoreDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return applicationSupport
            .appendingPathComponent("Codex Account Switcher", isDirectory: true)
            .appendingPathComponent("reference-plugins", isDirectory: true)
    }

    private func saveCurrentPluginsAsReference() {
        guard !isSwitching else { return }
        isSwitching = true
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        statusItem.button?.title = "Saving"
        rebuildMenu()

        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = ReferencePluginStore.capture(
                homeDirectory: NSHomeDirectory(),
                storeDirectory: self.referencePluginStoreDirectory()
            )
            DispatchQueue.main.async {
                self.isSwitching = false
                self.updateStatusTitle()
                switch outcome {
                case .captured(let remoteCount, let curatedCount):
                    let manifest = ReferencePluginStore.load(
                        storeDirectory: self.referencePluginStoreDirectory()
                    )?.manifest
                    let identifiers = ((manifest?.remotePluginIDs ?? []) + (manifest?.curatedPluginIDs ?? []))
                        .sorted()
                        .joined(separator: ", ")
                    self.showAlert(
                        title: "Reference plugins saved",
                        message: "Saved \(remoteCount) remote packages and \(curatedCount) curated plugins: \(identifiers). This exact set will be applied after account switches."
                    )
                case .failed(let reason):
                    self.showAlert(title: "Could not save reference plugins", message: reason)
                }
                self.rebuildMenu()
            }
        }
    }

    private nonisolated func restartCodexApp() -> CommandResult {
        var transcript: [String] = []
        guard terminateCodexProcessTree(transcript: &transcript) else {
            return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
        }

        let bundledOutcome = ensureBundledPluginsHealthy()
        switch bundledOutcome {
        case .ok:
            transcript.append("Bundled plugins verified: \(BundledMarketplaceInspector.expectedPluginIDs().count) expected, all present.")
        case .repairedFromApp:
            transcript.append("Bundled plugins repaired: snapshot restored from ChatGPT.app.")
        case .repairedByStaleMove:
            transcript.append("Bundled plugins repaired: stale snapshot moved aside for regeneration.")
        case .noAppFound:
            break
        case .failed(let reason):
            transcript.append("Bundled plugins repair failed: \(reason)")
            _ = openCodexAndVerify(label: "Reopening \(codexDesktopAppName) after bundled plugin repair failure...", transcript: &transcript)
            return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
        }

        if let configMessage = ensureComputerUsePluginConfigured() {
            transcript.append(configMessage)
        }

        let reference = ReferencePluginStore.load(storeDirectory: referencePluginStoreDirectory())
        if let reference {
            if let failure = openCodexAndVerify(label: "Opening \(codexDesktopAppName) for account plugin sync...", transcript: &transcript) {
                return failure
            }
            let stabilized = waitForRemotePluginSync(timeout: 15)
            transcript.append(stabilized ? "Account plugin sync stabilized." : "Account plugin sync wait timed out; applying the latest observed state.")
            guard terminateCodexProcessTree(transcript: &transcript) else {
                return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
            }
            guard applyReferencePlugins(reference, transcript: &transcript, launchAfterApply: true) else {
                _ = openCodexAndVerify(
                    label: "Reopening \(codexDesktopAppName) after plugin restoration failure...",
                    transcript: &transcript
                )
                return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
            }

            return CommandResult(status: 0, output: transcript.joined(separator: "\n"))
        }

        transcript.append("Reference plugins not saved; keeping the account-synchronized user plugin set.")
        if let failure = openCodexAndVerify(label: "Opening \(codexDesktopAppName)...", transcript: &transcript) {
            return failure
        }
        return CommandResult(status: 0, output: transcript.joined(separator: "\n"))
    }

    private nonisolated func terminateCodexProcessTree(transcript: inout [String]) -> Bool {
        transcript.append("Quitting \(codexDesktopAppName) process tree...")
        for attempt in 1...6 {
            let pids: [String]
            switch codexAppPIDs() {
            case .noMatches:
                return true
            case .matches(let matches):
                pids = matches
            case .failed(let reason):
                transcript.append("Could not inspect Codex processes: \(reason)")
                return false
            }
            let signal = attempt == 1 ? "-TERM" : "-KILL"
            _ = run("/bin/kill", [signal] + pids)
            Thread.sleep(forTimeInterval: 1)
        }
        switch codexAppPIDs() {
        case .noMatches:
            return true
        case .matches(let remaining):
            transcript.append("Codex helper processes remained after force quit: \(remaining.joined(separator: ", ")).")
            return false
        case .failed(let reason):
            transcript.append("Could not verify Codex process termination: \(reason)")
            return false
        }
    }

    private nonisolated func openCodexAndVerify(label: String, transcript: inout [String]) -> CommandResult? {
        transcript.append(label)
        let openResult = run("/usr/bin/open", [codexDesktopAppPath])
        if openResult.status != 0 {
            return CommandResult(
                status: openResult.status,
                output: transcript.joined(separator: "\n") + "\n" + openResult.output
            )
        }
        for _ in 0..<8 {
            Thread.sleep(forTimeInterval: 0.5)
            let runningResult = run(
                "/usr/bin/osascript",
                ["-e", "application \"\(codexDesktopAppName)\" is running"]
            )
            if runningResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                return nil
            }
        }
        transcript.append("\(codexDesktopAppName) did not report as running after launch.")
        return CommandResult(status: 1, output: transcript.joined(separator: "\n"))
    }

    private nonisolated func waitForRemotePluginSync(timeout: TimeInterval) -> Bool {
        let cacheURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/plugins/cache/openai-curated-remote", isDirectory: true)
        var tracker = PluginSyncStabilityTracker(requiredStableObservations: 4)
        let deadline = Date().addingTimeInterval(timeout)
        var stabilized = false
        Thread.sleep(forTimeInterval: 2)
        while Date() < deadline {
            let inventory = ReferencePluginInventory.remotePluginIDs(homeDirectory: NSHomeDirectory())
            let fingerprint = ReferencePluginInventory.remoteTreeDigest(in: cacheURL)
            stabilized = tracker.observe(inventory: inventory, fingerprint: fingerprint)
            if stabilized { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return stabilized
    }

    private nonisolated func applyReferencePlugins(
        _ reference: ReferencePluginStore.LoadedReference,
        transcript: inout [String],
        launchAfterApply: Bool = false
    ) -> Bool {
        var messages: [String] = []
        let transaction = ReferencePluginTransaction.perform(
            homeDirectory: NSHomeDirectory(),
            finalize: {
                if launchAfterApply,
                   let failure = self.openCodexAndVerify(
                       label: "Opening \(self.codexDesktopAppName) with reference plugins...",
                       transcript: &transcript
                   ) {
                    let reason = "final Codex launch failed: \(failure.output)"
                    return self.terminateCodexProcessTree(transcript: &transcript)
                        ? .rollback(reason: reason)
                        : .preserveBackup(reason: reason)
                }
                guard self.verifyReferencePlugins(reference, transcript: &transcript) else {
                    if launchAfterApply {
                        return self.terminateCodexProcessTree(transcript: &transcript)
                            ? .rollback(reason: "final reference plugin verification failed")
                            : .preserveBackup(reason: "final reference plugin verification failed")
                    }
                    return .rollback(reason: "final reference plugin verification failed")
                }
                return .success
            },
            operation: {
                let bundledCodex = "\(self.codexDesktopResourcesPath)/codex"
                guard FileManager.default.isExecutableFile(atPath: bundledCodex) else {
                    return "reference plugin reconciliation failed: bundled codex CLI not found"
                }
                let marketplaceOutcome = ReferenceMarketplacePluginReconciler.reconcile(
                    homeDirectory: NSHomeDirectory(),
                    reference: reference
                ) { arguments in
                    self.run(bundledCodex, arguments)
                }
                switch marketplaceOutcome {
                case .alreadyMatched:
                    messages.append("Reference local plugins already matched.")
                case .applied(let changes):
                    messages.append("Reference local plugins applied: \(changes) change(s).")
                case .failed(let reason):
                    return "reference local plugin reconciliation failed: \(reason)"
                }
                let curatedOutcome = CuratedPluginReconciler.reconcile(
                    homeDirectory: NSHomeDirectory(),
                    referenceIDs: reference.manifest.curatedPluginIDs
                ) { arguments in
                    self.run(bundledCodex, arguments)
                }
                switch curatedOutcome {
                case .alreadyMatched:
                    messages.append("Reference curated plugins already matched.")
                    return nil
                case .applied(let changes):
                    messages.append("Reference curated plugins applied: \(changes) change(s).")
                    return nil
                case .failed(let reason):
                    return "reference curated plugin reconciliation failed: \(reason)"
                }
            }
        )
        transcript.append(contentsOf: messages)
        switch transaction {
        case .applied:
            return true
        case .failed(let reason):
            transcript.append("Reference plugin transaction failed: \(reason)")
            return false
        }
    }

    private nonisolated func verifyReferencePlugins(
        _ reference: ReferencePluginStore.LoadedReference,
        transcript: inout [String]
    ) -> Bool {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let referenceCache = home.appendingPathComponent(
            ".codex/plugins/cache/\(ReferencePluginMarketplace.name)",
            isDirectory: true
        )
        guard ReferencePluginInventory.remotePluginIDs(in: referenceCache) == reference.manifest.remotePluginIDs else {
            transcript.append("Reference local plugin cache verification failed after launch.")
            return false
        }
        let configURL = home.appendingPathComponent(".codex/config.toml")
        guard let configText = try? String(contentsOf: configURL, encoding: .utf8) else {
            transcript.append("Reference curated plugin verification failed: config.toml could not be read.")
            return false
        }
        guard ReferencePluginInventory.curatedPluginIDs(configText: configText)
            == reference.manifest.curatedPluginIDs.sorted() else {
            transcript.append("Reference curated plugin verification failed after launch.")
            return false
        }
        guard ReferencePluginInventory.pluginIDs(
            configText: configText,
            marketplace: ReferencePluginMarketplace.name
        ) == reference.manifest.remotePluginIDs.sorted() else {
            transcript.append("Reference local plugin configuration verification failed after launch.")
            return false
        }
        let marketplaceURL = reference.remoteCacheURL
            .deletingLastPathComponent()
            .appendingPathComponent("local-marketplace", isDirectory: true)
        guard ReferencePluginMarketplace.staleInstalledPluginIDs(
            marketplaceURL: marketplaceURL,
            installedCacheURL: referenceCache,
            pluginIDs: reference.manifest.remotePluginIDs
        ).isEmpty else {
            transcript.append("Reference local plugin content verification failed after launch.")
            return false
        }
        transcript.append("Reference plugin set verified after launch.")
        return true
    }

    private nonisolated func ensureComputerUsePluginConfigured() -> String? {
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

    private nonisolated func ensureBundledPluginsHealthy() -> BundledMarketplaceRepairer.RepairOutcome {
        let bundledCodex = "\(codexDesktopResourcesPath)/codex"
        let outcome = BundledMarketplaceRepairer.repairIfNeeded(
            homeDirectory: NSHomeDirectory(),
            appPath: codexDesktopAppPath,
            codexExecutable: FileManager.default.isExecutableFile(atPath: bundledCodex) ? bundledCodex : nil,
            pluginRunner: { executable, arguments, _ in
                self.run(executable, arguments)
            }
        )
        return outcome
    }

    private nonisolated func codexAppPIDs() -> ProcessLookupPolicy.Outcome {
        let escapedPath = NSRegularExpression.escapedPattern(for: codexDesktopAppPath)
        let result = run("/usr/bin/pgrep", ["-f", "\(escapedPath)/Contents/"])
        return ProcessLookupPolicy.parse(status: result.status, output: result.output)
    }

    private nonisolated func parseAccounts(_ output: String, usageIsLive: Bool = true) -> [CodexAccount] {
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
        let requestedCount = Int(ProcessInfo.processInfo.environment["CODEX_ACCOUNT_SWITCHER_DEMO_COUNT"] ?? "") ?? 3
        let count = min(20, max(1, requestedCount))
        let remainingValues = [82, 64, 41, 24, 17, 10, 7, 93, 56, 31, 14, 5]

        return (0..<count).map { index in
            let remaining = remainingValues[index % remainingValues.count]
            return CodexAccount(
                selector: String(format: "%02d", index + 1),
                email: String(format: "account-%02d@example.com", index + 1),
                plan: "plus",
                fiveHourUsage: "--",
                weeklyUsage: "\(remaining)% (Fri 09:00)",
                fiveHourUsedPercent: nil,
                weeklyUsedPercent: remaining,
                lastActivity: index == 0 ? "Just now" : "\(index)h ago",
                isActive: index == 0
            )
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

    private nonisolated static func parseUsage(_ tokens: [String], from startIndex: Int, usageIsLive: Bool = true) -> (text: String, usedPercent: Int?, nextIndex: Int) {
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

    private nonisolated static func usageErrorText(for token: String) -> String? {
        switch token {
        case "400", "401":
            return "Login expired"
        case "403":
            return "Usage blocked"
        default:
            return nil
        }
    }

    private nonisolated static func firstPercent(in token: String) -> Int? {
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
                    let refreshedAuth = await self.maybeRefreshAuth(auth)
                    guard case .success(let usage) = await self.fetchDirectUsage(using: refreshedAuth) else { return nil }
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

    private func fetchDirectUsage(
        using auth: SavedAccountAuth,
        alreadyRetried: Bool = false
    ) async -> DirectUsageFetchResult {
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
            if !alreadyRetried,
               payload.statusCode == 400 || payload.statusCode == 401,
               let refreshToken = auth.refreshToken, !refreshToken.isEmpty {
                let refreshed = await performTokenRefresh(auth: auth, refreshToken: refreshToken)
                if refreshed.accessToken != auth.accessToken {
                    return await fetchDirectUsage(using: refreshed, alreadyRetried: true)
                }
            }
            return .failure("usage endpoint returned \(payload.statusCode)")
        }
        return parseDirectUsageResponse(payload.data)
    }

    private func maybeRefreshAuth(_ auth: SavedAccountAuth) async -> SavedAccountAuth {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty else {
            return auth
        }
        guard CodexTokenRefresher.shouldRefresh(lastRefresh: auth.lastRefresh) else {
            return auth
        }
        return await performTokenRefresh(auth: auth, refreshToken: refreshToken)
    }

    private func performTokenRefresh(auth: SavedAccountAuth, refreshToken: String) async -> SavedAccountAuth {
        guard claimRefreshSlot(email: auth.email) else { return auth }
        defer { releaseRefreshSlot(email: auth.email) }

        let result = await CodexTokenRefresher.refresh(refreshToken: refreshToken)

        switch result {
        case .success(let payload):
            writeBackRefreshedTokens(auth: auth, payload: payload)
            return SavedAccountAuth(
                accountKey: auth.accountKey,
                email: auth.email,
                accessToken: payload.accessToken,
                accountID: auth.accountID,
                refreshToken: payload.refreshToken ?? auth.refreshToken,
                lastRefresh: payload.lastRefresh
            )
        case .expired, .revoked, .reused:
            notifyLoginExpiredIfNeeded(auth: auth)
            return auth
        case .notRefreshable, .networkError, .invalidResponse:
            return auth
        }
    }

    private func claimRefreshSlot(email: String) -> Bool {
        refreshInFlightLock.lock()
        defer { refreshInFlightLock.unlock() }
        guard !refreshInFlightEmails.contains(email) else { return false }
        refreshInFlightEmails.insert(email)
        return true
    }

    private func releaseRefreshSlot(email: String) {
        refreshInFlightLock.lock()
        defer { refreshInFlightLock.unlock() }
        refreshInFlightEmails.remove(email)
    }

    private func writeBackRefreshedTokens(auth: SavedAccountAuth, payload: CodexTokenRefreshPayload) {
        let root = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/accounts")
        guard let fileURL = SavedAccountAuthFilePolicy.fileURL(accountKey: auth.accountKey, expectedAccountID: auth.accountID, root: root) else { return }
        guard CodexAuthTokenWriter.applyTokenUpdate(
            to: fileURL,
            expectedAccountID: auth.accountID,
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            lastRefresh: payload.lastRefresh
        ) == nil else {
            return
        }
        mirrorActiveAuthIfNeeded(accountKey: auth.accountKey, accountID: auth.accountID, payload: payload)
    }

    private func mirrorActiveAuthIfNeeded(accountKey: String, accountID: String, payload: CodexTokenRefreshPayload) {
        let home = NSHomeDirectory()
        let registryURL = URL(fileURLWithPath: "\(home)/.codex/accounts/registry.json")
        let activeAuthURL = URL(fileURLWithPath: "\(home)/.codex/auth.json")
        guard
            let registryData = try? Data(contentsOf: registryURL),
            let registry = try? JSONSerialization.jsonObject(with: registryData) as? [String: Any],
            let activeKey = registry["active_account_key"] as? String,
            SavedAccountAuthFilePolicy.shouldMirror(activeAccountKey: activeKey, refreshedAccountKey: accountKey)
        else {
            return
        }
        let encoded = Data(activeKey.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let accountAuthURL = URL(fileURLWithPath: "\(home)/.codex/accounts/\(encoded).auth.json")
        guard FileManager.default.fileExists(atPath: activeAuthURL.path),
              FileManager.default.fileExists(atPath: accountAuthURL.path),
              let accountData = try? Data(contentsOf: accountAuthURL),
              let accountJSON = try? JSONSerialization.jsonObject(with: accountData) as? [String: Any],
              let accountTokens = accountJSON["tokens"] as? [String: Any],
              let storedAccountID = accountTokens["account_id"] as? String,
              storedAccountID == accountID
        else {
            return
        }
        _ = CodexAuthTokenWriter.applyTokenUpdate(
            to: activeAuthURL,
            expectedAccountID: accountID,
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            lastRefresh: payload.lastRefresh
        )
    }

    private func notifyLoginExpiredIfNeeded(auth: SavedAccountAuth) {
        let defaults = UserDefaults.standard
        let cooldowns = defaults.dictionary(forKey: loginExpiredCooldownDefaultsKey) as? [String: TimeInterval] ?? [:]
        let lastNotified = cooldowns[auth.email] ?? 0
        let now = Date().timeIntervalSince1970
        guard now - lastNotified >= loginExpiredNotificationCooldown else { return }
        var updated = cooldowns
        updated[auth.email] = now
        defaults.set(updated, forKey: loginExpiredCooldownDefaultsKey)
        sendNotification(
            title: "Codex account login expired",
            subtitle: displayLabel(for: auth.email),
            body: "Auto token refresh failed for \(auth.email). Run `codex-auth login` to restore this account."
        )
    }

    private func displayLabel(for email: String) -> String {
        limitedLabel(customLabel(forEmail: email) ?? defaultLabel(forEmail: email))
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
            weekly: weekly,
            hasFiveHourWindow: !(
                ["team", "business"].contains((object["plan_type"] as? String ?? "").lowercased())
                && secondary == nil && (primary?.duration ?? 0) >= 86_400
            )
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

        var businessFixture = postResetUsageFixture
        businessFixture["plan_type"] = "team"
        businessFixture["rate_limit"] = [
            "primary_window": ["used_percent": 31, "limit_window_seconds": 604_800],
            "secondary_window": NSNull()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: businessFixture),
              case .success(let business) = parseDirectUsageResponse(data),
              !business.hasFiveHourWindow,
              business.weekly.remainingPercent == 69 else {
            return "Reset logic self-test FAILED: Business weekly-only window"
        }

        var dualWindowBusinessFixture = usageFixture
        dualWindowBusinessFixture["plan_type"] = "team"
        guard let data = try? JSONSerialization.data(withJSONObject: dualWindowBusinessFixture),
              case .success(let business) = parseDirectUsageResponse(data),
              business.hasFiveHourWindow,
              business.fiveHour.remainingPercent == 99 else {
            return "Reset logic self-test FAILED: Business with both windows"
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
        if creditExpiryNotificationsEnabled {
            for (email, snapshot) in results {
                checkCreditExpiryNotifications(snapshot: snapshot, email: email)
            }
        }
        return results
    }

    private func checkCreditExpiryNotifications() {
        guard creditExpiryNotificationsEnabled else { return }
        for (email, snapshot) in resetCreditsByEmail {
            checkCreditExpiryNotifications(snapshot: snapshot, email: email)
        }
    }

    private func checkCreditExpiryNotifications(snapshot: ResetCreditsSnapshot, email: String) {
        let now = Date()
        let expiring: [(id: String, expiresAt: TimeInterval)] = snapshot.credits.compactMap { credit in
            guard let expiresAt = credit.expiresAt else { return nil }
            let remaining = expiresAt.timeIntervalSince(now)
            guard remaining > 0, remaining <= creditExpiryWindow else { return nil }
            return (credit.id, expiresAt.timeIntervalSince1970)
        }
        guard !expiring.isEmpty else { return }

        let fingerprint = creditExpirySummaryFingerprint(expiring)
        var stored = creditExpiryFingerprints
        guard !stored.contains(fingerprint) else { return }
        stored.append(fingerprint)
        if stored.count > creditExpiryFingerprintLimit {
            stored.removeFirst(stored.count - creditExpiryFingerprintLimit)
        }
        creditExpiryFingerprints = stored

        let earliest = expiring.map(\.expiresAt).min() ?? 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE · d MMM"
        let dateText = formatter.string(from: Date(timeIntervalSince1970: earliest)).uppercased()
        let count = expiring.count
        sendNotification(
            title: "Reset credits expire soon",
            subtitle: "\(displayLabel(for: email)) · \(count) credit\(count == 1 ? "" : "s")",
            body: "\(count) reset credit\(count == 1 ? "" : "s") for \(email) expire \(dateText). Open the RESETS panel to use them before they are lost."
        )
    }

    private func creditExpirySummaryFingerprint(_ expiring: [(id: String, expiresAt: TimeInterval)]) -> String {
        let material = expiring
            .map { "\($0.id)\u{1f}\(Int($0.expiresAt))" }
            .sorted()
            .joined(separator: "\u{1e}")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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

    private nonisolated func savedAuth(forEmail email: String) -> SavedAccountAuthResult {
        let root = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/accounts")
        let registryURL = root.appendingPathComponent("registry.json")
        guard
            let registryData = try? Data(contentsOf: registryURL),
            let registry = try? JSONSerialization.jsonObject(with: registryData) as? [String: Any],
            let registryAccounts = registry["accounts"] as? [[String: Any]],
            let registryAccount = registryAccounts.first(where: { ($0["email"] as? String) == email }),
            let accountKey = registryAccount["account_key"] as? String,
            !accountKey.isEmpty,
            let expectedAccountID = registryAccount["chatgpt_account_id"] as? String,
            !expectedAccountID.isEmpty
        else {
            return .failure("saved account registry was not readable")
        }

        guard let authURL = SavedAccountAuthFilePolicy.fileURL(accountKey: accountKey, expectedAccountID: expectedAccountID, root: root) else {
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

        return .success(SavedAccountAuth(
            accountKey: accountKey,
            email: email,
            accessToken: accessToken,
            accountID: accountID,
            refreshToken: tokens["refresh_token"] as? String,
            lastRefresh: CodexAuthDate.parseLastRefresh(tokens["last_refresh"] as? String)
        ))
    }

    private nonisolated func runCodexAuth(_ args: [String]) -> CommandResult {
        guard let path = codexAuthPath() else {
            return CommandResult(status: 127, output: "codex-auth was not found in known locations.")
        }
        return run(path, args)
    }

    private nonisolated func codexAuthPath() -> String? {
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

    private nonisolated func run(_ executable: String, _ args: [String]) -> CommandResult {
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

    private nonisolated func commandTimeout(for executable: String, arguments: [String]) -> TimeInterval {
        let command = URL(fileURLWithPath: executable).lastPathComponent
        if command == "codex-auth" {
            return arguments.first == "login" ? 180 : 20
        }
        if command == "open" || command == "osascript" { return 15 }
        return 12
    }

    private nonisolated func augmentedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = augmentedPath(from: environment["PATH"])
        return environment
    }

    private nonisolated func augmentedPath(from currentPath: String?) -> String {
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
            "refresh: \(lastUpdatedText(language: .english))",
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

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
