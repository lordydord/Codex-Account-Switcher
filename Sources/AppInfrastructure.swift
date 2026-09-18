import Darwin
import Foundation
import CryptoKit

enum SettingsNumericValidationError: Error, Equatable {
    case invalidDraft
    case outOfRange
}

enum SettingsNumericPolicy {
    static let reminderThresholdRange = 1...99
    static let creditExpiryLeadDaysRange = 1...30
    static let reminderThresholdDefault = 10
    static let creditExpiryLeadDaysDefault = 3

    static func normalizedInteger(
        _ draft: String,
        within range: ClosedRange<Int>
    ) -> Result<Int, SettingsNumericValidationError> {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty, let value = Int(trimmedDraft) else {
            return .failure(.invalidDraft)
        }
        guard range.contains(value) else {
            return .failure(.outOfRange)
        }
        return .success(value)
    }

    static func creditExpiryInterval(leadDays: Int) -> TimeInterval {
        TimeInterval(leadDays) * 24 * 60 * 60
    }
}

struct CommandResult {
    let status: Int32
    let output: String
}

enum WeeklyRemainingBand: Equatable {
    case unknown
    case healthy
    case warning
    case critical

    static func classify(_ remainingPercent: Int?) -> WeeklyRemainingBand {
        guard let remainingPercent else { return .unknown }
        let clamped = min(100, max(0, remainingPercent))
        if clamped <= 10 { return .critical }
        if clamped <= 25 { return .warning }
        return .healthy
    }
}

struct AccountUsagePairText: Equatable {
    let fiveHour: String
    let weekly: String
}

enum AccountUsagePresentationPolicy {
    static func pair(fiveHourRemaining: Int?, weeklyRemaining: Int?) -> AccountUsagePairText {
        AccountUsagePairText(
            fiveHour: percentText(fiveHourRemaining),
            weekly: percentText(weeklyRemaining)
        )
    }

    private static func percentText(_ remaining: Int?) -> String {
        guard let remaining else { return "--" }
        return "\(min(100, max(0, remaining)))%"
    }
}

enum AccountListPresentationPolicy {
    static let maximumRowsWithoutScrolling = 10

    static func visibleRowCount(accountCount: Int, availableRowCapacity: Int) -> Int {
        min(max(0, accountCount), min(maximumRowsWithoutScrolling, max(0, availableRowCapacity)))
    }

    static func requiresScrolling(accountCount: Int, availableRowCapacity: Int) -> Bool {
        accountCount > visibleRowCount(accountCount: accountCount, availableRowCapacity: availableRowCapacity)
    }

    static func viewportHeight(
        accountCount: Int,
        visibleRowCount: Int,
        maximumHeight: Double,
        rowHeight: Double,
        confirmationRowHeight: Double,
        rowGap: Double,
        showsConfirmation: Bool
    ) -> Double {
        let visibleRows = min(max(0, accountCount), max(0, visibleRowCount))
        guard visibleRows > 0 else { return 0 }

        let normalHeight = Double(visibleRows) * rowHeight + Double(max(0, visibleRows - 1)) * rowGap
        guard showsConfirmation else { return min(maximumHeight, normalHeight) }

        let completeRows = max(1, visibleRows - 1)
        let compactExpandedHeight = confirmationRowHeight
            + Double(max(0, completeRows - 1)) * rowHeight
            + Double(max(0, completeRows - 1)) * rowGap
        return min(maximumHeight, compactExpandedHeight)
    }
}

enum AccountRemovalPolicy {
    static func arguments(email: String, isActive: Bool) -> [String]? {
        guard !isActive else { return nil }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !email.hasPrefix("-"), email.contains("@") else { return nil }
        return ["remove", email]
    }
}

enum UsagePanelLayoutMetrics {
    static let verdictCardHeight = 108.0
    static let verdictResetGap = 10.0
    static let refreshButtonWidth = 68.0
    static let quitButtonWidth = 50.0
    static let footerButtonHeight = 26.0
    static let controlBarHeight = 40.0
    static let accountRowHeight = 39.0
    static let accountRowGap = 4.0
    static let accountPrimaryTrackHeight = 4.0
    static let accountSecondaryTrackHeight = 3.0
    static let accountSecondaryOpacity = 0.55
    static let accountListEdgeAllowance = 2.0
}

enum InlineSwitchDecision: Equatable {
    case ignore
    case arm
    case confirm
}

enum InlineSwitchConfirmationPolicy {
    static func decision(
        armedEmail: String?,
        requestedEmail: String,
        isActive: Bool,
        isSwitching: Bool
    ) -> InlineSwitchDecision {
        if isActive || isSwitching {
            return .ignore
        }
        return armedEmail == requestedEmail ? .confirm : .arm
    }
}

enum InlineQuitDecision: Equatable {
    case arm
    case confirm
}

enum InlineQuitConfirmationPolicy {
    static func decision(isArmed: Bool) -> InlineQuitDecision {
        isArmed ? .confirm : .arm
    }
}

enum ProcessRunner {
    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Data()

        func store(_ data: Data) {
            lock.lock()
            value = data
            lock.unlock()
        }

        func load() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String],
        input: Data? = nil,
        timeout: TimeInterval = 15
    ) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = input == nil ? nil : Pipe()
        let outputBox = DataBox()
        let outputGroup = DispatchGroup()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.standardInput = inputPipe

        do {
            try process.run()
        } catch {
            return CommandResult(status: 127, output: error.localizedDescription)
        }

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outputBox.store(outputPipe.fileHandleForReading.readDataToEndOfFile())
            outputGroup.leave()
        }

        if let inputPipe, let input {
            inputPipe.fileHandleForWriting.write(input)
            inputPipe.fileHandleForWriting.closeFile()
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        let timedOut = process.isRunning
        if timedOut {
            process.terminate()
            let terminationDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < terminationDeadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
            }
        }

        process.waitUntilExit()
        _ = outputGroup.wait(timeout: .now() + 2)
        var output = String(data: outputBox.load(), encoding: .utf8) ?? ""
        if timedOut {
            if !output.isEmpty, !output.hasSuffix("\n") {
                output += "\n"
            }
            output += "Command timed out after \(Int(timeout.rounded())) seconds."
        }
        return CommandResult(status: timedOut ? 124 : process.terminationStatus, output: output)
    }
}

enum ResetRefreshPolicy {
    static func shouldRefresh(lastRefresh: Date?, now: Date = Date(), ttl: TimeInterval, force: Bool) -> Bool {
        guard !force else { return true }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= ttl
    }
}

enum UsageRefreshPolicy {
    static func shouldRefresh(lastRefresh: Date?, now: Date = Date(), ttl: TimeInterval, force: Bool) -> Bool {
        guard !force else { return true }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= ttl
    }
}

enum LastKnownGoodSnapshotPolicy {
    static func merged<Key: Hashable, Value>(
        current: [Key: Value],
        successful: [Key: Value],
        validKeys: Set<Key>
    ) -> [Key: Value] {
        var merged = current.filter { validKeys.contains($0.key) }
        for (key, value) in successful where validKeys.contains(key) {
            merged[key] = value
        }
        return merged
    }
}

enum ToolbarStatusFormatter {
    static func text(usage: String) -> String {
        usage
    }
}

enum StatusAnimationPolicy {
    static func shouldContinue(isSwitching: Bool, isRedeemingReset: Bool) -> Bool {
        isSwitching || isRedeemingReset
    }
}

enum ComputerUsePluginLocator {
    static func latestApp(in versionsRoot: URL, fileManager: FileManager = .default) -> URL? {
        guard let versionDirectories = try? fileManager.contentsOfDirectory(
            at: versionsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return versionDirectories
            .compactMap { directory -> (version: String, app: URL)? in
                let app = directory.appendingPathComponent("Codex Computer Use.app", isDirectory: true)
                guard fileManager.fileExists(atPath: app.path) else { return nil }
                return (directory.lastPathComponent, app)
            }
            .sorted { left, right in
                left.version.compare(right.version, options: .numeric) == .orderedDescending
            }
            .first?.app
    }

    static func latestApp(homeDirectory: String, fileManager: FileManager = .default) -> URL? {
        latestApp(
            in: URL(fileURLWithPath: homeDirectory)
                .appendingPathComponent(".codex/plugins/cache/openai-bundled/computer-use", isDirectory: true),
            fileManager: fileManager
        )
    }
}

enum BundledMarketplaceInspector {
    enum SnapshotState: Equatable {
        case ok
        case incomplete(missing: [String])
        case absent
    }

    static func expectedPluginIDs() -> [String] {
        ["browser", "chrome", "computer-use"]
    }

    static func snapshotRoot(homeDirectory: String) -> URL {
        URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".codex/.tmp/bundled-marketplaces/openai-bundled", isDirectory: true)
    }

    static func pluginIDs(in marketplace: URL, fileManager: FileManager = .default) -> [String] {
        let plugins = marketplace.appendingPathComponent("plugins", isDirectory: true)
        guard let directories = try? fileManager.contentsOfDirectory(
            at: plugins,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return directories
            .filter { fileManager.fileExists(atPath: $0.appendingPathComponent(".codex-plugin").path) }
            .map(\.lastPathComponent)
            .sorted()
    }

    static func snapshotState(
        homeDirectory: String,
        requiredPluginIDs: [String]? = nil,
        fileManager: FileManager = .default
    ) -> SnapshotState {
        let snapshot = snapshotRoot(homeDirectory: homeDirectory)
        guard fileManager.fileExists(atPath: snapshot.path) else { return .absent }
        let missing = (requiredPluginIDs ?? expectedPluginIDs()).filter { id in
            let manifest = snapshot.appendingPathComponent("plugins/\(id)/.codex-plugin")
            return !fileManager.fileExists(atPath: manifest.path)
        }
        return missing.isEmpty ? .ok : .incomplete(missing: missing)
    }

    static func appMarketplaceSource(appPath: String, fileManager: FileManager = .default) -> URL? {
        let candidates = [
            URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/plugins/openai-bundled"),
            URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/openai-bundled")
        ]
        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }
}

enum BundledMarketplaceRepairer {
    enum RepairOutcome: Equatable {
        case ok
        case repairedFromApp
        case repairedByStaleMove
        case noAppFound
        case failed(reason: String)
    }

    static func repairIfNeeded(
        homeDirectory: String,
        appPath: String,
        fileManager: FileManager = .default,
        codexExecutable: String? = nil,
        pluginRunner: ((String, [String], [String: String]) -> CommandResult)? = nil
    ) -> RepairOutcome {
        let source = BundledMarketplaceInspector.appMarketplaceSource(appPath: appPath, fileManager: fileManager)
        let discoveredPluginIDs = source.map {
            BundledMarketplaceInspector.pluginIDs(in: $0, fileManager: fileManager)
        } ?? []
        let requiredPluginIDs = Array(
            Set(BundledMarketplaceInspector.expectedPluginIDs() + discoveredPluginIDs)
        ).sorted()
        let state = BundledMarketplaceInspector.snapshotState(
            homeDirectory: homeDirectory,
            requiredPluginIDs: requiredPluginIDs,
            fileManager: fileManager
        )
        guard state != .ok else { return .ok }
        guard fileManager.fileExists(atPath: appPath) else { return .noAppFound }

        let snapshot = BundledMarketplaceInspector.snapshotRoot(homeDirectory: homeDirectory)
        let marketplaceDir = snapshot.deletingLastPathComponent()

        if let source {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = marketplaceDir.appendingPathComponent("bundled-marketplaces.bak.\(stamp)")
            let snapshotExisted = fileManager.fileExists(atPath: snapshot.path)
            do {
                try fileManager.createDirectory(at: marketplaceDir, withIntermediateDirectories: true)
                if snapshotExisted {
                    try moveItem(source: snapshot, to: backup, fileManager: fileManager)
                }
                try fileManager.copyItem(at: source, to: snapshot)
            } catch {
                restoreBackup(
                    backup: backup,
                    snapshot: snapshot,
                    originallyExisted: snapshotExisted,
                    fileManager: fileManager
                )
                return .failed(reason: "snapshot copy failed: \(error.localizedDescription)")
            }

            let recheck = BundledMarketplaceInspector.snapshotState(
                homeDirectory: homeDirectory,
                requiredPluginIDs: requiredPluginIDs,
                fileManager: fileManager
            )
            guard recheck == .ok else {
                restoreBackup(
                    backup: backup,
                    snapshot: snapshot,
                    originallyExisted: snapshotExisted,
                    fileManager: fileManager
                )
                return .failed(reason: "snapshot verification failed after repair")
            }

            if let codexExecutable {
                let runner = pluginRunner ?? { executable, arguments, environment in
                    ProcessRunner.run(executable, arguments, environment: environment)
                }
                for id in enabledPluginIDs(
                    homeDirectory: homeDirectory,
                    candidatePluginIDs: requiredPluginIDs,
                    fileManager: fileManager
                ) {
                    let result = runner(codexExecutable, ["plugin", "add", "\(id)@openai-bundled"], [:])
                    if result.status != 0 {
                        restoreBackup(
                            backup: backup,
                            snapshot: snapshot,
                            originallyExisted: snapshotExisted,
                            fileManager: fileManager
                        )
                        return .failed(reason: "snapshot repaired but plugin reinstall failed for \(id): \(result.output)")
                    }
                }
            }
            return .repairedFromApp
        }

        // Fallback A: app exists but contains no marketplace — move the stale snapshot aside so Codex regenerates it.
        if case .incomplete = state {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = marketplaceDir.appendingPathComponent("bundled-marketplaces.bak.\(stamp)")
            do {
                try fileManager.moveItem(at: snapshot, to: backup)
                return .repairedByStaleMove
            } catch {
                return .failed(reason: "stale snapshot move failed: \(error.localizedDescription)")
            }
        }
        return .noAppFound
    }

