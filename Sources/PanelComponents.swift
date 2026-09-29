import AppKit
import Foundation

// MARK: - Layout primitives

final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

func textWidth(_ text: String, font: NSFont) -> CGFloat {
    ceil((text as NSString).size(withAttributes: [.font: font]).width)
}

func makeLabel(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    monospacedDigits: Bool = false,
    kern: CGFloat? = nil
) -> NSTextField {
    let font: NSFont = monospacedDigits
        ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
        : .systemFont(ofSize: size, weight: weight)
    let field = NSTextField(labelWithString: text)
    field.font = font
    field.textColor = color
    field.alignment = alignment
    field.lineBreakMode = .byTruncatingTail
    field.maximumNumberOfLines = 1
    field.cell?.truncatesLastVisibleLine = true
    if let kern {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        field.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraph
        ])
    }
    field.sizeToFit()
    return field
}

extension NSView {
    /// Adds a label at a position, optionally constraining its width, and returns its frame.
    @discardableResult
    func place(_ view: NSView, x: CGFloat, y: CGFloat, width: CGFloat? = nil, height: CGFloat? = nil) -> NSRect {
        var frame = view.frame
        frame.origin = NSPoint(x: x, y: y)
        if let width { frame.size.width = max(0, width) }
        if let height { frame.size.height = height }
        view.frame = frame
        addSubview(view)
        return frame
    }
}

// MARK: - Glass panel

/// The panel's Liquid Glass surface. On macOS 26 and later this is a real
/// NSGlassEffectView (which honours the system transparency setting); older
/// systems fall back to a popover material with a drawn edge.
final class GlassPanelBackground: NSView {
    let contentView: FlippedContainerView

    init(frame: NSRect, theme: PanelTheme, cornerRadius: CGFloat = 16) {
        contentView = FlippedContainerView(frame: NSRect(origin: .zero, size: frame.size))
        contentView.autoresizingMask = [.width, .height]
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        wantsLayer = true

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.cornerRadius = cornerRadius
            glass.style = .regular
            glass.tintColor = theme.panelTint
            glass.contentView = contentView
            addSubview(glass)
        } else {
            let material = NSVisualEffectView(frame: bounds)
            material.autoresizingMask = [.width, .height]
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = cornerRadius
            material.layer?.cornerCurve = .continuous
            material.layer?.masksToBounds = true
            addSubview(material)

            let tint = NSView(frame: bounds)
            tint.autoresizingMask = [.width, .height]
            tint.wantsLayer = true
            tint.layer?.backgroundColor = theme.panelTint.cgColor
            material.addSubview(tint)
            material.addSubview(contentView)

            let edge = PanelEdgeView(frame: bounds, theme: theme, cornerRadius: cornerRadius)
            edge.autoresizingMask = [.width, .height]
            addSubview(edge)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Darkened outer edge plus a bright top highlight, for systems without NSGlassEffectView.
final class PanelEdgeView: NSView {
    private let theme: PanelTheme
    private let cornerRadius: CGFloat

    init(frame: NSRect, theme: PanelTheme, cornerRadius: CGFloat) {
        self.theme = theme
        self.cornerRadius = cornerRadius
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.25, dy: 0.25), xRadius: cornerRadius, yRadius: cornerRadius)
        outer.lineWidth = 0.5
        theme.panelEdge.setStroke()
        outer.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: cornerRadius - 0.5, yRadius: cornerRadius - 0.5)
        inner.lineWidth = 0.5
        theme.panelHighlight.withAlphaComponent(theme.isDark ? 0.10 : 0.6).setStroke()
        inner.stroke()
    }
}

// MARK: - Tiles

/// A rounded glass tile. With an action it behaves like a large button (hover, click, VoiceOver press).
final class TileView: NSView {
    private var fillColor: NSColor
    private let hoverFillColor: NSColor?
    private let action: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var pressed = false

