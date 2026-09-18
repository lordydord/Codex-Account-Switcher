# Pool Verdict and Main-Panel Localization Design

**Date:** 2026-08-17
**Status:** Awaiting written-spec review
**Scope:** Main-panel forecast presentation and first-stage Russian/English localization

## Context

The Native Glass main panel currently exposes internal forecast inputs such as total pool percentage and daily burn. Users must interpret those values and compare them with the next reset themselves. The panel also uses English-only interface strings.

This change replaces the raw forecast sentence with a direct verdict and an event-order scale. It also introduces a reusable two-language localization mechanism. Russian is the default language and English can be selected in Settings without restarting the app.

This specification amends the forecast-line presentation in `2026-08-17-native-glass-main-panel-design.md`; it does not change the pool-history source or sampling cadence.

## Goals

- Answer the user's primary question directly: will the current pooled capacity last until the next weekly reset?
- Explain the verdict with an ordered three-point event scale.
- Remove raw `pool` and `burn` values from the main panel.
- Preserve the existing pool chart and forecast calculations as inputs.
- Support Russian and English main-panel strings through one typed localization interface.
- Default to Russian when no language preference has been saved.
- Apply a language change immediately without relaunching the application.

## First-Stage Localization Scope

This iteration localizes:

- the main account panel;
- the inline manual-switch confirmation;
- the inline quit confirmation;
- the pool-verdict card;
- the reset-chance title;
- main-panel button labels and tooltips;
- the language control itself.

Settings content unrelated to language, auxiliary dialogs, notifications, and technical error messages remain in their current language for this iteration. They will use the same localization mechanism in a later stage.

## Non-goals

- Detecting or following the macOS preferred language automatically.
- Adding languages other than Russian and English.
- Replacing or migrating pool-history data.
- Showing raw pool totals, burn rates, or sustainable-rate limits in the main panel.
- Making the event line a mathematically proportional timeline.
- Redesigning the pool chart, reset-credit screen, or unrelated Settings sections.

## Language Preference

Settings adds one segmented row labelled `Язык / Language` with `Русский` and `English` options. The bilingual row label stays constant so the control remains discoverable in either language.

The selected language is stored in `UserDefaults` as a stable raw value. Missing, empty, or unknown stored values resolve to Russian. Selecting a different language persists the preference and rebuilds the currently visible panel immediately. It must not restart Codex or Codex Account Switcher, alter account state, or trigger network refreshes.

## Localization Architecture

Use a small typed Swift localization layer rather than bundle language overrides or external JSON dictionaries:

- `AppLanguage` defines the supported stable values: Russian and English.
- `LocalizedText` exposes typed keys or typed functions for strings with arguments.
- Each key has both Russian and English values in the same exhaustive switch.
- Formatting inputs remain typed; callers do not assemble translated sentences from fragments.
- Time quantities use language-specific singular and plural forms.

This keeps runtime language switching independent of `Bundle` language selection and fits the existing manually assembled application bundle. It also makes missing translations and unsupported language cases visible to the compiler or unit tests.

Technical logging and upstream error payloads remain unchanged and must not pass through the user-interface localizer in this stage.

## Forecast Verdict Model

The visible verdict answers only whether the capacity exhaustion event occurs before or after the next reset:

1. **Enough:** the reset occurs before predicted exhaustion.
2. **Not enough:** predicted exhaustion occurs before the reset.
3. **Collecting:** the app lacks enough history, burn information, or a reset anchor to order the two events reliably.

A burn rate above the full-week sustainable rate does not by itself produce a negative visible verdict when the current capacity is still forecast to last past the next reset. Raw burn and sustainable-rate comparisons remain internal diagnostics.

The presentation model contains only display-ready semantics:

- verdict kind;
- reset interval;
- exhaustion interval;
- signed margin between the two events;
- selected language.

All intervals are calculated from one captured `now` value so the title, badge, and scale cannot disagree at a boundary.

## Verdict Card

The verdict appears in a separate rounded card directly below the pool chart and directly above `Reset chance by Tibo`.

### Enough

- Subtle green/mint semantic border and background tint.
- Filled green circle with a checkmark.
- Russian title: `Хватит до сброса`.
- English title: `Enough until reset`.
- Secondary text states that current capacity is sufficient.
- Margin badge: `+0,9 дня` / `+0.9 days`.
- Event order: `Сейчас` → `Сброс через …` → `Запас закончится через …`.