    private static func enabledPluginIDs(
        homeDirectory: String,
        candidatePluginIDs: [String],
        fileManager: FileManager = .default
    ) -> [String] {
        let configURL = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex/config.toml")
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }
        return candidatePluginIDs.filter { id in
            config.contains("[plugins.\"\(id)@openai-bundled\"]") || config.contains("[plugins.\"\(id)\"]")
        }
    }

    private static func moveItem(source: URL, to destination: URL, fileManager: FileManager) throws {
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            try fileManager.copyItem(at: source, to: destination)
            try fileManager.removeItem(at: source)
        }
    }

    private static func restoreBackup(
        backup: URL,
        snapshot: URL,
        originallyExisted: Bool,
        fileManager: FileManager
    ) {
        if fileManager.fileExists(atPath: snapshot.path) {
            try? fileManager.removeItem(at: snapshot)
        }
        if originallyExisted, fileManager.fileExists(atPath: backup.path) {
            try? fileManager.moveItem(at: backup, to: snapshot)
        }
    }
}

enum ReferencePluginInventory {
    static func remotePluginIDs(homeDirectory: String, fileManager: FileManager = .default) -> [String] {
        let cache = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".codex/plugins/cache/openai-curated-remote", isDirectory: true)
        return remotePluginIDs(in: cache, fileManager: fileManager)
    }

    static func remotePluginIDs(in cache: URL, fileManager: FileManager = .default) -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: cache,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.compactMap { entry in
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return entry.lastPathComponent
        }.sorted()
    }

    static func curatedPluginIDs(configText: String) -> [String] {
        pluginIDs(configText: configText, marketplace: "openai-curated")
    }

    static func pluginIDs(configText: String, marketplace: String) -> [String] {
        let prefix = "[plugins.\""
        let suffix = "@\(marketplace)\"]"
        var currentID: String?
        var enabledIDs: [String] = []

        for rawLine in configText.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                if line.hasPrefix(prefix), line.hasSuffix(suffix) {
                    currentID = String(line.dropFirst(prefix.count).dropLast(suffix.count))
                } else {
                    currentID = nil
                }
                continue
            }
            if line == "enabled = true", let currentID {
                enabledIDs.append(currentID)
            }
        }
        return Array(Set(enabledIDs)).sorted()
    }

    static func remoteTreeDigest(in cache: URL, fileManager: FileManager = .default) -> String? {
        guard let enumerator = fileManager.enumerator(
            at: cache,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return nil
        }
        let normalizedRootPath = cache.resolvingSymlinksInPath().standardizedFileURL.path
        let entries = enumerator.compactMap { value -> (url: URL, relativePath: String)? in
            guard let url = value as? URL else { return nil }
            let normalizedPath = url.standardizedFileURL.path
            guard normalizedPath.hasPrefix(normalizedRootPath + "/") else { return nil }
            return (url, String(normalizedPath.dropFirst(normalizedRootPath.count + 1)))
        }.sorted { $0.relativePath < $1.relativePath }
        var hasher = SHA256()
        for entry in entries {
            guard let values = try? entry.url.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            ) else { return nil }
            let marker: String
            if values.isSymbolicLink == true {
                marker = "L"
            } else if values.isDirectory == true {
                marker = "D"
            } else if values.isRegularFile == true {
                marker = "F"
            } else {
                marker = "O"
            }
            hasher.update(data: Data("\(marker):\(entry.relativePath)\u{0}".utf8))
            if values.isSymbolicLink == true {
                guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: entry.url.path) else { return nil }
                hasher.update(data: Data(destination.utf8))
            } else if values.isRegularFile == true {
                guard let data = try? Data(contentsOf: entry.url) else { return nil }
                hasher.update(data: data)
            }
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum ReferencePluginMarketplace {
    static let name = "account-switcher-reference"

    enum PreparationOutcome: Equatable {
        case prepared(marketplaceURL: URL, pluginIDs: [String])
        case failed(reason: String)
    }

    static func prepare(
        reference: ReferencePluginStore.LoadedReference,
        fileManager: FileManager = .default
    ) -> PreparationOutcome {
        let storeDirectory = reference.remoteCacheURL.deletingLastPathComponent()
        let marketplaceURL = storeDirectory.appendingPathComponent("local-marketplace", isDirectory: true)
        let stagingURL = storeDirectory.appendingPathComponent(
            ".local-marketplace.staging.\(UUID().uuidString)",
            isDirectory: true
        )
        let backupURL = storeDirectory.appendingPathComponent(
            ".local-marketplace.backup.\(UUID().uuidString)",
            isDirectory: true
        )

        do {
            let pluginsURL = stagingURL.appendingPathComponent("plugins", isDirectory: true)
            let manifestDirectory = stagingURL.appendingPathComponent(".agents/plugins", isDirectory: true)
            try fileManager.createDirectory(at: pluginsURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)

            var entries: [MarketplaceManifest.Plugin] = []
            for pluginID in reference.manifest.remotePluginIDs {
                let sourceRoot = reference.remoteCacheURL.appendingPathComponent(pluginID, isDirectory: true)
                guard let source = latestValidPackage(
                    pluginID: pluginID,
                    sourceRoot: sourceRoot,
                    fileManager: fileManager
                ) else {
                    throw MarketplaceError.missingPackage(pluginID)
                }
                try fileManager.copyItem(at: source, to: pluginsURL.appendingPathComponent(pluginID, isDirectory: true))
                entries.append(
                    MarketplaceManifest.Plugin(
                        name: pluginID,
                        source: .init(source: "local", path: "./plugins/\(pluginID)"),
                        policy: .init(installation: "AVAILABLE")
                    )
                )
            }

            let manifest = MarketplaceManifest(name: name, plugins: entries)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(
                to: manifestDirectory.appendingPathComponent("marketplace.json"),
                options: .atomic
            )
            guard validate(marketplaceURL: stagingURL, expectedIDs: reference.manifest.remotePluginIDs, fileManager: fileManager) else {
                throw MarketplaceError.verificationFailed
            }

            if fileManager.fileExists(atPath: marketplaceURL.path) {
                try fileManager.moveItem(at: marketplaceURL, to: backupURL)
            }
            do {
                try fileManager.moveItem(at: stagingURL, to: marketplaceURL)
                guard validate(
                    marketplaceURL: marketplaceURL,
                    expectedIDs: reference.manifest.remotePluginIDs,
                    fileManager: fileManager
                ) else {
                    throw MarketplaceError.verificationFailed
                }
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
            } catch {
                if fileManager.fileExists(atPath: marketplaceURL.path) {
                    try? fileManager.removeItem(at: marketplaceURL)
                }
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.moveItem(at: backupURL, to: marketplaceURL)
                }
                throw error
            }
            return .prepared(marketplaceURL: marketplaceURL, pluginIDs: reference.manifest.remotePluginIDs)
        } catch {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
            return .failed(reason: error.localizedDescription)
        }
    }

    static func staleInstalledPluginIDs(
        marketplaceURL: URL,
        installedCacheURL: URL,
        pluginIDs: [String],
        fileManager: FileManager = .default
    ) -> [String] {
        pluginIDs.filter { pluginID in
            let referencePackage = marketplaceURL.appendingPathComponent("plugins/\(pluginID)", isDirectory: true)
            let installedRoot = installedCacheURL.appendingPathComponent(pluginID, isDirectory: true)
            guard let installedPackage = latestValidPackage(
                pluginID: pluginID,
                sourceRoot: installedRoot,
                fileManager: fileManager
            ) else { return true }
            return !packageDigestsMatch(
                installed: ReferencePluginInventory.remoteTreeDigest(in: installedPackage, fileManager: fileManager),
                reference: ReferencePluginInventory.remoteTreeDigest(in: referencePackage, fileManager: fileManager)
            )
        }.sorted()
    }

    static func packageDigestsMatch(installed: String?, reference: String?) -> Bool {
        guard let installed, let reference else { return false }
        return installed == reference
    }

    private static func latestValidPackage(
        pluginID: String,
        sourceRoot: URL,
        fileManager: FileManager
    ) -> URL? {
        guard let versions = try? fileManager.contentsOfDirectory(
            at: sourceRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return versions.sorted {
            $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending
        }.first { version in
            let manifestURL = version.appendingPathComponent(".codex-plugin/plugin.json")
            guard
                let data = try? Data(contentsOf: manifestURL),
                let manifest = try? JSONDecoder().decode(PluginIdentity.self, from: data)
            else { return false }
            return manifest.name == pluginID
        }
    }

    private static func validate(
        marketplaceURL: URL,
        expectedIDs: [String],
        fileManager: FileManager
    ) -> Bool {
        let manifestURL = marketplaceURL.appendingPathComponent(".agents/plugins/marketplace.json")
        guard
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(MarketplaceManifest.self, from: data),
            manifest.name == name,
            manifest.plugins.map(\.name).sorted() == expectedIDs.sorted()
        else { return false }
        return expectedIDs.allSatisfy { pluginID in
            fileManager.fileExists(
                atPath: marketplaceURL.appendingPathComponent("plugins/\(pluginID)/.codex-plugin/plugin.json").path
            )
        }
    }

    private struct PluginIdentity: Decodable {
        let name: String
    }

    private struct MarketplaceManifest: Codable {
        let name: String
        let plugins: [Plugin]

        struct Plugin: Codable {
            let name: String
            let source: Source
            let policy: Policy
        }

        struct Source: Codable {
            let source: String
            let path: String
        }

        struct Policy: Codable {
            let installation: String
        }
    }

    private enum MarketplaceError: LocalizedError {
        case missingPackage(String)
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .missingPackage(let pluginID):
                return "saved plugin package is invalid: \(pluginID)"
            case .verificationFailed:
                return "local reference marketplace verification failed"
            }
        }
    }
}