    init(
        frame: NSRect,
        fill: NSColor,
        border: NSColor? = nil,
        borderWidth: CGFloat = 0.5,
        cornerRadius: CGFloat = 12,
        hoverFill: NSColor? = nil,
        shadow: NSColor? = nil,
        accessibilityLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.fillColor = fill
        self.hoverFillColor = hoverFill
        self.action = action
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = fill.cgColor
        if let border {
            layer?.borderColor = border.cgColor
            layer?.borderWidth = borderWidth
        }
        if let shadow {
            layer?.shadowColor = shadow.cgColor
            layer?.shadowOpacity = 1
            layer?.shadowRadius = 1.5
            layer?.shadowOffset = NSSize(width: 0, height: -1)
        }
        if action != nil {
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
            setAccessibilityLabel(accessibilityLabel)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
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
        pressed = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard action != nil, let hit = super.hitTest(point) else { return super.hitTest(point) }
        return hit is NSControl ? hit : self
    }

    override func mouseDown(with event: NSEvent) {
        guard action != nil else { return super.mouseDown(with: event) }
        pressed = true
        layer?.opacity = 0.82
    }

    override func mouseUp(with event: NSEvent) {
        guard let action else { return super.mouseUp(with: event) }
        layer?.opacity = 1
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        if pressed, inside { action() }
        pressed = false
    }

    override func accessibilityPerformPress() -> Bool {
        guard let action else { return false }
        action()
        return true
    }
}

final class HairlineView: NSView {
    init(frame: NSRect, color: NSColor) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Buttons

final class GlassButton: NSButton {
    enum Style {
        case primary
        case secondary
        case icon
        case text(NSColor)
        case popup
        case use
    }

    private let style: Style
    private let theme: PanelTheme
    private let onPress: () -> Void
    private var trackingArea: NSTrackingArea?
    private var hovering = false
    private var pressedDown = false
    private let buttonTitle: String
    private let fontSize: CGFloat

    init(
        title: String = "",
        symbol: String? = nil,
        style: Style,
        theme: PanelTheme,
        height: CGFloat = 28,
        fontSize: CGFloat = 12,
        accessibilityLabel: String? = nil,
        onPress: @escaping () -> Void
    ) {
        self.style = style
        self.theme = theme
        self.onPress = onPress
        self.buttonTitle = title
        self.fontSize = fontSize
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(firePress)
        if let accessibilityLabel { setAccessibilityLabel(accessibilityLabel) }

        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        var width: CGFloat
        switch style {
        case .icon:
            width = height
            imagePosition = .imageOnly
            let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .semibold)
            image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: accessibilityLabel)?.withSymbolConfiguration(config) }
        case .popup:
            width = textWidth(title, font: .systemFont(ofSize: fontSize, weight: .medium)) + 28
            imagePosition = .imageTrailing
            let config = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        case .text:
            width = textWidth(title, font: font) + 14
            if let symbol {
                imagePosition = .imageTrailing
                let config = NSImage.SymbolConfiguration(pointSize: fontSize - 3, weight: .bold)
                image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                width += 12
            }
        case .primary:
            width = textWidth(title, font: font) + 28
        case .secondary:
            width = textWidth(title, font: .systemFont(ofSize: fontSize, weight: .medium)) + 24
        case .use:
            width = textWidth(title, font: font) + 24
        }
        frame = NSRect(x: 0, y: 0, width: ceil(width), height: height)
        switch style {
        case .icon, .primary, .secondary, .use:
            layer?.cornerRadius = height / 2
        case .popup, .text:
            layer?.cornerRadius = 6
        }
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet { applyAppearance() }
    }

    @objc private func firePress() {
        onPress()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        applyAppearance()
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        pressedDown = flag
        applyAppearance()
    }

    private func applyAppearance() {
        let active = isEnabled && hovering
        var fill: NSColor = .clear
        var textColor = theme.primaryText
        var weight: NSFont.Weight = .semibold
        var borderColor: NSColor?

        switch style {
        case .primary:
            fill = active ? theme.accent.blended(withFraction: 0.12, of: .white) ?? theme.accent : theme.accent
            textColor = .white
        case .secondary:
            fill = active ? theme.controlHoverFill : theme.controlFill
            borderColor = theme.controlBorder
            weight = .medium
        case .icon:
            fill = active ? theme.controlHoverFill : theme.controlFill
            borderColor = theme.controlBorder
            textColor = active ? theme.primaryText : theme.secondaryText
        case .text(let color):
            fill = active ? theme.controlFill : .clear
            textColor = color
            weight = .medium
        case .popup:
            fill = active ? theme.controlHoverFill : theme.controlFill
            borderColor = theme.controlBorder
            weight = .medium
        case .use:
            fill = active ? theme.accent : theme.controlFill
            textColor = active ? .white : theme.primaryText
            borderColor = active ? nil : theme.controlBorder
        }
        if pressedDown {
            fill = fill.blended(withFraction: 0.18, of: theme.isDark ? .black : .gray) ?? fill
        }
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = borderColor?.cgColor
        layer?.borderWidth = borderColor == nil ? 0 : 0.5
        alphaValue = isEnabled ? 1 : 0.45
        contentTintColor = textColor

        if !buttonTitle.isEmpty {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            attributedTitle = NSAttributedString(string: buttonTitle, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: textColor,
                .paragraphStyle: paragraph
            ])
        } else {
            title = ""
        }
    }
}

