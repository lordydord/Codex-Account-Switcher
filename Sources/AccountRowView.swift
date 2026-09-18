import AppKit
import SwiftUI

struct AccountRowPalette {
    let start: NSColor
    let end: NSColor
    let label: NSColor

    static func make(remainingPercent: Int?, theme: PanelTheme) -> AccountRowPalette {
        switch WeeklyRemainingBand.classify(remainingPercent) {
        case .healthy:
            return AccountRowPalette(start: .nativeMint, end: .nativeBlue, label: .nativeMint)
        case .warning:
            return AccountRowPalette(start: .nativeGold, end: .nativeOrange, label: .nativeOrange)
        case .critical:
            return AccountRowPalette(start: .nativeCoral, end: .nativeRed, label: .nativeRed)
        case .unknown:
            let neutral = theme.secondaryText.withAlphaComponent(0.65)
            return AccountRowPalette(start: neutral, end: neutral, label: neutral)
        }
    }
}

struct AccountRowView: View {
    let account: CodexAccount
    let displayIndex: Int
    let isArmed: Bool
    let language: AppLanguage
    let theme: PanelTheme
    var warmupState: LimitWarmupState? = nil
    let onCancel: () -> Void
    let onSwitch: () -> Void

    private var fiveHourPalette: AccountRowPalette {
        AccountRowPalette.make(remainingPercent: account.fiveHourUsedPercent, theme: theme)
    }

    private var weeklyPalette: AccountRowPalette {
        AccountRowPalette.make(remainingPercent: account.weeklyUsedPercent, theme: theme)
    }

    private var usagePair: AccountUsagePairText {
        AccountUsagePresentationPolicy.pair(
            fiveHourRemaining: account.fiveHourUsedPercent,
            weeklyRemaining: account.weeklyUsedPercent
        )
    }

    private var weeklyResetText: String {
        WeeklyResetFormatter.text(from: account.weeklyUsage, language: language)
    }

    var body: some View {
        Group {
            if isArmed {
                confirmationContent
            } else {
                usageContent
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(account.email)
        .accessibilityValue(LocalizedText.accountUsageAccessibility(
            pair: usagePair,
            weeklyReset: weeklyResetText,
            language: language
        ))
    }

    private var usageContent: some View {
        HStack(spacing: 12) {
            badge
            accountIdentity
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            AccountUsageMetersView(
                fiveHourLabel: LocalizedText.value(.fiveHourShort, language: language),
                weeklyLabel: LocalizedText.value(.weeklyShort, language: language),
                fiveHourPercent: account.fiveHourUsedPercent,
                weeklyPercent: account.weeklyUsedPercent,
                fiveHourPalette: fiveHourPalette,
                weeklyPalette: weeklyPalette,
                trackColor: Color(nsColor: theme.progressTrack)
            )
            .frame(minWidth: 104, idealWidth: 140, maxWidth: 140)
            percentagePair
        }
    }

    private var percentagePair: some View {
        HStack(spacing: 2) {
            Text(usagePair.fiveHour)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(nsColor: fiveHourPalette.label))
            Text("/")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color(nsColor: theme.tertiaryText))
            Text(usagePair.weekly)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: weeklyPalette.label))
                .opacity(UsagePanelLayoutMetrics.accountSecondaryOpacity)
        }
        .monospacedDigit()
        .frame(width: 74, alignment: .trailing)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }

    private var confirmationContent: some View {
        HStack(spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 4) {
                Text(account.email)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: theme.primaryText))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(account.email)
                Text(LocalizedText.value(.switchPrompt, language: language))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: theme.primaryText))
                    .lineLimit(1)
                Text(LocalizedText.value(.switchRelaunchDetail, language: language))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: theme.tertiaryText))
                    .lineLimit(1)
            }
            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(LocalizedText.value(.cancelButton, language: language), action: onCancel)
                    .buttonStyle(AccountRowButtonStyle(
                        fillColor: Color(nsColor: theme.inactiveButtonFill),
                        textColor: Color(nsColor: theme.primaryText)
                    ))
                Button(LocalizedText.value(.switchButton, language: language), action: onSwitch)
                    .buttonStyle(AccountRowButtonStyle(
                        fillColor: Color(nsColor: fiveHourPalette.end.withAlphaComponent(0.82)),
                        textColor: Color(nsColor: theme.primaryText)
                    ))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var badge: some View {
        Text("\(displayIndex)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color(nsColor: account.isActive ? fiveHourPalette.label : theme.secondaryText))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(nsColor: account.isActive ? fiveHourPalette.start.withAlphaComponent(0.22) : theme.inactiveButtonFill))
            )
            .overlay(
                Circle()
                    .stroke(Color(nsColor: account.isActive ? fiveHourPalette.start.withAlphaComponent(0.78) : theme.inactiveCardBorder), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var accountIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.email)
                .font(.system(size: 11.5, weight: account.isActive ? .semibold : .medium, design: .rounded))
                .foregroundStyle(Color(nsColor: theme.primaryText))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(account.email)
            Text(warmupState?.text(language: language) ?? weeklyResetText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(nsColor: warmupState?.isFailure == true ? .nativeRed : theme.tertiaryText))
                .lineLimit(1)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: account.isActive ? theme.activeCardFill : theme.inactiveCardFill))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color(nsColor: account.isActive
                            ? fiveHourPalette.start.withAlphaComponent(theme.isDark ? 0.48 : 0.40)
                            : theme.inactiveCardBorder),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(account.isActive ? 0.18 : 0.09), radius: account.isActive ? 9 : 5, y: 3)
    }

}