struct ReferencePluginManifest: Codable, Equatable {
    let schemaVersion: Int
    let capturedAt: Date
    let remotePluginIDs: [String]
    let remoteTreeDigest: String
    let curatedPluginIDs: [String]
}

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
    ) -> CaptureOutcome {
        let home = URL(fileURLWithPath: homeDirectory)
        let sourceCache = home.appendingPathComponent(
            ".codex/plugins/cache/openai-curated-remote",
            isDirectory: true
        )
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceCache.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failed(reason: "remote plugin cache is missing")
        }

        let configURL = home.appendingPathComponent(".codex/config.toml")
        let configText: String
        do {
            configText = try String(contentsOf: configURL, encoding: .utf8)
        } catch {
            return .failed(reason: "config.toml could not be read: \(error.localizedDescription)")
        }
        let remoteIDs = ReferencePluginInventory.remotePluginIDs(in: sourceCache, fileManager: fileManager)
        guard let remoteTreeDigest = ReferencePluginInventory.remoteTreeDigest(in: sourceCache, fileManager: fileManager) else {
            return .failed(reason: "remote plugin cache could not be fingerprinted")
        }
        let curatedIDs = ReferencePluginInventory.curatedPluginIDs(configText: configText)
        let parent = storeDirectory.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".reference-plugins.staging.\(UUID().uuidString)", isDirectory: true)
        let backup = parent.appendingPathComponent(".reference-plugins.backup.\(UUID().uuidString)", isDirectory: true)
        let hadPreviousReference = fileManager.fileExists(atPath: storeDirectory.path)
        let previousReference = load(storeDirectory: storeDirectory, fileManager: fileManager)

        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try fileManager.copyItem(
                at: sourceCache,
                to: staging.appendingPathComponent("openai-curated-remote", isDirectory: true)
            )
            let manifest = ReferencePluginManifest(
                schemaVersion: 1,
                capturedAt: Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)),
                remotePluginIDs: remoteIDs,
                remoteTreeDigest: remoteTreeDigest,
                curatedPluginIDs: curatedIDs
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(
                to: staging.appendingPathComponent("manifest.json"),
                options: .atomic
            )
            guard load(storeDirectory: staging, fileManager: fileManager)?.manifest == manifest else {
                throw ReferencePluginStoreError.verificationFailed
            }

            if fileManager.fileExists(atPath: storeDirectory.path) {
                try fileManager.moveItem(at: storeDirectory, to: backup)
            }
            do {
                try fileManager.moveItem(at: staging, to: storeDirectory)
                guard load(storeDirectory: storeDirectory, fileManager: fileManager)?.manifest == manifest else {
                    throw ReferencePluginStoreError.verificationFailed
                }
                if fileManager.fileExists(atPath: backup.path) {
                    try fileManager.removeItem(at: backup)
                }
            } catch {
                let swapFailure = error
                if fileManager.fileExists(atPath: storeDirectory.path) {
                    do {
                        try fileManager.removeItem(at: storeDirectory)
                    } catch {
                        return .failed(
                            reason: "\(swapFailure.localizedDescription); rollback failed: \(error.localizedDescription); backup kept at \(backup.path)"
                        )
                    }
                }
                if hadPreviousReference {
                    do {
                        guard fileManager.fileExists(atPath: backup.path) else {
                            throw ReferencePluginStoreError.rollbackVerificationFailed
                        }
                        try fileManager.moveItem(at: backup, to: storeDirectory)
                        if let previousReference {
                            guard load(storeDirectory: storeDirectory, fileManager: fileManager) == previousReference else {
                                throw ReferencePluginStoreError.rollbackVerificationFailed
                            }
                        } else if !fileManager.fileExists(atPath: storeDirectory.path) {
                            throw ReferencePluginStoreError.rollbackVerificationFailed
                        }
                    } catch {
                        return .failed(
                            reason: "\(swapFailure.localizedDescription); rollback failed: \(error.localizedDescription); backup kept at \(backup.path)"
                        )
                    }
                }
                return .failed(reason: "\(swapFailure.localizedDescription); previous reference restored")
            }
            return .captured(remoteCount: remoteIDs.count, curatedCount: curatedIDs.count)
        } catch {
            if fileManager.fileExists(atPath: staging.path) {
                try? fileManager.removeItem(at: staging)
            }
            return .failed(reason: error.localizedDescription)
        }
    }

    static func load(
        storeDirectory: URL,
        fileManager: FileManager = .default
    ) -> LoadedReference? {
        let manifestURL = storeDirectory.appendingPathComponent("manifest.json")
        let remoteCacheURL = storeDirectory.appendingPathComponent("openai-curated-remote", isDirectory: true)
        guard
            let data = try? Data(contentsOf: manifestURL),
            let manifest = decodeManifest(data),
            manifest.schemaVersion == 1,
            ReferencePluginInventory.remotePluginIDs(in: remoteCacheURL, fileManager: fileManager) == manifest.remotePluginIDs,
            ReferencePluginInventory.remoteTreeDigest(in: remoteCacheURL, fileManager: fileManager) == manifest.remoteTreeDigest
        else {
            return nil
        }
        return LoadedReference(manifest: manifest, remoteCacheURL: remoteCacheURL)
    }

    private static func decodeManifest(_ data: Data) -> ReferencePluginManifest? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReferencePluginManifest.self, from: data)
    }

    private enum ReferencePluginStoreError: LocalizedError {
        case verificationFailed
        case rollbackVerificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "reference plugin verification failed"
            case .rollbackVerificationFailed:
                return "reference plugin rollback verification failed"
            }
        }
    }
}

enum ReferencePluginReconciler {
    enum ReconcileOutcome: Equatable {
        case alreadyMatched
        case applied(added: [String], removed: [String])
        case noReference
        case failed(reason: String)
    }

    static func reconcile(
        homeDirectory: String,
        reference: ReferencePluginStore.LoadedReference?,
        fileManager: FileManager = .default
    ) -> ReconcileOutcome {
        guard let reference else { return .noReference }
        let activeCache = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".codex/plugins/cache/openai-curated-remote", isDirectory: true)
        let cacheParent = activeCache.deletingLastPathComponent()
        let currentIDs = ReferencePluginInventory.remotePluginIDs(in: activeCache, fileManager: fileManager)
        let referenceIDs = reference.manifest.remotePluginIDs
        let currentDigest = ReferencePluginInventory.remoteTreeDigest(in: activeCache, fileManager: fileManager)
        guard currentIDs != referenceIDs || currentDigest != reference.manifest.remoteTreeDigest else {
            return .alreadyMatched
        }

        let currentSet = Set(currentIDs)
        let referenceSet = Set(referenceIDs)
        let added = referenceSet.subtracting(currentSet).sorted()
        let removed = currentSet.subtracting(referenceSet).sorted()
        let staging = cacheParent.appendingPathComponent(
            "openai-curated-remote.staging.\(UUID().uuidString)",
            isDirectory: true
        )
        let backup = cacheParent.appendingPathComponent(
            "openai-curated-remote.backup.\(Int(Date().timeIntervalSince1970)).\(UUID().uuidString)",
            isDirectory: true
        )
        var activeWasMoved = false

        do {
            try fileManager.createDirectory(at: cacheParent, withIntermediateDirectories: true)
            try fileManager.copyItem(at: reference.remoteCacheURL, to: staging)
            guard
                ReferencePluginInventory.remotePluginIDs(in: staging, fileManager: fileManager) == referenceIDs,
                ReferencePluginInventory.remoteTreeDigest(in: staging, fileManager: fileManager) == reference.manifest.remoteTreeDigest
            else {
                throw ReferencePluginReconcileError.verificationFailed
            }
            if fileManager.fileExists(atPath: activeCache.path) {
                try fileManager.moveItem(at: activeCache, to: backup)
                activeWasMoved = true
            }
            do {
                try fileManager.moveItem(at: staging, to: activeCache)
                guard
                    ReferencePluginInventory.remotePluginIDs(in: activeCache, fileManager: fileManager) == referenceIDs,
                    ReferencePluginInventory.remoteTreeDigest(in: activeCache, fileManager: fileManager) == reference.manifest.remoteTreeDigest
                else {
                    throw ReferencePluginReconcileError.verificationFailed
                }
            } catch {
                let swapFailure = error
                if fileManager.fileExists(atPath: activeCache.path) {
                    do {
                        try fileManager.removeItem(at: activeCache)
                    } catch {
                        return .failed(
                            reason: "\(swapFailure.localizedDescription); rollback failed: \(error.localizedDescription); backup kept at \(backup.path)"
                        )
                    }
                }
                if activeWasMoved {
                    do {
                        guard fileManager.fileExists(atPath: backup.path) else {
                            throw ReferencePluginReconcileError.rollbackVerificationFailed
                        }
                        try fileManager.moveItem(at: backup, to: activeCache)
                        guard
                            ReferencePluginInventory.remotePluginIDs(in: activeCache, fileManager: fileManager) == currentIDs,
                            ReferencePluginInventory.remoteTreeDigest(in: activeCache, fileManager: fileManager) == currentDigest
                        else {
                            throw ReferencePluginReconcileError.rollbackVerificationFailed
                        }
                    } catch {
                        return .failed(
                            reason: "\(swapFailure.localizedDescription); rollback failed: \(error.localizedDescription); backup kept at \(backup.path)"
                        )
                    }
                }
                return .failed(reason: "\(swapFailure.localizedDescription); previous remote plugin state restored")
            }
            pruneBackups(in: cacheParent, fileManager: fileManager)
            return .applied(added: added, removed: removed)
        } catch {
            if fileManager.fileExists(atPath: staging.path) {
                try? fileManager.removeItem(at: staging)
            }
            return .failed(reason: error.localizedDescription)
        }
    }

    private static func pruneBackups(in directory: URL, keeping keepCount: Int = 3, fileManager: FileManager) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let backups = entries
            .filter { $0.lastPathComponent.hasPrefix("openai-curated-remote.backup.") }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }
        for backup in backups.dropFirst(keepCount) {
            try? fileManager.removeItem(at: backup)
        }
    }

    private enum ReferencePluginReconcileError: LocalizedError {
        case verificationFailed
        case rollbackVerificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "reference plugin reconciliation verification failed"
            case .rollbackVerificationFailed:
                return "reference plugin rollback verification failed"
            }
        }
    }
}

enum PluginInstallPlan {
    static func commands(
        referenceIDs: [String],
        installedIDs: [String],
        staleIDs: [String] = [],
        marketplace: String
    ) -> [[String]] {
        guard isBarePluginID(marketplace) else { return [] }
        let reference = Set(referenceIDs.filter(isBarePluginID))
        let installed = Set(installedIDs.filter(isBarePluginID))
        let stale = Set(staleIDs.filter(isBarePluginID)).intersection(reference).intersection(installed)
        let removals = installed.subtracting(reference).union(stale).sorted().map {
            ["plugin", "remove", "\($0)@\(marketplace)"]
        }
        let additions = reference.subtracting(installed).union(stale).sorted().map {
            ["plugin", "add", "\($0)@\(marketplace)"]
        }
        return removals + additions
    }

    private static func isBarePluginID(_ id: String) -> Bool {
        !id.isEmpty && !id.contains("@") && !id.contains(where: \.isWhitespace)
    }
}

enum CuratedPluginPlan {
    static func commands(referenceIDs: [String], installedIDs: [String]) -> [[String]] {
        PluginInstallPlan.commands(
            referenceIDs: referenceIDs,
            installedIDs: installedIDs,
            marketplace: "openai-curated"
        )
    }
}

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
    ) -> ReconcileOutcome {
        let marketplaceURL: URL
        let referenceIDs: [String]
        switch ReferencePluginMarketplace.prepare(reference: reference) {
        case .prepared(let url, let pluginIDs):
            marketplaceURL = url
            referenceIDs = pluginIDs
        case .failed(let reason):
            return .failed(reason: reason)
        }

        let configURL = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex/config.toml")
        guard var configText = try? String(contentsOf: configURL, encoding: .utf8) else {
            return .failed(reason: "config.toml could not be read")
        }
        var changeCount = 0
        let marketplaceHeader = "[marketplaces.\(ReferencePluginMarketplace.name)]"
        if !configText.contains(marketplaceHeader) {
            let result = runCommand(["plugin", "marketplace", "add", marketplaceURL.path])
            guard result.status == 0 else {
                return .failed(reason: "reference marketplace registration failed: \(result.output)")
            }
            changeCount += 1
            guard let updatedConfig = try? String(contentsOf: configURL, encoding: .utf8) else {
                return .failed(reason: "config.toml could not be read after marketplace registration")
            }
            configText = updatedConfig
        }

        let installedIDs = ReferencePluginInventory.pluginIDs(
            configText: configText,
            marketplace: ReferencePluginMarketplace.name
        )
        let installedCache = URL(fileURLWithPath: homeDirectory).appendingPathComponent(
            ".codex/plugins/cache/\(ReferencePluginMarketplace.name)",
            isDirectory: true
        )
        let staleIDs = ReferencePluginMarketplace.staleInstalledPluginIDs(
            marketplaceURL: marketplaceURL,
            installedCacheURL: installedCache,
            pluginIDs: referenceIDs
        )
        let commands = PluginInstallPlan.commands(
            referenceIDs: referenceIDs,
            installedIDs: installedIDs,
            staleIDs: staleIDs,
            marketplace: ReferencePluginMarketplace.name
        )
        for arguments in commands {
            let result = runCommand(arguments)
            guard result.status == 0 else {
                return .failed(reason: "\(arguments.joined(separator: " ")) failed: \(result.output)")
            }
            changeCount += 1
        }

        guard
            let finalConfig = try? String(contentsOf: configURL, encoding: .utf8),
            ReferencePluginInventory.pluginIDs(
                configText: finalConfig,
                marketplace: ReferencePluginMarketplace.name
            ) == referenceIDs.sorted(),
            ReferencePluginMarketplace.staleInstalledPluginIDs(
                marketplaceURL: marketplaceURL,
                installedCacheURL: installedCache,
                pluginIDs: referenceIDs
            ).isEmpty
        else {
            return .failed(reason: "reference marketplace plugin verification failed")
        }
        return changeCount == 0 ? .alreadyMatched : .applied(changes: changeCount)
    }
}

