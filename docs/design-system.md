# Codex Account Switcher Design System

**Version:** 1.0

**Date:** 2026-08-18

**Status:** Canonical direction for new UI and incremental redesigns

**Platform:** macOS 14+

**Appearance:** Dark only

## 1. Purpose

This document is the visual and interaction source of truth for Codex Account Switcher. Use it when creating a new screen, changing an existing screen, or deciding whether a one-off visual value belongs in the product.

The current main usage panel is the reference implementation. Settings, API Mode, Reset Credits, and auxiliary dialogs should move toward the same system incrementally rather than being redesigned independently.

When implementation and this document disagree:

1. This document defines the intended product direction.
2. Semantic tokens in [`PanelTheme`](../Sources/Models.swift) define the current executable values.
3. Reusable components in [`PanelComponents.swift`](../Sources/PanelComponents.swift) and [`AccountRowView.swift`](../Sources/AccountRowView.swift) define current interaction behavior.
4. One-off values in screen-building code are legacy details, not new design tokens.

## 2. Product Principles

### Native macOS first

- Use native controls, keyboard focus, trackpad gestures, tooltips, and SF Symbols.
- Preserve familiar macOS behavior even when the visual treatment is custom.
- Use AppKit only for capabilities that SwiftUI cannot currently provide reliably, such as the existing panel lifecycle and native table-row swipe action.

### Dark, warm glass

- The product has one visual appearance: dark.
- Surfaces are translucent layers over a native macOS material, not opaque gray rectangles.
- Borders are quiet and low-contrast. Color is reserved for state and action.
- Do not add a white/light theme, purple aurora backgrounds, saturated decorative gradients, or ornamental glow.

`PanelTheme` still contains light-appearance branches for compatibility with older code. They are technical debt and must not be treated as an approved light design.

### Compact but breathable

- Optimize for quick scanning in a menu-bar panel.
- Keep information dense, but separate semantic sections with real spacing.
- Prefer fewer, stronger containers over nested boxes.
- Never solve fitting problems by clipping text or moving content beyond a container boundary.

### Status is explicit

- Color reinforces meaning; it never carries meaning alone.
- Percentages, state labels, and action text remain visible.
- Unknown, loading, empty, warning, error, and destructive states are designed states, not fallback accidents.

## 3. Foundations

### 3.1 Backdrop and material

The root panel uses:

- macOS 26+: `NSGlassEffectView`, regular style;
- macOS 14–15: `NSVisualEffectView` with `.menu` material, `.behindWindow` blending, and active state;
- root corner radius: `22 pt`;
- transparent, non-opaque window with the native panel shadow.

This behavior is implemented by `DashboardBackgroundView` in [`PanelComponents.swift`](../Sources/PanelComponents.swift).

Do not simulate glass with a static dark fill. Reduced Transparency and older-system behavior must continue to rely on the native material fallback.

### 3.2 Core color palette

| Token | Value | Role |
| --- | --- | --- |
| `nativeMint` | `#47D7A5` | healthy quota, positive verdict, active-account start |
| `nativeBlue` | `#64B9FF` | healthy progress endpoint |
| `nativeGold` | `#FFD166` | warning progress start |
| `nativeOrange` | `#FF8F3F` | warning label and progress endpoint |
| `nativeCoral` | `#FF8A7A` | critical progress start and negative surface tint |
| `nativeRed` | `#E83F54` | critical quota, negative verdict, destructive emphasis |
| `warmWhite` | `#F5F3EE` | high-contrast warm value when semantic white is needed |
| `warmGreen` | `#4ADE80` | generic healthy status |
| `warmAmber` | `#FF9F0A` | generic caution status |
| `warmRed` | `#FF453A` | generic error/critical status |
| `meterBlue` | `#4FB6C3` | legacy/API meter accent |
| `meterBlueDeep` | `#3584A3` | legacy/API meter gradient endpoint |

Use semantic names in code. Raw RGB/hex values must not be repeated in individual views.

### 3.3 Dark surface tokens

