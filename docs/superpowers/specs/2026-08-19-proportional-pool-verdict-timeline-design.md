# Proportional Pool Verdict Timeline Design

**Date:** 2026-08-19
**Status:** Approved for implementation
**Scope:** Pool verdict card timeline and margin summary

## Context

The pool verdict card currently presents three events in equal-width columns: now, the first forecast event, and the later forecast event. The line and points communicate ordering, but their positions are fixed. Users reasonably interpret the control as a time scale, so a permanently centered first event makes the scale look decorative rather than informative.

The signed margin is also rendered inside a fixed `84 pt` capsule. Full Russian clock-time strings such as `−9 часов 22 минуты` do not fit and are truncated.

This change amends the `Event-Order Scale` and margin-badge sections of `2026-08-17-pool-verdict-localization-design.md`. Forecast inputs, verdict calculation, history sampling, and reset calculation remain unchanged.

## Goals

- Make event-point positions proportional to their forecast intervals.
- Preserve the existing direct verdict, semantic color, and event ordering.
- Explain the signed margin without a truncating capsule.
- Keep the card compact and readable at the current panel width in Russian and English.
- Cover timeline geometry and localized summary semantics with pure automated tests.

## Non-goals

- Changing how burn, exhaustion, reset, or margin values are calculated.
- Animating the point continuously between data refreshes.
- Redesigning the pool chart, reset-chance section, account rows, or panel shell.
- Migrating the AppKit card to SwiftUI.
- Performing visual automation or screenshot comparison.

## Timeline Semantics

The timeline spans from `now` to the later of the reset and exhaustion events.

- `now` is always at fraction `0`.
- The later event is always at fraction `1`.
- The earlier event is placed at `earlierInterval / laterInterval`.
- Fractions are clamped to `0...1` before drawing.
- Invalid, missing, or non-positive intervals continue to produce the existing Collecting state rather than timeline geometry.

For the observed example:

- exhaustion: `10 hours 54 minutes`;
- reset: `20 hours 16 minutes`;
- exhaustion fraction: approximately `0.54`.

The point therefore appears near the middle for this specific forecast, but moves left or right when the ratio changes.

## Event Labels

The three text groups remain in ordered left, center, and right columns so long localized strings never overlap. The points themselves use proportional positions. No diagonal connector is drawn between a point and its fixed label column; the area below the horizontal track stays visually quiet.

This deliberately separates accurate time geometry from collision-safe text layout:

- point position communicates relative time;
- ordered columns communicate event identity and exact intervals;
- the event order and exact interval text preserve their semantic association.

The `now` and later-event points stay aligned with the left and right label columns. Exact interval text remains below each event name.

## Track Treatment

The segment from `now` to the first event uses the verdict accent gradient. The remaining segment uses the subdued progress-track color. The transition between the two segments occurs at the proportional first-event position rather than at the fixed center.

## Margin Summary

Remove the fixed capsule and replace it with a trailing two-line text summary in the header:

- negative verdict: `Дефицит` / `Deficit` plus the absolute duration;
- positive verdict: `Запас после сброса` / `After reset` plus the absolute duration.

The duration does not include a leading sign because the semantic label and verdict color already convey direction. The value uses the existing localized clock-time formatter, preserving correct plural forms.

The summary is right-aligned and receives a stable width large enough for the current Russian and English clock-time strings. The title and detail frames reserve this width. No background capsule or clipping-dependent presentation remains.

## Presentation Model

The display-ready presentation adds explicit fields for:

- first-event timeline fraction;
- margin summary label;
- absolute margin summary value.

The view does not recompute forecast semantics. `PoolVerdictPresenter` derives all three values from the already validated reset, exhaustion, and margin intervals.

The existing signed-margin formatter remains available for unrelated callers or tests, but the verdict card no longer exposes `marginBadge`.

## AppKit Rendering

`PoolVerdictCardView` continues to own drawing and label construction. It:

1. reserves trailing header space for the two-line margin summary;
2. draws the first event at the supplied fraction;
3. splits the accent and subdued track at that point;
4. keeps the area between the horizontal track and event labels free of auxiliary lines;
5. keeps existing accessibility semantics and verdict styling.

The card height and surrounding panel layout remain unchanged.

## Collecting State

The Collecting state remains neutral and unchanged:

- no timeline;
- no margin summary;
- existing title, detail, symbol, and accessibility label.

## Accessibility

- The verdict title and detail continue to explain the outcome without relying on color or geometry.
- The margin summary uses visible text rather than only a sign or color.
- The group accessibility label remains localized.
- Exact event intervals remain available as text even when a point is close to another point.

## Verification

Automated tests cover:

- the not-enough fraction `exhaustion / reset`;
- the enough fraction `reset / exhaustion`;
- fractions close to both endpoints;
- clamping of timeline fractions;
- Russian and English deficit labels and absolute values;
- Russian and English positive-buffer labels and absolute values;
- no timeline or margin summary in Collecting state;
- unchanged verdict event ordering and interval strings;
- an AppKit bitmap regression proving the band between the track and labels contains no diagonal connector;
- existing layout metrics, full test suite, and debug build.

Per user request, verification does not include launching the app, browser automation, screenshots, or visual inspection.
