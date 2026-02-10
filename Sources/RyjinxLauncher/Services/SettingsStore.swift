import Foundation
import Combine
import ServiceManagement

final class SettingsStore: ObservableObject {
    private let locator = GameDirectoryLocator()

    @Published var ryujinxDirectory: String {
        didSet { UserDefaults.standard.set(ryujinxDirectory, forKey: Keys.ryujinxDirectory) }
    }

    @Published var gamesDirectory: String {
        didSet { UserDefaults.standard.set(gamesDirectory, forKey: Keys.gamesDirectory) }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var backgroundCacheVersion: Int {
        didSet { UserDefaults.standard.set(backgroundCacheVersion, forKey: Keys.backgroundCacheVersion) }
    }

    init() {
        self.ryujinxDirectory = UserDefaults.standard.string(forKey: Keys.ryujinxDirectory) ?? ""
        self.gamesDirectory = UserDefaults.standard.string(forKey: Keys.gamesDirectory) ?? ""
        let storedLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        self.launchAtLogin = storedLogin
        let storedVersion = UserDefaults.standard.integer(forKey: Keys.backgroundCacheVersion)
        self.backgroundCacheVersion = storedVersion == 0 ? 1 : storedVersion

        if gamesDirectory.isEmpty, let detected = locator.autoDetectGamesDirectory() {
            self.gamesDirectory = detected
        }

        applyLoginItemSetting(launchAtLogin)
    }

    private enum Keys {
        static let ryujinxDirectory = "ryujinxDirectory"
        static let gamesDirectory = "gamesDirectory"
        static let launchAtLogin = "launchAtLogin"
        static let backgroundCacheVersion = "backgroundCacheVersion"
    }

    enum BookmarkKind {
        case ryujinx
        case games
    }

    struct ScopedAccess {
        let url: URL
        let stop: () -> Void
    }

    func storeBookmark(for kind: BookmarkKind, url: URL) {
        let options: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        do {
            let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey(for: kind))
        } catch {
            return
        }
    }

    func bumpBackgroundCacheVersion() {
        backgroundCacheVersion &+= 1
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        applyLoginItemSetting(enabled)
    }

    func beginAccessing(_ kind: BookmarkKind) -> ScopedAccess? {
        let path = (kind == .ryujinx) ? ryujinxDirectory : gamesDirectory
        guard !path.isEmpty else { return nil }

        let resolved = resolveBookmark(for: kind)
        let url = resolved ?? URL(fileURLWithPath: path)
        let needsStop = resolved != nil && url.startAccessingSecurityScopedResource()

        return ScopedAccess(url: url, stop: {
            if needsStop {
                url.stopAccessingSecurityScopedResource()
            }
        })
    }

    private func resolveBookmark(for kind: BookmarkKind) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey(for: kind)) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            storeBookmark(for: kind, url: url)
        }
        return url
    }

    private func bookmarkKey(for kind: BookmarkKind) -> String {
        switch kind {
        case .ryujinx:
            return "ryujinxDirectoryBookmark"
        case .games:
            return "gamesDirectoryBookmark"
        }
    }

    private func applyLoginItemSetting(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return
        }
    }
}