All values are composited over the native material.

| Semantic token | Current value | Use |
| --- | --- | --- |
| `primaryText` | `labelColor` | titles, important values, primary actions |
| `secondaryText` | `secondaryLabelColor` | supporting values and metadata |
| `tertiaryText` | `tertiaryLabelColor` | timestamps, captions, low-priority detail |
| `valueText` | `labelColor` at `86%` | prominent numerical values |
| `activeCardFill` | white at `10.5%` | selected/active surfaces |
| `inactiveCardFill` | white at `6.5%` | default cards and rows |
| `inactiveCardHoverFill` | white at `13%` | hover state without movement |
| `inactiveCardBorder` | white at `14%` | neutral one-pixel border |
| `bottomBarFill` | white at `7.5%` | toolbars and compact utility strips |
| `divider` | label color at `13%` | separators |
| `iconTint` | label color at `72%` | neutral SF Symbols |
| `ringTrack` | label color at `9%` | circular meter track |
| `progressTrack` | label color at `12%` | linear meter track |
| `inactiveButtonFill` | label color at `14%` | neutral text button |
| `usageInactiveButtonFill` | label color at `18%` | stronger utility button |
| `switchOffFill` | white at `18%` | inactive compact switch |

Do not introduce raw `Color.gray`, opaque charcoal card fills, or pure white text when a semantic system color exists.

### 3.4 Semantic quota bands

Account quota and forecast visuals use remaining capacity:

| Remaining | State | Gradient | Label |
| --- | --- | --- | --- |
| `26–100%` | healthy | mint → blue | mint |
| `11–25%` | warning | gold → orange | orange |
| `0–10%` | critical | coral → red | red |
| unknown | neutral | subdued secondary → secondary | secondary |

The 14-day pool chart is the explicit exception: its fill represents gross daily **consumed** capacity across the normalized weekly account pool. It reuses the semantic palette with spend-specific thresholds:

| Daily pool spend | State | Gradient |
| --- | --- | --- |
| `0–14.3%` | within daily reference | mint → blue |
| `>14.3–25%` | above daily reference | gold → orange |
| `>25%` | high daily spend | coral → red |
| unknown | no usable observations | track only |

The dashed `14.3%` reference represents an even one-seventh-per-day pace. It is context, not a forecast or hard budget.

These boundaries come from `WeeklyRemainingBand` in [`AppInfrastructure.swift`](../Sources/AppInfrastructure.swift). Always clamp presented percentages to `0...100`.

`usageStatusColor(for:)` uses a separate generic health scale (`≥50` green, `20–49` amber, `<20` red). Do not mix the generic scale with the quota gradient in the same component.

### 3.5 Typography

Use the rounded system design for product UI and monospaced digits for changing numerical values.

| Role | Size | Weight | Typical use |
| --- | ---: | --- | --- |
| Screen title | `22–24 pt` | semibold/bold | Settings, API Mode, Reset Vault |
| Section/empty title | `18 pt` | semibold | empty states, major card heading |
| Verdict title | `15 pt` | semibold | forecast verdict |
| Body/action | `12–13 pt` | medium/semibold | buttons, primary descriptions |
| Account identity | `11.5 pt` | medium/semibold | email and row identity |
| Detail | `10–11 pt` | medium | reset time, status detail |
| Micro label | `8.8–9.5 pt` | medium/semibold | chart axes, badges, tertiary metadata |

Rules:

- Use `.leading`, `.trailing`, and `.center`; never encode layout direction as left/right in new SwiftUI code.
- Use `.monospacedDigit()` or `monospacedDigitSystemFont` for percentages, durations, dates, and counters that update in place.
- Primary content is one line only when truncation is intentional and the full value is available through a tooltip or accessibility label.
- New scalable SwiftUI screens should prefer semantic text styles. If a fixed compact macOS size is necessary, document the role and verify it in Russian and English.
- Do not create a new font family.

### 3.6 Spacing scale

Use this scale rather than inventing adjacent values:

