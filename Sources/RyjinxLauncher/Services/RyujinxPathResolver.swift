import Foundation

struct RyujinxPaths {
    let executableURL: URL
    let dataDirectoryURL: URL?
}

final class RyujinxPathResolver {
    func resolve(from directory: URL) -> RyujinxPaths? {
        let fm = FileManager.default
        let normalized = directory.resolvingSymlinksInPath()
        let isDirectory = (try? normalized.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        var appURL: URL?
        var executableURL: URL?

        if !isDirectory, fm.isExecutableFile(atPath: normalized.path) {
            executableURL = normalized
            appURL = appBundleURL(fromExecutable: normalized)
        } else {
            if normalized.pathExtension.lowercased() == "app" {
                appURL = normalized
            } else {
                let candidate = normalized.appendingPathComponent("Ryujinx.app")
                appURL = fm.fileExists(atPath: candidate.path) ? candidate : nil
            }

            if let appURL {
                let candidate = appURL.appendingPathComponent("Contents/MacOS/Ryujinx")
                executableURL = fm.isExecutableFile(atPath: candidate.path) ? candidate : nil
            } else {
                let candidate = normalized.appendingPathComponent("Ryujinx")
                executableURL = fm.isExecutableFile(atPath: candidate.path) ? candidate : nil
            }
        }

        guard let executableURL else {
            return nil
        }

        let baseDirectory = isDirectory ? normalized : normalized.deletingLastPathComponent()
        let dataDir = locateDataDirectory(near: baseDirectory, appURL: appURL)
        return RyujinxPaths(executableURL: executableURL, dataDirectoryURL: dataDir)
    }

    private func appBundleURL(fromExecutable executableURL: URL) -> URL? {
        let path = executableURL.path
        guard let range = path.range(of: "/Contents/MacOS/") else { return nil }
        let appPath = String(path[..<range.lowerBound])
        guard appPath.hasSuffix(".app") else { return nil }
        return URL(fileURLWithPath: appPath)
    }

    private func locateDataDirectory(near directory: URL, appURL: URL?) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []

        let portableCandidates: [URL] = [directory, appURL?.deletingLastPathComponent()].compactMap { $0 }
        for base in portableCandidates {
            let portableDir = base.appendingPathComponent("portable")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: portableDir.path, isDirectory: &isDir) {
                let candidate = isDir.boolValue ? portableDir : base
                if hasConfig(at: candidate) { return candidate }
            }
        }

        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let ryujinx = appSupport.appendingPathComponent("Ryujinx")
            if hasConfig(at: ryujinx) { candidates.append(ryujinx) }
        }

        if let home = fm.homeDirectoryForCurrentUser as URL? {
            let config = home.appendingPathComponent(".config/Ryujinx")
            if hasConfig(at: config) { candidates.append(config) }
        }

        return candidates.first
    }

    private func hasConfig(at directory: URL) -> Bool {
        let fm = FileManager.default
        let config = directory.appendingPathComponent("Config.json")
        return fm.fileExists(atPath: config.path)
    }
}
