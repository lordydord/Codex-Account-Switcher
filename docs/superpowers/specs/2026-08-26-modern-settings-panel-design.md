# Modern Settings Panel Design

**Date:** 2026-08-26  
**Surface:** macOS menu-bar panel settings  
**Status:** Approved design

## Goal

Replace the legacy fixed-coordinate AppKit Settings screen with a concise, modern SwiftUI screen that follows the visual grammar of the redesigned account panel and behaves like a native current-version macOS settings surface.

The redesign removes controls that no longer represent the product, keeps ordinary settings immediately understandable, and moves infrequent maintenance controls into a compact Advanced screen.

## Product decisions

- Remove the `Weekly / 5H` menu-bar display selector.
- Remove the usage percentage from the macOS status item entirely. The status item remains a compact app icon; per-account five-hour and weekly limits remain visible together inside the account panel.
- Remove the Settings health-status section. Internal health checks continue to support diagnostics but are not shown as an always-visible dashboard.
- Remove the duplicate `Add account` action from Settings. Account creation remains available from the account panel.
- Keep routine preferences on the first screen.
- Move numeric thresholds and infrequent maintenance actions into an Advanced screen.
- Replace the hard-coded three-day reset-credit expiry window with a persisted user preference.
- Check releases from `smashlight/Codex-Account-Switcher`, never the original author's repository.

## Information architecture

### Settings root

The root screen uses one vertically scrolling column only if the available panel height requires it. At the normal panel size, the complete root screen should fit without scrolling.

#### Header

- Title: `Настройки` / `Settings`.
- Secondary label: `Codex Account Switcher`.
- One trailing `Готово` / `Done` button returns to the account list.

#### General section

One language row uses a native segmented `Picker` for Russian and English. Language changes apply immediately and preserve the existing language-store behavior.

#### Automation section

1. **Follow Codex / ChatGPT**
   - Native system switch.
   - Preserves the existing launch/follow behavior.
   - Subtitle explains that the switcher follows the Codex or ChatGPT lifecycle.

2. **Usage limit reminder**
   - Native system switch that enables or disables reminder notifications.
   - Subtitle includes the current saved percentage, for example `Предупреждать при остатке 20%`.
   - The threshold is edited on the Advanced screen, not in a dialog.

3. **Reset-credit expiry**
   - Native system switch that enables or disables expiry notifications.
   - Subtitle includes the current saved lead time, for example `За 3 дня до истечения`.
   - The lead time is edited on the Advanced screen, not in a dialog.

4. **Auto switch**
   - Navigation row rather than a binary switch because the existing preference supports several modes.
   - The trailing summary describes the selected behavior, for example `Спросить при 10%` or `Выключено`.
   - Activating the row preserves the existing auto-switch editor and its behavior. Redesigning that auxiliary editor is outside this task.

#### Advanced navigation

A final full-width row contains an ellipsis-style utility icon, `Дополнительно` / `Advanced`, a short description, and a disclosure chevron. It navigates within the same panel; it does not open a separate window or alert.

### Advanced screen

The Advanced screen uses the same header and section components. Its leading Back action returns to the Settings root.

#### Notification values

1. **Reminder threshold**
   - Compact right-aligned numeric field.
   - Visible `%` suffix outside the editable text.
   - Valid inclusive range: `1...99`.
   - Initial value comes from the existing `usageReminderThreshold` preference.

2. **Reset-credit warning**
   - Compact right-aligned numeric field.
   - Localized `days` suffix outside the editable text.
   - Valid inclusive range: `1...30`.
   - Default: `3` days.
   - Persist under a new dedicated UserDefaults key.
   - Notification evaluation uses this preference instead of the current hard-coded three-day `TimeInterval`.

Both values commit on Return or focus loss. A valid value updates UserDefaults immediately and refreshes the root-screen summary. Invalid or empty text does not change the saved value. The field receives a restrained error border and an inline localized validation message; no modal alert appears. Escape restores the saved value.

#### Refresh frequency

Expose the existing active and idle refresh intervals as two native menus or pickers in one section:

- active Codex: existing choices `5`, `15`, `30`, and `60` seconds;
- background/idle: existing choices `15`, `30`, and `60` seconds.

Selection saves immediately. The old refresh-settings dialog is no longer used from Settings.

#### Maintenance

Use ordinary full-width action rows:

- **Check for updates** calls the existing release comparison pipeline against `https://api.github.com/repos/smashlight/Codex-Account-Switcher/releases/latest`. When a newer release is available, every repository or release action opens `https://github.com/smashlight/Codex-Account-Switcher/releases` or the release URL returned by that repository. The UI must never direct the user to `lordydord/Codex-Account-Switcher`.
- **Save reference plugins** invokes the existing reference-capture workflow and preserves its confirmations and error reporting.
- **Diagnostics** invokes the existing diagnostics workflow. Health information remains available there rather than occupying the root Settings screen.

The screen does not include `Add account`, a separate reminder-threshold dialog action, a health dashboard, or destructive cleanup actions that were not requested.