| Token | Value | Use |
| --- | ---: | --- |
| `space.2` | `2 pt` | optical correction only |
| `space.4` | `4 pt` | tightly related text lines |
| `space.6` | `6 pt` | compact row gap |
| `space.8` | `8 pt` | control gap, compact section gap |
| `space.10` | `10 pt` | toolbar grouping |
| `space.12` | `12 pt` | standard content gap, verdict separation |
| `space.14` | `14 pt` | usage-panel inset, compact card inset |
| `space.16` | `16 pt` | regular card inset |
| `space.18` | `18 pt` | settings/secondary-screen outer inset |
| `space.22` | `22 pt` | spacious empty-state/card content |

Prefer the larger token when two adjacent regions feel crowded. The `12 pt` gap between the verdict and reset-chance cards is the reference for separating two different semantic blocks.

### 3.7 Corner radii

| Token | Value | Use |
| --- | ---: | --- |
| `radius.control` | `9 pt` | compact text buttons |
| `radius.compact` | `14 pt` | badges and compact bars |
| `radius.card` | `16 pt` | account rows, reset chance, footer |
| `radius.section` | `18 pt` | verdict and large content cards |
| `radius.window` | `22 pt` | root panel material |

Use continuous rounded rectangles in SwiftUI. Borders are `1 pt` unless a native focus ring owns emphasis.

### 3.8 Elevation

- Default card: black at `9%`, radius `5 pt`, vertical offset `3 pt` in SwiftUI.
- Active card: black at `18%`, radius `9 pt`, vertical offset `3 pt`.
- AppKit legacy card: very dark blue-black shadow, opacity about `7–12%`, radius `10–12 pt`.
- Hover may brighten the fill and add a restrained accent shadow; it must not translate or scale the component.
- Do not stack multiple visible shadows on nested surfaces.

## 4. Layout System

### 4.1 Screen sizes

| Screen | Canonical size |
| --- | --- |
| Usage | `520 pt` wide; height adapts to rows and visible screen |
| Settings | `432 × 590 pt` |
| API Mode | `432 × 520 pt` |
| Reset Credits, 1–2 accounts | `432 × 520 pt` |
| Reset Credits, 3+ accounts | `468 × 640 pt` |

The panel remains at least `8 pt` inside the visible screen edge. Height is capped by the current screen; only the content collection that needs overflow should scroll.

### 4.2 Usage-screen vertical order

1. Account list.
2. Pool history chart.
3. Forecast verdict.
4. Reset chance strip.
5. Bottom toolbar.

The aggregate sections and toolbar remain visible while only the account list scrolls.

Current metrics:

| Element | Value |
| --- | ---: |
| Usage outer inset | `14 pt` |
| Account row | `39 pt` |
| Expanded confirmation row | `78 pt` |
| Account row gap | `4 pt` |
| Pool chart | `104 pt` |
| Verdict card | `108 pt` |
| Verdict → reset chance gap | `12 pt` |
| Reset chance strip | `44 pt` |
| Bottom toolbar | `40 pt` |

### 4.3 Adaptive layout rules

- A component receives available space from its parent; it never reads a global screen width.
- Use `HStack`/`VStack`, layout priorities, intrinsic button sizes, and `.frame(maxWidth: .infinity, alignment:)`.
- Text and flexible content compress before percentages, destructive actions, or primary buttons disappear.
- Use `ViewThatFits` when localized actions may need a vertical fallback.
- One measurement-dependent primitive, such as a progress fill, may use `GeometryReader`; the rest of the row must remain relative.
- Do not calculate reusable content with construction-time `x`, `y`, and width coordinates.
- Do not fix a text width merely to match one Russian or English string.
- Decoration belongs in `background`/`overlay`; use `ZStack` only for peer layers that jointly define layout.

## 5. Components

### 5.1 Glass card

Base anatomy:

- semantic translucent fill;
- one-pixel low-contrast border;
- `16` or `18 pt` radius;
- optional restrained shadow;
- content inset from the spacing scale;
- hover brightness only when the entire surface is interactive.

