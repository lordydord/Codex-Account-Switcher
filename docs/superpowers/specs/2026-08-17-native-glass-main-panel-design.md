# Native Glass Main Panel Design

**Date:** 2026-08-17
**Status:** Implemented; visual acceptance delegated to the user
**Scope:** Codex Account Switcher main usage panel

## Context

The main panel currently uses two different layouts: large cards for one or two accounts and compact rows for three or more accounts. The large cards still emphasize the retired five-hour usage window, while the compact layout already contains the more useful pool history, forecast, reset-chance, and reset-credit controls.

The redesign gives every account count one consistent layout, adds visible account numbering, and updates the panel to a restrained Apple-style Native Glass treatment. It preserves the existing account data, pool history, forecast, reset-credit, and switching pipelines.

## Goals

- Show visual account numbers from `1` through `N` in current top-to-bottom display order.
- Use one compact account-list layout for every account count.
- Remove five-hour usage information from the main panel.
- Preserve the pool chart, pool forecast, reset-chance section, and bottom toolbar.
- Make the panel wider and less visually dense without sacrificing fast scanning.
- Require an explicit inline confirmation before every manual account switch.
- Fit up to ten normal account rows without scrolling when the available screen height permits it.
- Preserve dark mode, light mode, older-macOS material fallback, and existing switching safety behavior.

## Non-goals

- Redesigning Settings, Reset Credits, or auxiliary dialogs beyond removing the obsolete confirmation toggle.
- Changing how account usage, reset credits, pool history, or forecasts are fetched or calculated.
- Importing activity logs from Codex, OhMyPi, or other clients.
- Adding number-based keyboard shortcuts.
- Changing automatic-switch behavior or account sort rules.
- Deleting five-hour data from internal models or reset workflows that still depend on it.

## Information Architecture

The main panel keeps this fixed vertical order:

1. Account list.
2. Pool history chart and forecast line.
3. `RESET CHANCE` section.
4. Bottom toolbar with Settings, Add Account, last refresh, reset credits, refresh, and close.

Only the account list scrolls. The chart, forecasts, and toolbar remain visible.

The chart section is available for any non-empty account count when pool history exists. It is no longer gated on having three or more accounts. Existing empty-history behavior remains unchanged.

## Panel Sizing

- Target width: `520 pt`.
- Horizontal placement remains constrained to the current screen's visible frame with an `8 pt` minimum edge margin.
- The normal layout reserves enough list height for up to ten rows when the screen permits it.
- At eleven or more accounts, the list scrolls.
- On a shorter screen, panel height is capped to the visible frame and scrolling begins earlier.
- Opening inline confirmation does not resize the outer panel. If the expanded row exceeds the current list viewport, the list becomes temporarily scrollable.
- The panel shrinks for fewer accounts instead of leaving unused account-row space.

## Account Ordering and Numbering

Existing display ordering remains authoritative. After accounts are sorted for display, rows receive sequential visual numbers starting at `1`.

Numbers describe positions, not identities. They may change when display order changes, and they are not persisted. They do not trigger keyboard shortcuts or any other hidden behavior.

## Account Row

Each normal row shows:

- sequential number badge;
- account email using the existing truncation and tooltip behavior;
- active state when applicable;
- weekly remaining percentage;
- weekly reset time;
- a progress bar whose filled width represents **remaining**, not used, weekly capacity.

The active row receives a subtle mint-tinted glass border and number badge. Non-active rows use a neutral glass surface. No separate `ACTIVE` or `SWITCH` pill is displayed.

The complete non-active row is clickable. Hover slightly increases surface brightness and border contrast without moving the row. Numeric percentages remain visible so color is never the only status signal.

## Inline Switching Confirmation

The first click on a non-active row opens an expanded Inline Buttons state in that row. It displays:

- `Switch to account #N?`;
- the target email;
- a short note that Codex will relaunch;
- `Cancel` and `Switch` text buttons;
- a four-second timeout hint.

No account mutation, app termination, or plugin synchronization starts before `Switch` is pressed.

`Cancel`, clicking a different account, panel dismissal, or the four-second timeout closes the confirmation. Confirming clears the armed state and enters the existing switch pipeline exactly once. During switching, all rows are disabled and the target row displays `Switching…`.