### Not Enough

- Subtle red/coral semantic border and background tint.
- Filled red circle with a cross.
- Russian title: `Не хватит до сброса`.
- English title: `Runs out before reset`.
- Secondary text states that capacity will run out first.
- Margin badge: `−0,7 дня` / `−0.7 days`.
- Event order: `Сейчас` → `Запас закончится через …` → `Сброс через …`.

### Collecting

- Neutral border and background tint.
- Neutral progress/history symbol rather than a checkmark or cross.
- Russian title: `Собираем историю`.
- English title: `Collecting history`.
- Secondary text explains that more data is needed for a reliable forecast.
- No margin badge and no event scale are shown until both events can be ordered.

## Event-Order Scale

The scale communicates event order, not proportional elapsed time:

- `Now` is fixed at the left edge.
- The event that happens first is fixed in the center.
- The later event is fixed at the right edge.
- Each label occupies its own left, center, or right column so labels cannot overlap.
- The line from `Now` to the first event uses the verdict's semantic gradient; the remaining segment is subdued.
- Exact relative intervals appear under their respective event points.

This deliberate discrete layout remains legible when the two predicted events are only minutes apart. The signed margin badge communicates the size of the difference.

## Time and Number Formatting

- Forecast intervals below 24 hours are shown in hours; longer intervals are shown in days with one decimal when useful.
- Values close enough to round to zero use a less-than form instead of `0 days`.
- Russian uses the correct `день / дня / дней` and `час / часа / часов` forms.
- English uses singular or plural as appropriate.
- The signed margin badge uses a locale-appropriate decimal separator: comma in Russian and period in English.
- The compact margin badge uses only the signed value; the title and semantic color already explain whether the difference is a buffer or deficit.

## Layout and Sizing

The verdict card replaces the current one-line forecast area. It may increase the fixed forecast section, but the outer panel must retain the currently approved stable-height behavior during account-switch confirmation. The account-list viewport absorbs any required fixed-height adjustment; account rows are not partially clipped.

The card uses the same Native Glass border strength, corner language, typography, and semantic palette as the account rows and chart. It must remain readable at the current `520 pt` panel width in both languages without truncating titles or event labels.

## Data Flow

1. Existing history and reset data enter the current forecast pipeline.
2. A pure verdict evaluator orders reset and exhaustion using a single `now` value.
3. A pure presentation formatter converts the verdict into localized title, detail, badge, and event labels.
4. The AppKit panel renders the display model.
5. Changing language updates `UserDefaults` and rebuilds the panel using the same forecast data.

No language change initiates a usage refresh or changes stored history.

## Error and Unknown Handling

- Missing history, insufficient samples, non-positive or unavailable burn, missing reset anchors, or invalid dates produce the neutral Collecting state.
- Non-finite calculations never reach UI formatting.
- Unknown saved language values fall back to Russian.
- Existing network and storage errors continue through their current paths; this feature does not suppress them.

## Accessibility

- Icons, titles, and text communicate every verdict; color is never the only signal.
- Checkmark and cross symbols have accessibility labels in the selected language.
- The event order is represented by both position and text.
- The language control is keyboard-focusable and announces its selected value.
- Semantic colors retain sufficient contrast in dark and light appearances.

## Verification

Automated tests cover:

- Russian as the default for missing and unknown preferences;
- persistence and restoration of both supported languages;
- complete Russian and English values for every first-stage localization key;
- immediate rebuild behavior without a network refresh side effect;
- Enough, Not Enough, and Collecting verdict mapping;
- an above-sustainable burn that still lasts past reset mapping to Enough;
- signed margin calculation on both sides of the reset boundary;
- event ordering for positive and negative verdicts;
- Russian and English day/hour pluralization and decimal formatting;
- boundary-safe less-than formatting;
- non-finite and incomplete inputs mapping to Collecting.

User visual verification covers:

- Russian and English at the current panel width;
- no overlap among left, center, and right scale labels;
- green, red, and neutral card states;
- dark and light appearance;
- immediate language switching while the main panel is visible;
- stable outer-panel height and complete account rows during inline confirmation.