enum CuratedPluginReconciler {
    enum ReconcileOutcome: Equatable {
        case alreadyMatched
        case applied(changes: Int)
        case failed(reason: String)
    }

    static func reconcile(
        homeDirectory: String,
        referenceIDs: [String],
        fileManager: FileManager = .default,
        runCommand: ([String]) -> CommandResult
    ) -> ReconcileOutcome {
        let codexDirectory = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex", isDirectory: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let curatedCache = codexDirectory.appendingPathComponent("plugins/cache/openai-curated", isDirectory: true)
        let originalConfig: Data
        do {
            originalConfig = try Data(contentsOf: configURL)
        } catch {
            return .failed(reason: "config.toml could not be read: \(error.localizedDescription)")
        }
        guard let configText = String(data: originalConfig, encoding: .utf8) else {
            return .failed(reason: "config.toml is not valid UTF-8")
        }
        let installedIDs = ReferencePluginInventory.curatedPluginIDs(configText: configText)
        let commands = CuratedPluginPlan.commands(referenceIDs: referenceIDs, installedIDs: installedIDs)
        guard !commands.isEmpty else { return .alreadyMatched }

        let backupDirectory = codexDirectory.appendingPathComponent(
            ".curated-plugin-backup.\(UUID().uuidString)",
            isDirectory: true
        )
        let backupCache = backupDirectory.appendingPathComponent("openai-curated", isDirectory: true)
        let cacheExisted = fileManager.fileExists(atPath: curatedCache.path)
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            if cacheExisted {
                try fileManager.copyItem(at: curatedCache, to: backupCache)
            }
        } catch {
            try? fileManager.removeItem(at: backupDirectory)
            return .failed(reason: "curated plugin backup failed: \(error.localizedDescription)")
        }

        func rollback(after failure: String) -> ReconcileOutcome {
            do {
                try originalConfig.write(to: configURL, options: .atomic)
                if fileManager.fileExists(atPath: curatedCache.path) {
                    try fileManager.removeItem(at: curatedCache)
                }
                if cacheExisted {
                    try fileManager.createDirectory(at: curatedCache.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fileManager.copyItem(at: backupCache, to: curatedCache)
                }
                guard try Data(contentsOf: configURL) == originalConfig else {
                    throw CuratedPluginReconcileError.rollbackVerificationFailed
                }
                let restoredCacheExists = fileManager.fileExists(atPath: curatedCache.path)
                guard restoredCacheExists == cacheExisted else {
                    throw CuratedPluginReconcileError.rollbackVerificationFailed
                }
                if cacheExisted {
                    guard ReferencePluginInventory.remoteTreeDigest(in: curatedCache, fileManager: fileManager)
                        == ReferencePluginInventory.remoteTreeDigest(in: backupCache, fileManager: fileManager) else {
                        throw CuratedPluginReconcileError.rollbackVerificationFailed
                    }
                }
                try fileManager.removeItem(at: backupDirectory)
                return .failed(reason: failure + "; previous curated plugin state restored")
            } catch {
                return .failed(
                    reason: failure + "; rollback failed: \(error.localizedDescription); backup kept at \(backupDirectory.path)"
                )
            }
        }

        for arguments in commands {
            let result = runCommand(arguments)
            guard result.status == 0 else {
                return rollback(after: "\(arguments.joined(separator: " ")) failed: \(result.output)")
            }
        }
        do {
            let finalConfig = try String(contentsOf: configURL, encoding: .utf8)
            guard ReferencePluginInventory.curatedPluginIDs(configText: finalConfig) == referenceIDs.sorted() else {
                return rollback(after: "curated plugin verification failed")
            }
            try fileManager.removeItem(at: backupDirectory)
            return .applied(changes: commands.count)
        } catch {
            return rollback(after: "curated plugin verification failed: \(error.localizedDescription)")
        }
    }

    private enum CuratedPluginReconcileError: LocalizedError {
        case rollbackVerificationFailed

        var errorDescription: String? {
            "curated plugin rollback verification failed"
        }
    }
}

enum ReferencePluginTransaction {
    enum Outcome: Equatable {
        case applied
        case failed(reason: String)
    }

    enum FinalizationOutcome: Equatable {
        case success
        case rollback(reason: String)
        case preserveBackup(reason: String)
    }

    static func perform(
        homeDirectory: String,
        fileManager: FileManager = .default,
        finalize: () -> FinalizationOutcome = { .success },
        operation: () -> String?
    ) -> Outcome {
        let codexDirectory = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex", isDirectory: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let remoteCache = codexDirectory.appendingPathComponent("plugins/cache/openai-curated-remote", isDirectory: true)
        let curatedCache = codexDirectory.appendingPathComponent("plugins/cache/openai-curated", isDirectory: true)
        let referenceCache = codexDirectory.appendingPathComponent(
            "plugins/cache/\(ReferencePluginMarketplace.name)",
            isDirectory: true
        )
        let backupDirectory = codexDirectory.appendingPathComponent(
            ".reference-plugin-transaction.\(UUID().uuidString)",
            isDirectory: true
        )
        let backupRemote = backupDirectory.appendingPathComponent("openai-curated-remote", isDirectory: true)
        let backupCurated = backupDirectory.appendingPathComponent("openai-curated", isDirectory: true)
        let backupReference = backupDirectory.appendingPathComponent(ReferencePluginMarketplace.name, isDirectory: true)
        let backupConfig = backupDirectory.appendingPathComponent("config.toml")

        let originalConfig: Data
        do {
            originalConfig = try Data(contentsOf: configURL)
        } catch {
            return .failed(reason: "plugin transaction could not read config.toml: \(error.localizedDescription)")
        }
        let remoteExisted = fileManager.fileExists(atPath: remoteCache.path)
        let curatedExisted = fileManager.fileExists(atPath: curatedCache.path)
        let referenceExisted = fileManager.fileExists(atPath: referenceCache.path)
        let originalRemoteDigest = ReferencePluginInventory.remoteTreeDigest(in: remoteCache, fileManager: fileManager)
        let originalCuratedDigest = ReferencePluginInventory.remoteTreeDigest(in: curatedCache, fileManager: fileManager)
        let originalReferenceDigest = ReferencePluginInventory.remoteTreeDigest(in: referenceCache, fileManager: fileManager)

        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            try originalConfig.write(to: backupConfig, options: .atomic)
            if remoteExisted {
                try fileManager.copyItem(at: remoteCache, to: backupRemote)
            }
            if curatedExisted {
                try fileManager.copyItem(at: curatedCache, to: backupCurated)
            }
            if referenceExisted {
                try fileManager.copyItem(at: referenceCache, to: backupReference)
            }
            guard try Data(contentsOf: backupConfig) == originalConfig else {
                throw ReferencePluginTransactionError.rollbackVerificationFailed
            }
        } catch {
            try? fileManager.removeItem(at: backupDirectory)
            return .failed(reason: "plugin transaction backup failed: \(error.localizedDescription)")
        }

        let failure: String
        if let operationFailure = operation() {
            failure = operationFailure
        } else {
            switch finalize() {
            case .success:
                do {
                    try fileManager.removeItem(at: backupDirectory)
                    return .applied
                } catch {
                    return .failed(reason: "plugins were applied but transaction backup cleanup failed: \(error.localizedDescription)")
                }
            case .rollback(let reason):
                failure = reason
            case .preserveBackup(let reason):
                return .failed(
                    reason: reason + "; rollback skipped while Codex may be running; backup kept at \(backupDirectory.path)"
                )
            }
        }

        do {
            try originalConfig.write(to: configURL, options: .atomic)
            try restoreDirectory(
                active: remoteCache,
                backup: backupRemote,
                originallyExisted: remoteExisted,
                fileManager: fileManager
            )
            try restoreDirectory(
                active: curatedCache,
                backup: backupCurated,
                originallyExisted: curatedExisted,
                fileManager: fileManager
            )
            try restoreDirectory(
                active: referenceCache,
                backup: backupReference,
                originallyExisted: referenceExisted,
                fileManager: fileManager
            )
            guard try Data(contentsOf: configURL) == originalConfig,
                  fileManager.fileExists(atPath: remoteCache.path) == remoteExisted,
                  fileManager.fileExists(atPath: curatedCache.path) == curatedExisted,
                  fileManager.fileExists(atPath: referenceCache.path) == referenceExisted,
                  ReferencePluginInventory.remoteTreeDigest(in: remoteCache, fileManager: fileManager) == originalRemoteDigest,
                  ReferencePluginInventory.remoteTreeDigest(in: curatedCache, fileManager: fileManager) == originalCuratedDigest,
                  ReferencePluginInventory.remoteTreeDigest(in: referenceCache, fileManager: fileManager) == originalReferenceDigest else {
                throw ReferencePluginTransactionError.rollbackVerificationFailed
            }
            try fileManager.removeItem(at: backupDirectory)
            return .failed(reason: failure + "; previous plugin state restored")
        } catch {
            return .failed(
                reason: failure + "; plugin transaction rollback failed: \(error.localizedDescription); backup kept at \(backupDirectory.path)"
            )
        }
    }

    private static func restoreDirectory(
        active: URL,
        backup: URL,
        originallyExisted: Bool,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: active.path) {
            try fileManager.removeItem(at: active)
        }
        if originallyExisted {
            guard fileManager.fileExists(atPath: backup.path) else {
                throw ReferencePluginTransactionError.rollbackVerificationFailed
            }
            try fileManager.createDirectory(at: active.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: backup, to: active)
        }
    }

    private enum ReferencePluginTransactionError: LocalizedError {
        case rollbackVerificationFailed

        var errorDescription: String? {
            "plugin transaction rollback verification failed"
        }
    }
}

enum ProcessLookupPolicy {
    enum Outcome: Equatable {
        case matches([String])
        case noMatches
        case failed(reason: String)
    }

    static func parse(status: Int32, output: String) -> Outcome {
        if status == 1 { return .noMatches }
        guard status == 0 else {
            return .failed(reason: output.isEmpty ? "pgrep failed with status \(status)" : output)
        }
        let processIDs = output.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        return processIDs.isEmpty ? .noMatches : .matches(processIDs)
    }
}

struct PluginSyncStabilityTracker {
    private struct Observation: Equatable {
        let inventory: [String]
        let fingerprint: String?
    }

    private let requiredStableObservations: Int
    private var previous: Observation?
    private var matchingObservationCount = 0

    init(requiredStableObservations: Int = 2) {
        self.requiredStableObservations = max(2, requiredStableObservations)
    }

    mutating func observe(inventory: [String], fingerprint: String?) -> Bool {
        let observation = Observation(inventory: inventory.sorted(), fingerprint: fingerprint)
        if previous == observation {
            matchingObservationCount += 1
        } else {
            matchingObservationCount = 1
        }
        previous = observation
        return matchingObservationCount >= requiredStableObservations
    }
}

enum AuthBackupPruner {
    @discardableResult
    static func prune(in directory: URL, keepingPerAccount keepCount: Int = 10, fileManager: FileManager = .default) -> Int {
        guard keepCount >= 0,
              let files = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.contentModificationDateKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return 0
        }

        let backups = files.filter { $0.lastPathComponent.contains(".auth.json.bak.") }
        let grouped = Dictionary(grouping: backups) { url in
            url.lastPathComponent.components(separatedBy: ".bak.").first ?? url.lastPathComponent
        }

        var removed = 0
        for group in grouped.values {
            let ordered = group.sorted { left, right in
                let leftStamp = Int(left.lastPathComponent.components(separatedBy: ".bak.").last ?? "") ?? 0
                let rightStamp = Int(right.lastPathComponent.components(separatedBy: ".bak.").last ?? "") ?? 0
                if leftStamp != rightStamp { return leftStamp > rightStamp }
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }

            for staleURL in ordered.dropFirst(keepCount) {
                do {
                    try fileManager.removeItem(at: staleURL)
                    removed += 1
                } catch {
                    continue
                }
            }
        }
        return removed
    }
}

