# Dual Usage Limits Account Row Design

## Goal

Show the current five-hour Codex allowance and the supplementary weekly allowance simultaneously in every normal account row, with the five-hour window carrying the stronger visual priority.

## Information Hierarchy

- The five-hour limit is the primary metric because it is the immediate operating constraint.
- The weekly limit remains visible as context for comparing the longer-term capacity of all accounts.
- The five-hour progress line is placed above the weekly progress line.
- The weekly line is thinner and visually subdued, but retains its own semantic quota color so warning and critical states remain recognizable.
- The trailing value is a single ordered pair: `five-hour / weekly`, for example `10% / 80%`.

## Account Row Layout

The normal row keeps its current four regions:

1. The numbered `28 pt` badge.
2. The flexible account identity and weekly reset detail.
3. A fixed-width stack of two labelled progress lines.
4. A fixed-width pair of remaining percentages.

The progress stack uses localized compact labels:

- Russian: `5 Ч` and `НЕД`.
- English: `5H` and `WK`.

The five-hour progress track remains `4 pt` high. The weekly progress track is `3 pt` high and rendered with reduced opacity. Both fills represent remaining capacity and clamp values to `0...100`.

The row remains `39 pt` high with the existing `4 pt` inter-row gap. Panel dimensions, scrolling rules, confirmation-row layout, swipe actions, and switching behavior do not change.

## Color and State

- Each metric derives its semantic palette independently from its own remaining percentage.
- Five-hour healthy, warning, and critical states use the existing full-strength quota gradients and label colors.
- Weekly states use the same semantic gradients at reduced opacity.
- The active row border and numbered badge use the five-hour palette because it represents the currently actionable constraint.
- Unknown values display `--` without synthesizing `0%` or a visible fill.
- Mixed availability is supported, for example `-- / 80%` or `10% / --`.

## Typography and Accessibility

- Percentages use rounded, monospaced digits.
- The five-hour percentage is slightly stronger than the weekly percentage.
- The slash is neutral and visually separates the two values.
- The row exposes one accessibility value that explicitly names both remaining limits and the weekly reset detail; meaning never depends on color or ordering alone.
- New labels and accessibility text are supplied in Russian and English.

## Code Boundaries

- `AccountRowView` owns the composition of the two metrics.
- A small pure presentation policy prepares clamped percentage text and the ordered pair so unknown and mixed states can be tested without rendering SwiftUI.
- `AccountProgressLine` remains the shared primitive for both tracks and gains only the styling inputs required for primary and secondary presentation.
- No unrelated account-list or panel refactoring is included.

## Documentation

Update the design system account-row and progress-indicator sections so they describe the five-hour-first dual-limit presentation rather than a weekly-only row.

## Verification

- Add infrastructure assertions for ordered percentage pairs, clamping, and mixed unknown values.
- Keep the existing row-height and viewport assertions passing to prove panel geometry is unchanged.
- Run `./run-tests.sh` and `./build.sh`.
- Run `./install.sh`, relaunch the installed app, and run `./verify-install.sh`.
- The user performs the final visual review of the installed application.
- Do not commit or push until the user approves the visual result.
