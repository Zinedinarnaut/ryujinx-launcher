import Foundation
import Combine

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var selectedGame: Game?
    @Published var consoleLines: [ConsoleLine] = []
    @Published var isScanning = false
    @Published var isLaunching = false
    @Published var ryujinxValidation = ValidationResult.invalid(message: "Select Ryujinx directory")
    @Published var gamesValidation = ValidationResult.invalid(message: "Select games directory")
    @Published var statusMessage: String?
    @Published var isSettingsPresented = false
    @Published var isGamingMode = false {
        didSet {
            gamingModeService.setFullscreenActive(isGamingMode)
        }
    }
    @Published var isLaunchIsolationActive = false {
        didSet {
            gamingModeService.setLaunchActive(isLaunchIsolationActive)
        }
    }

    let settings: SettingsStore
    let thumbnailService: ThumbnailService

    private let pathResolver: RyujinxPathResolver
    private let metadataService: RyujinxMetadataService
    private let scannerService: GameScannerService
    private let processService: RyujinxProcessService
    private let gamingModeService = GamingModeService()
    private let notificationService = NotificationService()
    private let spotlightService = SpotlightIndexService()
    private let sharedStore = SharedDataStore.shared
    private var ryujinxPaths: RyujinxPaths?
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore = SettingsStore(),
        pathResolver: RyujinxPathResolver = RyujinxPathResolver(),
        metadataService: RyujinxMetadataService = RyujinxMetadataService(),
        scannerService: GameScannerService = GameScannerService(),
        processService: RyujinxProcessService = RyujinxProcessService(),
        thumbnailService: ThumbnailService = ThumbnailService()
    ) {
        self.settings = settings
        self.pathResolver = pathResolver
        self.metadataService = metadataService
        self.scannerService = scannerService
        self.processService = processService
        self.thumbnailService = thumbnailService

        settings.$ryujinxDirectory
            .sink { [weak self] _ in
                self?.validateRyujinx()
                self?.scanGamesIfPossible()
            }
            .store(in: &cancellables)

        settings.$gamesDirectory
            .sink { [weak self] _ in
                self?.validateGamesDirectory()
                self?.scanGamesIfPossible()
            }
            .store(in: &cancellables)

        validateRyujinx()
        validateGamesDirectory()
        scanGamesIfPossible()
        notificationService.requestAuthorization()
    }

    var canLaunch: Bool {
        ryujinxValidation.isValid && gamesValidation.isValid && selectedGame != nil && !isLaunching
    }

    func rescan() {
        scanGamesIfPossible(force: true)
    }

    func launchSelectedGame() {
        guard canLaunch, let game = selectedGame, let exec = ryujinxPaths?.executableURL else { return }
        guard FileManager.default.fileExists(atPath: game.fileURL.path) else {
            appendSystem("Game file not found: \(game.fileURL.lastPathComponent)")
            return
        }
        isLaunching = true
        isLaunchIsolationActive = true
        SoundPlayer.shared.play(.launch)
        appendSystem("Launching \(game.title)...")
        notificationService.notify(title: "Launching Ryujinx", body: game.title)

        do {
            try processService.launch(executableURL: exec, gamePath: game.fileURL, onOutput: { [weak self] line in
                Task { @MainActor in
                    self?.consoleLines.append(line)
                }
            }, onTermination: { [weak self] status in
                Task { @MainActor in
                    self?.appendSystem("Ryujinx exited with status \(status)")
                    self?.isLaunching = false
                    self?.isLaunchIsolationActive = false
                    self?.notificationService.notify(title: "Ryujinx Exited", body: "Exit status \(status)")
                }
            })
            sharedStore.markLaunchedFromApp(game: game)
        } catch {
            appendSystem("Failed to launch Ryujinx: \(error.localizedDescription)")
            isLaunching = false
            isLaunchIsolationActive = false
        }
    }

    func launchGame(withId id: String) {
        guard let game = games.first(where: { $0.id == id }) else {
            appendSystem("Game not found for id \(id)")
            return
        }
        selectedGame = game
        if canLaunch {
            launchSelectedGame()
        } else {
            appendSystem("Launch conditions not met. Check paths in Settings.")
        }
    }

    func launchGame(atPath path: String) {
        guard ryujinxValidation.isValid, let exec = ryujinxPaths?.executableURL else {
            appendSystem("Ryujinx not configured. Open Settings.")
            return
        }
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            appendSystem("Game file not found at \(fileURL.lastPathComponent)")
            return
        }
        isLaunching = true
        isLaunchIsolationActive = true
        SoundPlayer.shared.play(.launch)
        appendSystem("Launching \(fileURL.lastPathComponent)...")
        notificationService.notify(title: "Launching Ryujinx", body: fileURL.lastPathComponent)

        do {
            try processService.launch(executableURL: exec, gamePath: fileURL, onOutput: { [weak self] line in
                Task { @MainActor in
                    self?.consoleLines.append(line)
                }
            }, onTermination: { [weak self] status in
                Task { @MainActor in
                    self?.appendSystem("Ryujinx exited with status \(status)")
                    self?.isLaunching = false
                    self?.isLaunchIsolationActive = false
                    self?.notificationService.notify(title: "Ryujinx Exited", body: "Exit status \(status)")
                }
            })
        } catch {
            appendSystem("Failed to launch Ryujinx: \(error.localizedDescription)")
            isLaunching = false
            isLaunchIsolationActive = false
        }
    }

    func stopLaunch() {
        processService.stop()
        isLaunching = false
        isLaunchIsolationActive = false
        appendSystem("Process terminated by user")
    }

    func clearConsole() {
        consoleLines.removeAll()
    }

    func clearImageCache() {
        ImageCache.shared.clearAll()
        SharedThumbnailStore.shared.clearAll()
        settings.bumpBackgroundCacheVersion()
        statusMessage = "Image cache cleared"
        if let current = selectedGame {
            selectedGame = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000)
                self.selectedGame = current
            }
        }
    }

    func rebuildBackgrounds() {
        settings.bumpBackgroundCacheVersion()
        statusMessage = "Rebuilding background art…"
        if let current = selectedGame {
            selectedGame = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000)
                self.selectedGame = current
            }
        }
    }

    func selectNextGame() {
        guard !games.isEmpty else { return }
        guard let selected = selectedGame, let index = games.firstIndex(where: { $0.id == selected.id }) else {
            selectedGame = games.first
            return
        }
        let nextIndex = (index + 1) % games.count
        selectedGame = games[nextIndex]
    }

    func selectPreviousGame() {
        guard !games.isEmpty else { return }
        guard let selected = selectedGame, let index = games.firstIndex(where: { $0.id == selected.id }) else {
            selectedGame = games.first
            return
        }
        let prevIndex = (index - 1 + games.count) % games.count
        selectedGame = games[prevIndex]
    }

    private func validateRyujinx() {
        guard !settings.ryujinxDirectory.isEmpty else {
            ryujinxValidation = .invalid(message: "Select Ryujinx directory")
            ryujinxPaths = nil
            sharedStore.updateValidation(ryujinxValid: false, gamesValid: gamesValidation.isValid)
            return
        }
        guard let access = settings.beginAccessing(.ryujinx) else {
            ryujinxValidation = .invalid(message: "Select Ryujinx directory")
            ryujinxPaths = nil
            sharedStore.updateValidation(ryujinxValid: false, gamesValid: gamesValidation.isValid)
            return
        }
        defer { access.stop() }

        if let resolved = pathResolver.resolve(from: access.url) {
            ryujinxValidation = .valid(message: "Ryujinx found")
            ryujinxPaths = resolved
            sharedStore.updateValidation(ryujinxValid: true, gamesValid: gamesValidation.isValid)
        } else {
            ryujinxValidation = .invalid(message: "Ryujinx executable not found")
            ryujinxPaths = nil
            sharedStore.updateValidation(ryujinxValid: false, gamesValid: gamesValidation.isValid)
        }
    }

    private func validateGamesDirectory() {
        guard !settings.gamesDirectory.isEmpty else {
            gamesValidation = .invalid(message: "Select games directory")
            sharedStore.updateValidation(ryujinxValid: ryujinxValidation.isValid, gamesValid: false)
            return
        }
        guard let access = settings.beginAccessing(.games) else {
            gamesValidation = .invalid(message: "Invalid games directory")
            sharedStore.updateValidation(ryujinxValid: ryujinxValidation.isValid, gamesValid: false)
            return
        }
        defer { access.stop() }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: access.url.path, isDirectory: &isDir), isDir.boolValue {
            gamesValidation = .valid(message: "Games directory found")
            sharedStore.updateValidation(ryujinxValid: ryujinxValidation.isValid, gamesValid: true)
        } else {
            gamesValidation = .invalid(message: "Invalid games directory")
            sharedStore.updateValidation(ryujinxValid: ryujinxValidation.isValid, gamesValid: false)
        }
    }

    private func scanGamesIfPossible(force: Bool = false) {
        guard !isLaunching else { return }
        guard gamesValidation.isValid else { return }
        if isScanning && !force { return }

        isScanning = true
        statusMessage = "Scanning games..."

        guard let gamesAccess = settings.beginAccessing(.games) else {
            isScanning = false
            statusMessage = "Invalid games directory"
            return
        }
        let ryujinxAccess = settings.beginAccessing(.ryujinx)
        let gamesURL = gamesAccess.url
        let dataDir = ryujinxPaths?.dataDirectoryURL

        Task {
            defer {
                gamesAccess.stop()
                ryujinxAccess?.stop()
            }
            let metadata = await metadataService.loadMetadata(from: dataDir)
            do {
                let games = try await scannerService.scanGames(in: gamesURL, metadata: metadata)
                await MainActor.run {
                    self.games = games
                    self.sharedStore.updateGamesFromApp(games)
                    self.spotlightService.indexGames(games)
                    if let selected = self.selectedGame, let refreshed = games.first(where: { $0.id == selected.id }) {
                        self.selectedGame = refreshed
                    } else {
                        self.selectedGame = games.first
                    }
                    self.isScanning = false
                    self.statusMessage = games.isEmpty ? "No games found" : "Found \(games.count) games"
                    self.handlePendingLaunchIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.games = []
                    self.isScanning = false
                    self.statusMessage = "Scan failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func appendSystem(_ message: String) {
        consoleLines.append(ConsoleLine(timestamp: Date(), text: message + "\n", stream: .system))
    }

    func handlePendingLaunchIfNeeded() {
        guard !games.isEmpty else { return }
        let pending = sharedStore.consumePendingLaunch()
        if let pendingId = pending.id, let game = games.first(where: { $0.id == pendingId }) {
            selectedGame = game
            if canLaunch {
                launchSelectedGame()
            } else {
                appendSystem("Pending launch blocked. Check Settings.")
            }
            return
        }
        if let pendingPath = pending.path {
            if let game = games.first(where: { $0.fileURL.path == pendingPath }) {
                selectedGame = game
                if canLaunch {
                    launchSelectedGame()
                } else {
                    appendSystem("Pending launch blocked. Check Settings.")
                }
                return
            }
            launchGame(atPath: pendingPath)
        }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "ryjinx" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let host = url.host ?? ""
        let query = components.queryItems ?? []

        if host == "open" {
            isSettingsPresented = query.first(where: { $0.name == "settings" })?.value == "1"
            return
        }

        if host == "launch" {
            if let id = query.first(where: { $0.name == "id" })?.value {
                launchGame(withId: id)
                return
            }
            if let path = query.first(where: { $0.name == "path" })?.value?.removingPercentEncoding {
                launchGame(atPath: path)
            }
        }
    }
}

struct ValidationResult {
    let isValid: Bool
    let message: String

    static func valid(message: String) -> ValidationResult {
        ValidationResult(isValid: true, message: message)
    }

    static func invalid(message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}
