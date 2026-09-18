# Daily Spend Popover Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the concise daily-spend hover popover a narrower, taller, more square shape with larger text.

**Architecture:** Keep the existing concise hover copy and detailed VoiceOver description unchanged. Put the approved dimensions and typography in one pure metrics policy used by the Swift Charts popover; aggregation and chart values remain untouched.

**Tech Stack:** Swift 6.3, SwiftUI, Swift Charts, Foundation localization, existing shell-driven Swift tests.

## Global Constraints

- Keep the chart section at `104 pt` and clamp the enlarged popover inside it.
- Use a `164 pt` popover width, an `80 pt` minimum height, a `13 pt` date, and a `12 pt` body.
- Visible content is date, spent percentage, and remaining percentage only.
- Do not show pace, `at least`, `incomplete day`, or sampling-gap caveats in the visible popover.
- Preserve completeness details and daily-reference comparison in accessibility text.
- Keep Russian and English behavior equivalent.
- Do not change aggregation, forecast, verdict, account rows, or persistence.
- Run automated checks, reinstall, and relaunch; the user performs visual verification.

---

### Task 1: Concise visible copy and readable popover

**Files:**
- Modify: `Sources/AppInfrastructure.swift:2170-2220`
- Modify: `Tests/InfrastructureTests.swift:230-300,1070-1110`
- Modify: `Sources/main.swift:55-275`

**Interfaces:**
- Consumes: `PoolChartPopoverPolicy.placement(...)` and the existing concise localized detail lines.
- Produces: `PoolChartPopoverMetrics` as the tested source of truth for width, minimum height, typography, and padding.

- [ ] **Step 1: Write failing metrics and geometry tests**

Add assertions for a new pure metrics policy:

```swift
expect(PoolChartPopoverMetrics.width == 164, "popover width should be compact")
expect(PoolChartPopoverMetrics.minimumHeight == 80, "popover should be taller")
expect(PoolChartPopoverMetrics.dateFontSize == 13, "date should be more readable")
expect(PoolChartPopoverMetrics.bodyFontSize == 12, "body should be more readable")
expect(PoolChartPopoverMetrics.horizontalPadding == 12, "horizontal padding should remain balanced")
expect(PoolChartPopoverMetrics.verticalPadding == 10, "vertical padding should create a taller card")
```

Update edge-placement fixtures to `popoverWidth: 164` and `popoverHeight: 80`, expecting centers at `84`/`436`, vertical centers at `42`/`62`, and caret offsets at `-70`/`70`.

- [ ] **Step 2: Run tests and verify the new expectations fail**

Run: `./run-tests.sh`

Expected: compilation fails because `PoolChartPopoverMetrics` does not exist.

- [ ] **Step 3: Add the shared metrics policy**

Add `PoolChartPopoverMetrics` to `AppInfrastructure.swift` with the six approved `Double` constants. Keep presentation values in one testable source of truth without changing aggregation or localization.

- [ ] **Step 4: Increase SwiftUI popover metrics and typography**

Use `PoolChartPopoverMetrics` in `main.swift`. Apply width `164`, minimum height `80`, date font `13`, body font `12`, horizontal padding `12`, and vertical padding `10`. Keep spacing at `3` and continue using `PoolChartPopoverPolicy` for bounded placement and caret offset.

- [ ] **Step 5: Run all automated verification**

Run: `./run-tests.sh`

Expected: all infrastructure, AppKit, reset, and install-script tests pass.

Run: `./build.sh`

Expected: the application builds successfully.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 6: Commit the implementation**

```bash
git add Sources/AppInfrastructure.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "fix: refine daily spend popover proportions"
```

- [ ] **Step 7: Reinstall and relaunch for user review**

Run: `./install.sh`

Run: `./verify-install.sh`

Expected: version `1.8.5`, ad-hoc signature, lifecycle monitor, and running installed process are verified. Do not perform visual inspection.