struct HTTPPayload {
    let data: Data
    let statusCode: Int
}

enum CodexHTTPClient {
    static func send(_ request: URLRequest, retries: Int) async throws -> HTTPPayload {
        var lastError: Error?
        let attempts = max(1, retries + 1)

        for attempt in 0..<attempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode >= 500, attempt + 1 < attempts {
                    try await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
                    continue
                }
                return HTTPPayload(data: data, statusCode: httpResponse.statusCode)
            } catch {
                lastError = error
                guard attempt + 1 < attempts else { break }
                try await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
            }
        }

        throw lastError ?? URLError(.unknown)
    }
}

enum LimitWarmupState: Equatable {
    case waiting, running, refreshing, completed, failed
    case quotaExceeded, loginExpired, networkFailure, serverFailure, rateLimited, accessDenied

    var isFailure: Bool {
        switch self {
        case .waiting, .running, .refreshing, .completed: return false
        default: return true
        }
    }

    func text(language: AppLanguage) -> String {
        let key: LocalizedTextKey
        switch self {
        case .waiting: key = .warmupWaiting
        case .running: key = .warmupRunning
        case .refreshing: key = .warmupRefreshing
        case .completed: key = .warmupCompleted
        case .failed: key = .warmupFailed
        case .quotaExceeded: key = .warmupQuota
        case .loginExpired: key = .warmupLogin
        case .networkFailure: key = .warmupNetwork
        case .serverFailure: key = .warmupServer
        case .rateLimited: key = .warmupRate
        case .accessDenied: key = .warmupAccess
        }
        return LocalizedText.value(key, language: language)
    }
}

enum CodexLimitWarmupClient {
    static let model = "gpt-5.6-luna"
    static let endpoint = URL(string: "https://chatgpt.com/backend-api/codex/responses")!

