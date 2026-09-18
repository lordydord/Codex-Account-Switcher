import AppKit
import SwiftUI

struct NativeSettingsSwitch: NSViewRepresentable {
    let isOn: Bool
    let onChange: (Bool) -> Void

    final class Coordinator: NSObject {
        let onChange: (Bool) -> Void

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        @objc func changed(_ sender: NSSwitch) {
            onChange(sender.state == .on)
        }
    }

    static func makeControl(isOn: Bool) -> NSSwitch {
        let control = NSSwitch()
        control.controlSize = .small
        control.state = isOn ? .on : .off
        control.sizeToFit()
        return control
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSSwitch {
        let control = Self.makeControl(isOn: isOn)
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        return control
    }

    func updateNSView(_ control: NSSwitch, context: Context) {
        let nextState: NSControl.StateValue = isOn ? .on : .off
        if control.state != nextState {
            control.state = nextState
        }
    }
}

struct SettingsScreenView: View {
    let language: AppLanguage
    let theme: PanelTheme
    let followsCodex: Bool
    let remindersEnabled: Bool
    let creditExpiryEnabled: Bool
    let reminderThreshold: Int
    let creditExpiryLeadDays: Int
    let autoSwitchSummary: String
    let activeRefreshInterval: Int
    let idleRefreshInterval: Int
    let onLanguageChanged: (AppLanguage) -> Void
    let onFollowChanged: (Bool) -> Void
    let onRemindersChanged: (Bool) -> Void
    let onCreditExpiryChanged: (Bool) -> Void
    let onAutoSwitch: () -> Void
    let onReminderThresholdCommit: (String) -> Bool
    let onCreditExpiryLeadDaysCommit: (String) -> Bool
    let onActiveRefreshChanged: (Int) -> Void
    let onIdleRefreshChanged: (Int) -> Void
    let onCheckUpdates: () -> Void
    let onSavePlugins: () -> Void
    let onDiagnostics: () -> Void
    let onDone: () -> Void

    @State private var showsAdvanced = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showsAdvanced {
                AdvancedSettingsView(
                    language: language,
                    theme: theme,
                    reminderThreshold: reminderThreshold,
                    creditExpiryLeadDays: creditExpiryLeadDays,
                    activeRefreshInterval: activeRefreshInterval,
                    idleRefreshInterval: idleRefreshInterval,
                    onBack: { navigate(toAdvanced: false) },
                    onReminderThresholdCommit: onReminderThresholdCommit,
                    onCreditExpiryLeadDaysCommit: onCreditExpiryLeadDaysCommit,
                    onActiveRefreshChanged: onActiveRefreshChanged,
                    onIdleRefreshChanged: onIdleRefreshChanged,
                    onCheckUpdates: onCheckUpdates,
                    onSavePlugins: onSavePlugins,
                    onDiagnostics: onDiagnostics
                )
                .transition(transition(insertionEdge: .trailing))
            } else {
                rootContent
                    .transition(transition(insertionEdge: .leading))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2), value: showsAdvanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rootContent: some View {
        SettingsSurface(theme: theme) {
            SettingsHeader(
                title: LocalizedText.value(.settingsTitle, language: language),
                subtitle: LocalizedText.value(.settingsSubtitle, language: language),
                actionTitle: LocalizedText.value(.doneButton, language: language),
                action: onDone,
                actionAccessibility: LocalizedText.value(.settingsDoneAccessibility, language: language)
            )

            SettingsSection(title: LocalizedText.value(.generalSection, language: language), theme: theme) {
                HStack(spacing: 12) {
                    SettingsSymbol(symbol: "character.book.closed", theme: theme)
                    Text(LocalizedText.value(.languageLabel, language: language))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color(nsColor: theme.primaryText))
                    Spacer(minLength: 8)
                    Picker("", selection: Binding(
                        get: { language },
                        set: onLanguageChanged
                    )) {
                        Text(LocalizedText.value(.russianOption, language: language)).tag(AppLanguage.russian)
                        Text(LocalizedText.value(.englishOption, language: language)).tag(AppLanguage.english)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 144)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            SettingsSection(title: LocalizedText.value(.automationSection, language: language), theme: theme) {
                SettingsToggleRow(
                    symbol: "eye",
                    title: LocalizedText.value(.followCodexToggle, language: language),
                    detail: language == .russian ? "Показывать вместе с Codex или ChatGPT" : "Show with Codex or ChatGPT",
                    isOn: followsCodex,
                    language: language,
                    theme: theme,
                    action: onFollowChanged
                )
                SettingsToggleRow(
                    symbol: "bell",
                    title: LocalizedText.value(.usageReminderToggle, language: language),
                    detail: language == .russian ? "Предупреждать при остатке \(reminderThreshold)%" : "Alert at \(reminderThreshold)% remaining",
                    isOn: remindersEnabled,
                    language: language,
                    theme: theme,
                    action: onRemindersChanged
                )
                SettingsToggleRow(
                    symbol: "clock.badge.exclamationmark",
                    title: LocalizedText.value(.creditExpiryToggle, language: language),
                    detail: language == .russian ? "За \(creditExpiryLeadDays) дн. до истечения" : "\(creditExpiryLeadDays) days before expiry",
                    isOn: creditExpiryEnabled,
                    language: language,
                    theme: theme,
                    action: onCreditExpiryChanged
                )
                SettingsNavigationRow(
                    symbol: "arrow.triangle.2.circlepath",
                    title: LocalizedText.value(.autoSwitchRow, language: language),
                    detail: autoSwitchSummary,
                    language: language,
                    theme: theme,
                    action: onAutoSwitch
                )
            }

            SettingsNavigationRow(
                symbol: "ellipsis.circle",
                title: LocalizedText.value(.advancedRow, language: language),
                detail: LocalizedText.value(.advancedSubtitle, language: language),
                language: language,
                theme: theme,
                action: { navigate(toAdvanced: true) }
            )
        }
    }

    private func navigate(toAdvanced: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2)) {
            showsAdvanced = toAdvanced
        }
    }

