import AppKit
import Foundation

extension NSFont {
    /// Rounded system font (AppKit has no design: parameter on systemFont).
    static func roundedSystemFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

final class DashboardBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        installFrostedBackdrop()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private func installFrostedBackdrop() {
        if #available(macOS 26.0, *) {
            // Native Liquid Glass backing — the same engine system menus use on 26.
            let glass = NSGlassEffectView(frame: bounds)
            glass.cornerRadius = 22
            glass.style = .regular
            glass.autoresizingMask = [.width, .height]
            addSubview(glass)
        } else {
            let material = NSVisualEffectView(frame: bounds)
            // `.menu` matches the material native status-bar menus use (`.popover`
            // renders with a cooler tint on dark mode).
            material.material = .menu
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = 22
            material.layer?.masksToBounds = true
            material.autoresizingMask = [.width, .height]
            addSubview(material)
        }
    }
}

final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

final class AccountListTableView: NSTableView, NSTableViewDataSource, NSTableViewDelegate {
    typealias RowViewProvider = (CodexAccount, NSRect) -> NSView

    private let accounts: [CodexAccount]
    private let isInteractionEnabled: Bool
    private let armedEmail: String?
    private let deleteTitle: String
    private let rowHeightProvider: (CodexAccount) -> CGFloat
    private let rowViewProvider: RowViewProvider
    private let onSelect: (CodexAccount) -> Void
    private let onDelete: (CodexAccount) -> Void

    init(
        frame: NSRect,
        accounts: [CodexAccount],
        isInteractionEnabled: Bool,
        armedEmail: String?,
        deleteTitle: String,
        rowSpacing: CGFloat,
        rowHeightProvider: @escaping (CodexAccount) -> CGFloat,
        rowViewProvider: @escaping RowViewProvider,
        onSelect: @escaping (CodexAccount) -> Void,
        onDelete: @escaping (CodexAccount) -> Void
    ) {
        self.accounts = accounts
        self.isInteractionEnabled = isInteractionEnabled
        self.armedEmail = armedEmail
        self.deleteTitle = deleteTitle
        self.rowHeightProvider = rowHeightProvider
        self.rowViewProvider = rowViewProvider
        self.onSelect = onSelect
        self.onDelete = onDelete
        super.init(frame: frame)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        column.width = frame.width
        addTableColumn(column)
        headerView = nil
        dataSource = self
        delegate = self
        style = .plain
        intercellSpacing = NSSize(width: 0, height: rowSpacing)
        backgroundColor = .clear
        selectionHighlightStyle = .none
        allowsMultipleSelection = false
        allowsEmptySelection = true
        columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        accounts.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard accounts.indices.contains(row) else { return 0 }
        return rowHeightProvider(accounts[row])
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard accounts.indices.contains(row) else { return nil }
        let account = accounts[row]
        let contentWidth = tableColumn
            .flatMap { tableColumns.firstIndex(of: $0) }
            .map { frameOfCell(atColumn: $0, row: row).width }
            ?? bounds.width
        return rowViewProvider(
            account,
            NSRect(x: 0, y: 0, width: contentWidth, height: rowHeightProvider(account))
        )
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard isInteractionEnabled, armedEmail == nil, accounts.indices.contains(row) else { return false }
        return !accounts[row].isActive
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = selectedRow
        guard accounts.indices.contains(row) else { return }
        let account = accounts[row]
        deselectAll(nil)
        onSelect(account)
    }

    func tableView(
        _ tableView: NSTableView,
        rowActionsForRow row: Int,
        edge: NSTableView.RowActionEdge
    ) -> [NSTableViewRowAction] {
        guard edge == .trailing,
              isInteractionEnabled,
              armedEmail == nil,
              accounts.indices.contains(row),
              !accounts[row].isActive else {
            return []
        }
        return [NSTableViewRowAction(style: .destructive, title: deleteTitle) { [weak self] _, row in
            self?.deleteAccount(at: row)
        }]
    }

    func deleteAccount(at row: Int) {
        guard isInteractionEnabled,
              accounts.indices.contains(row),
              !accounts[row].isActive else {
            return
        }
        onDelete(accounts[row])
    }
}

