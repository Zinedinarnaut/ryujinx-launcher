import Foundation
import AppKit
import ImageIO

actor ThumbnailService {
    private let cache = ImageCache.shared
    private let session: URLSession

    private enum BackgroundValidation {
        static let minWidth: CGFloat = 1200
        static let minHeight: CGFloat = 600
        static let minAspect: CGFloat = 1.4
        static let maxAspect: CGFloat = 2.2
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchThumbnail(for game: Game, targetPixelSize: Int? = nil) async -> NSImage? {
        let cacheKey = game.titleId ?? game.title
        if let targetPixelSize, let scaled = cache.scaledImage(forKey: cacheKey, maxPixelSize: targetPixelSize) {
            return scaled
        }
        if let cached = cache.image(forKey: cacheKey) {
            return cached
        }

        if let titleId = game.titleId {
            if let image = await fetchFromNlib(titleId: titleId, cacheKey: cacheKey, preferBanner: false) {
                return image
            }
        }

        if let image = await fetchFromNintendoSearch(title: game.title, cacheKey: cacheKey, preferWide: false) {
            return image
        }

        return nil
    }

    func fetchBackground(for game: Game) async -> NSImage? {
        let cacheKey = (game.titleId ?? game.title) + ":bg-v\(backgroundCacheVersion())"
        if let data = cache.imageData(forKey: cacheKey) {
            if isValidBackground(data) {
                return NSImage(data: data)
            } else {
                cache.remove(forKey: cacheKey)
            }
        }

        if let titleId = game.titleId {
            if let image = await fetchFromNlib(titleId: titleId, cacheKey: cacheKey, preferBanner: true, validateBackground: true) {
                return image
            }
        }

        if let image = await fetchFromNintendoSearch(title: game.title, cacheKey: cacheKey, preferWide: true, validateBackground: true) {
            return image
        }

        return nil
    }

    private func backgroundCacheVersion() -> Int {
        let stored = UserDefaults.standard.integer(forKey: "backgroundCacheVersion")
        return stored == 0 ? 1 : stored
    }

    private func fetchFromNlib(titleId: String, cacheKey: String, preferBanner: Bool, validateBackground: Bool = false) async -> NSImage? {
        guard let url = URL(string: "https://api.nlib.cc/nx/\(titleId)?fields=name,icon,banner") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let info = try? JSONDecoder().decode(NlibGameResponse.self, from: data) else { return nil }

            if preferBanner {
                if let bannerURLString = info.banner, let bannerURL = URL(string: enforceHTTPS(bannerURLString)) {
                    return await fetchImageData(from: bannerURL, cacheKey: cacheKey, validateBackground: validateBackground)
                }
            } else {
                if let iconURLString = info.icon, let iconURL = URL(string: enforceHTTPS(iconURLString)) {
                    return await fetchImageData(from: iconURL, cacheKey: cacheKey)
                }
                if let bannerURLString = info.banner, let bannerURL = URL(string: enforceHTTPS(bannerURLString)) {
                    return await fetchImageData(from: bannerURL, cacheKey: cacheKey)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func fetchFromNintendoSearch(title: String, cacheKey: String, preferWide: Bool, validateBackground: Bool = false) async -> NSImage? {
        guard let url = nintendoSearchURL(query: title) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let result = try? JSONDecoder().decode(NintendoSearchResponse.self, from: data) else { return nil }
            guard let doc = result.response.docs.first else { return nil }

            let imageURLString: String?
            if preferWide {
                imageURLString = doc.imageWideURLHighRes ?? doc.imageWideURL
            } else {
                imageURLString = doc.imageURL ?? doc.imageSquareURL ?? doc.imageWideURL
            }
            guard let imageURLString, let imageURL = URL(string: enforceHTTPS(imageURLString)) else { return nil }
            return await fetchImageData(from: imageURL, cacheKey: cacheKey, validateBackground: validateBackground)
        } catch {
            return nil
        }
    }

    private func fetchImageData(from url: URL, cacheKey: String, validateBackground: Bool = false) async -> NSImage? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            if validateBackground, !isValidBackground(data) {
                return nil
            }
            let fileExt = fileExtension(from: http, url: url)
            let image = cache.store(data: data, forKey: cacheKey, fileExtension: fileExt)
            SharedThumbnailStore.shared.store(data: data, key: cacheKey, fileExtension: fileExt)
            return image
        } catch {
            return nil
        }
    }

    private func isValidBackground(_ data: Data) -> Bool {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return false }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return false
        }
        let aspect = width / max(height, 1)
        if width < BackgroundValidation.minWidth || height < BackgroundValidation.minHeight {
            return false
        }
        if aspect < BackgroundValidation.minAspect || aspect > BackgroundValidation.maxAspect {
            return false
        }
        return true
    }

    private func enforceHTTPS(_ urlString: String) -> String {
        if urlString.lowercased().hasPrefix("http://") {
            return "https://" + urlString.dropFirst("http://".count)
        }
        return urlString
    }

    private func fileExtension(from response: HTTPURLResponse, url: URL) -> String {
        if let mime = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() {
            if mime.contains("png") { return "png" }
            if mime.contains("jpeg") || mime.contains("jpg") { return "jpg" }
            if mime.contains("webp") { return "webp" }
        }
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "jpg" : ext
    }

    private func nintendoSearchURL(query: String) -> URL? {
        var components = URLComponents(string: "https://search.nintendo-europe.com/en/select")
        let fq = "type:GAME AND system_type:nintendoswitch*"
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fq", value: fq),
            URLQueryItem(name: "rows", value: "1"),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "wt", value: "json")
        ]
        return components?.url
    }
}

private struct NlibGameResponse: Decodable {
    let id: String?
    let name: String?
    let icon: String?
    let banner: String?
}

private struct NintendoSearchResponse: Decodable {
    let response: NintendoSearchDocs
}

private struct NintendoSearchDocs: Decodable {
    let docs: [NintendoSearchDoc]
}

private struct NintendoSearchDoc: Decodable {
    let imageURL: String?
    let imageSquareURL: String?
    let imageWideURL: String?
    let imageWideURLHighRes: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case imageSquareURL = "image_url_sq_s"
        case imageWideURL = "image_url_h2x1_s"
        case imageWideURLHighRes = "image_url_h2x1"
    }
}