private struct AccountUsageMetersView: View {
    let fiveHourLabel: String
    let weeklyLabel: String
    let fiveHourPercent: Int?
    let weeklyPercent: Int?
    let fiveHourPalette: AccountRowPalette
    let weeklyPalette: AccountRowPalette
    let trackColor: Color

    var body: some View {
        VStack(spacing: 4) {
            labelledProgress(
                label: fiveHourLabel,
                percent: fiveHourPercent,
                palette: fiveHourPalette,
                height: CGFloat(UsagePanelLayoutMetrics.accountPrimaryTrackHeight)
            )
            labelledProgress(
                label: weeklyLabel,
                percent: weeklyPercent,
                palette: weeklyPalette,
                height: CGFloat(UsagePanelLayoutMetrics.accountSecondaryTrackHeight)
            )
            .opacity(UsagePanelLayoutMetrics.accountSecondaryOpacity)
        }
        .accessibilityHidden(true)
    }

    private func labelledProgress(
        label: String,
        percent: Int?,
        palette: AccountRowPalette,
        height: CGFloat
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 7.8, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: palette.label))
                .lineLimit(1)
                .frame(width: 24, alignment: .leading)
            AccountProgressLine(
                percent: percent,
                startColor: Color(nsColor: palette.start),
                endColor: Color(nsColor: palette.end),
                trackColor: trackColor,
                height: height
            )
        }
    }
}

private struct AccountProgressLine: View {
    let percent: Int?
    let startColor: Color
    let endColor: Color
    let trackColor: Color
    let height: CGFloat

    private var progress: CGFloat {
        CGFloat(max(0, min(100, percent ?? 0))) / 100
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(LinearGradient(colors: [startColor, endColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct AccountRowButtonStyle: ButtonStyle {
    let fillColor: Color
    let textColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fillColor.opacity(configuration.isPressed ? 0.72 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 9))
    }
}

final class AccountRowHostingView<Content: View>: NSHostingView<Content> {
    private let passesGesturesToTable: Bool

    init(frame: NSRect, rootView: Content, passesGesturesToTable: Bool) {
        self.passesGesturesToTable = passesGesturesToTable
        super.init(rootView: rootView)
        self.frame = frame
        sizingOptions = []
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("init(rootView:) is unavailable")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        passesGesturesToTable ? nil : super.hitTest(point)
    }
}