Do not nest a full glass card inside another full glass card. Use dividers or spacing for internal grouping.

### 5.2 Account row

Reference: [`AccountRowView.swift`](../Sources/AccountRowView.swift).

Normal state contains:

- `28 pt` numbered badge;
- email and weekly reset detail;
- a flexible two-line remaining-capacity meter with five-hour usage above weekly usage;
- a fixed, visible `five-hour / weekly` percentage pair at the trailing edge.

The five-hour meter is the primary actionable status. Its `4 pt` track, semantic palette, trailing value, active badge, and active border use the five-hour remaining percentage. The weekly `3 pt` meter and trailing value use their own semantic palette at reduced opacity so the longer-term allowance remains visible without competing with the current window.

The identity column expands and truncates first. The meter stack has a useful minimum width; the percentage pair never leaves the row. Unknown and mixed availability remain explicit, for example `-- / 80%` or `10% / --`.

States:

- inactive: neutral glass;
- hover: brighter neutral glass, no movement;
- active: five-hour semantic border and badge, with independently colored five-hour and weekly progress;
- warning/critical: semantic quota palette;
- unknown: `--` plus neutral progress treatment;
- confirmation: email, prompt, relaunch detail, intrinsic-width Cancel and Switch buttons;
- maintenance: interaction disabled without hiding current information.

Native `NSTableView` remains the owner of row identity, selection, scrolling, and swipe-to-delete. SwiftUI owns row content.

### 5.3 Progress indicators

- Linear progress uses a subdued capsule track and semantic gradient fill.
- Both account progress fills represent **remaining**, not used, capacity.
- The five-hour account track is `4 pt`; the secondary weekly track is `3 pt` at `55%` opacity.
- Each account track derives its semantic palette independently from its own remaining percentage.
- The daily pool chart is separate: its fill represents normalized gross spend for each day and must be labelled as consumed capacity.
- Values are clamped to `0...100`.
- A numeric label always accompanies color.
- Do not force a fake visible minimum for `0%`; only circular legacy meters may use a documented minimum arc for discoverability.

### 5.4 Forecast verdict card

Reference: `PoolVerdictCardView` in [`PanelComponents.swift`](../Sources/PanelComponents.swift).

Anatomy:

- `32 pt` semantic symbol;
- title and explanatory detail;
- centered signed-margin badge when available;
- three-column timeline: Now, Reset, Capacity Ends;
- visible text for each meaningful interval.

States:

- enough: mint accent and subtle mint surface;
- not enough: red accent and subtle coral surface;
- collecting/unknown: neutral surface, but the same card footprint whenever meaningful partial information can be shown.

Do not remove information merely to make the card compact. Tighten grouping and spacing first.

### 5.5 Reset chance strip

- `44 pt` high compact utility card;
- yellow `bolt.fill`, `16 pt`;
- bold title;
- trailing `24h` and `48h` values with a divider;
- unavailable data uses em dashes without collapsing the component.

### 5.6 Bottom toolbar

- `40 pt` high, `16 pt` radius;
- settings icon, Add, freshness indicator, Reset Credits, Refresh, Quit;
- dividers separate navigation/status from primary and destructive actions;
- text buttons are `26 pt` high;
- Refresh is `68 pt` wide and Quit is `50 pt` wide at the `520 pt` panel width;
- the freshness region absorbs width changes before buttons are clipped.

### 5.7 Buttons

Use a real SwiftUI `Button` or AppKit `NSButton`, never a tap gesture pretending to be a button.

| Variant | Fill | Text | Use |
| --- | --- | --- | --- |
| Neutral | `inactiveButtonFill` | `primaryText` | Cancel, Refresh, navigation |
| Accent | semantic color at controlled opacity | primary/white | Switch, redeem, selected action |
| Destructive quiet | red at `14–22%` | system red | Quit, delete entry point |
| Destructive committed | red at about `72%` | white | armed confirmation only |

Compact text buttons:

