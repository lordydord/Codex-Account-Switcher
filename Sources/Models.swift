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

struct ApiUsageSnapshot: Equatable {
    let usedTokens: Int
    let limitTokens: Int
    let warningPercent: Int
    let lastUpdatedText: String
    let lastError: String?

    var usedPercent: Int {
        guard limitTokens > 0 else { return 0 }
        return max(0, min(100, Int((Double(usedTokens) / Double(limitTokens)) * 100.0)))
    }

    var remainingTokens: Int {
        max(0, limitTokens - usedTokens)
    }
}

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
    case api
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
    case apiView
    case setupApiMode
    case switchApiMode
    case editApiLimit
    case refreshApiUsage
    case testApiReminder
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

    static func current(for appearance: NSAppearance?) -> PanelTheme {
        PanelTheme(isDark: appearance?.isDarkMode ?? NSApp.effectiveAppearance.isDarkMode)
    }

    var primaryText: NSColor {
        isDark ? NSColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1) : NSColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
    }

    var secondaryText: NSColor {
        isDark ? NSColor(red: 0.58, green: 0.62, blue: 0.68, alpha: 1) : NSColor(red: 0.37, green: 0.41, blue: 0.46, alpha: 1)
    }

    var tertiaryText: NSColor {
        isDark ? NSColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1) : NSColor(red: 0.49, green: 0.53, blue: 0.58, alpha: 1)
    }

    var valueText: NSColor {
        isDark ? NSColor(red: 0.75, green: 0.79, blue: 0.84, alpha: 1) : NSColor(red: 0.24, green: 0.28, blue: 0.33, alpha: 1)
    }

    var inactiveAccent: NSColor {
        isDark ? NSColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1) : NSColor(red: 0.47, green: 0.51, blue: 0.56, alpha: 1)
    }

    var activeCardFill: NSColor {
        isDark ? NSColor(red: 0.045, green: 0.105, blue: 0.088, alpha: 0.94) : NSColor(red: 0.91, green: 0.97, blue: 0.935, alpha: 0.98)
    }

    var inactiveCardFill: NSColor {
        isDark ? NSColor(red: 0.060, green: 0.073, blue: 0.093, alpha: 0.96) : NSColor(red: 0.955, green: 0.965, blue: 0.978, alpha: 0.98)
    }

    var inactiveCardHoverFill: NSColor {
        isDark ? NSColor(red: 0.082, green: 0.101, blue: 0.128, alpha: 1) : NSColor(red: 0.985, green: 0.99, blue: 1.0, alpha: 1)
    }

    var inactiveCardBorder: NSColor {
        isDark ? NSColor(red: 0.42, green: 0.48, blue: 0.56, alpha: 0.16) : NSColor(red: 0.18, green: 0.23, blue: 0.29, alpha: 0.12)
    }

    var bottomBarFill: NSColor {
        isDark ? NSColor(red: 0.055, green: 0.068, blue: 0.087, alpha: 0.98) : NSColor(red: 0.93, green: 0.945, blue: 0.965, alpha: 0.98)
    }

    var divider: NSColor {
        isDark ? NSColor(red: 0.48, green: 0.54, blue: 0.62, alpha: 0.14) : NSColor(red: 0.18, green: 0.22, blue: 0.27, alpha: 0.10)
    }

    var iconTint: NSColor {
        isDark ? NSColor(red: 0.64, green: 0.69, blue: 0.75, alpha: 1) : NSColor(red: 0.34, green: 0.39, blue: 0.44, alpha: 1)
    }

    var ringTrack: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.075) : NSColor.black.withAlphaComponent(0.075)
    }

    var progressTrack: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.09) : NSColor.black.withAlphaComponent(0.08)
    }

    var inactiveButtonFill: NSColor {
        isDark ? NSColor(red: 0.12, green: 0.145, blue: 0.18, alpha: 1) : NSColor(red: 0.88, green: 0.905, blue: 0.935, alpha: 1)
    }

    var usageInactiveButtonFill: NSColor {
        isDark ? NSColor(red: 0.14, green: 0.165, blue: 0.20, alpha: 1) : NSColor(red: 0.31, green: 0.35, blue: 0.40, alpha: 0.96)
    }

    var switchOffFill: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.18)
    }
}

enum ApiUsageFetchResult {
    case success(Int)
    case failure(String)
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
