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
    var hasFiveHourWindow: Bool = true

    var toolbarRemainingPercent: Int? {
        hasFiveHourWindow ? fiveHourUsedPercent : weeklyUsedPercent
    }
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
    var hasFiveHourWindow: Bool = true
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

enum AutoSwitchMode: String {
    case off
    case ask
    case threshold
    case zero
}

enum AccountPanelMode {
    case usage
    case settings
    case resets
}

enum SettingsPanelAction: String {
    case warmupLimits
    case usageView
    case settingsView
    case resetCreditsView
    case addAccount
    case editLabels
    case removeAccount
    case usageWeekly
    case usageFiveHour
    case languageRussian
    case languageEnglish
    case toggleLaunchAtLogin
    case toggleUsageReminder
    case toggleCreditExpiryNotifications
    case editUsageReminder
    case toggleAutoSwitch
    case editAutoSwitch
    case toggleProtectCodex
    case editRefresh
    case forceRefresh
    case checkUpdates
    case cleanBackups
    case saveReferencePlugins
    case diagnostics
    case quit
}

func usageStatusColor(for percent: Int?) -> NSColor {
    guard let percent else { return .secondaryLabelColor }
    if percent >= 50 { return .warmGreen }
    if percent >= 20 { return .warmAmber }
    return .warmRed
}

// MARK: - Warm glass palette

extension NSColor {
    static let nativeMint = NSColor(red: CGFloat(0x47) / 255.0, green: CGFloat(0xD7) / 255.0, blue: CGFloat(0xA5) / 255.0, alpha: 1)
    static let nativeBlue = NSColor(red: CGFloat(0x64) / 255.0, green: CGFloat(0xB9) / 255.0, blue: CGFloat(0xFF) / 255.0, alpha: 1)
    static let nativeGold = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0xD1) / 255.0, blue: CGFloat(0x66) / 255.0, alpha: 1)
    static let nativeOrange = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0x8F) / 255.0, blue: CGFloat(0x3F) / 255.0, alpha: 1)
    static let nativeCoral = NSColor(red: CGFloat(0xFF) / 255.0, green: CGFloat(0x8A) / 255.0, blue: CGFloat(0x7A) / 255.0, alpha: 1)
    static let nativeRed = NSColor(red: CGFloat(0xE8) / 255.0, green: CGFloat(0x3F) / 255.0, blue: CGFloat(0x54) / 255.0, alpha: 1)
    /// CodexBar-style teal-blue meter fill (#4FB6C3).
    static let meterBlue = NSColor(red: 0.310, green: 0.714, blue: 0.765, alpha: 1)
    /// Deeper variant of the meter gradient (#3584A3).
    static let meterBlueDeep = NSColor(red: 0.208, green: 0.518, blue: 0.639, alpha: 1)
    /// Warm off-white (#F5F3EE).
    static let warmWhite = NSColor(red: 0.960, green: 0.953, blue: 0.933, alpha: 1)
    /// Warm green (#4ADE80).
    static let warmGreen = NSColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1)
    /// Amber / system orange (#FF9F0A).
    static let warmAmber = NSColor(red: 1.000, green: 0.624, blue: 0.039, alpha: 1)
    /// Warm system red (#FF453A).
    static let warmRed = NSColor(red: 1.000, green: 0.271, blue: 0.227, alpha: 1)
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
        NSColor.labelColor
    }

    var secondaryText: NSColor {
        NSColor.secondaryLabelColor
    }

    var tertiaryText: NSColor {
        NSColor.tertiaryLabelColor
    }

    var valueText: NSColor {
        NSColor.labelColor.withAlphaComponent(0.86)
    }

    var inactiveAccent: NSColor {
        NSColor.secondaryLabelColor
    }

    var activeCardFill: NSColor {
        NSColor.white.withAlphaComponent(isDark ? 0.105 : 0.42)
    }

    var inactiveCardFill: NSColor {
        NSColor.white.withAlphaComponent(isDark ? 0.065 : 0.30)
    }

    var inactiveCardHoverFill: NSColor {
        NSColor.white.withAlphaComponent(isDark ? 0.13 : 0.48)
    }

    var inactiveCardBorder: NSColor {
        NSColor.white.withAlphaComponent(isDark ? 0.14 : 0.58)
    }

    var bottomBarFill: NSColor {
        NSColor.white.withAlphaComponent(isDark ? 0.075 : 0.34)
    }

    var divider: NSColor {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.13 : 0.11)
    }

    var iconTint: NSColor {
        NSColor.labelColor.withAlphaComponent(0.72)
    }

    var ringTrack: NSColor {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.09 : 0.08)
    }

    var progressTrack: NSColor {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.12 : 0.10)
    }

    var inactiveButtonFill: NSColor {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.14 : 0.09)
    }

    var usageInactiveButtonFill: NSColor {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.18 : 0.12)
    }

    var switchOffFill: NSColor {
        NSColor.white.withAlphaComponent(0.18)
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
    let accountKey: String
    let email: String
    let accessToken: String
    let accountID: String
    let refreshToken: String?
    let lastRefresh: Date?
}

enum SavedAccountAuthResult {
    case success(SavedAccountAuth)
    case failure(String)
}
