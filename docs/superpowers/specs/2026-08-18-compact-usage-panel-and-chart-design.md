# Compact Usage Panel and Complete Daily Chart — Design

**Date:** 2026-08-18
**Status:** Approved

## Goal

Keep ten account rows fully visible in the usage panel, make the reset-credit button readable, and render the complete 14-day chart even when some days have no history.

## Reset-credit button

- Use `Сбросы (N)` whenever the total is known, including zero.
- Use `Сбросы (…)` while no account count is known and checks are still running.
- Use `Сбросы (?)` when checks failed and no count is known.
- Use `Сбросы (N+)` when a known partial total exists alongside failed account checks.
- Give the button enough width and horizontal padding for the longest expected title without touching its border.
- Keep the existing colors, tooltip behavior, and action.

## Account-list density

- Keep a single-column list and the existing ten-row visibility limit.
- Reduce each account row from 48 pt to 39 pt and each inter-row gap from 6 pt to 4 pt.
- Adjust only the row's vertical layout so its label, usage values, progress lines, and reset times remain vertically centered and do not overlap.
- Preserve the current panel width, account sorting, colors, interactions, and overflow caption for more than ten accounts.
- Ten rows must occupy the same 426 pt row-stack height as the current eight-row layout, avoiding a scroll view and avoiding a taller panel.

## Equal lower-panel heights

- The reset-chance card and bottom settings bar remain 44 pt high.
- Represent their shared height with one layout constant so the two panels cannot drift apart.
- Preserve their existing content, actions, and visual styling.

## Complete 14-day chart

- Build exactly 14 chronological calendar-day slots, ending today.
- A day with samples keeps the current daily minimum, end value, sample count, and status color.
- A day without samples remains a real dated slot with no numeric value. Render its muted capacity track without a colored fill; never render it as zero usage.
- Hovering a missing day shows its date and `Нет данных`.
- X-axis labels are selected from the full 14-slot range, so spacing remains stable regardless of missing history.
- If the complete history is empty, still render the 14 empty dated slots to show the full chart shape.
- Forecast and verdict calculations continue to use real samples only and remain unchanged.

## Engineering boundaries

- Keep calendar-slot construction in `AppInfrastructure.swift` so it can be tested without AppKit or SwiftUI.
- Keep chart rendering and panel geometry in `main.swift`.
- Do not refactor unrelated panel code or change settings, reset redemption, networking, or forecast behavior.

## Verification

- Extend infrastructure tests to verify exactly 14 ordered slots, correct known-day aggregation, empty slots for missing days, and an all-empty 14-day window.
- Run `./run-tests.sh` and `./build.sh`.
- Install, relaunch, and visually verify the panel with ten accounts: all rows are visible, both lower cards are equally tall, the reset title has breathing room, and the chart has 14 evenly spaced positions.