- height `26–30 pt`;
- horizontal padding at least `12 pt`;
- `9 pt` radius;
- semibold `12 pt` text;
- intrinsic width in SwiftUI; never clip a localized title;
- visible focus ring and disabled state.

### 5.8 Empty, loading, and error states

- Preserve the normal screen structure; replace content, not the entire visual language.
- Loading should use stable placeholders or `.redacted(reason: .placeholder)` where appropriate.
- Empty states include a concise title, one sentence of recovery guidance, and no more than two actions.
- Errors show actionable text and preserve the user's previous data when possible.
- Never display `0%` when the value is actually unknown; use `--` or an em dash.

## 6. Interaction Patterns

### Account switch

1. Clicking an inactive row expands that same row.
2. The row shows Cancel and Switch without opening a modal.
3. No account mutation happens before Switch is pressed.
4. Switching disables conflicting row actions while preserving context.

### Account deletion

1. Swipe left on an inactive row.
2. Reveal one native destructive Delete action.
3. Pressing Delete executes immediately; there is no additional confirmation.
4. The active account never exposes deletion.
5. Only the exact selected account identity is passed to the command layer.

### Hover and press

- Hover is supplementary, never required for discovery.
- Hover changes brightness/border contrast; it does not move layout.
- Pressed state is a brief increase in contrast.
- Until shared motion tokens are implemented, use native/system timing rather than inventing per-screen durations.
- Respect Reduce Motion and Reduced Transparency.

### Keyboard and focus

- Every action is reachable by keyboard.
- Use native focus rings.
- Do not remove focus styling merely because it differs from the pointer state.
- Logical focus order follows the visual top-to-bottom, leading-to-trailing sequence.

## 7. Iconography

- Use SF Symbols as template images.
- Neutral icons use `iconTint`; semantic icons use the corresponding status token.
- Common inline symbol size: `16–17 pt`.
- Common toolbar hit target: at least `28 × 28 pt`; prefer `32 pt` where space allows.
- A symbol next to an explicit text label is decorative for accessibility.
- Standalone icon buttons require a localized tooltip and accessibility label.
- Do not mix filled and outlined variants without a state reason.

## 8. Localization

Supported languages are Russian and English; Russian is the default for a new installation. Current copy is centralized in [`Localization.swift`](../Sources/Localization.swift).

Rules:

- Every new user-facing string must exist in both languages in the same change.
- Pass complete sentences to localization; never concatenate translated fragments.
- Dynamic values use locale-aware formatting and interpolation.
- Layout is verified with the longer of the Russian and English strings.
- Use leading/trailing alignment and intrinsic button width.
- Truncation is permitted for account identifiers when a tooltip exposes the complete value; it is not permitted for action titles or critical state.
- New SwiftUI localization should move toward `LocalizedStringResource`/String Catalogs when that area is deliberately migrated. Do not mix two localization systems inside one small component without a migration plan.

## 9. Accessibility

- Use native controls (`Button`, `Toggle`, `NSTableView`) wherever possible.
- Color is always paired with text, percentage, shape, or symbol.
- Decorative symbols use `accessibilityHidden(true)`; meaningful symbols have localized labels.
- Group related row/card content with `.accessibilityElement(children:)` or the AppKit equivalent.
- Expose the account email, five-hour and weekly remaining percentages, reset detail, and active state in the account-row accessibility value.
- Custom controls require a native accessibility representation or explicit role, label, value, and action.
- Disabled controls remain visible and announce their disabled state.
- Dynamic/scalable text must not overlap or hide actions.
- Verify VoiceOver order after changing a compound card.

## 10. SwiftUI and AppKit Architecture

### New and redesigned content

Prefer SwiftUI for content and layout:

- one dedicated `View` type per independently evolving section;
- narrow immutable inputs;
- business rules prepared outside `body`;
- `@State` private and used only for state owned by the view;
- `@Binding` only when the child mutates parent-owned state;
- native `Button` for actions;
- `foregroundStyle`, continuous shapes, and modern modifiers;
- stable identity in every collection;
- no `AnyView` unless type erasure is unavoidable.