final class RoundedPanelView: NSView {
    private let fillColor: NSColor
    private let hoverFillColor: NSColor?
    private let borderColor: NSColor
    private let cornerRadius: CGFloat
    private let clickAction: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(frame: NSRect, fillColor: NSColor, borderColor: NSColor, cornerRadius: CGFloat = 18, hoverFillColor: NSColor? = nil, clickAction: (() -> Void)? = nil, shadowOpacity: Float = 0.12, shadowRadius: CGFloat = 12) {
        self.fillColor = fillColor
        self.hoverFillColor = hoverFillColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.clickAction = clickAction
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = borderColor.cgColor
        layer?.shadowColor = NSColor(red: 0.01, green: 0.02, blue: 0.035, alpha: 1).cgColor
        layer?.shadowOpacity = shadowOpacity
        layer?.shadowRadius = shadowRadius
        layer?.shadowOffset = NSSize(width: 0, height: -5)
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
        isHovering = true
        layer?.backgroundColor = hoverFillColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
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
            let base = hoverFillColor ?? fillColor
            let pressed = base.blended(withFraction: 0.12, of: .white) ?? base
            layer?.backgroundColor = pressed.cgColor
            clickAction()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.layer?.backgroundColor = (self.isHovering ? self.hoverFillColor : nil)?.cgColor ?? self.fillColor.cgColor
            }
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

final class PanelMarkView: NSView {
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
        let plate = bounds.insetBy(dx: 1, dy: 1)
        color.withAlphaComponent(0.12).setFill()
        plate.roundedPath(radius: 12).fill()
        color.withAlphaComponent(0.34).setStroke()
        let outline = plate.roundedPath(radius: 12)
        outline.lineWidth = 1
        outline.stroke()

        let bars: [NSRect] = [
            NSRect(x: 11, y: 11, width: 20, height: 3),
            NSRect(x: 11, y: 19, width: 14, height: 3),
            NSRect(x: 11, y: 27, width: 20, height: 3)
        ]
        color.withAlphaComponent(0.96).setFill()
        for (index, bar) in bars.enumerated() {
            let shifted = index == 1 ? bar.offsetBy(dx: 6, dy: 0) : bar
            shifted.roundedPath(radius: 1.5).fill()
        }
    }
}

final class MetricValueView: NSView {
    private let percent: Int?
    private let color: NSColor
    private let isActive: Bool

