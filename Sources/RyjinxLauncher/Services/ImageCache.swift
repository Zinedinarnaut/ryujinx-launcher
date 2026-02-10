import Foundation
import AppKit
import CryptoKit
import ImageIO

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("RyjinxLauncher/Covers", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RyjinxLauncher/Covers", isDirectory: true)
        cacheDirectory = dir
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func image(forKey key: String) -> NSImage? {
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        let hashed = Self.hash(key)
        let possibleExtensions = ["jpg", "png", "webp"]
        for ext in possibleExtensions {
            let fileURL = cacheDirectory.appendingPathComponent(hashed).appendingPathExtension(ext)
            if let data = try? Data(contentsOf: fileURL), let image = NSImage(data: data) {
                memoryCache.setObject(image, forKey: key as NSString)
                SharedThumbnailStore.shared.store(data: data, key: key, fileExtension: ext)
                return image
            }
        }
        return nil
    }

    func scaledImage(forKey key: String, maxPixelSize: Int) -> NSImage? {
        let cacheKey = "\(key)#\(maxPixelSize)" as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }
        guard let data = imageData(forKey: key) else { return nil }
        guard let thumbnail = Self.createThumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
        memoryCache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }

    func imageData(forKey key: String) -> Data? {
        let hashed = Self.hash(key)
        let possibleExtensions = ["jpg", "png", "webp"]
        for ext in possibleExtensions {
            let fileURL = cacheDirectory.appendingPathComponent(hashed).appendingPathExtension(ext)
            if let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }
        return nil
    }

    func remove(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        let hashed = Self.hash(key)
        let possibleExtensions = ["jpg", "png", "webp"]
        for ext in possibleExtensions {
            let fileURL = cacheDirectory.appendingPathComponent(hashed).appendingPathExtension(ext)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    @discardableResult
    func store(data: Data, forKey key: String, fileExtension: String) -> NSImage? {
        let fileURL = cacheFileURL(forKey: key, fileExtension: fileExtension)
        do {
            try data.write(to: fileURL, options: .atomic)
            if let image = NSImage(data: data) {
                memoryCache.setObject(image, forKey: key as NSString)
                return image
            }
        } catch {
            return nil
        }
        return nil
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        do {
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.removeItem(at: cacheDirectory)
            }
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }
    }

    private func cacheFileURL(forKey key: String, fileExtension: String = "jpg") -> URL {
        let hashed = Self.hash(key)
        return cacheDirectory.appendingPathComponent(hashed).appendingPathExtension(fileExtension)
    }

    private static func hash(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func createThumbnail(from data: Data, maxPixelSize: Int) -> NSImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        let originalMax = max(width, height)
        let targetMax = min(CGFloat(maxPixelSize), originalMax)

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(targetMax)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