final class ToggleSwitch: NSButton {
    private let theme: PanelTheme
    private let onToggle: () -> Void

    init(isOn: Bool, theme: PanelTheme, accessibilityLabel: String, onToggle: @escaping () -> Void) {
        self.theme = theme
        self.onToggle = onToggle
        super.init(frame: NSRect(x: 0, y: 0, width: 34, height: 20))
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.switch)
        wantsLayer = true
        focusRingType = .exterior
        state = isOn ? .on : .off
        setAccessibilityLabel(accessibilityLabel)
        target = self
        action = #selector(toggled)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    @objc private func toggled() {
        needsDisplay = true
        onToggle()
    }

    override func draw(_ dirtyRect: NSRect) {
        let on = state == .on
        let track = bounds
        (on ? theme.accent : theme.switchOff).setFill()
        NSBezierPath(roundedRect: track, xRadius: track.height / 2, yRadius: track.height / 2).fill()

        let knobSize = track.height - 4
        let knobX = on ? track.maxX - knobSize - 2 : track.minX + 2
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: knobX, y: track.minY + 2, width: knobSize, height: knobSize)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Segmented tabs

final class SegmentedTabsView: NSView {
    struct Segment {
        let title: String
        let badge: String?
        let isSelected: Bool
        let action: () -> Void
    }

    init(frame: NSRect, theme: PanelTheme, segments: [Segment], fontSize: CGFloat = 12) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = frame.height >= 28 ? 9 : 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = theme.segmentTrack.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = theme.tileBorder.cgColor

        guard !segments.isEmpty else { return }
        let gap: CGFloat = 2
        let segmentRadius: CGFloat = (frame.height >= 28 ? 9 : 8) - 2
        let width = (frame.width - 4 - gap * CGFloat(segments.count - 1)) / CGFloat(segments.count)
        for (index, segment) in segments.enumerated() {
            let rect = NSRect(x: 2 + CGFloat(index) * (width + gap), y: 2, width: width, height: frame.height - 4)
            let tile = TileView(
                frame: rect,
                fill: segment.isSelected ? theme.segmentSelected : .clear,
                border: segment.isSelected ? theme.segmentSelectedBorder : nil,
                cornerRadius: segmentRadius,
                hoverFill: segment.isSelected ? nil : theme.controlFill,
                shadow: segment.isSelected ? NSColor.black.withAlphaComponent(theme.isDark ? 0.30 : 0.12) : nil,
                accessibilityLabel: segment.badge.map { "\(segment.title), \($0)" } ?? segment.title,
                action: segment.isSelected ? nil : segment.action
            )
            if segment.isSelected {
                tile.setAccessibilityElement(true)
                tile.setAccessibilityRole(.button)
                tile.setAccessibilityLabel(segment.title)
                tile.setAccessibilitySelected(true)
            }

            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            let titleLabel = makeLabel(segment.title, size: fontSize, weight: .medium, color: segment.isSelected ? theme.primaryText : theme.secondaryText)
            var groupWidth = textWidth(segment.title, font: font)
            var badgeView: CapsuleTagView?
            if let badge = segment.badge {
                let view = CapsuleTagView(text: badge, theme: theme, foreground: theme.blueText, background: theme.tint(.blue), height: 16, fontSize: 10.5, minWidth: 16)
                groupWidth += 6 + view.frame.width
                badgeView = view
            }
            let startX = max(4, (rect.width - groupWidth) / 2)
            tile.place(titleLabel, x: startX, y: (rect.height - titleLabel.frame.height) / 2, width: min(titleLabel.frame.width + 2, rect.width - 8))
            if let badgeView {
                tile.place(badgeView, x: startX + textWidth(segment.title, font: font) + 6, y: (rect.height - badgeView.frame.height) / 2)
            }
            addSubview(tile)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
}

// MARK: - Small visual pieces

final class CapsuleTagView: NSView {
    private let text: String
    private let foreground: NSColor
    private let background: NSColor
    private let dotColor: NSColor?
    private let font: NSFont

