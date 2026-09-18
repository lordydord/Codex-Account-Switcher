# Reference Plugin Set Implementation Plan

> **Runtime correction:** End-to-end testing invalidated direct reconciliation of `openai-curated-remote`: Codex owns and rewrites that account-scoped cache after launch. The implemented fix builds a local `account-switcher-reference` marketplace from the saved packages and installs them with the bundled CLI. The final launch verifies the local installed set and does not retry against the server-owned remote cache.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Codex account switch finish with the same saved user/integration plugin set, removing target-account-only plugins while preserving system plugins.

**Architecture:** AppKit-free infrastructure captures a versioned manifest plus an exact copy of `openai-curated-remote`, converts it into an atomic local `account-switcher-reference` marketplace, and installs saved packages through the bundled CLI. A transaction retains config/cache rollback through the final launch and content verification. The account-owned remote cache is observed for synchronization but never replaced.

**Tech Stack:** Swift 6, Foundation `FileManager`/`Codable`, AppKit menu integration, existing `ProcessRunner`, existing standalone infrastructure test harness.

## Global Constraints

- Never read, copy, modify, or log auth files, account registries, OAuth grants, tokens, account IDs, or email addresses.
- Never reconcile `openai-bundled` or `openai-primary-runtime` through the reference set.
- Installed plugin configuration and caches must have a verified rollback until final launch verification succeeds.
- Reference capture is explicit; account switching never updates the saved reference.
- OAuth-backed plugins may require authorization on each ChatGPT account.
- Keep all new pure logic in `Sources/AppInfrastructure.swift` so `./run-tests.sh` covers it.

---

### Task 1: Reference manifest, inventory, and atomic capture

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `ReferencePluginManifest(schemaVersion:capturedAt:remotePluginIDs:curatedPluginIDs:)`.
- Produces: `ReferencePluginInventory.remotePluginIDs(homeDirectory:fileManager:) -> [String]`.
- Produces: `ReferencePluginInventory.curatedPluginIDs(configText:) -> [String]`.
- Produces: `ReferencePluginStore.capture(homeDirectory:storeDirectory:fileManager:) -> CaptureOutcome`.
- Produces: `ReferencePluginStore.load(storeDirectory:fileManager:) -> LoadedReference?`.

- [ ] **Step 1: Write failing inventory tests**

Add tests that create `openai-curated-remote/{cloudflare,product-design,superpowers}` and config entries for `github@openai-curated`, `superpowers@openai-curated`, bundled, and primary-runtime plugins. Assert sorted remote IDs and only explicitly installed `openai-curated` IDs. Use literal expected arrays.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./run-tests.sh
```

Expected: compilation fails because `ReferencePluginInventory` is undefined.

- [ ] **Step 3: Implement manifest and inventory**

Add:

```swift
struct ReferencePluginManifest: Codable, Equatable {
    let schemaVersion: Int
    let capturedAt: Date
    let remotePluginIDs: [String]
    let curatedPluginIDs: [String]
}

enum ReferencePluginInventory {
    static func remotePluginIDs(homeDirectory: String, fileManager: FileManager = .default) -> [String]
    static func curatedPluginIDs(configText: String) -> [String]
}
```

Inventory reads immediate child directories only and parses enabled `[plugins."<id>@openai-curated"]` sections. It ignores `openai-curated-remote`, bundled, primary-runtime, and disabled sections.

- [ ] **Step 4: Run tests and verify GREEN**

Expected: new inventory tests pass.

- [ ] **Step 5: Write failing capture/load tests**

Assert that capture copies the exact remote tree, writes schema version `1`, round-trips through `load`, and preserves the previous valid reference when source copying or verification fails.

- [ ] **Step 6: Run tests and verify RED**

Expected: compilation fails because `ReferencePluginStore` is undefined.

- [ ] **Step 7: Implement atomic store**

Add:

```swift
enum ReferencePluginStore {
    struct LoadedReference: Equatable {
        let manifest: ReferencePluginManifest
        let remoteCacheURL: URL
    }

    enum CaptureOutcome: Equatable {
        case captured(remoteCount: Int, curatedCount: Int)
        case failed(reason: String)
    }

    static func capture(
        homeDirectory: String,
        storeDirectory: URL,
        fileManager: FileManager = .default
    ) -> CaptureOutcome

    static func load(
        storeDirectory: URL,
        fileManager: FileManager = .default
    ) -> LoadedReference?
}
```

Capture builds a sibling staging directory, copies the remote cache, writes sorted JSON, verifies by loading, then swaps the staging directory into place. On failure it restores the previous reference.

- [ ] **Step 8: Run tests and verify GREEN**

Expected: all infrastructure tests pass.

### Task 2: Local reference marketplace and rollback

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Consumes: `ReferencePluginStore.LoadedReference`.
- Produces: `ReferencePluginMarketplace.prepare(reference:fileManager:) -> PreparationOutcome`.
- Produces: `ReferenceMarketplacePluginReconciler.reconcile(homeDirectory:reference:runCommand:) -> ReconcileOutcome`.

- [ ] **Step 1: Write failing local-marketplace tests**

Create a reference containing `cloudflare`, `product-design`, and `vercel`. Assert preparation flattens valid versioned packages into a local marketplace with an exact manifest, and reconciliation installs the three selectors under `account-switcher-reference`.

- [ ] **Step 2: Run tests and verify RED**

Expected: compilation fails because `ReferencePluginMarketplace` is undefined.

- [ ] **Step 3: Implement staged local marketplace**

Add:

```swift
enum ReferenceMarketplacePluginReconciler {
    enum ReconcileOutcome: Equatable {
        case alreadyMatched
        case applied(changes: Int)
        case failed(reason: String)
    }