    private func transition(insertionEdge: Edge) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: insertionEdge).combined(with: .opacity),
                removal: .move(edge: insertionEdge == .leading ? .trailing : .leading).combined(with: .opacity)
            )
    }
}

private struct AdvancedSettingsView: View {
    let language: AppLanguage
    let theme: PanelTheme
    let reminderThreshold: Int
    let creditExpiryLeadDays: Int
    let activeRefreshInterval: Int
    let idleRefreshInterval: Int
    let onBack: () -> Void
    let onReminderThresholdCommit: (String) -> Bool
    let onCreditExpiryLeadDaysCommit: (String) -> Bool
    let onActiveRefreshChanged: (Int) -> Void
    let onIdleRefreshChanged: (Int) -> Void
    let onCheckUpdates: () -> Void
    let onSavePlugins: () -> Void
    let onDiagnostics: () -> Void

    var body: some View {
        SettingsSurface(theme: theme) {
            SettingsHeader(
                title: LocalizedText.value(.advancedTitle, language: language),
                subtitle: LocalizedText.value(.advancedSubtitle, language: language),
                actionTitle: LocalizedText.value(.backButton, language: language),
                action: onBack,
                actionAccessibility: LocalizedText.value(.settingsBackAccessibility, language: language)
            )

            SettingsSection(title: LocalizedText.value(.advancedSection, language: language), theme: theme) {
                SettingsNumericFieldRow(
                    symbol: "bell",
                    title: LocalizedText.value(.reminderThresholdLabel, language: language),
                    value: reminderThreshold,
                    suffix: LocalizedText.value(.percentSuffix, language: language),
                    errorMessage: LocalizedText.value(.invalidReminderThreshold, language: language),
                    language: language,
                    theme: theme,
                    range: SettingsNumericPolicy.reminderThresholdRange,
                    onCommit: onReminderThresholdCommit
                )
                SettingsNumericFieldRow(
                    symbol: "clock.badge.exclamationmark",
                    title: LocalizedText.value(.creditExpiryLeadDaysLabel, language: language),
                    value: creditExpiryLeadDays,
                    suffix: LocalizedText.value(.daysSuffix, language: language),
                    errorMessage: LocalizedText.value(.invalidCreditExpiryLeadDays, language: language),
                    language: language,
                    theme: theme,
                    range: SettingsNumericPolicy.creditExpiryLeadDaysRange,
                    onCommit: onCreditExpiryLeadDaysCommit
                )
            }

            SettingsSection(title: LocalizedText.value(.refreshSection, language: language), theme: theme) {
                SettingsPickerRow(
                    symbol: "bolt",
                    title: LocalizedText.value(.activeRefreshLabel, language: language),
                    value: activeRefreshInterval,
                    choices: [5, 15, 30, 60],
                    suffix: "s",
                    language: language,
                    theme: theme,
                    action: onActiveRefreshChanged
                )
                SettingsPickerRow(
                    symbol: "moon",
                    title: LocalizedText.value(.idleRefreshLabel, language: language),
                    value: idleRefreshInterval,
                    choices: [15, 30, 60],
                    suffix: "s",
                    language: language,
                    theme: theme,
                    action: onIdleRefreshChanged
                )
            }

            SettingsSection(title: LocalizedText.value(.maintenanceSection, language: language), theme: theme) {
                SettingsActionRow(symbol: "arrow.down.circle", title: LocalizedText.value(.checkUpdatesButton, language: language), language: language, theme: theme, action: onCheckUpdates)
                SettingsActionRow(symbol: "puzzlepiece.extension", title: LocalizedText.value(.pluginsButton, language: language), language: language, theme: theme, action: onSavePlugins)
                SettingsActionRow(symbol: "stethoscope", title: LocalizedText.value(.diagnosticsButton, language: language), language: language, theme: theme, action: onDiagnostics)
            }
        }
    }
}

