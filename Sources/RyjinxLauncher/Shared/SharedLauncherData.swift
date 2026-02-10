import Foundation
import CryptoKit

#if canImport(WidgetKit)
import WidgetKit
#endif

struct SharedGameRecord: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let titleId: String?
    let hoursPlayed: Double
    let lastPlayed: Date?
    let thumbnailKey: String
    let filePath: String?
}

struct SharedLauncherSnapshot: Codable, Hashable {
    var games: [SharedGameRecord]
    var lastLaunchedId: String?
    var lastLaunchedAt: Date?
    var pendingLaunchId: String?
    var pendingLaunchPath: String?
    var ryujinxValid: Bool?
    var gamesValid: Bool?
}

final class SharedDataStore: @unchecked Sendable {
    static let appGroupID = "group.com.ryjinx.launcher"
    static let shared = SharedDataStore()

    private let queue = DispatchQueue(label: "ryjinx.shared.data", qos: .utility)
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func updateGames(_ games: [SharedGameRecord]) {
        queue.async {
            var snapshot = self.loadSnapshotInternal() ?? SharedLauncherSnapshot(games: [], lastLaunchedId: nil, lastLaunchedAt: nil, pendingLaunchId: nil, pendingLaunchPath: nil, ryujinxValid: nil, gamesValid: nil)
            let existingById = Dictionary(uniqueKeysWithValues: snapshot.games.map { ($0.id, $0) })

            let newRecords: [SharedGameRecord] = games.map { game in
                let existing = existingById[game.id]
                return SharedGameRecord(
                    id: game.id,
                    title: game.title,
                    titleId: game.titleId,
                    hoursPlayed: game.hoursPlayed,
                    lastPlayed: existing?.lastPlayed ?? game.lastPlayed,
                    thumbnailKey: game.thumbnailKey,
                    filePath: game.filePath ?? existing?.filePath
                )
            }

            snapshot.games = newRecords
            self.saveSnapshotInternal(snapshot)
        }
    }

    func markLaunched(id: String, title: String, titleId: String?, hoursPlayed: Double, thumbnailKey: String, filePath: String?) {
        queue.async {
            var snapshot = self.loadSnapshotInternal() ?? SharedLauncherSnapshot(games: [], lastLaunchedId: nil, lastLaunchedAt: nil, pendingLaunchId: nil, pendingLaunchPath: nil, ryujinxValid: nil, gamesValid: nil)
            let now = Date()
            snapshot.lastLaunchedId = id
            snapshot.lastLaunchedAt = now

            var updated: [SharedGameRecord] = []
            var found = false
            for record in snapshot.games {
                if record.id == id {
                    updated.append(SharedGameRecord(
                        id: record.id,
                        title: title,
                        titleId: titleId,
                        hoursPlayed: hoursPlayed,
                        lastPlayed: now,
                        thumbnailKey: thumbnailKey,
                        filePath: filePath ?? record.filePath
                    ))
                    found = true
                } else {
                    updated.append(record)
                }
            }

            if !found {
                updated.append(SharedGameRecord(
                    id: id,
                    title: title,
                    titleId: titleId,
                    hoursPlayed: hoursPlayed,
                    lastPlayed: now,
                    thumbnailKey: thumbnailKey,
                    filePath: filePath
                ))
            }

            snapshot.games = updated
            self.saveSnapshotInternal(snapshot)
        }
    }

    func setPendingLaunch(id: String) {
        queue.async {
            var snapshot = self.loadSnapshotInternal() ?? SharedLauncherSnapshot(games: [], lastLaunchedId: nil, lastLaunchedAt: nil, pendingLaunchId: nil, pendingLaunchPath: nil, ryujinxValid: nil, gamesValid: nil)
            snapshot.pendingLaunchId = id
            snapshot.pendingLaunchPath = nil
            self.saveSnapshotInternal(snapshot)
        }
    }

    func setPendingLaunch(path: String) {
        queue.async {
            var snapshot = self.loadSnapshotInternal() ?? SharedLauncherSnapshot(games: [], lastLaunchedId: nil, lastLaunchedAt: nil, pendingLaunchId: nil, pendingLaunchPath: nil, ryujinxValid: nil, gamesValid: nil)
            snapshot.pendingLaunchPath = path
            snapshot.pendingLaunchId = nil
            self.saveSnapshotInternal(snapshot)
        }
    }

    func consumePendingLaunch() -> (id: String?, path: String?) {
        var result: (String?, String?) = (nil, nil)
        queue.sync {
            guard var snapshot = self.loadSnapshotInternal() else { return }
            result = (snapshot.pendingLaunchId, snapshot.pendingLaunchPath)
            snapshot.pendingLaunchId = nil
            snapshot.pendingLaunchPath = nil
            self.saveSnapshotInternal(snapshot)
        }
        return result
    }

    func updateValidation(ryujinxValid: Bool, gamesValid: Bool) {
        queue.async {
            var snapshot = self.loadSnapshotInternal() ?? SharedLauncherSnapshot(games: [], lastLaunchedId: nil, lastLaunchedAt: nil, pendingLaunchId: nil, pendingLaunchPath: nil, ryujinxValid: nil, gamesValid: nil)
            snapshot.ryujinxValid = ryujinxValid
            snapshot.gamesValid = gamesValid
            self.saveSnapshotInternal(snapshot)
        }
    }

    func loadSnapshot(completion: @Sendable @escaping (SharedLauncherSnapshot?) -> Void) {
        queue.async {
            completion(self.loadSnapshotInternal())
        }
    }

    func loadSnapshotSync() -> SharedLauncherSnapshot? {
        queue.sync {
            loadSnapshotInternal()
        }
    }

    private func loadSnapshotInternal() -> SharedLauncherSnapshot? {
        guard let url = dataURL() else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(SharedLauncherSnapshot.self, from: data)
    }

    private func saveSnapshotInternal(_ snapshot: SharedLauncherSnapshot) {
        guard let url = dataURL() else { return }
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
            reloadWidgets()
        } catch {
            return
        }
    }

    private func dataURL() -> URL? {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
            return nil
        }
        return container.appendingPathComponent("launcher_snapshot.json")
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

final class SharedThumbnailStore: @unchecked Sendable {
    static let shared = SharedThumbnailStore()

    private let fileManager = FileManager.default

    private init() {}

    static func key(titleId: String?, title: String) -> String {
        return titleId ?? title
    }

    func store(data: Data, key: String, fileExtension: String) {
        guard let dir = directoryURL() else { return }
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let filename = Self.hash(key)
        let url = dir.appendingPathComponent(filename).appendingPathExtension(fileExtension)
        try? data.write(to: url, options: .atomic)
    }

    func imageData(for key: String) -> Data? {
        guard let dir = directoryURL() else { return nil }
        let filename = Self.hash(key)
        let extensions = ["jpg", "png", "webp"]
        for ext in extensions {
            let url = dir.appendingPathComponent(filename).appendingPathExtension(ext)
            if let data = try? Data(contentsOf: url) { return data }
        }
        return nil
    }

    func clearAll() {
        guard let dir = directoryURL() else { return }
        do {
            if fileManager.fileExists(atPath: dir.path) {
                try fileManager.removeItem(at: dir)
            }
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return
        }
    }

    private func directoryURL() -> URL? {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedDataStore.appGroupID) else {
            return nil
        }
        return container.appendingPathComponent("thumbnails", isDirectory: true)
    }

    private static func hash(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
