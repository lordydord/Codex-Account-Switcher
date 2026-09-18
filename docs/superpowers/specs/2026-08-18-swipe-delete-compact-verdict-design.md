# Swipe Delete and Compact Verdict Card Design

**Date:** 2026-08-18  
**Status:** Approved in conversation; awaiting written-spec confirmation  
**Target:** macOS 14+, dark appearance only

## Goal

Add a familiar swipe-to-reveal deletion action to inactive account rows and tighten the localized pool-verdict area without removing any information. The installed application must remove exactly the selected account through `codex-auth`, preserve the active account, and give the verdict card and footer controls more deliberate spacing.

## Scope

This change includes:

- swipe left on an inactive account row to reveal a destructive button;
- immediate address-specific deletion after pressing that button;
- compact verdict layout B selected by the user;
- a visible gap between the verdict card and reset-chance card;
- exact centering of the signed-margin badge;
- slightly wider Refresh and Quit buttons;
- Russian and English copy for the new main-panel action;
- automated behavior, command, localization, and layout-policy coverage;
- rebuilding and reinstalling the application for user inspection.

This change does not include:

- deletion of the active account;
- `codex-auth remove --all` or interactive multi-account removal;
- an additional deletion-confirmation dialog or inline confirmation row;
- light-appearance work or visual re-verification by the implementer;
- removal of any information currently shown in the verdict card;
- unrelated Settings-panel localization or refactoring.

## Account Removal Interaction

### Resting state

Account rows retain their current appearance and click-to-switch behavior. An active row cannot enter the destructive reveal state. A maintenance operation also disables reveal and deletion until it completes.

### Swipe state

An inactive row accepts a horizontal left gesture from a trackpad or pointing device. Horizontal intent must win only after a small movement threshold so ordinary clicks continue to switch accounts and vertical intent continues scrolling the list. The foreground account card follows the gesture within a clamped range and reveals a fixed red action surface on its right edge.

The revealed action is localized as `Удалить` or `Delete`. Only one row can remain revealed. Revealing another row, clicking outside the revealed action, scrolling the account list vertically, rebuilding the panel, or completing/failing deletion closes the previous row.

The action button is a real accessible control with a localized accessibility label. The existing Settings removal flow remains an accessible non-gesture alternative.

### Deletion

Pressing the revealed button deletes immediately; there is no third confirmation step. Safety comes from the deliberate swipe-plus-button sequence, the active-account guard, and exact argument construction.

The command is built as an argument array, never shell text:

```text
codex-auth remove <account.selector>
```

`account.selector` is the selector parsed from the same `codex-auth list` snapshot as the row. It is not the UI's reordered display index and is not a partial email. The application never constructs or accepts `--all` for this interaction.

On success, the normal account-maintenance path reloads accounts from disk. On a non-zero exit, the row closes, the account stays visible, and the existing maintenance error alert shows the CLI output. No Codex restart is required for deleting an inactive account.

## Component Boundaries

### Swipe reveal view

A small row container owns gesture tracking, foreground offset, the red background action, and animation back to either the closed or fully revealed position. It receives immutable deletion eligibility and callbacks; it does not run processes or mutate account data.

### Swipe policy

A pure policy determines horizontal-versus-vertical intent, clamped offset, reveal threshold, and final settled state. Keeping the math outside AppKit makes thresholds deterministic and testable.

### Removal request

A small typed request builder accepts a `CodexAccount` and returns the exact `codex-auth` argument array only when the account is inactive and has a non-empty selector. The AppDelegate executes the request through the existing `runAccountMaintenance` path.

### Panel state

The panel tracks at most one revealed account identity. Rebuilding the panel clears this transient state. Existing switch-confirmation state remains independent; arming a switch closes any revealed deletion action.

## Compact Verdict Layout B

The verdict card height changes from `142 pt` to `108 pt`. The outer usage panel height does not increase; the recovered height becomes available to the account-list viewport.

All current information remains:

- verdict symbol;
- title;
- explanatory detail;
- signed margin badge;
- progress line and event points;
- Now, Reset, and Capacity Ends labels;
- reset and exhaustion interval values.

The layout uses tighter internal spacing while preserving three distinct event columns. The top group uses a `32 pt` symbol and a compact title/detail stack. The timeline moves upward as a unit rather than compressing individual labels into overlap.

The signed-margin badge uses a vertically and horizontally centered text-drawing component instead of relying on an `NSTextField` baseline. Its oval remains large enough for the longest supported Russian and English margin strings at 520 pt panel width.

A real `12 pt` vertical gap separates the verdict card from the reset-chance card. They must no longer share an edge.

## Footer Sizing

At the 520 pt usage-panel width:

- Refresh grows from `60 pt` to `68 pt`;
- Quit grows from `42 pt` to `50 pt`;
- button height stays `26 pt`;
- existing gaps and dividers remain;
- the last-updated region absorbs the additional width without overlapping the reset-credit button.

Russian and English button titles must fit without touching their rounded edges. Quit-confirmation arming keeps the existing stable footer and panel height.

## Error Handling and Safety

- Active-account deletion is rejected before constructing a command.
- Empty selectors cannot produce a removal command.
- Arguments are passed directly to `Process`; no shell interpolation is introduced.
- `--all` is not present in any swipe-deletion path.
- Duplicate clicks are prevented by the existing maintenance-in-progress state.
- Failed CLI execution preserves the visible account and exposes the error.
- A successful deletion refreshes all derived account, usage, history, reset-credit, and label presentation through the existing refresh path; unrelated persisted preferences remain untouched.

## Testing

Implementation follows test-driven development.

Automated tests cover:

- horizontal intent versus vertical scrolling and ordinary clicks;
- offset clamping and settle thresholds;
- single-open-row state transitions;
- active and missing-selector rejection;
- exact inactive-account arguments: `["remove", account.selector]`;
- proof that the request cannot contain `--all`;
- Russian and English delete copy and localization completeness;
- verdict-card, inter-card gap, and footer-width layout policy;
- stable existing switch/quit confirmation sizing;
- full infrastructure suite, reset self-test, application build, signature, and whitespace checks.

The implementer will not perform a new visual judgment pass. After successful automated verification, the app is reinstalled and opened in dark appearance for the user to evaluate directly.

## Acceptance Criteria

- Swiping an inactive row left reveals one red localized Delete button.
- Active rows never reveal or execute deletion.
- Pressing Delete immediately removes only that row's exact `codex-auth` account.
- No swipe-deletion path can issue `remove --all`.
- Success refreshes the list; failure keeps the account and shows the CLI error.
- The verdict card is visibly more compact while retaining every current datum.
- A 12 pt gap is visible before the reset-chance card.
- The signed-margin text is centered in its oval.
- Refresh and Quit have comfortable horizontal padding in Russian and English.
- The dark application passes the complete automated suite and is reinstalled for user review.