private struct SettingsSurface<Content: View>: View {
    let theme: PanelTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12, content: content)
                .padding(18)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    let actionAccessibility: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .accessibilityLabel(actionAccessibility)
        }
        .padding(.horizontal, 2)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let theme: PanelTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(nsColor: theme.tertiaryText))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            VStack(spacing: 0, content: content)
                .background(Color(nsColor: theme.inactiveCardFill), in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(nsColor: theme.inactiveCardBorder), lineWidth: 1) }
        }
    }
}

private struct SettingsSymbol: View {
    let symbol: String
    let theme: PanelTheme

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 26, height: 26)
            .background(Color.accentColor.opacity(0.14), in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

private struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isOn: Bool
    let language: AppLanguage
    let theme: PanelTheme
    let action: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            SettingsSymbol(symbol: symbol, theme: theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(Color(nsColor: theme.primaryText))
                Text(detail).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Color(nsColor: theme.secondaryText)).lineLimit(2)
            }
            Spacer(minLength: 8)
            MacOSSettingsSwitch(isOn: isOn, onChange: action, accessibilityLabel: title)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityHint(LocalizedText.value(.settingsToggleHint, language: language))
    }
}

private struct MacOSSettingsSwitch: View {
    let isOn: Bool
    let onChange: (Bool) -> Void
    let accessibilityLabel: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            let update = { onChange(!isOn) }
            if reduceMotion {
                update()
            } else {
                withAnimation(.easeInOut(duration: 0.16)) {
                    update()
                }
            }
        } label: {
            Capsule(style: .continuous)
                .fill(isOn ? Color.accentColor : Color(nsColor: NSColor.tertiaryLabelColor).opacity(0.42))
                .frame(width: 38, height: 22)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                }
        }
        .buttonStyle(.plain)
        .contentShape(.capsule)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SettingsNavigationRow: View {
    let symbol: String
    let title: String
    let detail: String
    let language: AppLanguage
    let theme: PanelTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsSymbol(symbol: symbol, theme: theme)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(Color(nsColor: theme.primaryText))
                    Text(detail).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Color(nsColor: theme.secondaryText)).lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color(nsColor: theme.tertiaryText))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(LocalizedText.value(.settingsNavigationHint, language: language))
    }
}

private struct SettingsActionRow: View {
    let symbol: String
    let title: String
    let language: AppLanguage
    let theme: PanelTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsSymbol(symbol: symbol, theme: theme)
                Text(title).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(Color(nsColor: theme.primaryText))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color(nsColor: theme.tertiaryText))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsNumericFieldRow: View {
    enum Field: Hashable { case value }
    let symbol: String
    let title: String
    let value: Int
    let suffix: String
    let errorMessage: String
    let language: AppLanguage
    let theme: PanelTheme
    let range: ClosedRange<Int>
    let onCommit: (String) -> Bool
    @State private var draft: String
    @State private var showsError = false
    @FocusState private var focusedField: Field?

    init(symbol: String, title: String, value: Int, suffix: String, errorMessage: String, language: AppLanguage, theme: PanelTheme, range: ClosedRange<Int>, onCommit: @escaping (String) -> Bool) {
        self.symbol = symbol; self.title = title; self.value = value; self.suffix = suffix; self.errorMessage = errorMessage; self.language = language; self.theme = theme; self.range = range; self.onCommit = onCommit
        _draft = State(initialValue: String(value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                SettingsSymbol(symbol: symbol, theme: theme)
                Text(title).font(.system(.body, design: .rounded)).foregroundStyle(Color(nsColor: theme.primaryText))
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    TextField("", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .value)
                        .onSubmit { commit() }
                    Text(suffix).font(.system(.caption, design: .rounded)).foregroundStyle(Color(nsColor: theme.secondaryText))
                }
            }
            if showsError {
                Text(errorMessage).font(.system(.caption2, design: .rounded)).foregroundStyle(.red).padding(.leading, 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil { commit() }
        }
        .onChange(of: value) { _, newValue in
            if focusedField == nil { draft = String(newValue) }
        }
        .onExitCommand { draft = String(value); showsError = false; focusedField = nil }
        .accessibilityElement(children: .contain)
        .accessibilityHint(LocalizedText.value(.settingsNumericHint, language: language))
    }

    private func commit() {
        guard SettingsNumericPolicy.normalizedInteger(draft, within: range).map({ _ in true }) == .success(true) else {
            showsError = true
            return
        }
        showsError = !onCommit(draft)
        if !showsError { focusedField = nil }
    }
}

private struct SettingsPickerRow: View {
    let symbol: String
    let title: String
    let value: Int
    let choices: [Int]
    let suffix: String
    let language: AppLanguage
    let theme: PanelTheme
    let action: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            SettingsSymbol(symbol: symbol, theme: theme)
            Text(title).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(Color(nsColor: theme.primaryText))
            Spacer(minLength: 8)
            Picker("", selection: Binding(get: { value }, set: action)) {
                ForEach(choices, id: \.self) { choice in Text("\(choice)\(suffix)").tag(choice) }
            }
            .labelsHidden()
            .frame(width: 84)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
