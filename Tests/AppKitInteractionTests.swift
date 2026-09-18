import AppKit
import SwiftUI

@main
struct AppKitInteractionTests {
    private static var failures: [String] = []
    private static var assertionCount = 0

    static func main() {
        testNativeTableMapsSelectionToExactAccount()
        testNativeTableOffersDeleteOnlyForInactiveAccount()
        testNativeTableMapsDeleteToExactAccount()
        testNativeTableProvidesFinalCellWidth()
        testAccountRowHostingViewFollowsTableWidth()
        testAccountRowHostingViewPreservesTableGestures()
        testNativeSettingsSwitchUsesSmallSystemControl()
        testAccountTableUsesCompactSpacing()
        testTenCompactRowsFitViewport()
        testPoolVerdictCardShowsHybridForecast()
        testPoolVerdictCardCollectingHidesForecast()

        if failures.isEmpty {
            print("AppKit interaction tests passed (\(assertionCount) assertions).")
            return
        }
        for failure in failures {
            FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8))
        }
        exit(1)
    }

    private static func testAccountTableUsesCompactSpacing() {
        expect(makeTable().intercellSpacing.height == 4, "account table should use compact row spacing")
    }

    private static func testTenCompactRowsFitViewport() {
        let accounts = (0..<10).map {
            account(email: "account-\($0)@example.com", active: $0 == 0)
        }
        let viewportHeight: CGFloat = 426 + CGFloat(UsagePanelLayoutMetrics.accountListEdgeAllowance)
        let table = AccountListTableView(
            frame: NSRect(x: 0, y: 0, width: 480, height: viewportHeight),
            accounts: accounts,
            isInteractionEnabled: true,
            armedEmail: nil,
            deleteTitle: "Delete",
            rowSpacing: 4,
            rowHeightProvider: { _ in 39 },
            rowViewProvider: { _, frame in NSView(frame: frame) },
            onSelect: { _ in },
            onDelete: { _ in }
        )
        table.reloadData()
        table.layoutSubtreeIfNeeded()
        let finalCellFrame = table.frameOfCell(atColumn: 0, row: 9)
        expect(
            finalCellFrame.maxY <= viewportHeight,
            "the tenth compact account cell must fit fully (maxY \(finalCellFrame.maxY), viewport \(viewportHeight))"
        )
    }

    private static func testPoolVerdictCardShowsHybridForecast() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let forecast = PoolSufficiencyForecast(
            kind: .notEnough,
            isPreliminary: true,
            historyDays: 4.7,
            burnPerDay: 118.7,
            expectedDemand: 830.9,
            usableCapacity: 697.956,
            coverageRatio: 0.84,
            exhaustionDate: now.addingTimeInterval(2 * 86_400),
            resetEvents: [
                PoolResetEvent(date: now.addingTimeInterval(2 * 86_400 + 22 * 3_600), accountCount: 2),
                PoolResetEvent(date: now.addingTimeInterval(4 * 86_400), accountCount: 1)
            ],
            accountCount: 7,
            requiredAccountCount: 9
        )
        let presentation = PoolVerdictPresenter.make(forecast: forecast, language: .russian, now: now)
        let card = PoolVerdictCardView(
            frame: NSRect(x: 0, y: 0, width: 484, height: 108),
            presentation: presentation,
            theme: PanelTheme(isDark: true)
        )
        let labels = allLabels(in: card)

        expect(labels.contains { $0.stringValue == "−16%" }, "card should show rounded deficit")
        expect(labels.contains { $0.stringValue == "Запас с учётом сбросов" }, "card should explain the capacity track")
        expect(labels.contains { $0.stringValue == "7 / ≈9" }, "card should compare current and required accounts")
        expect(labels.contains { $0.stringValue == "2 д 22 ч · ×2" }, "card should show grouped resets")
        expect(
            card.subviews.contains { $0.accessibilityIdentifier() == "pool-capacity-track" },
            "card should expose the capacity track"
        )
        expect(card.accessibilityLabel() == presentation.accessibilityLabel, "card should expose the complete forecast")
    }

    private static func testPoolVerdictCardCollectingHidesForecast() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let presentation = PoolVerdictPresenter.make(
            forecast: .collecting(historyDays: 0, accountCount: 7),
            language: .russian,
            now: now
        )
        let card = PoolVerdictCardView(
            frame: NSRect(x: 0, y: 0, width: 484, height: 108),
            presentation: presentation,
            theme: PanelTheme(isDark: true)
        )
        let labels = allLabels(in: card)

        expect(labels.contains { $0.stringValue == "Собираем историю" }, "collecting title should remain visible")
        expect(!labels.contains { $0.stringValue.contains("≈") }, "collecting should hide the account requirement")
        expect(
            !card.subviews.contains { $0.accessibilityIdentifier() == "pool-capacity-track" },
            "collecting should hide the capacity track"
        )
    }

    private static func allLabels(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { subview -> [NSTextField] in
            let own = (subview as? NSTextField).map { [$0] } ?? []
            return own + allLabels(in: subview)
        }
    }

    private static func testNativeTableMapsSelectionToExactAccount() {
        var selected = ""
        let table = makeTable(onSelect: { selected = $0.email })
        table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        table.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: table))
        expect(selected == "second@example.com", "selecting row 1 must invoke the second account, not the first")
    }

    private static func testNativeTableOffersDeleteOnlyForInactiveAccount() {
        let table = makeTable()
        let activeActions = table.tableView(table, rowActionsForRow: 0, edge: .trailing)
        let inactiveActions = table.tableView(table, rowActionsForRow: 1, edge: .trailing)
        expect(activeActions.isEmpty, "the active account must not expose a delete swipe action")
        expect(inactiveActions.count == 1, "an inactive account must expose one native trailing delete action")
    }

    private static func testNativeTableMapsDeleteToExactAccount() {
        var deleted = ""
        let table = makeTable(onDelete: { deleted = $0.email })
        table.deleteAccount(at: 1)
        expect(deleted == "second@example.com", "deleting row 1 must remove exactly the second account")
        table.deleteAccount(at: 0)
        expect(deleted == "second@example.com", "requesting deletion of the active row must do nothing")
    }

    private static func testNativeTableProvidesFinalCellWidth() {
        var suppliedWidth: CGFloat = 0
        let table = makeTable(rowViewProvider: { account, frame in
            suppliedWidth = frame.width
            let view = NSView(frame: frame)
            view.identifier = NSUserInterfaceItemIdentifier(account.email)
            return view
        })
        table.tableColumns[0].width = 440
        table.reloadData()
        let cell = table.view(atColumn: 0, row: 1, makeIfNecessary: true)
        expect(cell != nil, "the native table must create the requested account cell")
        expect(
            suppliedWidth == cell?.frame.width,
            "row content must be laid out with the final AppKit cell width (supplied \(suppliedWidth), final \(cell?.frame.width ?? -1))"
        )
    }

    private static func testAccountRowHostingViewFollowsTableWidth() {
        let host = AccountRowHostingView(
            frame: NSRect(x: 0, y: 0, width: 492, height: 48),
            rootView: Color.clear,
            passesGesturesToTable: true
        )
        host.frame.size.width = 440
        host.layoutSubtreeIfNeeded()
        expect(host.frame.width == 440, "SwiftUI account content must follow the final table cell width")
        expect(host.sizingOptions.isEmpty, "SwiftUI account content must not impose intrinsic sizing on its table cell")
    }

    private static func testAccountRowHostingViewPreservesTableGestures() {
        let passiveHost = AccountRowHostingView(
            frame: NSRect(x: 0, y: 0, width: 440, height: 48),
            rootView: Color.clear,
            passesGesturesToTable: true
        )
        let interactiveHost = AccountRowHostingView(
            frame: NSRect(x: 0, y: 0, width: 440, height: 78),
            rootView: Color.clear,
            passesGesturesToTable: false
        )
        expect(passiveHost.hitTest(NSPoint(x: 10, y: 10)) == nil, "normal rows must leave click and swipe handling to NSTableView")
        expect(interactiveHost.hitTest(NSPoint(x: 10, y: 10)) != nil, "confirmation rows must deliver clicks to their SwiftUI buttons")
    }

    private static func testNativeSettingsSwitchUsesSmallSystemControl() {
        let enabled = NativeSettingsSwitch.makeControl(isOn: true)
        let disabled = NativeSettingsSwitch.makeControl(isOn: false)
        expect(enabled.controlSize == .small, "settings switch must use the compact native macOS control size")
        expect(enabled.state == .on, "enabled native settings switch must preserve its on state")
        expect(disabled.state == .off, "disabled native settings switch must preserve its off state")
    }

    private static func makeTable(
        onSelect: @escaping (CodexAccount) -> Void = { _ in },
        onDelete: @escaping (CodexAccount) -> Void = { _ in },
        rowViewProvider: AccountListTableView.RowViewProvider? = nil
    ) -> AccountListTableView {
        AccountListTableView(
            frame: NSRect(x: 0, y: 0, width: 480, height: 102),
            accounts: [account(email: "first@example.com", active: true), account(email: "second@example.com", active: false)],
            isInteractionEnabled: true,
            armedEmail: nil,
            deleteTitle: "Delete",
            rowSpacing: 4,
            rowHeightProvider: { _ in 48 },
            rowViewProvider: rowViewProvider ?? { account, frame in
                let view = NSView(frame: frame)
                view.identifier = NSUserInterfaceItemIdentifier(account.email)
                return view
            },
            onSelect: onSelect,
            onDelete: onDelete
        )
    }

    private static func account(email: String, active: Bool) -> CodexAccount {
        CodexAccount(
            selector: active ? "01" : "02",
            email: email,
            plan: "plus",
            fiveHourUsage: "--",
            weeklyUsage: "50%",
            fiveHourUsedPercent: nil,
            weeklyUsedPercent: 50,
            lastActivity: "--",
            isActive: active
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        if !condition() {
            failures.append(message)
        }
    }
}
