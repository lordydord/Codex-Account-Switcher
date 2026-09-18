# Account Row Fit and Exact Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep account-row percentages and confirmation buttons fully visible, tint the reset-chance bolt yellow, and delete exactly the swiped account by full email.

**Architecture:** Put deterministic row geometry and removal validation in pure policies inside `AppInfrastructure.swift`, then let the AppKit panel consume their frames/arguments. Preserve native `NSTableView` row actions and the existing panel dimensions.

**Tech Stack:** Swift 5, AppKit, native `NSTableViewRowAction`, shell-based Swift test targets.

## Global Constraints

- Keep the panel's outer dimensions unchanged.
- Keep the current typography and confirmation-button sizes.
- Delete immediately after pressing the native destructive row action.
- Never delete the active account and never emit `--all` or another flag-like query.
- Do not perform a visual review; the user will inspect the installed build.

---

### Task 1: Exact Email Removal

**Files:**
- Modify: `Sources/AppInfrastructure.swift:59-67`
- Modify: `Sources/main.swift:2823-2833`
- Test: `Tests/InfrastructureTests.swift:323-331`

**Interfaces:**
- Consumes: selected `CodexAccount.email` and `CodexAccount.isActive`.
- Produces: `AccountRemovalPolicy.arguments(email:isActive:) -> [String]?`.

- [ ] **Step 1: Write the failing tests**

Replace selector expectations with exact-email expectations:

```swift
expect(
    AccountRemovalPolicy.arguments(email: "riccardoroberts6408@gmail.com", isActive: false)
        == ["remove", "riccardoroberts6408@gmail.com"],
    "removal must pass the selected full email unchanged"
)
expect(
    AccountRemovalPolicy.arguments(email: "r.oberttonyer677408@gmail.com", isActive: false)
        != AccountRemovalPolicy.arguments(email: "riccardoroberts6408@gmail.com", isActive: false),
    "similar account emails must remain distinct"
)
expect(AccountRemovalPolicy.arguments(email: "--all", isActive: false) == nil, "remove-all must be rejected")
expect(AccountRemovalPolicy.arguments(email: "active@example.com", isActive: true) == nil, "active account must be rejected")
```

- [ ] **Step 2: Run tests and verify RED**

Run: `./run-tests.sh`

Expected: compilation fails because `arguments(email:isActive:)` does not exist.

- [ ] **Step 3: Implement exact-email arguments**

```swift
enum AccountRemovalPolicy {
    static func arguments(email: String, isActive: Bool) -> [String]? {
        guard !isActive else { return nil }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !email.hasPrefix("-"), email.contains("@") else { return nil }
        return ["remove", email]
    }
}
```

Update `removeAccountFromRowAction(email:)` to call the new label with `account.email`.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `./run-tests.sh`

Expected: infrastructure, AppKit interaction, and reset self-tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppInfrastructure.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "fix: remove exact swiped account"
```

### Task 2: Responsive Account Row Geometry

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Sources/main.swift:1080-1150`
- Test: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `AccountRowLayout.frames(rowWidth:) -> AccountRowFrames` with `emailWidth`, `progressX`, `progressWidth`, `percentX`, `percentWidth`, `cancelX`, `cancelWidth`, `switchX`, and `switchWidth`.
- Consumes: actual row width supplied by `accountListRowContent(_:displayIndex:frame:)`.

- [ ] **Step 1: Write failing layout tests**

Use hand-derived bounds for 480- and 504-point rows:

```swift
let compact = AccountRowLayout.frames(rowWidth: 480)
expect(compact.percentX + compact.percentWidth <= 466, "percentage must remain inside the trailing inset")
expect(compact.progressX + compact.progressWidth + 8 <= compact.percentX, "progress must not overlap percentage")
expect(compact.cancelX >= 250, "confirmation controls must leave room for prompt text")
expect(compact.switchX + compact.switchWidth <= 466, "switch button must remain inside the trailing inset")
expect(compact.cancelX + compact.cancelWidth + 8 == compact.switchX, "confirmation buttons must preserve their gap")
```

- [ ] **Step 2: Run tests and verify RED**

Run: `./run-tests.sh`

Expected: compilation fails because `AccountRowLayout` does not exist.

- [ ] **Step 3: Implement the pure layout policy**

Use a 14-point trailing inset, a 36-point percentage, an 8-point gap, a progress bar beginning at x=292 and shrinking to the available width, and unchanged 68-/100-point confirmation buttons. Clamp prompt width to end 12 points before the confirmation group.

- [ ] **Step 4: Apply geometry to the AppKit row**

Replace fixed `barWidth`, percentage x, `switchX`, and prompt widths in `accountListRowContent` with values from `AccountRowLayout.frames(rowWidth: frame.width)`.

- [ ] **Step 5: Run tests and verify GREEN**

Run: `./run-tests.sh`

Expected: all test targets pass and the new boundary assertions are included.

- [ ] **Step 6: Commit**

```bash
git add Sources/AppInfrastructure.swift Sources/main.swift Tests/InfrastructureTests.swift
git commit -m "fix: fit account row controls"
```

### Task 3: Yellow Reset-Chance Bolt and Delivery

**Files:**
- Modify: `Sources/main.swift:1386-1391`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: existing `SymbolIconView` color parameter.
- Produces: warm yellow `bolt.fill` without changing reset-chance content or layout.

- [ ] **Step 1: Change only the bolt tint**

Pass `NSColor.systemYellow.withAlphaComponent(0.9)` to the reset-chance `SymbolIconView`.

- [ ] **Step 2: Update the Unreleased changelog**

Record responsive row controls, yellow reset bolt, and exact-email removal.

- [ ] **Step 3: Run full verification**

Run:

```bash
git diff --check
./run-tests.sh
./build.sh
```

Expected: no whitespace errors, all test targets pass, and the app bundle builds successfully.

- [ ] **Step 4: Commit**

```bash
git add Sources/main.swift CHANGELOG.md
git commit -m "style: tint reset chance bolt"
```

- [ ] **Step 5: Install and restart**

Run:

```bash
./install.sh
/usr/bin/pkill -x CodexAccountSwitcher || true
/usr/bin/open -a "/Applications/Codex Account Switcher.app"
./verify-install.sh
```

Expected: version 1.8.5 is installed, signed, monitored, and running.

- [ ] **Step 6: Verify installed binary identity and clean worktree**

Run:

```bash
/usr/bin/shasum -a 256 "build/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher" "/Applications/Codex Account Switcher.app/Contents/MacOS/CodexAccountSwitcher"
git status --short
```

Expected: both hashes are identical and `git status --short` is empty.