    init(text: String, theme: PanelTheme, foreground: NSColor, background: NSColor, dot: NSColor? = nil, height: CGFloat = 18, fontSize: CGFloat = 10.5, weight: NSFont.Weight = .semibold, minWidth: CGFloat = 0, fixedWidth: CGFloat? = nil) {
        self.text = text
        self.foreground = foreground
        self.background = background
        self.dotColor = dot
        self.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
        let content = textWidth(text, font: font) + (dot == nil ? 0 : 11)
        let width = fixedWidth ?? max(minWidth, content + 14)
        super.init(frame: NSRect(x: 0, y: 0, width: ceil(width), height: height))
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        background.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let size = (text as NSString).size(withAttributes: attributes)
        let content = size.width + (dotColor == nil ? 0 : 11)
        var x = (bounds.width - content) / 2
        if let dotColor {
            dotColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: (bounds.height - 6) / 2, width: 6, height: 6)).fill()
            x += 11
        }
        (text as NSString).draw(at: NSPoint(x: x, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}

final class MonogramView: NSView {
    private let text: String
    private let fill: NSColor
    private let textColor: NSColor
    private let symbol: String?

    init(frame: NSRect, text: String, fill: NSColor, textColor: NSColor, symbol: String? = nil) {
        self.text = text
        self.fill = fill
        self.textColor = textColor
        self.symbol = symbol
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        if let symbol {
            let config = NSImage.SymbolConfiguration(pointSize: bounds.height * 0.42, weight: .semibold)
            guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
            let tinted = image.tinted(with: textColor)
            let size = tinted.size
            tinted.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
            return
        }
        let scale: CGFloat
        switch text.count {
        case 0, 1: scale = 0.44
        case 2: scale = 0.38
        case 3: scale = 0.31
        default: scale = 0.26
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: bounds.height * scale, weight: .semibold),
            .foregroundColor: textColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}

final class SymbolIconView: NSImageView {
    init(frame: NSRect, symbol: String, color: NSColor, pointSize: CGFloat = 13, weight: NSFont.Weight = .semibold) {
        super.init(frame: frame)
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        imageScaling = .scaleProportionallyDown
        contentTintColor = color
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

/// Two concentric Activity-style rings: outer = 5-hour window, inner = weekly.
final class ActivityRingsView: NSView {
    private let outerPercent: Int?
    private let outerColor: NSColor
    private let innerPercent: Int?
    private let innerColor: NSColor
    private let lineWidth: CGFloat

    init(frame: NSRect, outerPercent: Int?, outerColor: NSColor, innerPercent: Int?, innerColor: NSColor, lineWidth: CGFloat = 9) {
        self.outerPercent = outerPercent
        self.outerColor = outerColor
        self.innerPercent = innerPercent
        self.innerColor = innerColor
        self.lineWidth = lineWidth
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        let describe: (Int?) -> String = { $0.map { "\($0) percent left" } ?? "unknown" }
        setAccessibilityLabel("5-hour \(describe(outerPercent)), weekly \(describe(innerPercent))")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 - lineWidth / 2
        let innerRadius = outerRadius - lineWidth - 2
        drawRing(center: center, radius: outerRadius, percent: outerPercent, color: outerColor)
        drawRing(center: center, radius: innerRadius, percent: innerPercent, color: innerColor)
    }

    private func drawRing(center: NSPoint, radius: CGFloat, percent: Int?, color: NSColor) {
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        color.withAlphaComponent(0.20).setStroke()
        track.stroke()

        guard let percent, percent > 0 else { return }
        let fraction = min(1, CGFloat(percent) / 100)
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()
    }
}

/// Label, value and a thin bar — the compact usage meter used in account rows.
final class MeterView: NSView {
    private let title: String
    private let value: String
    private let percent: CGFloat?
    private let color: NSColor
    private let theme: PanelTheme

    init(frame: NSRect, title: String, percent: Int?, color: NSColor, theme: PanelTheme) {
        self.title = title
        self.value = percent.map { "\(max(0, min(100, $0)))%" } ?? "--"
        self.percent = percent.map { CGFloat(max(0, min(100, $0))) / 100 }
        self.color = color
        self.theme = theme
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("\(title) \(value) left")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: theme.secondaryText
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: theme.primaryText
        ]
        (title as NSString).draw(at: NSPoint(x: 0, y: 0), withAttributes: titleAttributes)
        let valueSize = (value as NSString).size(withAttributes: valueAttributes)
        (value as NSString).draw(at: NSPoint(x: bounds.width - valueSize.width, y: 0), withAttributes: valueAttributes)

        let bar = NSRect(x: 0, y: bounds.height - 4, width: bounds.width, height: 4)
        theme.trackFill.setFill()
        NSBezierPath(roundedRect: bar, xRadius: 2, yRadius: 2).fill()
        if let percent, percent > 0 {
            let fill = NSRect(x: bar.minX, y: bar.minY, width: max(4, bar.width * percent), height: bar.height)
            color.setFill()
            NSBezierPath(roundedRect: fill, xRadius: 2, yRadius: 2).fill()
        }
    }
}

/// A row of proportional coloured segments separated by small gaps.
final class StackedBarView: NSView {
    private let segments: [(weight: CGFloat, color: NSColor)]

    init(frame: NSRect, segments: [(weight: CGFloat, color: NSColor)]) {
        self.segments = segments.filter { $0.weight > 0 }
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let total = segments.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return }
        let gap: CGFloat = 3
        let usable = bounds.width - gap * CGFloat(max(0, segments.count - 1))
        var x: CGFloat = 0
        let radius = bounds.height / 2
        for segment in segments {
            let width = usable * segment.weight / total
            segment.color.setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: width, height: bounds.height), xRadius: radius, yRadius: radius).fill()
            x += width + gap
        }
    }
}

// MARK: - Menu bar glyphs

enum MenuBarGlyph {
    /// A small usage ring. The track uses the menu bar's own label colour, so it adapts to light and dark menu bars.
    static func ring(percent: Int?, color: NSColor, diameter: CGFloat = 13, lineWidth: CGFloat = 2.2) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            let radius = (min(rect.width, rect.height) - lineWidth) / 2
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.28).setStroke()
            track.stroke()
            if let percent, percent > 0 {
                let fraction = min(1, CGFloat(percent) / 100)
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static var spinnerCache: [String: NSImage] = [:]

    /// A quarter arc rotated by `frame` steps — the switching / resetting spinner.
    /// The 12 frames are drawn once per colour and size, then reused.
    static func spinner(frame: Int, color: NSColor, diameter: CGFloat = 13, lineWidth: CGFloat = 2.2) -> NSImage {
        let step = frame % 12
        let key = "\(step)|\(diameter)|\(lineWidth)|\(color.description)"
        if let cached = spinnerCache[key] { return cached }
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            let radius = (min(rect.width, rect.height) - lineWidth) / 2
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.22).setStroke()
            track.stroke()
            let start = 90 - CGFloat(step) * 30
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start - 100, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = false
        spinnerCache[key] = image
        return image
    }

    static func symbol(_ name: String, color: NSColor?, pointSize: CGFloat = 12) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return nil }
        guard let color else {
            base.isTemplate = true
            return base
        }
        let tinted = base.tinted(with: color)
        tinted.isTemplate = false
        return tinted
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let source = self
        let image = NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }
}

// MARK: - Shared helpers

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

    static let resetCreditShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
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
