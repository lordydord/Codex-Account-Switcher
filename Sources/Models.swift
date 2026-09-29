import AppKit
import Foundation

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

struct SwitchHistoryEntry: Codable {
    let date: Date
    let fromLabel: String
    let toLabel: String
    let automatic: Bool
    let reason: String
    let result: String
}

struct ResetHistoryEntry: Codable {
    let date: Date
    let accountLabel: String
    let result: String
    let creditBefore: Int?
    let creditAfter: Int?
    let fiveHourRemaining: Int?
    let weeklyRemaining: Int?
    let detail: String
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

let routeBProviderProfiles = [
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

struct UsageLimitWindowSnapshot: Equatable {
    let remainingPercent: Int
    let resetAt: Date?
}

struct DirectUsageSnapshot: Equatable {
    let fiveHour: UsageLimitWindowSnapshot
    let weekly: UsageLimitWindowSnapshot
}

struct ResetConsumeReceipt {
    let code: String
    let windowsReset: Int
    let message: String
}

struct ResetVerificationOutcome {
    let resetSnapshot: ResetCreditsSnapshot?
    let usageSnapshot: DirectUsageSnapshot?
    let creditConfirmed: Bool
    let usageConfirmed: Bool
    let attempts: Int
    let detail: String
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
    case diagnostics
    case quit
}

func usageStatusColor(for percent: Int?) -> NSColor {
    guard let percent else { return .secondaryLabelColor }
    if percent >= 50 { return .systemGreen }
    if percent >= 20 { return .systemOrange }
    return .systemRed
}

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct PanelTheme {
    let isDark: Bool

    enum Tone {
        case green
        case orange
        case red
        case blue
        case indigo
        case neutral
    }

    static func current(for appearance: NSAppearance?) -> PanelTheme {
        PanelTheme(isDark: appearance?.isDarkMode ?? NSApp.effectiveAppearance.isDarkMode)
    }

    private static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    // Text
    var primaryText: NSColor { isDark ? NSColor.white.withAlphaComponent(0.92) : NSColor.black.withAlphaComponent(0.86) }
    var secondaryText: NSColor { isDark ? Self.rgb(0xEBEBF5, 0.66) : Self.rgb(0x3C3C43, 0.76) }
    var tertiaryText: NSColor { isDark ? Self.rgb(0xEBEBF5, 0.46) : Self.rgb(0x3C3C43, 0.58) }

    // Glass surface
    var panelTint: NSColor { isDark ? Self.rgb(0x16171E, 0.50) : Self.rgb(0xF6F6FA, 0.55) }
    var panelEdge: NSColor { isDark ? NSColor.black.withAlphaComponent(0.60) : NSColor.black.withAlphaComponent(0.16) }
    var panelHighlight: NSColor { isDark ? NSColor.white : NSColor.white }

    // Tiles, hairlines and controls
    var tileFill: NSColor { isDark ? NSColor.white.withAlphaComponent(0.06) : NSColor.white.withAlphaComponent(0.55) }
    var tileHoverFill: NSColor { isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.white.withAlphaComponent(0.82) }
    var tileBorder: NSColor { isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.07) }
    var hairline: NSColor { isDark ? NSColor.white.withAlphaComponent(0.09) : NSColor.black.withAlphaComponent(0.08) }
    var controlFill: NSColor { isDark ? NSColor.white.withAlphaComponent(0.09) : NSColor.black.withAlphaComponent(0.05) }
    var controlHoverFill: NSColor { isDark ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.09) }
    var controlBorder: NSColor { isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.06) }
    var segmentTrack: NSColor { isDark ? NSColor.black.withAlphaComponent(0.26) : NSColor.black.withAlphaComponent(0.06) }
    var segmentSelected: NSColor { isDark ? NSColor.white.withAlphaComponent(0.17) : NSColor.white }
    var segmentSelectedBorder: NSColor { isDark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.05) }
    var trackFill: NSColor { isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08) }
    var switchOff: NSColor { isDark ? NSColor.white.withAlphaComponent(0.20) : NSColor.black.withAlphaComponent(0.14) }
    var accent: NSColor { NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? NSColor.controlAccentColor }

    // Semantic colours: `color` for graphics, `text` for readable text on the glass
    var blueText: NSColor { text(.blue) }

    func color(_ tone: Tone) -> NSColor {
        switch tone {
        case .green: return isDark ? Self.rgb(0x30D158) : Self.rgb(0x34C759)
        case .orange: return isDark ? Self.rgb(0xFF9F0A) : Self.rgb(0xFF9500)
        case .red: return isDark ? Self.rgb(0xFF453A) : Self.rgb(0xFF3B30)
        case .blue: return isDark ? Self.rgb(0x0A84FF) : Self.rgb(0x007AFF)
        case .indigo: return isDark ? Self.rgb(0x5E5CE6) : Self.rgb(0x5856D6)
        case .neutral: return secondaryText
        }
    }

    func text(_ tone: Tone) -> NSColor {
        switch tone {
        case .green: return isDark ? Self.rgb(0x4BE07A) : Self.rgb(0x1A7A36)
        case .orange: return isDark ? Self.rgb(0xFFB340) : Self.rgb(0xA34E00)
        case .red: return isDark ? Self.rgb(0xFF7B72) : Self.rgb(0xC4271D)
        case .blue: return isDark ? Self.rgb(0x8CC6FF) : Self.rgb(0x0055B3)
        case .indigo: return isDark ? Self.rgb(0xC3C1FF) : Self.rgb(0x3F3DB8)
        case .neutral: return primaryText
        }
    }

    func tint(_ tone: Tone) -> NSColor {
        if tone == .neutral { return controlFill }
        return color(tone).withAlphaComponent(isDark ? 0.20 : 0.14)
    }

    static func usageTone(for percent: Int?) -> Tone {
        guard let percent else { return .neutral }
        if percent >= 50 { return .green }
        if percent >= 20 { return .orange }
        return .red
    }
}

enum ResetCreditsFetchResult {
    case success(ResetCreditsSnapshot)
    case failure(String)
}

enum ResetCreditRedemptionResult {
    case success(ResetConsumeReceipt)
    case failure(String)
}

enum DirectUsageFetchResult {
    case success(DirectUsageSnapshot)
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
