import Foundation

final class GameScannerService: @unchecked Sendable {
    private static let supportedExtensions: Set<String> = ["xci", "xcz", "nsp", "nsz", "nca", "nro", "nso", "pfs0"]

    func scanGames(in directory: URL, metadata: [String: RyujinxGameMetadata]) async throws -> [Game] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .nameKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
                    continuation.resume(returning: [])
                    return
                }

                var byTitleId: [String: GameCandidate] = [:]
                var byPath: [String: Game] = [:]
                let metadataByTitle = Dictionary(uniqueKeysWithValues: metadata.values.compactMap { entry in
                    let normalized = Self.normalize(entry.title)
                    return normalized.isEmpty ? nil : (normalized, entry)
                })

                for case let fileURL as URL in enumerator {
                    guard let isRegular = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular == true else { continue }
                    let ext = fileURL.pathExtension.lowercased()
                    guard Self.supportedExtensions.contains(ext) else { continue }

                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    let titleId = Self.extractTitleId(from: fileName)
                    let titleIdKey = titleId?.uppercased()
                    var metadataEntry = titleIdKey.flatMap { metadata[$0] }

                    let title: String
                    if let metadataEntry, !metadataEntry.title.isEmpty {
                        title = metadataEntry.title
                    } else {
                        let cleaned = Self.sanitizeTitle(from: fileName)
                        title = cleaned
                        if metadataEntry == nil {
                            let normalized = Self.normalize(cleaned)
                            metadataEntry = metadataByTitle[normalized]
                        }
                    }

                    let hoursPlayed = metadataEntry?.hoursPlayed ?? 0
                    let lastPlayed = metadataEntry?.lastPlayed
                    let resolvedTitleId = titleIdKey ?? metadataEntry?.titleId
                    let titleIdKeyFinal = resolvedTitleId?.uppercased()
                    let id = fileURL.path

                    let game = Game(id: id, title: title, titleId: titleIdKeyFinal, fileURL: fileURL, hoursPlayed: hoursPlayed, lastPlayed: lastPlayed)

                    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let fileSize = Int64(values?.fileSize ?? 0)
                    let modDate = values?.contentModificationDate ?? Date.distantPast

                    if let titleIdKeyFinal {
                        if let existing = byTitleId[titleIdKeyFinal] {
                            if fileSize > existing.fileSize || modDate > existing.modDate {
                                byTitleId[titleIdKeyFinal] = GameCandidate(game: game, fileSize: fileSize, modDate: modDate)
                            }
                        } else {
                            byTitleId[titleIdKeyFinal] = GameCandidate(game: game, fileSize: fileSize, modDate: modDate)
                        }
                    } else {
                        byPath[id] = game
                    }
                }

                var results = byTitleId.values.map { $0.game }
                results.append(contentsOf: byPath.values)
                results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                continuation.resume(returning: results)
            }
        }
    }

    private static func extractTitleId(from fileName: String) -> String? {
        let regex = try? NSRegularExpression(pattern: "[0-9a-fA-F]{16}")
        let range = NSRange(location: 0, length: fileName.utf16.count)
        guard let match = regex?.firstMatch(in: fileName, options: [], range: range) else { return nil }
        guard let swiftRange = Range(match.range, in: fileName) else { return nil }
        return String(fileName[swiftRange]).uppercased()
    }

    private static func sanitizeTitle(from fileName: String) -> String {
        var result = fileName

        let patterns = ["\\[[^\\]]+\\]", "\\([^\\)]+\\)"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
            }
        }

        result = result.replacingOccurrences(of: "_", with: " ")
        result = result.replacingOccurrences(of: ".", with: " ")
        result = result.replacingOccurrences(of: "-", with: " ")
        result = result.replacingOccurrences(of: "  ", with: " ")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ value: String) -> String {
        let lowered = value.lowercased()
        let tokens = lowered.split { !$0.isLetter && !$0.isNumber }
        return tokens.joined(separator: " ")
    }

    private struct GameCandidate {
        let game: Game
        let fileSize: Int64
        let modDate: Date
    }
}
