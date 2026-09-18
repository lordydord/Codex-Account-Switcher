# MainActor Refactor Specification

## Goal

Make AppKit and SwiftUI-facing application state main-actor isolated while keeping command-line, file-system, token, and network work off the main thread.

## Current problem

`AppDelegate` owns status-bar UI, panels, mutable account state, refresh flags, timers, and background workflows in one type. Background closures currently capture `self` and call methods that read or mutate this state. Most callbacks manually dispatch to `DispatchQueue.main`, but the boundary is implicit and incomplete.

## Requirements

1. `AppDelegate` is annotated `@MainActor`.
2. AppKit objects, panel state, timers, menu state, and user-defaults-backed UI settings are accessed only from the main actor.
3. Command execution, auth-file reads, command parsing, and process/plugin maintenance remain nonisolated and do not touch AppKit state.
4. Background results are returned as `Sendable` value types and applied on `MainActor`.
5. A refresh result cannot overwrite a newer refresh result.
6. Existing account switching, dual usage limits, settings UI, localization, and reset-credit behavior remain unchanged.
7. No new production dependency is introduced.
8. Existing layout metrics and panel sizes remain unchanged in this stage.

## Non-goals

- No visual redesign.
- No migration to a new app lifecycle.
- No change to refresh intervals or account-selection policy.
- No removal of the current AppKit/SwiftUI bridge.

## Verification

- Infrastructure tests and AppKit interaction tests pass.
- The project builds from `build.sh`.
- Source checks prove `AppDelegate` is main-actor isolated and refresh generation protection remains present.
- The freshly built app is relaunched for user inspection.
