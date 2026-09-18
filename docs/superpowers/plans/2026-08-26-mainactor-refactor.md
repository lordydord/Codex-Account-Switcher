# MainActor Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Isolate UI-owned application state on `MainActor` and make command/file/process helpers explicitly nonisolated without changing the UI layout or behavior.

**Architecture:** `AppDelegate` becomes `@MainActor`. Existing pure/I/O helpers are explicitly `nonisolated`; async usage and reset-credit fetches retain their structured task boundary. `AppDelegate` starts a generation-tagged task and applies its value result on the main actor.

**Tech Stack:** Swift 5.9+/macOS 14, AppKit, SwiftUI, structured concurrency, existing shell/URLSession infrastructure.

## Global Constraints

- Keep macOS deployment target at 14.0.
- Do not change panel sizes, layout metrics, or dual usage-limit rendering.
- Do not add a production dependency.
- Preserve the current `origin/main` feature set.
- Run `CLANG_MODULE_CACHE_PATH=/tmp/codex-switcher-module-cache ./run-tests.sh` and `./build.sh` after implementation.

### Task 1: Add regression tests for the actor boundary

**Files:**
- Modify: `Tests/InfrastructureTests.swift`

- [x] Add source-contract assertions for `@MainActor` on `AppDelegate`, `refreshGeneration`, and absence of direct API Mode production symbols.
- [x] Run the test suite and confirm the new actor assertion failed before the annotation was added.

### Task 2: Mark pure and I/O helpers as nonisolated

**Files:**
- Modify: `Sources/main.swift`

- [x] Mark command execution, account parsing, auth-file reads, and process/plugin maintenance `nonisolated`.
- [x] Keep `AppDelegate` responsible for deciding whether a refresh should start and for applying results.

### Task 3: Isolate AppDelegate and bridge callbacks

**Files:**
- Modify: `Sources/main.swift`
- Modify: `Sources/PanelComponents.swift` only if compiler isolation requires a callback annotation.

- [x] Annotate `AppDelegate` with `@MainActor`.
- [x] Replace top-level delegate construction with `Task { @MainActor in ... }` while preserving `NSApplication.run()`.
- [x] Wrap notification, timer, and background completion callbacks with explicit `Task { @MainActor in ... }` at the boundary.
- [x] Remove redundant `DispatchQueue.main.sync` calls from background workflows.

### Task 4: Verify behavior and relaunch

**Files:**
- No production files unless verification exposes a regression.

- [x] Run Infrastructure and AppKit tests.
- [x] Build the app.
- [x] Stop any older app process and launch only the freshly built app.
- [ ] Report the commit boundary; do not commit or push until the user confirms the UI is correct.
