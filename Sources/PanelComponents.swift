import AppKit
import Foundation

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
        let material = NSVisualEffectView(frame: bounds)
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 22
        material.layer?.masksToBounds = true
        material.autoresizingMask = [.width, .height]
        addSubview(material)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        let isDark = effectiveAppearance.isDarkMode
        let base = isDark
            ? NSColor(red: 0.027, green: 0.034, blue: 0.045, alpha: 0.16)
            : NSColor(red: 0.925, green: 0.94, blue: 0.958, alpha: 0.20)
        base.setFill()
        rect.fill()

        let topGlow = NSGradient(
            starting: isDark ? NSColor(red: 0.12, green: 0.19, blue: 0.18, alpha: 0.42) : NSColor(red: 0.70, green: 0.90, blue: 0.82, alpha: 0.42),
            ending: base.withAlphaComponent(0)
        )
        topGlow?.draw(in: NSRect(x: -90, y: -150, width: rect.width + 180, height: 360), relativeCenterPosition: NSPoint(x: -0.10, y: 0.18))

        let sideGlow = NSGradient(
            starting: isDark ? NSColor(red: 0.14, green: 0.20, blue: 0.30, alpha: 0.28) : NSColor(red: 0.74, green: 0.82, blue: 0.94, alpha: 0.30),
            ending: base.withAlphaComponent(0)
        )
        sideGlow?.draw(in: NSRect(x: rect.width * 0.36, y: rect.height * 0.42, width: rect.width * 0.88, height: rect.height * 0.72), relativeCenterPosition: NSPoint(x: 0.22, y: -0.10))

        let gridColor = isDark ? NSColor.white.withAlphaComponent(0.024) : NSColor.black.withAlphaComponent(0.022)
        gridColor.setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 0.5
        var x: CGFloat = 22
        while x < rect.width {
            grid.move(to: NSPoint(x: x, y: 0))
            grid.line(to: NSPoint(x: x, y: rect.height))
            x += 44
        }
        var y: CGFloat = 22
        while y < rect.height {
            grid.move(to: NSPoint(x: 0, y: y))
            grid.line(to: NSPoint(x: rect.width, y: y))
            y += 44
        }
        grid.stroke()

        (isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.09)).setStroke()
        let border = rect.insetBy(dx: 1, dy: 1).roundedPath(radius: 24)
        border.lineWidth = 1
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

final class AccentRailView: NSView {
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
        color.withAlphaComponent(0.92).setFill()
        bounds.roundedPath(radius: bounds.width / 2).fill()
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
        let text = NSMutableAttributedString(
            string: value,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 32, weight: isActive ? .bold : .semibold),
                .foregroundColor: color,
                .kern: -1.3
            ]
        )
        text.append(NSAttributedString(
            string: "\u{2009}%",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
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