Manual switches always use this inline confirmation. The `Confirm before switching` setting, its stored preference, and the modal manual-switch preview are removed. Automatic switching retains its existing independent behavior.

Authentication and switching failures continue to use the existing alerts. After failure, the list returns to its normal enabled state.

## Native Glass Visual Language

The background continues to use `NSGlassEffectView` on macOS 26 and the existing `NSVisualEffectView` fallback on older systems.

The new treatment uses:

- restrained translucent layers rather than opaque cards;
- soft inner highlights and low-opacity borders;
- `17–18 pt` row corner radii;
- rounded system typography with existing monospaced digits for changing values;
- minimal green emphasis for the active account;
- no decorative aurora gradients or strong violet tinting.

The bottom toolbar keeps its current actions but increases SF Symbol size to approximately `20–22 pt`. Each icon receives a hit target of at least `34 × 32 pt`, with clear hover and pressed states.

## Progress Palette

Weekly remaining percentage selects one of three semantic gradients:

| Remaining | Start | End | Meaning |
| --- | --- | --- | --- |
| `26–100%` | mint `#47D7A5` | blue `#64B9FF` | healthy |
| `11–25%` | gold `#FFD166` | orange `#FF8F3F` | approaching low |
| `0–10%` | coral `#FF8A7A` | red `#E83F54` | low |

The percentage label uses a matching readable solid color. Unknown values use the existing subdued neutral treatment.

Pool-chart samples use the same semantic thresholds based on each sample's average remaining percentage. Forecast verdict text retains its existing semantic meaning while adopting the matching palette.

## Component Changes

Implementation should stay surgical and reuse current components:

- `AccountPanelLayout` owns the new width, row sizing, ten-row target, fixed-section heights, and visible-screen cap.
- `buildUsageContent()` always builds the unified list path and fixed aggregate sections.
- The account-list container becomes an `NSScrollView`; account rows receive their display index.
- `accountListRow` renders either normal or inline-confirmation content from the existing `armedSwitchEmail` state.
- `RoundedPanelView` continues to own whole-row hover and click behavior.
- `ProgressLineView` accepts gradient endpoints while retaining its neutral track and clamped fill behavior.
- A pure palette function maps weekly remaining percentage to endpoints and label color.

No new persistence format, network request, history schema, or switching service is introduced.

## Data Semantics

The chart history remains a local sequence of server-side weekly-remaining snapshots fetched from `https://chatgpt.com/backend-api/wham/usage`. Sampling continues on refresh and approximately every 30 minutes, with 56-day retention.

Because snapshots reflect server-side account limits, usage from OhMyPi is automatically represented when it uses the same ChatGPT/Codex account and consumes the same weekly quota. The switcher does not attribute consumption to a particular client.

## Accessibility and Input

- Percentage text accompanies every progress color.
- Text actions accompany confirmation controls; confirmation does not rely on icons alone.
- Hover is supplementary and not required to discover state.
- Whole-row activation and inline buttons remain keyboard-focusable.
- Reduced Transparency and pre-macOS-26 behavior rely on the existing material fallback.
- Light and dark appearances use theme-derived surfaces and borders while retaining the approved semantic gradient endpoints where contrast permits.

## Verification

Automated coverage must include:

- unified layout selection for 1, 2, 10, and 11 accounts;
- visible-screen height capping and list-only scrolling;
- sequential numbering after existing display sorting;
- palette boundaries at `10`, `11`, `25`, and `26` percent;
- remaining-percentage fill width;
- hover and normal row states;
- opening, cancelling, timing out, and confirming inline switching;
- exactly one switch request after confirmation;
- all rows disabled while switching;
- chart availability with one and two accounts when history exists;
- absence of five-hour labels and large-card construction from the main panel;
- removal of the confirmation preference and modal manual-switch path.

Manual verification must cover:

- 1, 2, 10, and 11+ account datasets;
- a short screen that forces earlier scrolling;
- dark and light appearance;
- macOS 26 Native Glass and the older-system material fallback;
- hover, keyboard focus, confirmation timeout, cancellation, success, and failure;
- graph, forecast, reset chance, reset-credit navigation, and toolbar actions;
- build, infrastructure tests, installation verification, and a real account switch.
