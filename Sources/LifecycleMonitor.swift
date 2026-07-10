import AppKit
import Foundation

// launchd can expose the caller's inherited environment to agents. The monitor
// needs no credentials, so discard secret-shaped values immediately.
for key in ProcessInfo.processInfo.environment.keys {
    let upper = key.uppercased()
    if upper.contains("TOKEN") || upper.contains("SECRET") || upper.contains("PASSWORD") || upper.contains("API_KEY") {
        unsetenv(key)
    }
}

private let switcherBundleID = "com.mohamedfuad.codexaccountswitcher"
private let targetBundleIDs: Set<String> = ["com.openai.codex", "com.openai.chat"]
private let switcherURL = URL(fileURLWithPath: "/Applications/Codex Account Switcher.app")
private let grace: TimeInterval = 5

final class LifecycleMonitor {
    private var quitWorkItem: DispatchWorkItem?
    private let workspace = NSWorkspace.shared

    init() {
        let center = workspace.notificationCenter
        center.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        reconcile()
    }

    @objc private func appChanged(_ notification: Notification) {
        reconcile()
    }

    private func reconcile() {
        let running = workspace.runningApplications
        let targetRunning = running.contains { targetBundleIDs.contains($0.bundleIdentifier ?? "") }
        let switcher = running.first { $0.bundleIdentifier == switcherBundleID }

        if targetRunning {
            quitWorkItem?.cancel()
            quitWorkItem = nil
            if switcher == nil, FileManager.default.fileExists(atPath: switcherURL.path) {
                workspace.openApplication(at: switcherURL, configuration: .init())
            }
            return
        }

        guard switcher != nil, quitWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.quitWorkItem = nil
            let stillRunning = self.workspace.runningApplications.contains { targetBundleIDs.contains($0.bundleIdentifier ?? "") }
            if !stillRunning {
                self.workspace.runningApplications.first { $0.bundleIdentifier == switcherBundleID }?.terminate()
            }
        }
        quitWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + grace, execute: item)
    }
}

let monitor = LifecycleMonitor()
RunLoop.main.run()