## Visual design

Use the approved single-column native-list direction:

- dark translucent surfaces derived from existing `PanelTheme` semantic colors;
- one restrained glass card per semantic section;
- rounded corners, subtle borders, and spacing from the repository design system;
- small tinted symbol tiles to distinguish row roles without creating a colorful dashboard;
- clear title/subtitle hierarchy and intrinsic-width localized controls;
- monospaced digits for percentage and interval values;
- no fixed frames tailored to one language.

The Settings view reuses the account panel's visual grammar but does not copy its information architecture or usage gradients.

## Native controls and interaction

- Boolean controls are genuine SwiftUI `Toggle` values using the platform switch style. Do not re-create the track, thumb, hover state, focus ring, fill transition, or on/off colors.
- The switch uses the current macOS system rendering and user accent behavior. Active and inactive fills come from the system.
- Language uses a genuine segmented SwiftUI `Picker`.
- Tappable rows use `Button`, not `onTapGesture` or custom clickable `NSView` implementations.
- All controls have localized accessibility labels, values, and hints where the visible subtitle is insufficient.
- Keyboard focus order follows visual order. Return commits an edited numeric value; Escape restores it.

## Motion

- Root-to-Advanced navigation uses a restrained directional slide combined with opacity, approximately 200 milliseconds.
- Back navigation mirrors the direction.
- Panel size changes animate smoothly rather than jumping.
- Row hover changes only surface emphasis and icon tint.
- System switches own their native thumb and fill animation; the app adds no competing custom animation.
- Validation changes use a short opacity/color transition and no shake effect.
- No repeating or ornamental animation is allowed.
- When Reduce Motion is enabled, directional and spring movement becomes a short opacity transition while system controls retain their platform-provided accessible behavior.

## Architecture

The existing AppKit panel continues to own menu-bar window lifecycle, placement, activation, and final frame. Settings content is hosted with `NSHostingView`.

Use small SwiftUI units with narrow responsibilities:

- `SettingsScreenView`: root composition and navigation destination state;
- `SettingsHeader`: title, subtitle, and one navigation action;
- `SettingsSection`: semantic glass-card container;
- `SettingsToggleRow`: title, subtitle, symbol, and native switch;
- `SettingsNavigationRow`: title, summary, symbol, and disclosure affordance;
- `SettingsNumericFieldRow`: validated numeric draft, suffix, commit, and restore behavior;
- `AdvancedSettingsView`: notification values, refresh frequency, and maintenance actions.

Business rules remain outside SwiftUI views:

- a pure validation policy clamps or rejects supported numeric settings;
- AppDelegate continues to own preferences, notifications, refresh scheduling, update checks, and maintenance workflows;
- the hosted view receives values and explicit callbacks rather than reaching into `UserDefaults` directly.

Do not introduce a new architecture layer or dependency. Extract only the state and validation logic needed to keep the views small and testable.

## Localization

All newly visible strings are added to the existing localization system in Russian and English. This includes screen titles, section titles, row titles, summaries, field suffixes, validation messages, action progress/results where displayed inside Settings, and accessibility text.

Existing English-only Settings strings are migrated as part of this screen because leaving them would make the redesigned localized screen internally inconsistent.

## Error and progress states

- Invalid numeric input is handled inline and never overwrites a valid saved value.
- Maintenance actions retain their existing error-reporting behavior. If the redesigned screen shows an in-progress state, only the activated row is disabled and displays a compact progress indicator.
- A failed update request must report the failure with context and keep the user on the Advanced screen.
- The screen retains stable outer geometry when an inline validation message appears.

## Testing and verification

Add or update tests for:

- numeric validation boundaries and invalid input for reminder percent and reset-credit lead days;
- default and persisted reset-credit warning days;
- conversion of saved warning days to the expiry evaluation interval;
- update endpoint and repository/release URL ownership;
- removal of Settings actions for `usageWeekly` and `usageFiveHour`;
- status-item presentation no longer depending on `UsageDisplayMode` and no longer displaying a usage percentage;
- root and Advanced presentation state summaries where pure presentation helpers are introduced;
- Russian and English localized strings required by the new screen.

Run the repository's infrastructure and AppKit interaction test suites, build the application, install it, and relaunch it for user-owned visual verification. Visual acceptance covers:

- current macOS native switch appearance and animation;
- Settings-to-Advanced and Back transitions;
- light/dark behavior supported by the surrounding panel theme;
- Reduce Motion behavior;
- Russian and English layout;
- keyboard editing, Return, Escape, and focus loss for numeric fields;
- update actions opening only the `smashlight` repository.

No commit or push of the implementation occurs until the user visually approves the installed application.

## Out of scope

- Redesigning the auto-switch editor, plugin workflow dialogs, diagnostics output, or other auxiliary alerts.
- Redesigning API Mode or Reset Credits screens.
- Adding new automation features.
- Showing aggregate usage in the macOS status item.
- Changing how five-hour or weekly account usage is fetched or calculated.