### AppKit boundaries

AppKit remains appropriate for:

- borderless menu-bar panel lifecycle and positioning;
- status item integration;
- native `NSTableView` swipe actions;
- OS services that have no suitable SwiftUI equivalent.

Embed SwiftUI content with `NSHostingView`. The parent AppKit container owns the final frame. Hosted reusable content must fill the proposed width and must not impose an intrinsic width on a table cell. Gesture hit testing must deliberately preserve either table gestures or hosted controls, as demonstrated by `AccountRowHostingView`.

### Prohibited layout patterns

- construction-time coordinate math for reusable row/card content;
- global screen-width reads inside a component;
- fixed text frames chosen for one language;
- invisible overflow used to make a clipped control appear correct;
- custom clickable `NSView`/`onTapGesture` when a native button is sufficient;
- duplicated raw palette values;
- a new full-screen view implemented as one large body or one large AppKit builder method.

## 11. Screen Composition Template

Use this structure when redesigning Settings, API Mode, or Reset Credits:

1. `ScreenView`: owns only screen-level composition and injected state.
2. `ScreenHeader`: title, optional subtitle, one navigation action.
3. Dedicated semantic sections with narrow inputs.
4. `GlassCard`/utility strip styles from shared tokens.
5. One persistent bottom action bar only when actions must remain visible.
6. A single scroll owner for variable-length content.
7. Empty/loading/error states that preserve the same outer geometry.

Do not copy the usage panel's exact information architecture to another screen. Reuse its visual grammar, tokens, component behavior, and density.

The current Settings implementation follows this template with a SwiftUI root screen and an in-panel Advanced screen. Boolean rows use a compact macOS-style switch with a visible thumb, language uses a native segmented control, and numeric notification values commit inline without modal dialogs. The menu-bar status item shows the active account's five-hour remaining percentage; weekly and per-account details remain in the account panel.

## 12. Migration Priorities

1. **Settings:** replace fixed AppKit coordinates with adaptive SwiftUI sections and localized intrinsic-width controls.
2. **API Mode:** reuse shared cards, status colors, progress components, and screen header.
3. **Reset Credits:** convert account cards and credit rows to adaptive SwiftUI components while retaining exact command safety.
4. **Auxiliary dialogs:** normalize typography, buttons, localization, and destructive states after the primary screens.
5. **Token implementation:** move spacing, radii, typography roles, and component styles into shared Swift types as each screen migrates; do not create a speculative parallel framework in advance.

## 13. Review Checklist

Before accepting a new or redesigned screen:

### Visual

- [ ] Dark appearance only; no white surface or unapproved accent.
- [ ] Colors come from semantic tokens.
- [ ] Spacing and radii use the documented scale.
- [ ] Important values use monospaced digits where movement would be distracting.
- [ ] No clipped text, percentages, buttons, or focus rings.
- [ ] Unknown, empty, loading, error, and disabled states are intentional.

### Layout

- [ ] The component adapts to the width proposed by its parent.
- [ ] Russian and English fit without one-language frame hacks.
- [ ] Only the variable-length collection scrolls.
- [ ] Primary and destructive actions stay visible.
- [ ] No reusable content depends on manual `x` coordinates.

### Interaction

- [ ] Every action is a native accessible control.
- [ ] Hover is optional and does not shift layout.
- [ ] Keyboard focus order is logical and focus rings are visible.
- [ ] Swipe, click, scrolling, and inline buttons do not steal events from one another.
- [ ] Destructive behavior protects the active account and uses exact identity.

### Engineering

- [ ] SwiftUI is preferred for new content; AppKit use is justified by a platform capability.
- [ ] Views have narrow inputs and business rules remain testable outside the view.
- [ ] Repeated styling is a shared style/token, not copied modifiers.
- [ ] New strings exist in Russian and English.
- [ ] Accessibility labels/values are localized and tested.
- [ ] Automated layout/interaction tests cover the regression risk.
- [ ] Full tests, build, and `git diff --check` pass.