    static func makeRequest(using auth: SavedAccountAuth) throws -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "session_id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Codex's request transformer removes max_output_tokens. Keep the prompt tiny instead.
        let body: [String: Any] = [
            "model": model,
            "instructions": "Reply only with OK.",
            "input": [["role": "user", "content": [["type": "input_text", "text": "Reply only with OK."]]]],
            "reasoning": ["effort": "low"],
            "store": false,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func completed(_ payload: HTTPPayload) -> Bool {
        guard payload.statusCode == 200, let text = String(data: payload.data, encoding: .utf8) else { return false }
        var completed = false
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("data:") {
            let data = Data(line.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
            guard let event = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            let type = event["type"] as? String
            if type == "error" || type == "response.failed" || type == "response.incomplete" { return false }
            if type == "response.completed",
               let response = event["response"] as? [String: Any],
               response["status"] as? String == "completed" { completed = true }
        }
        return completed
    }

    static func resultState(_ payload: HTTPPayload?) -> LimitWarmupState {
        guard let payload else { return .networkFailure }
        if completed(payload) { return .completed }
        if payload.statusCode == 401 { return .loginExpired }
        if payload.statusCode >= 500 { return .serverFailure }
        // Read structured error identifiers only; never expose raw server messages or account data.
        var identifiers = Set<String>()
        func collect(_ value: Any) {
            guard let object = value as? [String: Any] else { return }
            for key in ["code", "type"] {
                if let identifier = object[key] as? String { identifiers.insert(identifier.lowercased()) }
            }
            for key in ["error", "response"] {
                if let nested = object[key] { collect(nested) }
            }
        }
        if let json = try? JSONSerialization.jsonObject(with: payload.data) { collect(json) }
        if let text = String(data: payload.data, encoding: .utf8) {
            for line in text.components(separatedBy: .newlines) where line.hasPrefix("data:") {
                let data = Data(line.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
                if let json = try? JSONSerialization.jsonObject(with: data) { collect(json) }
            }
        }
        if !identifiers.isDisjoint(with: ["usage_limit_reached", "insufficient_quota", "quota_exceeded", "usage_limit_exceeded"]) { return .quotaExceeded }
        if !identifiers.isDisjoint(with: ["token_expired", "invalid_token", "invalid_api_key", "authentication_error", "session_expired", "unauthorized"]) { return .loginExpired }
        if payload.statusCode == 429 || identifiers.contains("rate_limit_exceeded") { return .rateLimited }
        if payload.statusCode == 403 { return .accessDenied }
        if !identifiers.isDisjoint(with: ["server_error", "internal_server_error"]) { return .serverFailure }
        return .failed
    }

    static func run(using auth: SavedAccountAuth) async -> HTTPPayload? {
        // Never replay an ambiguous inference request after timeout or a server error.
        try? await CodexHTTPClient.send(makeRequest(using: auth), retries: 0)
    }
}

struct CodexTokenRefreshPayload {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let lastRefresh: Date
}

enum CodexTokenRefreshResult {
    case success(CodexTokenRefreshPayload)
    case notRefreshable
    case expired
    case revoked
    case reused
    case networkError(String)
    case invalidResponse(String)
}

enum CodexTokenRefresher {
    static let refreshEndpoint = URL(string: "https://auth.openai.com/oauth/token")!
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let refreshAgeThreshold: TimeInterval = 3 * 24 * 60 * 60

    static func shouldRefresh(lastRefresh: Date?, now: Date = Date()) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= refreshAgeThreshold
    }

    static func makeRequest(refreshToken: String, timeout: TimeInterval = 30) -> URLRequest {
        var request = URLRequest(
            url: refreshEndpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(
        data: Data,
        statusCode: Int,
        previousRefreshToken: String?,
        now: Date = Date()
    ) -> CodexTokenRefreshResult {
        guard statusCode == 200 else {
            return failureResult(statusCode: statusCode, data: data)
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .invalidResponse("Invalid JSON")
        }
        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            return .invalidResponse("Missing access_token")
        }
        let refreshToken = (json["refresh_token"] as? String) ?? previousRefreshToken
        let idToken = json["id_token"] as? String
        return .success(CodexTokenRefreshPayload(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            lastRefresh: now
        ))
    }

    static func refresh(refreshToken: String, now: Date = Date()) async -> CodexTokenRefreshResult {
        guard !refreshToken.isEmpty else { return .notRefreshable }
        let payload: HTTPPayload
        do {
            payload = try await CodexHTTPClient.send(makeRequest(refreshToken: refreshToken), retries: 1)
        } catch {
            return .networkError(error.localizedDescription)
        }
        return parseResponse(
            data: payload.data,
            statusCode: payload.statusCode,
            previousRefreshToken: refreshToken,
            now: now
        )
    }

    private static func failureResult(statusCode: Int, data: Data) -> CodexTokenRefreshResult {
        if let code = errorCode(from: data) {
            switch code.lowercased() {
            case "refresh_token_expired":
                return .expired
            case "refresh_token_reused":
                return .reused
            case "invalid_grant", "refresh_token_invalidated":
                return .revoked
            default:
                break
            }
        }
        if statusCode == 401 {
            return .expired
        }
        return .invalidResponse("Status \(statusCode)")
    }

    private static func errorCode(from data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        if let error = json["error"] as? [String: Any], let code = error["code"] as? String {
            return code
        }
        if let error = json["error"] as? String { return error }
        return json["code"] as? String
    }
}

enum CodexAuthDate {
    static func parseLastRefresh(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw)
    }

    static func encode(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

enum SavedAccountAuthFilePolicy {
    // Workspace IDs can be shared by different users. The registry key identifies
    // the user's exact file and must also be retained for token refresh writes.
    static func fileURL(accountKey: String, expectedAccountID: String, root: URL) -> URL? {
        guard !accountKey.isEmpty, !expectedAccountID.isEmpty else { return nil }
        let encoded = Data(accountKey.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let url = root.appendingPathComponent("\(encoded).auth.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              tokens["account_id"] as? String == expectedAccountID else { return nil }
        return url
    }

    static func shouldMirror(activeAccountKey: String, refreshedAccountKey: String) -> Bool {
        !refreshedAccountKey.isEmpty && activeAccountKey == refreshedAccountKey
    }
}

enum CodexAuthTokenWriter {
    /// Atomically updates `tokens` in a Codex account auth file. Returns nil on
    /// success or a failure description. Aborts when the stored `account_id` no
    /// longer matches, so a concurrent codex-auth rewrite cannot be clobbered.
    static func applyTokenUpdate(
        to url: URL,
        expectedAccountID: String,
        accessToken: String,
        refreshToken: String?,
        lastRefresh: Date,
        fileManager: FileManager = .default
    ) -> String? {
        guard let data = try? Data(contentsOf: url),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var tokens = json["tokens"] as? [String: Any] else {
            return "auth file was not readable"
        }
        guard let storedAccountID = tokens["account_id"] as? String,
              storedAccountID == expectedAccountID else {
            return "auth file account changed concurrently"
        }
        tokens["access_token"] = accessToken
        if let refreshToken {
            tokens["refresh_token"] = refreshToken
        }
        tokens["last_refresh"] = CodexAuthDate.encode(lastRefresh)
        json["tokens"] = tokens
        guard let output = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else {
            return "auth file could not be serialized"
        }
        do {
            try output.write(to: url, options: [.atomic])
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

enum WeeklyResetFormatter {
    private static let weekdayIndexByToken: [String: Int] = [
        "mon": 2, "monday": 2,
        "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "wednesday": 4,
        "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6,
        "sat": 7, "saturday": 7,
        "sun": 1, "sunday": 1
    ]

    static func text(
        from usage: String,
        language: AppLanguage,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let open = usage.firstIndex(of: "("),
              let close = usage.firstIndex(of: ")"),
              open < close else {
            return "--"
        }
        let inner = String(usage[usage.index(after: open)..<close])
        guard let weekday = firstWeekday(in: inner) else {
            return inner.uppercased()
        }

        let time = firstTime(in: inner)
        let target = upcomingDate(weekday: weekday, time: time, now: now, calendar: calendar)

        let formatter = DateFormatter()
        let russian = [1: "ВС", 2: "ПН", 3: "ВТ", 4: "СР", 5: "ЧТ", 6: "ПТ", 7: "СБ"]
        let english = [1: "SUN", 2: "MON", 3: "TUES", 4: "WED", 5: "THUR", 6: "FRI", 7: "SAT"]
        formatter.locale = language == .russian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = time == nil ? "d MMM" : "d MMM · HH:mm"
        let dayMonth = formatter.string(from: target)
        let abbreviation = (language == .russian ? russian : english)[weekday] ?? "?"
        return "\(abbreviation) · \(dayMonth)"
    }

    static func upcomingResetDate(
        from usage: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let open = usage.firstIndex(of: "("),
              let close = usage.firstIndex(of: ")"),
              open < close else {
            return nil
        }
        let inner = String(usage[usage.index(after: open)..<close])
        guard let weekday = firstWeekday(in: inner) else { return nil }
        return upcomingDate(weekday: weekday, time: firstTime(in: inner), now: now, calendar: calendar)
    }

    private static func firstWeekday(in text: String) -> Int? {
        for token in text.split(whereSeparator: { !$0.isLetter }) {
            if let index = weekdayIndexByToken[String(token).lowercased()] {
                return index
            }
        }
        return nil
    }

    private static func firstTime(in text: String) -> (hour: Int, minute: Int)? {
        let pattern = #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hour = Int(text[hourRange]),
              let minute = Int(text[minuteRange]) else {
            return nil
        }
        return (hour, minute)
    }

    private static func upcomingDate(
        weekday: Int,
        time: (hour: Int, minute: Int)?,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.component(.weekday, from: now)
        var daysAhead = (weekday - today + 7) % 7
        if daysAhead == 0 {
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            let nowHour = nowComponents.hour ?? 0
            let nowMinute = nowComponents.minute ?? 0
            if let time {
                let sameHour = time.hour == nowHour
                let resetFiredToday = time.hour < nowHour || (sameHour && time.minute <= nowMinute)
                if resetFiredToday { daysAhead = 7 }
            } else {
                daysAhead = 7
            }
        }
        let resetHour = time?.hour ?? 0
        let resetMinute = time?.minute ?? 0
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
              let targetDay = calendar.date(byAdding: .day, value: daysAhead, to: startOfDay),
              let target = calendar.date(bySettingHour: resetHour, minute: resetMinute, second: 0, of: targetDay) else {
            return now
        }
        return target
    }
}

// MARK: - Pool usage history

struct PoolAccountSample: Codable, Equatable {
    let key: String
    let remaining: Double
    let resetsAt: Date?

    init(key: String, remaining: Double, resetsAt: Date? = nil) {
        self.key = key
        self.remaining = remaining
        self.resetsAt = resetsAt
    }
}

/// One pool-wide sample: remaining percents per account, the pool total, and
/// the earliest weekly reset date captured from the live usage windows.
struct PoolHistorySample: Codable, Equatable {
    let ts: Date
    let n: Int
    let poolTotal: Double
    let accounts: [PoolAccountSample]
    let resetsAt: Date?
}

extension PoolHistorySample {
    /// Shorthand for history without a captured reset date (tests, legacy code).
    init(ts: Date, n: Int, poolTotal: Double, accounts: [PoolAccountSample]) {
        self.init(ts: ts, n: n, poolTotal: poolTotal, accounts: accounts, resetsAt: nil)
    }

    static func makeLive(snapshots: [String: DirectUsageSnapshot], now: Date) -> PoolHistorySample? {
        guard !snapshots.isEmpty else { return nil }
        let accounts = snapshots.keys.sorted().compactMap { email -> PoolAccountSample? in
            guard let snapshot = snapshots[email] else { return nil }
            return PoolAccountSample(
                key: email,
                remaining: Double(snapshot.weekly.remainingPercent),
                resetsAt: snapshot.weekly.resetAt
            )
        }
        guard !accounts.isEmpty else { return nil }
        let reset = snapshots.values.compactMap(\.weekly.resetAt).min()
        return PoolHistorySample(
            ts: now,
            n: accounts.count,
            poolTotal: accounts.reduce(0) { $0 + $1.remaining },
            accounts: accounts,
            resetsAt: reset
        )
    }

    static func makeCurrent(
        accounts: [CodexAccount],
        snapshots: [String: DirectUsageSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> PoolHistorySample? {
        let currentAccounts = accounts.compactMap { account -> PoolAccountSample? in
            let remaining = snapshots[account.email]
                .map { Double($0.weekly.remainingPercent) }
                ?? account.weeklyUsedPercent.map(Double.init)
            guard let remaining else { return nil }
            let reset = snapshots[account.email]?.weekly.resetAt
                ?? WeeklyResetFormatter.upcomingResetDate(
                    from: account.weeklyUsage,
                    now: now,
                    calendar: calendar
                )
            return PoolAccountSample(key: account.email, remaining: remaining, resetsAt: reset)
        }
        guard !currentAccounts.isEmpty else { return nil }

        let resetDates = currentAccounts.compactMap(\.resetsAt)
        return PoolHistorySample(
            ts: now,
            n: currentAccounts.count,
            poolTotal: currentAccounts.reduce(0) { $0 + $1.remaining },
            accounts: currentAccounts,
            resetsAt: resetDates.min()
        )
    }
}

/// JSONL store for pool-wide usage history (one sample per line, newest wins
/// within a sampling bucket). Pure logic so it can be unit-tested without AppKit.
enum PoolHistoryStore {
    static let samplingInterval: TimeInterval = 30 * 60
    static let retentionDays = 56
    static let minimumDeltaPoints = 1.0

    static func poolAverage(n: Int, poolTotal: Double) -> Double {
        n > 0 ? poolTotal / Double(n) : 0
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func fileURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Codex Account Switcher", isDirectory: true)
            .appendingPathComponent("pool-history.jsonl")
    }

    /// Reads every valid line, keeps the newest sample per sampling bucket, and
    /// returns the history sorted chronologically. Corrupt lines are skipped.
    static func load(
        from url: URL? = nil,
        fileManager: FileManager = .default,
        interval: TimeInterval = Self.samplingInterval
    ) -> [PoolHistorySample] {
        let url = url ?? Self.fileURL(fileManager: fileManager)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }
        var samples: [PoolHistorySample] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let sample = try? decoder.decode(PoolHistorySample.self, from: lineData) else {
                continue
            }
            samples.append(sample)
        }
        var newestByBucket: [Int64: PoolHistorySample] = [:]
        for sample in samples {
            let bucket = Int64(sample.ts.timeIntervalSince1970 / interval)
            if let existing = newestByBucket[bucket], existing.ts >= sample.ts { continue }
            newestByBucket[bucket] = sample
        }
        return newestByBucket.values.sorted { $0.ts < $1.ts }
    }

    /// Drops samples older than the retention window.
    static func pruned(
        _ samples: [PoolHistorySample],
        now: Date = Date(),
        retentionSeconds: TimeInterval = TimeInterval(Self.retentionDays * 24 * 60 * 60)
    ) -> [PoolHistorySample] {
        let cutoff = now.addingTimeInterval(-retentionSeconds)
        return samples.filter { $0.ts >= cutoff }
    }

    /// Rewrites the whole history file atomically after pruning. Cheap at
    /// ~2 700 lines, and keeps the file consistent on every append.
    static func write(
        _ samples: [PoolHistorySample],
        to url: URL? = nil,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws {
        let url = url ?? Self.fileURL(fileManager: fileManager)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let kept = Self.pruned(samples, now: now)
        var lines: [String] = []
        lines.reserveCapacity(kept.count)
        for sample in kept {
            if let data = try? encoder.encode(sample),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// True when a new sample should be recorded: the pool average changed by
    /// more than the delta threshold, or the last sample is older than the
    /// sampling interval (or no history exists yet).
    static func shouldRecord(
        lastSample: PoolHistorySample?,
        poolAverage: Double,
        now: Date = Date(),
        interval: TimeInterval = samplingInterval,
        minimumDelta: Double = minimumDeltaPoints
    ) -> Bool {
        guard let lastSample else { return true }
        if now.timeIntervalSince(lastSample.ts) >= interval { return true }
        let previousAverage = Self.poolAverage(n: lastSample.n, poolTotal: lastSample.poolTotal)
        return abs(poolAverage - previousAverage) > minimumDelta
    }
}

/// Calculates observed pool consumption without treating newly added capacity
/// or a reset increase as negative usage.
enum PoolBurnRateEstimator {
    static let lookbackSeconds: TimeInterval = 7 * 24 * 60 * 60
    static let minimumSpanDays = 0.5

    static func grossBurnPerDay(
        _ history: [PoolHistorySample],
        lookback: TimeInterval = Self.lookbackSeconds
    ) -> Double? {
        guard let last = history.last, history.count >= 2 else { return nil }
        let cutoff = last.ts.addingTimeInterval(-lookback)
        let recent = history.filter { $0.ts >= cutoff }
        guard let first = recent.first, first.ts < last.ts else { return nil }

        var consumed = 0.0
        for index in 1..<recent.count {
            let previousByKey = recent[index - 1].accounts.reduce(into: [String: Double]()) {
                $0[$1.key] = $1.remaining
            }
            for account in recent[index].accounts {
                guard let previousRemaining = previousByKey[account.key] else { continue }
                consumed += max(0, previousRemaining - account.remaining)
            }
        }

        let elapsedDays = max(
            Self.minimumSpanDays,
            last.ts.timeIntervalSince(first.ts) / (24 * 60 * 60)
        )
        return consumed / elapsedDays
    }
}

struct PoolResetEvent: Equatable {
    let date: Date
    let accountCount: Int
}

struct PoolSufficiencyForecast: Equatable {
    let kind: PoolVerdictKind
    let isPreliminary: Bool
    let historyDays: Double
    let burnPerDay: Double?
    let expectedDemand: Double?
    let usableCapacity: Double?
    let coverageRatio: Double?
    let exhaustionDate: Date?
    let resetEvents: [PoolResetEvent]
    let accountCount: Int
    let requiredAccountCount: Int?

    static func collecting(historyDays: Double, accountCount: Int) -> Self {
        Self(
            kind: .collecting,
            isPreliminary: historyDays < PoolSufficiencyForecaster.horizonDays,
            historyDays: historyDays,
            burnPerDay: nil,
            expectedDemand: nil,
            usableCapacity: nil,
            coverageRatio: nil,
            exhaustionDate: nil,
            resetEvents: [],
            accountCount: accountCount,
            requiredAccountCount: nil
        )
    }
}

enum PoolSufficiencyForecaster {
    static let secondsPerDay: TimeInterval = 86_400
    static let horizonDays = 7.0
    static let horizonSeconds: TimeInterval = horizonDays * secondsPerDay

    private struct SimulatedAccount {
        let key: String
        var remaining: Double
        var resetDate: Date?
    }

    static func forecast(
        samples: [PoolHistorySample],
        now: Date = Date()
    ) -> PoolSufficiencyForecast {
        let ordered = samples
            .filter { $0.ts <= now }
            .sorted { $0.ts < $1.ts }
        guard let latest = ordered.last else {
            return .collecting(historyDays: 0, accountCount: 0)
        }

        let cutoff = now.addingTimeInterval(-horizonSeconds)
        let recent = ordered.filter { $0.ts >= cutoff }
        let historyDays = recent.first.map {
            max(0, now.timeIntervalSince($0.ts) / secondsPerDay)
        } ?? 0
        let collecting = PoolSufficiencyForecast.collecting(
            historyDays: historyDays,
            accountCount: latest.accounts.count
        )
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last,
              first.ts < last.ts,
              !latest.accounts.isEmpty,
              let burnPerDay = PoolBurnRateEstimator.grossBurnPerDay(recent),
              burnPerDay.isFinite,
              burnPerDay > 1e-9 else {
            return collecting
        }

        let horizonEnd = now.addingTimeInterval(horizonSeconds)
        var accounts = latest.accounts.map {
            SimulatedAccount(
                key: $0.key,
                remaining: max(0, min(100, $0.remaining)),
                resetDate: $0.resetsAt.map { nextResetDate(after: $0, now: now) }
            )
        }
        let groupedResets = Dictionary(grouping: accounts.indices.compactMap { index -> (Date, Int)? in
            guard let reset = accounts[index].resetDate, reset < horizonEnd else { return nil }
            return (reset, index)
        }, by: \.0)
        let resetSchedule = groupedResets.keys.sorted().map { date in
            (date: date, indices: groupedResets[date, default: []].map(\.1))
        }
        let resetEvents = resetSchedule.map {
            PoolResetEvent(date: $0.date, accountCount: $0.indices.count)
        }
        let expectedDemand = burnPerDay * horizonDays
        let requiredAccountCount = Int(ceil(expectedDemand / 100))
        let burnPerSecond = burnPerDay / secondsPerDay
        var consumed = 0.0
        var cursor = now

        for event in resetSchedule + [(date: horizonEnd, indices: [])] {
            let interval = max(0, event.date.timeIntervalSince(cursor))
            let demand = burnPerSecond * interval
            let available = accounts.reduce(0.0) { $0 + $1.remaining }
            if available + 1e-9 < demand {
                _ = consume(available, from: &accounts)
                consumed += available
                let exhaustionDate = cursor.addingTimeInterval(available / burnPerSecond)
                return result(
                    kind: .notEnough,
                    historyDays: historyDays,
                    burnPerDay: burnPerDay,
                    expectedDemand: expectedDemand,
                    usableCapacity: consumed,
                    exhaustionDate: exhaustionDate,
                    resetEvents: resetEvents,
                    accountCount: accounts.count,
                    requiredAccountCount: requiredAccountCount
                )
            }

            let unmet = consume(demand, from: &accounts)
            guard unmet <= 1e-9 else { return collecting }
            consumed += demand
            cursor = event.date
            for index in event.indices {
                accounts[index].remaining = 100
                accounts[index].resetDate = nil
            }
        }

        let remaining = accounts.reduce(0.0) { $0 + $1.remaining }
        return result(
            kind: .enough,
            historyDays: historyDays,
            burnPerDay: burnPerDay,
            expectedDemand: expectedDemand,
            usableCapacity: consumed + remaining,
            exhaustionDate: nil,
            resetEvents: resetEvents,
            accountCount: accounts.count,
            requiredAccountCount: requiredAccountCount
        )
    }

    private static func result(
        kind: PoolVerdictKind,
        historyDays: Double,
        burnPerDay: Double,
        expectedDemand: Double,
        usableCapacity: Double,
        exhaustionDate: Date?,
        resetEvents: [PoolResetEvent],
        accountCount: Int,
        requiredAccountCount: Int
    ) -> PoolSufficiencyForecast {
        PoolSufficiencyForecast(
            kind: kind,
            isPreliminary: historyDays + 1e-9 < horizonDays,
            historyDays: historyDays,
            burnPerDay: burnPerDay,
            expectedDemand: expectedDemand,
            usableCapacity: usableCapacity,
            coverageRatio: usableCapacity / expectedDemand,
            exhaustionDate: exhaustionDate,
            resetEvents: resetEvents,
            accountCount: accountCount,
            requiredAccountCount: requiredAccountCount
        )
    }

    private static func nextResetDate(after anchor: Date, now: Date) -> Date {
        guard anchor <= now else { return anchor }
        let cycles = floor(now.timeIntervalSince(anchor) / horizonSeconds) + 1
        return anchor.addingTimeInterval(cycles * horizonSeconds)
    }

    private static func consume(
        _ demand: Double,
        from accounts: inout [SimulatedAccount]
    ) -> Double {
        var unmet = max(0, demand)
        let order = accounts.indices.sorted { leftIndex, rightIndex in
            switch (accounts[leftIndex].resetDate, accounts[rightIndex].resetDate) {
            case let (left?, right?):
                if left == right { return accounts[leftIndex].key < accounts[rightIndex].key }
                return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return accounts[leftIndex].key < accounts[rightIndex].key
            }
        }
        for index in order where unmet > 1e-9 {
            let spent = min(accounts[index].remaining, unmet)
            accounts[index].remaining -= spent
            unmet -= spent
        }
        return unmet
    }
}

// MARK: - Weekly pace curves

/// Builds calendar-week curves of the normalized pool average (remaining %),
/// mirroring CodexBar's `HistoricalUsagePace` in the remaining-percent frame:
/// monotone (running minimum) curves over a fixed 0...1 grid. A window reset
/// (a spike upward) never looks like gained headroom.
enum WeekCurveBuilder {
    static let gridPointCount = 100
    static let minimumSamplesPerWeek = 2

    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Splits samples into calendar weeks, one monotone curve per week.
    /// Weeks with fewer than two samples are skipped.
    static func weekCurves(
        from samples: [PoolHistorySample],
        calendar: Calendar,
        gridPointCount: Int = Self.gridPointCount,
        minimumSamples: Int = Self.minimumSamplesPerWeek
    ) -> [(start: Date, curve: [Double])] {
        guard gridPointCount >= 2 else { return [] }
        var grouped: [Date: [PoolHistorySample]] = [:]
        for sample in samples {
            let start = Self.weekStart(of: sample.ts, calendar: calendar)
            grouped[start, default: []].append(sample)
        }
        var curves: [(start: Date, curve: [Double])] = []
        for (start, weekSamples) in grouped {
            guard weekSamples.count >= minimumSamples else { continue }
            guard let duration = calendar.dateInterval(of: .weekOfYear, for: start)?.duration,
                  duration > 0,
                  let curve = Self.reconstructCurve(
                      samples: weekSamples,
                      start: start,
                      duration: duration,
                      gridPointCount: gridPointCount
                  ) else {
                continue
            }
            curves.append((start: start, curve: curve))
        }
        return curves.sorted { $0.start < $1.start }
    }

    /// Grid values are the running minimum of the observed pool average,
    /// interpolated on a fixed grid. Before the first sample of the week the
    /// curve holds the first observed value (no anchor to 100). After the grid
    /// is filled the last observed slope extends to the very end of the week,
    /// so a burn-out in the final half hour is not hidden by the last sample
    /// sitting at Sat 23:30.
    static func reconstructCurve(
        samples: [PoolHistorySample],
        start: Date,
        duration: TimeInterval,
        gridPointCount: Int
    ) -> [Double]? {
        let points = samples
            .map { sample -> (u: Double, value: Double) in
                let u = max(0, min(1, sample.ts.timeIntervalSince(start) / duration))
                let average = PoolHistoryStore.poolAverage(n: sample.n, poolTotal: sample.poolTotal)
                return (u: u, value: max(0, min(100, average)))
            }
            .sorted { $0.u < $1.u }
        guard let first = points.first else { return nil }

        var curve = Array(repeating: first.value, count: gridPointCount)
        var runningMin = first.value
        var pointIndex = 0
        for index in 0..<gridPointCount {
            let u = Double(index) / Double(gridPointCount - 1)
            while pointIndex < points.count, points[pointIndex].u <= u {
                runningMin = min(runningMin, points[pointIndex].value)
                pointIndex += 1
            }
            curve[index] = runningMin
        }
        guard points.count >= 2, let lastPoint = points.last else { return curve }
        let previousPoint = points[points.count - 2]
        let slopeStep = lastPoint.u - previousPoint.u
        if slopeStep > 1e-9, lastPoint.u < 1 {
            // A rising tail must not climb above the running minimum: the
            // week-end level is unknown, the observed floor is the honest
            // guess. Only the downward extension is allowed.
            let endValue = lastPoint.value + ((lastPoint.value - previousPoint.value) / slopeStep) * (1 - lastPoint.u)
            if endValue < curve[gridPointCount - 1] {
                curve[gridPointCount - 1] = max(0, endValue)
            }
        }
        return curve
    }

    static func interpolate(curve: [Double], at u: Double) -> Double {
        guard curve.count >= 2 else { return curve.first ?? 0 }
        let clamped = max(0, min(1, u))
        let position = clamped * Double(curve.count - 1)
        let lower = Int(floor(position))
        let upper = min(curve.count - 1, Int(ceil(position)))
        guard lower != upper else { return curve[lower] }
        let fraction = position - Double(lower)
        return curve[lower] * (1 - fraction) + curve[upper] * fraction
    }
}

// MARK: - Daily pool spend aggregation

enum DailyPoolSpendCoverage: Equatable {
    case noData
    case complete
    case lowerBound
    case inProgress
    case inProgressLowerBound
}

enum DailyPoolSpendBand: Equatable {
    case unknown
    case withinReference
    case aboveReference
    case high

    static let dailyReferencePercent = 100.0 / 7.0
    private static let withinReferenceUpperBound = 14.3

    static func classify(_ spentPercent: Double?) -> DailyPoolSpendBand {
        guard let spentPercent else { return .unknown }
        if spentPercent > 25 { return .high }
        if spentPercent > withinReferenceUpperBound { return .aboveReference }
        return .withinReference
    }
}

enum PoolChartVisualScale {
    static let guidePercent = 50.0

    static func barHeight(for spentPercent: Double) -> Double {
        guard spentPercent.isFinite, spentPercent > 0 else { return 0 }
        return min(100, spentPercent / DailyPoolSpendBand.dailyReferencePercent * guidePercent)
    }
}

enum PoolChartHoverPolicy {
    static func nearestIndex(to xValue: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(count - 1, max(0, Int(xValue.rounded())))
    }
}

struct PoolChartPopoverPlacement: Equatable {
    let centerX: Double
    let centerY: Double
    let caretOffsetX: Double
}

enum PoolChartPopoverMetrics {
    static let width = 164.0
    static let minimumHeight = 80.0
    static let dateFontSize = 13.0
    static let bodyFontSize = 12.0
    static let horizontalPadding = 12.0
    static let verticalPadding = 10.0
}

enum PoolChartPopoverPolicy {
    static func shouldPlaceLeft(index: Int, count: Int, trailingCount: Int = 5) -> Bool {
        guard count > 0, trailingCount > 0 else { return false }
        return index >= max(0, count - trailingCount)
    }

    static func placement(
        anchorX: Double,
        preferredCenterY: Double,
        containerWidth: Double,
        containerHeight: Double,
        popoverWidth: Double,
        popoverHeight: Double,
        edgeInset: Double = 2,
        caretInset: Double = 12
    ) -> PoolChartPopoverPlacement {
        let halfWidth = popoverWidth / 2
        let halfHeight = popoverHeight / 2
        let centerX = min(
            containerWidth - halfWidth - edgeInset,
            max(halfWidth + edgeInset, anchorX)
        )
        let centerY = min(
            containerHeight - halfHeight - edgeInset,
            max(halfHeight + edgeInset, preferredCenterY)
        )
        let maximumCaretOffset = max(0, halfWidth - caretInset)
        let caretOffsetX = min(maximumCaretOffset, max(-maximumCaretOffset, anchorX - centerX))
        return PoolChartPopoverPlacement(
            centerX: centerX,
            centerY: centerY,
            caretOffsetX: caretOffsetX
        )
    }
}

struct DailyPoolSpendPoint: Equatable, Identifiable {
    let date: Date
    let spentPercent: Double?
    let remainingPercent: Double?
    let accountCount: Int
    let coverage: DailyPoolSpendCoverage

    var id: Date { date }
}

/// Builds normalized gross-spend bars from raw per-account remaining values.
/// Missing dates remain explicit no-data slots, and increases never erase burn.
enum DailyPoolSpendAggregator {
    static let defaultDayCount = 14

    static func dailyPoints(
        from samples: [PoolHistorySample],
        dayCount: Int = Self.defaultDayCount,
        now: Date = Date(),
        calendar: Calendar = .current,
        samplingInterval: TimeInterval = PoolHistoryStore.samplingInterval
    ) -> [DailyPoolSpendPoint] {
        guard dayCount >= 1 else { return [] }
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else { return [] }
        let orderedHistory = samples.sorted { $0.ts < $1.ts }

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { return nil }
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let samplesByDay = orderedHistory.filter { $0.ts >= day && $0.ts < dayEnd }
            guard let finalSample = samplesByDay.last else {
                return DailyPoolSpendPoint(
                    date: day,
                    spentPercent: nil,
                    remainingPercent: nil,
                    accountCount: 0,
                    coverage: .noData
                )
            }

            let openingAnchor = orderedHistory.last {
                $0.ts < day && day.timeIntervalSince($0.ts) <= samplingInterval
            }
            let observations = openingAnchor.map { [$0] + samplesByDay } ?? samplesByDay
            let anchorKeys = Set(openingAnchor?.accounts.map(\.key) ?? [])
            let representedKeys = Set(observations.flatMap { $0.accounts.map(\.key) })
            var previousByKey: [String: Double] = [:]
            var observationCountByKey: [String: Int] = [:]
            var spentPoints = 0.0
            var comparablePairs = 0

            for sample in observations {
                for account in sample.accounts {
                    observationCountByKey[account.key, default: 0] += 1
                    if let previous = previousByKey[account.key] {
                        spentPoints += max(0, previous - account.remaining)
                        comparablePairs += 1
                    }
                    previousByKey[account.key] = account.remaining
                }
            }

            guard !representedKeys.isEmpty, comparablePairs > 0 else {
                return DailyPoolSpendPoint(
                    date: day,
                    spentPercent: nil,
                    remainingPercent: PoolHistoryStore.poolAverage(n: finalSample.n, poolTotal: finalSample.poolTotal),
                    accountCount: representedKeys.count,
                    coverage: .noData
                )
            }

            let maximumGap = zip(observations, observations.dropFirst())
                .map { $1.ts.timeIntervalSince($0.ts) }
                .max() ?? 0
            let coverageEnd = day == today ? now : dayEnd
            let tailGap = max(0, coverageEnd.timeIntervalSince(finalSample.ts))
            let everyAccountComparable = representedKeys.allSatisfy {
                observationCountByKey[$0, default: 0] >= 2 && anchorKeys.contains($0)
            }
            let isLowerBound = openingAnchor == nil
                || !everyAccountComparable
                || maximumGap > samplingInterval * 2
                || tailGap > samplingInterval * 2
            let coverage: DailyPoolSpendCoverage
            if day == today {
                coverage = isLowerBound ? .inProgressLowerBound : .inProgress
            } else {
                coverage = isLowerBound ? .lowerBound : .complete
            }

            return DailyPoolSpendPoint(
                date: day,
                spentPercent: spentPoints / Double(representedKeys.count),
                remainingPercent: PoolHistoryStore.poolAverage(n: finalSample.n, poolTotal: finalSample.poolTotal),
                accountCount: representedKeys.count,
                coverage: coverage
            )
        }
    }
}

// MARK: - Pool pace forecast

/// Forecasts when the pool average reaches 0%, following the CodexBar
/// algorithm: a weighted-median typical week mixed with a linear quota
/// baseline, each historical week extended by its end slope and shifted to the
/// observed level, then a weighted-median crossing time. In the
/// remaining-percent frame the quota baseline (100 → 0 over the week) is only
/// ever pessimistic, so no upside cap is applied — an easy history is a real
/// reserve, unlike CodexBar's used-percent case.
enum PaceEstimator {
    struct Forecast {
        let insufficientData: Bool
        let historyDays: Double
        let eolDate: Date?
        let willLastToReset: Bool
        let runOutProbability: Double?
        let expectedNow: Double
        let actualNow: Double
    }

    static let minimumHistorySeconds: TimeInterval = 2 * 24 * 60 * 60
    static let recencyTauWeeks = 2.0
    static let minimumCompleteWeeks = 1
    static let probabilitySmoothing = 0.5

    static func forecast(
        samples: [PoolHistorySample],
        now: Date = Date(),
        calendar: Calendar = .current,
        gridPointCount: Int = WeekCurveBuilder.gridPointCount
    ) -> Forecast {
        let historyDays = samples.isEmpty
            ? 0
            : max(0, now.timeIntervalSince(samples[0].ts)) / (24 * 60 * 60)
        guard let last = samples.last else {
            return Forecast(
                insufficientData: true, historyDays: historyDays,
                eolDate: nil, willLastToReset: true, runOutProbability: nil,
                expectedNow: 0, actualNow: 0
            )
        }
        let actual = PoolHistoryStore.poolAverage(n: last.n, poolTotal: last.poolTotal)

        guard now.timeIntervalSince(samples[0].ts) >= Self.minimumHistorySeconds else {
            return Forecast(
                insufficientData: true, historyDays: historyDays,
                eolDate: nil, willLastToReset: true, runOutProbability: nil,
                expectedNow: 0, actualNow: actual
            )
        }

        let curves = WeekCurveBuilder.weekCurves(from: samples, calendar: calendar, gridPointCount: gridPointCount)
        guard let currentInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Forecast(insufficientData: false, historyDays: historyDays,
                            eolDate: nil, willLastToReset: true, runOutProbability: nil,
                            expectedNow: actual, actualNow: actual)
        }
        let currentStart = currentInterval.start
        let currentDuration = currentInterval.duration
        let uNow = max(0, min(1, now.timeIntervalSince(currentStart) / currentDuration))

        let scopedWeeks = curves.filter { $0.start < currentStart }
        guard scopedWeeks.count >= Self.minimumCompleteWeeks else {
            return Self.partialForecast(
                samples: samples,
                actual: actual,
                now: now,
                calendar: calendar,
                historyDays: historyDays
            )
        }

        let weightedWeeks = scopedWeeks.map { week in
            let ageWeeks = max(0, currentStart.timeIntervalSince(week.start) / currentDuration)
            let weight = exp(-ageWeeks / Self.recencyTauWeeks)
            return (week: week, weight: weight)
        }
        let totalWeight = weightedWeeks.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return Forecast(insufficientData: false, historyDays: historyDays,
                            eolDate: nil, willLastToReset: true, runOutProbability: nil,
                            expectedNow: actual, actualNow: actual)
        }

        // Weighted-median typical week, mixed with the linear quota baseline
        // (100 → 0 over the week). λ grows with the effective sample count, so
        // little history leans on the pessimistic quota instead.
        var medianCurve = Array(repeating: 0.0, count: gridPointCount)
        for index in 0..<gridPointCount {
            let values = weightedWeeks.map { $0.week.curve[index] }
            let weights = weightedWeeks.map(\.weight)
            medianCurve[index] = Self.weightedMedian(values: values, weights: weights)
        }
        let totalWeightSquared = weightedWeeks.reduce(0.0) { $0 + $1.weight * $1.weight }
        let nEff = totalWeightSquared > 0 ? totalWeight * totalWeight / totalWeightSquared : 0
        let lambda = Self.clamp((nEff - 2) / 6, lower: 0, upper: 1)
        var expectedCurve = Array(repeating: 0.0, count: gridPointCount)
        for index in 0..<gridPointCount {
            let u = Double(index) / Double(gridPointCount - 1)
            let linearBaseline = 100 * (1 - u)
            expectedCurve[index] = (lambda * medianCurve[index]) + ((1 - lambda) * linearBaseline)
        }

        let expectedNow = WeekCurveBuilder.interpolate(curve: expectedCurve, at: uNow)

        var weightedRunOutMass = 0.0
        var crossingCandidates: [(etaSeconds: TimeInterval, weight: Double)] = []
        for weighted in weightedWeeks {
            let curve = weighted.week.curve
            let shift = actual - WeekCurveBuilder.interpolate(curve: curve, at: uNow)
            if (curve.last ?? 0) + shift <= 0 {
                weightedRunOutMass += weighted.weight
                if let crossingU = Self.firstCrossing(
                    after: uNow,
                    curve: curve,
                    shift: shift,
                    actualAtNow: actual
                ) {
                    crossingCandidates.append((
                        etaSeconds: max(0, (crossingU - uNow) * currentDuration),
                        weight: weighted.weight
                    ))
                }
            }
        }

        let smoothedProbability = Self.clamp(
            (weightedRunOutMass + Self.probabilitySmoothing) / (totalWeight + 1),
            lower: 0,
            upper: 1
        )
        let willRunOut = smoothedProbability >= 0.5

        var eolDate: Date?
        if actual <= 0 {
            eolDate = now
        } else if willRunOut, !crossingCandidates.isEmpty {
            let values = crossingCandidates.map(\.etaSeconds)
            let weights = crossingCandidates.map(\.weight)
            eolDate = now.addingTimeInterval(max(0, Self.weightedMedian(values: values, weights: weights)))
        }

        return Forecast(
            insufficientData: false,
            historyDays: historyDays,
            eolDate: eolDate,
            willLastToReset: eolDate == nil,
            runOutProbability: smoothedProbability,
            expectedNow: expectedNow,
            actualNow: actual
        )
    }

    /// With no complete weeks yet, extrapolate the recent burn rate (last 12
    /// samples) to zero inside the current week. Marked as approximate by the
    /// UI. A flat recent history reports will-last.
    private static func partialForecast(
        samples: [PoolHistorySample],
        actual: Double,
        now: Date,
        calendar: Calendar,
        historyDays: Double
    ) -> Forecast {
        let willLast = Forecast(
            insufficientData: false, historyDays: historyDays,
            eolDate: nil, willLastToReset: true, runOutProbability: 0.5,
            expectedNow: actual, actualNow: actual
        )
        guard samples.count >= 4,
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
              let oldestSample = samples.suffix(12).first,
              let lastSample = samples.last else {
            return willLast
        }
        let span = lastSample.ts.timeIntervalSince(oldestSample.ts)
        guard span > 0 else { return willLast }
        let oldestAverage = PoolHistoryStore.poolAverage(n: oldestSample.n, poolTotal: oldestSample.poolTotal)
        let burnPerSecond = max(0, (oldestAverage - actual) / span)
        guard burnPerSecond > 1e-9 else { return willLast }
        let eolDate = now.addingTimeInterval(actual / burnPerSecond)
        if eolDate < weekInterval.end {
            return Forecast(insufficientData: false, historyDays: historyDays,
                            eolDate: eolDate, willLastToReset: false,
                            runOutProbability: 1, expectedNow: actual, actualNow: actual)
        }
        return willLast
    }

    static func firstCrossing(
        after uNow: Double,
        curve: [Double],
        shift: Double,
        actualAtNow: Double
    ) -> Double? {
        guard curve.count >= 2 else { return nil }
        let gridCount = curve.count
        let denominator = Double(gridCount - 1)
        var previousU = uNow
        var previousValue = actualAtNow
        let startIndex = min(gridCount - 1, max(1, Int(floor(uNow * denominator)) + 1))
        for index in startIndex..<gridCount {
            let u = Double(index) / denominator
            if u <= uNow + 1e-9 { continue }
            let value = curve[index] + shift
            if previousValue > 1e-9, value <= 1e-9 {
                let delta = previousValue - value
                let ratio = delta > 1e-9 ? (previousValue / delta) : 0
                return Self.clamp(previousU + ratio * (u - previousU), lower: uNow, upper: 1)
            }
            previousU = u
            previousValue = value
        }
        return nil
    }

    static func weightedMedian(values: [Double], weights: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let pairs = zip(values, weights).sorted { $0.0 < $1.0 }
        let total = max(1e-9, pairs.reduce(0.0) { $0 + $1.1 })
        var cumulative = 0.0
        for (value, weight) in pairs {
            cumulative += weight
            if cumulative >= total / 2 { return value }
        }
        return pairs.last?.0 ?? 0
    }

    static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        max(lower, min(upper, value))
    }
}

enum PoolVerdictKind: Equatable {
    case enough
    case notEnough
    case collecting
}

struct PoolVerdict: Equatable {
    let kind: PoolVerdictKind
    let resetInterval: TimeInterval?
    let exhaustionInterval: TimeInterval?
    let margin: TimeInterval?

    static let collecting = PoolVerdict(
        kind: .collecting,
        resetInterval: nil,
        exhaustionInterval: nil,
        margin: nil
    )

    static func evaluate(
        poolTotal: Double,
        burnPerDay: Double?,
        eolDate: Date?,
        resetDate: Date?,
        hasSufficientHistory: Bool,
        now: Date
    ) -> PoolVerdict {
        guard hasSufficientHistory,
              poolTotal.isFinite, poolTotal > 0,
              let burnPerDay, burnPerDay.isFinite, burnPerDay > 1e-9,
              let resetDate else {
            return .collecting
        }
        let effectiveEOL = eolDate ?? now.addingTimeInterval(poolTotal / burnPerDay * 86_400)
        let resetInterval = resetDate.timeIntervalSince(now)
        let exhaustionInterval = effectiveEOL.timeIntervalSince(now)
        guard resetInterval.isFinite, exhaustionInterval.isFinite,
              resetInterval > 0, exhaustionInterval >= 0 else {
            return .collecting
        }
        let margin = exhaustionInterval - resetInterval
        return PoolVerdict(
            kind: margin >= 0 ? .enough : .notEnough,
            resetInterval: resetInterval,
            exhaustionInterval: exhaustionInterval,
            margin: margin
        )
    }

    static func evaluateAvailableData(
        poolTotal: Double,
        observedBurnPerDay: Double?,
        accountCount: Int,
        eolDate: Date?,
        resetDate: Date?,
        now: Date
    ) -> PoolVerdict {
        let quotaBaseline = Double(max(1, accountCount)) * 100 / 7
        let effectiveBurn = observedBurnPerDay.flatMap { value in
            value.isFinite && value > 1e-9 ? value : nil
        } ?? quotaBaseline
        return evaluate(
            poolTotal: poolTotal,
            burnPerDay: effectiveBurn,
            eolDate: eolDate,
            resetDate: resetDate,
            hasSufficientHistory: true,
            now: now
        )
    }
}

// MARK: - Global reset chance (codex-reset.com)

/// Server-rounded global goodwill-reset probabilities from codex-reset.com.
/// Rounded values are kept as the single source of truth so the panel never
/// disagrees with the site's own display.
struct ResetChanceForecast: Equatable {
    let rounded24h: Int
    let rounded48h: Int
}

enum ResetChanceFetchResult {
    case success(ResetChanceForecast)
    case failure(String)
}

enum ResetChanceClient {
    static let endpoint = URL(string: "https://codex-reset.com/api/forecast")!

    static func makeRequest(timeout: TimeInterval = 30) -> URLRequest {
        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        return request
    }

    static func parseResponse(
        data: Data,
        statusCode: Int
    ) -> ResetChanceFetchResult {
        guard statusCode == 200 else {
            return .failure("Reset chance HTTP \(statusCode)")
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let probabilities = json["probabilities"] as? [String: Any],
              let rounded24h = probabilities["rounded_24h"] as? Int,
              let rounded48h = probabilities["rounded_48h"] as? Int else {
            return .failure("Invalid reset chance response")
        }
        return .success(ResetChanceForecast(rounded24h: rounded24h, rounded48h: rounded48h))
    }

    static func parseCommandResult(_ result: CommandResult) -> ResetChanceFetchResult {
        guard result.status == 0 else {
            let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(detail.isEmpty ? "Reset chance fallback failed" : detail)
        }
        return parseResponse(data: Data(result.output.utf8), statusCode: 200)
    }
}
