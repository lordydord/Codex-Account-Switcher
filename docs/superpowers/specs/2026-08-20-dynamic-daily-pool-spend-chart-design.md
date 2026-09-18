# Dynamic Daily Pool Spend Chart — Design

**Date:** 2026-08-20
**Status:** Approved
**Surface:** macOS usage panel
**Selected visual direction:** Compact popover (concept A)

## Goal

Replace the current daily-minimum remaining-capacity chart with a dynamic 14-day chart that answers one distinct question:

> What share of the combined weekly account pool was consumed on each calendar day?

The chart must complement, not duplicate, the existing forecast timeline below it. The current-day bar updates whenever a new pool sample arrives, including quiet sampling and manual refresh.

## Non-goals

- Do not show time remaining until reset; the forecast timeline already owns that information.
- Do not present absolute token counts. The direct account usage snapshots provide reliable remaining percentages, not comparable token limits for every saved account.
- Do not change forecast, verdict, reset-chance, account-row, switching, or reset-redemption behavior.
- Do not add chart controls, filters, tabs, or a separate detail screen.

## Metric model

### Normalized pool capacity

Each account with known weekly usage contributes one normalized quota unit of `100` percentage points. The full daily chart track represents the combined normalized capacity of the accounts observed for that day.

Because the direct endpoint exposes percentages rather than absolute plan limits, accounts are equally weighted. The UI must describe the result as a percentage of the **pool**, never as tokens.

### Daily gross spend

For each local calendar day:

1. Sort pool samples chronologically.
2. Match account samples by stable account key.
3. For every consecutive observation of the same account, add only a decrease in remaining weekly capacity:

   `spentPoints += max(0, previousRemaining - currentRemaining)`

4. Ignore increases caused by quota reset, capacity restoration, or account addition. They must not erase already observed spend.
5. Define the day's represented account set as the union of stable account keys in the opening anchor and all samples inside the day. Normalize against `100 × representedAccountCount`, so the result is a percentage of that combined pool.
6. Keep the unrounded value for calculations and animation; round only for user-facing text.

The existing local 30-minute sampling and delta-triggered samples are sufficient. A manual refresh updates today's value immediately when it produces a new usage sample.

### Account composition and incomplete history

- Match deltas only when the same account exists in both observations.
- Adding an account creates capacity but not negative spend.
- Removing or temporarily missing an account does not invent spend.
- Use the newest sample at or before local midnight as the opening anchor when it is no more than one sampling interval old.
- A past day is incomplete when it has no valid opening anchor, when any represented account is absent from that anchor or has fewer than two observations, when consecutive pool observations are separated by more than two sampling intervals, or when the final observation is more than two sampling intervals before day end. Treat its result as a lower bound.
- Today is an in-progress day and is not incomplete merely because the day has not ended. Missing opening coverage, incomplete account coverage, oversized sampling gaps, or a final sample older than two sampling intervals still make today's value a lower bound.
- A day with no usable deltas remains a dated empty slot and must not render as `0%` spend.

The aggregation layer must return explicit completeness metadata rather than making the view infer it from sample count.

## Chart presentation

### Structure

- Preserve exactly 14 chronological local-calendar-day slots ending today.
- Keep the existing compact `104 pt` chart section unless implementation evidence shows the approved compact popover cannot fit without clipping. Any height change requires separate review.
- Each slot has a subdued full-capacity track from `0...100%`.
- The colored fill grows upward from zero and represents normalized gross spend for that day.
- Today's fill animates from its previous value when a new sample arrives and stable day identity is retained.
- Empty days show only the subdued track.
- X-axis labels remain distributed across the full 14-slot range.
- The Y axis remains visually hidden.

### Daily reference

Draw a quiet dashed reference at `14.3%`, representing one seventh of a normalized weekly pool. It is a context aid, not a forecast or hard budget.

- Use a localized micro-label equivalent to `daily reference 14%` only when it fits without colliding with bars, axis labels, or the hover popover.
- The reference uses the existing gold/warning palette at subdued opacity.
- Accessibility must explain that the reference represents an even seven-day pace.

### Semantic colors

Reuse the existing quota palette while adapting its meaning to daily spend:

| Daily pool spend | State | Gradient |
| --- | --- | --- |
| `0...14.3%` | within daily reference | `nativeMint → nativeBlue` |
| `>14.3...25%` | above daily reference | `nativeGold → nativeOrange` |
| `>25%` | high daily spend | `nativeCoral → nativeRed` |
| unknown | no usable data | subdued secondary track only |

Color is supplementary. Hover text and accessibility values always state the numeric spend and its relation to the daily reference.

## Hover interaction

### Selected bar

When the pointer enters a dated slot:

- increase that bar's fill opacity and contrast;
- add a restrained semantic outline/glow that makes the bar appear slightly stronger;
- slightly subdue non-selected bars;
- do not change chart layout, move the bar, or alter the mark width used for layout;
- restore the normal state when hover ends.

Respect Reduce Motion. With reduced motion enabled, update emphasis without animated interpolation.

### Compact popover

Show a readable glass popover directly above the selected bar. It is an overlay, not a layout participant, so hovering must not resize or reposition the chart or panel.

- Anchor the pointer/caret to the selected bar.
- Clamp the popover inside the available chart bounds near the first and last bars.
- Prefer the side with available space when centered placement would clip.
- Use the existing dark material grammar, semantic text colors, low-contrast one-pixel border, compact radius, and restrained shadow.
- Use monospaced digits for all percentages and changing numeric values.
- Use a `164 pt` width and an `80 pt` minimum height so the popup reads as a compact, more square card. Use a `13 pt` date, a `12 pt` body, `12 pt` horizontal padding, and `10 pt` vertical padding so the three concise rows occupy most of the useful width.
- Hide it immediately when the pointer leaves the chart; moving between bars updates it in place.

### Popover content

Normal current day:

```text
20 August
Spent: 18% of pool
Remaining: 36.6%
```

Normal past day:

```text
19 August
Spent: 27% of pool
Remaining: 11%
```

Days with incomplete sampling use the same concise visible wording:

```text
15 August
Spent: 12% of pool
Remaining: 6.6%
```

The chart is an at-a-glance visualization, not an accounting report. Do not show `at least`, `incomplete day`, sampling gaps, or pace in the visual popover. Keep completeness metadata internally and disclose it in accessibility text, where the additional precision does not burden the default interaction.

Empty day:

```text
14 August
No data
```

If the popup cannot fit all normal rows without clipping in Russian or English, preserve this priority order:

1. date;
2. spent percentage or no-data state;
3. remaining value.

Do not show sample counts in the default popover. They are implementation detail and do not help the primary decision.

## Localization and accessibility

- Add complete Russian and English strings for chart semantics, reference label, concise hover rows, accessibility-only incomplete state, and no-data state.
- Use locale-aware day/month and decimal formatting.
- Do not construct translated sentences from fragments.
- Every dated slot must expose an accessibility label and value even when pointer hover is unavailable.
- VoiceOver value includes date, spend, comparison with the daily reference, completeness, and remaining value when known.
- Provide a chart-level summary describing this as daily consumption of the combined weekly account pool over 14 days.

## Architecture

Keep business rules outside SwiftUI:

- A pure aggregation type in `AppInfrastructure.swift` produces 14 daily spend points, completeness metadata, end remaining value, account coverage, and stable dates.
- The SwiftUI chart in `main.swift` renders those prepared points and owns only transient private hover state.
- Forecast and verdict calculations continue to consume raw `PoolHistorySample` history unchanged.
- Persistence remains backward-compatible with the existing JSONL history. Do not discard or rewrite valid local history merely to support the new visualization.

The implementation should remain surgical. Do not refactor the broader panel or introduce a general chart framework.

## Documentation consistency

The canonical design system currently states that pool-history fill represents remaining capacity. The implementation change must update that statement so account progress continues to represent remaining capacity while this daily pool chart explicitly represents consumed capacity.

The changelog wording must also be corrected if it still describes this pool chart as five-hour usage; the current pool samples use weekly remaining capacity.

## Verification

### Aggregation tests

- Multiple within-day decreases accumulate as gross spend.
- Remaining-capacity increases do not subtract previous spend.
- Account addition, removal, and intermittent fetch failure do not invent deltas.
- Daily normalization uses the represented pool capacity rather than a single-account percentage.
- Local day boundaries are correct.
- Today updates when a new sample is appended.
- Missing days remain empty dated slots.
- Partial historical coverage produces a lower-bound point with explicit completeness metadata.
- Existing JSONL history decodes without migration loss.

### Presentation and interaction tests

- Exactly 14 stable bars render.
- Healthy, warning, critical, incomplete, and empty states use the correct semantic treatment.
- Hover selects the nearest dated slot and clears on exit.
- The selected bar emphasis does not change chart layout.
- The popover remains inside the chart bounds for first, middle, and last bars.
- Russian and English popover content fits the approved compact treatment.
- Accessibility labels distinguish current, past, incomplete, and empty days.
- Reduce Motion disables non-essential hover and value animation.

### Repository verification

- Run `./run-tests.sh`.
- Run `./build.sh`.
- Run `git diff --check`.
- Install, terminate the old running process, relaunch the installed app, and visually verify the live chart with real local history.
- Verify manual refresh changes today's bar when usage has changed.
