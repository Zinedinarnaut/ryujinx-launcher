import Foundation
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.registerDefaultHotKeys()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Launcher", action: #selector(openLauncher), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Launch Last Played", action: #selector(launchLast), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        if let snapshot = SharedDataStore.shared.loadSnapshotSync() {
            let games = snapshot.games.sorted { $0.hoursPlayed > $1.hoursPlayed }.prefix(5)
            for game in games {
                let item = NSMenuItem(title: game.title, action: #selector(launchGame(_:)), keyEquivalent: "")
                item.representedObject = game.id
                menu.addItem(item)
            }
            if !games.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }
        }

        menu.addItem(NSMenuItem(title: "Rescan Library", action: #selector(rescan), keyEquivalent: ""))
        return menu
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        SharedDataStore.shared.setPendingLaunch(path: url.path)
        LauncherAppController.shared.launchGame(path: url.path)
    }

    @objc private func openLauncher() {
        LauncherAppController.shared.activateApp()
    }

    @objc private func launchLast() {
        LauncherAppController.shared.launchLastPlayed()
    }

    @objc private func launchGame(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        LauncherAppController.shared.launchGame(id: id)
    }

    @objc private func rescan() {
        LauncherAppController.shared.rescan()
    }
}