    init(frame: NSRect, percent: Int?, color: NSColor, isActive: Bool) {
        self.percent = percent
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
        let value = percent.map { "\(max(0, min(100, $0)))" } ?? "--"
        let valueFont: NSFont = NSFont.roundedSystemFont(ofSize: 32, weight: isActive ? .bold : .semibold)
        let percentFont: NSFont = NSFont.roundedSystemFont(ofSize: 13, weight: .bold)
        let text = NSMutableAttributedString(
            string: value,
            attributes: [
                .font: valueFont,
                .foregroundColor: color,
                .kern: -1.3
            ]
        )
        text.append(NSAttributedString(
            string: "\u{2009}%",
            attributes: [
                .font: percentFont,
                .foregroundColor: color.withAlphaComponent(0.90),
                .baselineOffset: 3.0,
                .kern: 0.2
            ]
        ))
        text.draw(at: NSPoint(x: 0, y: 3))
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
    private let startColor: NSColor
    private let endColor: NSColor
    private let trackColor: NSColor
    private let percent: CGFloat

    init(frame: NSRect, color: NSColor, trackColor: NSColor = NSColor.white.withAlphaComponent(0.11), percent: CGFloat, isMeter: Bool = false) {
        self.startColor = color
        self.endColor = isMeter && color == .meterBlue ? .meterBlueDeep : color
        self.trackColor = trackColor
        self.percent = max(0, min(1, percent))
        super.init(frame: frame)
        wantsLayer = true
    }

    init(
        frame: NSRect,
        startColor: NSColor,
        endColor: NSColor,
        trackColor: NSColor = NSColor.white.withAlphaComponent(0.11),
        percent: CGFloat
    ) {
        self.startColor = startColor
        self.endColor = endColor
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
        guard fill.width > 0 else { return }
        let clip = fill.roundedPath(radius: track.height / 2)
        let gradient = NSGradient(starting: startColor, ending: endColor)
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        gradient?.draw(in: fill, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class PoolVerdictCardView: NSView {
    private let presentation: PoolVerdictPresentation
    private let theme: PanelTheme

    init(frame: NSRect, presentation: PoolVerdictPresentation, theme: PanelTheme) {
        self.presentation = presentation
        self.theme = theme
        let style = Self.style(for: presentation.kind, theme: theme)
        super.init(frame: frame)

        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.backgroundColor = style.fill.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = style.border.cgColor

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(presentation.accessibilityLabel)

        let showsForecast = presentation.kind != .collecting
            && presentation.capacityFraction != nil
            && presentation.coverageLabel != nil
            && presentation.coverageValue != nil
            && presentation.accountValue != nil
            && presentation.accountLabel != nil
        let headerOffset: CGFloat = showsForecast ? 0 : 24
        let symbolView = PoolVerdictSymbolView(
            frame: NSRect(x: 14, y: 12 + headerOffset, width: 32, height: 32),
            color: style.accent,
            symbol: style.symbol,
            accessibilityLabel: presentation.accessibilityLabel
        )
        addSubview(symbolView)

        let summaryWidth: CGFloat = showsForecast ? ForecastCardLayout.summaryWidth : 0
        let summaryGap: CGFloat = showsForecast ? 10 : 0
        let textTrailingInset: CGFloat = 14 + summaryWidth + summaryGap
        addSubview(Self.label(
            frame: NSRect(x: 56, y: 10 + headerOffset, width: bounds.width - 56 - textTrailingInset, height: 19),
            text: presentation.title,
            font: .systemFont(ofSize: 15, weight: .semibold),
            color: theme.primaryText
        ))
        addSubview(Self.label(
            frame: NSRect(x: 56, y: 31 + headerOffset, width: bounds.width - 56 - textTrailingInset, height: 16),
            text: presentation.subtitle,
            font: .systemFont(ofSize: 11),
            color: theme.secondaryText
        ))

        if let coverageLabel = presentation.coverageLabel,
           let coverageValue = presentation.coverageValue {
            let summaryX = bounds.width - 14 - summaryWidth
            addSubview(Self.label(
                frame: NSRect(x: summaryX, y: 10, width: summaryWidth, height: 13),
                text: coverageLabel,
                font: .systemFont(ofSize: 9.5, weight: .semibold),
                color: theme.secondaryText,
                alignment: .right
            ))
            let summaryValueLabel = Self.label(
                frame: NSRect(x: summaryX, y: 23, width: summaryWidth, height: 19),
                text: coverageValue,
                font: .monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                color: style.accent,
                alignment: .right
            )
            summaryValueLabel.setAccessibilityLabel("\(coverageLabel) \(coverageValue)")
            addSubview(summaryValueLabel)
        }

        guard showsForecast,
              let capacityFraction = presentation.capacityFraction,
              let accountValue = presentation.accountValue,
              let accountLabel = presentation.accountLabel else { return }

        let accountX = bounds.width - 14 - ForecastCardLayout.accountWidth
        let trackX = ForecastCardLayout.horizontalInset
        let trackWidth = accountX - ForecastCardLayout.lowerGap - trackX
        addSubview(Self.label(
            frame: NSRect(x: trackX, y: 51, width: trackWidth, height: 12),
            text: LocalizedText.value(.verdictCapacityWithResets, language: presentation.language),
            font: .systemFont(ofSize: 9.5, weight: .medium),
            color: theme.secondaryText
        ))
        let trackView = PoolCapacityTrackView(
            frame: NSRect(
                x: trackX,
                y: ForecastCardLayout.trackY,
                width: trackWidth,
                height: ForecastCardLayout.trackHeight
            ),
            fraction: capacityFraction,
            accent: style.accent,
            track: theme.progressTrack
        )
        trackView.setAccessibilityIdentifier("pool-capacity-track")
        trackView.setAccessibilityElement(true)
        trackView.setAccessibilityRole(.progressIndicator)
        trackView.setAccessibilityValue("\(Int((capacityFraction * 100).rounded()))%")
        addSubview(trackView)

        addResetIndicators(
            presentation.resetIndicators,
            x: trackX,
            y: 83,
            width: trackWidth,
            accent: style.accent
        )

        addSubview(Self.label(
            frame: NSRect(x: accountX, y: 53, width: ForecastCardLayout.accountWidth, height: 20),
            text: accountValue,
            font: .monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            color: theme.primaryText,
            alignment: .right
        ))
        addSubview(Self.label(
            frame: NSRect(x: accountX, y: 75, width: ForecastCardLayout.accountWidth, height: 14),
            text: accountLabel,
            font: .systemFont(ofSize: 9.5, weight: .medium),
            color: theme.secondaryText,
            alignment: .right
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    private func addResetIndicators(
        _ indicators: [String],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        accent: NSColor
    ) {
        guard !indicators.isEmpty else { return }
        let gap: CGFloat = 4
        let pillWidth = (width - gap * CGFloat(indicators.count - 1)) / CGFloat(indicators.count)
        for (index, text) in indicators.enumerated() {
            let pill = NSView(frame: NSRect(
                x: x + CGFloat(index) * (pillWidth + gap),
                y: y,
                width: pillWidth,
                height: 17
            ))
            pill.wantsLayer = true
            pill.layer?.cornerRadius = 5
            pill.layer?.backgroundColor = (index == 0
                ? accent.withAlphaComponent(0.14)
                : theme.bottomBarFill).cgColor
            pill.addSubview(Self.label(
                frame: NSRect(x: 5, y: 2, width: pillWidth - 10, height: 13),
                text: text,
                font: .monospacedDigitSystemFont(ofSize: 9, weight: .medium),
                color: index == 0 ? accent : theme.secondaryText,
                alignment: .center
            ))
            addSubview(pill)
        }
    }

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

    private static func label(
        frame: NSRect,
        text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.font = font
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        return label
    }
}

private enum ForecastCardLayout {
    static let horizontalInset: CGFloat = 18
    static let summaryWidth: CGFloat = 124
    static let accountWidth: CGFloat = 106
    static let lowerGap: CGFloat = 12
    static let trackY: CGFloat = 67
    static let trackHeight: CGFloat = 8
}

private final class PoolCapacityTrackView: NSView {
    private let fraction: CGFloat
    private let accent: NSColor
    private let track: NSColor

    init(frame: NSRect, fraction: Double, accent: NSColor, track: NSColor) {
        self.fraction = CGFloat(max(0, min(1, fraction)))
        self.accent = accent
        self.track = track
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        track.setFill()
        bounds.roundedPath(radius: bounds.height / 2).fill()
        if fraction > 0 {
            accent.setFill()
            NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
                .roundedPath(radius: bounds.height / 2)
                .fill()
        }
        accent.setFill()
        NSRect(x: bounds.maxX - 2, y: 0, width: 2, height: bounds.height)
            .roundedPath(radius: 1)
            .fill()
    }
}

private final class PoolVerdictSymbolView: NSView {
    private let color: NSColor
    private let symbol: String

    init(frame: NSRect, color: NSColor, symbol: String, accessibilityLabel: String) {
        self.color = color
        self.symbol = symbol
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(accessibilityLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return }
        image.isTemplate = true
        NSColor.black.withAlphaComponent(0.72).set()
        image.draw(in: bounds.insetBy(dx: 8, dy: 8))
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
        let numberFont: NSFont = NSFont.roundedSystemFont(ofSize: 29, weight: .semibold)
        let percentFont: NSFont = NSFont.roundedSystemFont(ofSize: 15, weight: .semibold)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: color
        ]
        let percentAttributes: [NSAttributedString.Key: Any] = [
            .font: percentFont,
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
        (on ? NSColor.systemGreen : offColor).setFill()
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
        let lineWidth: CGFloat = isActive ? 5 : 3.5
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
        font = .systemFont(ofSize: frame.height <= 24 ? 9.5 : 11.5, weight: .bold)
        contentTintColor = .white
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = min(9, frame.height * 0.38)
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
        layer?.shadowColor = pillColor.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 8
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
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = min(10, frame.height * 0.30)
        layer?.backgroundColor = tintColor.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1
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
        layer?.backgroundColor = tintColor.withAlphaComponent(0.08).cgColor
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
        cell?.lineBreakMode = .byTruncatingTail
        cell?.usesSingleLineMode = true
        font = .systemFont(ofSize: min(12, max(10, frame.height * 0.42)), weight: .semibold)
        contentTintColor = textColor
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = min(9, frame.height * 0.34)
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

extension NSRect {
    func roundedPath(radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
    }
}

extension DateFormatter {
    static let diagnosticStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

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

    static let directFiveHourUsage: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static let directWeeklyUsage: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

}