    static func reconcile(
        homeDirectory: String,
        reference: ReferencePluginStore.LoadedReference,
        runCommand: ([String]) -> CommandResult
    ) -> ReconcileOutcome
}
```

Preparation copies saved package versions into staging, verifies package identities, writes the marketplace manifest, and atomically replaces the prior local marketplace. Reconciliation registers it, removes stale installations, installs missing or content-changed packages, and verifies config plus installed content. `openai-curated-remote`, `openai-bundled`, and `openai-primary-runtime` are never mutated by this reconciler.

- [ ] **Step 4: Run tests and verify GREEN**

Expected: marketplace preparation and installation tests pass.

- [ ] **Step 5: Write failing rollback and idempotency tests**

Cover missing/corrupt packages, failed staging replacement, CLI failures, content changes with identical IDs, failed final verification, and repeated reconciliation. Assert config and installed caches return to their pre-reconciliation state after failure.

- [ ] **Step 6: Implement minimal rollback/error handling**

Add only the branches needed by the failing tests. Keep transaction backups until final Codex launch and content verification succeed.

- [ ] **Step 7: Run tests and verify GREEN**

Expected: all infrastructure tests pass without warnings.

### Task 3: Curated manifest enforcement and sync stability policy

**Files:**
- Modify: `Sources/AppInfrastructure.swift`
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Produces: `CuratedPluginPlan.commands(referenceIDs:installedIDs:) -> [[String]]`.
- Produces: `PluginSyncStabilityTracker.observe(inventory:modifiedAt:) -> Bool`.

- [ ] **Step 1: Write failing command-plan tests**

For reference `github`, installed `canva,github`, assert literal commands:

```swift
[
    ["plugin", "remove", "canva@openai-curated"],
]
```

For reference `github,vercel`, installed `github`, assert:

```swift
[
    ["plugin", "add", "vercel@openai-curated"]
]
```

Assert bundled and primary-runtime selectors never appear even when supplied as installed inputs.

- [ ] **Step 2: Run RED, implement `CuratedPluginPlan`, run GREEN**

Use set difference, sorted identifiers, removal before addition, and selectors suffixed with `@openai-curated`.

- [ ] **Step 3: Write failing sync stability tests**

Assert stability only after two consecutive identical `(inventory, modifiedAt)` observations and timeout decisions remain external to the tracker.

- [ ] **Step 4: Run RED, implement tracker, run GREEN**

Add a small value-type tracker with no sleeping or filesystem access.

### Task 4: App integration and explicit capture action

**Files:**
- Modify: `Sources/main.swift`
- Modify: `Sources/Models.swift` only if a new settings action enum case is required
- Modify: `Tests/InfrastructureTests.swift`

**Interfaces:**
- Consumes all Task 1–3 interfaces.
- Produces: Settings action `saveReferencePlugins`.
- Produces: `referencePluginStoreDirectory() -> URL` under Application Support.
- Changes: `restartCodexApp()` performs sync launch, reconciliation, and final launch.

- [ ] **Step 1: Add the settings action and capture handler**

Add `Save Current Plugins as Reference` to the existing settings menu/action routing. The handler calls `ReferencePluginStore.capture`, shows a success/failure alert, and never captures during switching.

- [ ] **Step 2: Integrate bounded sync observation**

After the first Codex launch, poll the remote cache inventory and directory modification time every 500 ms, requiring two identical observations, with a 15-second maximum. Append whether synchronization stabilized or timed out.

- [ ] **Step 3: Integrate reconciliation and final relaunch**

Terminate Codex after the sync launch, load the reference, prepare/register the local marketplace, install its packages, execute `CuratedPluginPlan` commands through the bundled CLI, then launch Codex once more. Commit the transaction only after content-level verification; otherwise roll back and reopen Codex. Format one concise transcript line from every outcome.

- [ ] **Step 4: Verify compilation and tests**

Run `./run-tests.sh` and `./build.sh`. Expected: exit `0` from both.

### Task 5: Install, capture canonical reference, and end-to-end verification

**Files:**
- No source changes expected.
- Runtime writes only to the switcher Application Support reference directory and Codex plugin caches/config.

- [ ] **Step 1: Remove the temporary duplicate CLI test installation**

Run `codex plugin remove superpowers@openai-curated`. Verify remote `superpowers` remains in `openai-curated-remote` and GitHub remains installed.

- [ ] **Step 2: Install and verify the app**

Run `./install.sh`, terminate the old `CodexAccountSwitcher`, reopen it, and run `./verify-install.sh`.

- [ ] **Step 3: Capture the current canonical account**

Invoke `Save Current Plugins as Reference`. Verify the stored remote IDs are exactly:

```text
cloudflare
openai-templates
plugin-management
product-design
superpowers
vercel
```

Verify curated IDs are exactly `github`.

- [ ] **Step 4: Switch to the non-canonical account**

After the switch completes, verify the six reference IDs are installed and enabled from `account-switcher-reference`; account-catalog packages such as `canva`, `data-analytics`, and `posthog` are not installed by the reference reconciler; bundled and primary-runtime plugins remain installed.

- [ ] **Step 5: Final verification**

Run `./run-tests.sh`, `./build.sh`, `./verify-install.sh`, and `git diff --check`. Record any remaining manual OAuth authorization requirement without treating it as a file-restoration failure.
