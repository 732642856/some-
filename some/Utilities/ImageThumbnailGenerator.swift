import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ImageThumbnailGenerator {
    struct CacheMaintenanceResult: Equatable {
        var warmedCount: Int
        var removedCount: Int = 0
        var failedCount: Int
        var skippedCount: Int
    }

    static func image(
        for url: URL,
        maximumPixelSize: CGFloat = 240,
        usesDiskCache: Bool = true,
        fileManager: FileManager = .default
    ) -> UIImage? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        if usesDiskCache,
           let image = cachedImage(for: url, maximumPixelSize: maximumPixelSize, fileManager: fileManager) {
            return image
        }

        guard let image = downsampledImage(for: url, maximumPixelSize: maximumPixelSize) else {
            return nil
        }

        if usesDiskCache {
            saveCachedImage(image, for: url, maximumPixelSize: maximumPixelSize, fileManager: fileManager)
        }

        return image
    }

    static func cachedImage(
        for url: URL,
        maximumPixelSize: CGFloat = 240,
        fileManager: FileManager = .default
    ) -> UIImage? {
        guard let cacheURL = cachedImageURL(
            for: url,
            maximumPixelSize: maximumPixelSize,
            fileManager: fileManager
        ), fileManager.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        return UIImage(contentsOfFile: cacheURL.path)
    }

    static func cachedImageURL(
        for url: URL,
        maximumPixelSize: CGFloat = 240,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let directory = try? thumbnailCacheDirectory(fileManager: fileManager) else {
            return nil
        }

        return directory.appendingPathComponent(
            "\(cacheFilename(for: url, maximumPixelSize: maximumPixelSize)).jpg",
            isDirectory: false
        )
    }

    static func removeCachedImage(
        for url: URL,
        maximumPixelSize: CGFloat = 240,
        fileManager: FileManager = .default
    ) {
        guard let url = cachedImageURL(
            for: url,
            maximumPixelSize: maximumPixelSize,
            fileManager: fileManager
        ) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    static func previewMaximumPixelSize(
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat,
        layerScale: Double = 1,
        displayScale: CGFloat = 3,
        minimumPixelSize: CGFloat = 64
    ) -> CGFloat {
        let longestSide = max(width, height)
        let layerScale = CGFloat(layerScale.isFinite ? max(1, layerScale) : 1)
        let scaledSize = longestSide * max(0, scale) * layerScale * max(1, displayScale)
        return max(minimumPixelSize, scaledSize.rounded(.up))
    }

    static func sourceURLs(
        in assets: [MemoAsset],
        limit: Int = 120,
        fileManager: FileManager = .default
    ) -> [URL] {
        var urls: [URL] = []
        var seenPaths = Set<String>()

        for asset in assets {
            guard urls.count < limit,
                  isImageAsset(asset),
                  let attachment = AttachmentReferenceResolver.attachment(from: asset),
                  let url = SharedAttachmentStore.url(for: attachment, fileManager: fileManager) else {
                continue
            }

            let key = url.standardizedFileURL.path
            guard seenPaths.insert(key).inserted else {
                continue
            }

            urls.append(url)
        }

        return urls
    }

    static func preheatCache(
        for urls: [URL],
        maximumPixelSize: CGFloat = 240,
        fileManager: FileManager = .default
    ) -> CacheMaintenanceResult {
        var result = CacheMaintenanceResult(warmedCount: 0, failedCount: 0, skippedCount: 0)
        var seenKeys = Set<String>()

        for url in urls {
            let key = url.standardizedFileURL.path
            guard seenKeys.insert(key).inserted else {
                result.skippedCount += 1
                continue
            }

            if image(
                for: url,
                maximumPixelSize: maximumPixelSize,
                usesDiskCache: true,
                fileManager: fileManager
            ) == nil {
                result.failedCount += 1
            } else {
                result.warmedCount += 1
            }
        }

        return result
    }

    static func pruneCache(
        keeping sourceURLs: [URL],
        fileManager: FileManager = .default
    ) -> CacheMaintenanceResult {
        guard let cacheDirectory = try? thumbnailCacheDirectory(fileManager: fileManager),
              let cachedFiles = try? fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
              ) else {
            return CacheMaintenanceResult(warmedCount: 0, failedCount: 0, skippedCount: 0)
        }

        let keepPrefixes = Set(
            sourceURLs.compactMap {
                cacheSourceKey(for: $0).map { "\($0)-" }
            }
        )

        var result = CacheMaintenanceResult(warmedCount: 0, failedCount: 0, skippedCount: 0)
        for file in cachedFiles where file.pathExtension.lowercased() == "jpg" {
            let filename = file.lastPathComponent
            guard !keepPrefixes.contains(where: { filename.hasPrefix($0) }) else {
                continue
            }

            do {
                try fileManager.removeItem(at: file)
                result.removedCount += 1
            } catch {
                result.failedCount += 1
            }
        }

        return result
    }

    private static func isImageAsset(_ asset: MemoAsset) -> Bool {
        guard asset.kind == .attachment || asset.kind == .screenshot || asset.kind == .imageEdit,
              let type = asset.typeIdentifier.flatMap(UTType.init) else {
            return false
        }

        return type.conforms(to: .image)
    }

    private static func downsampledImage(for url: URL, maximumPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maximumPixelSize.rounded()))
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: image)
    }

    private static func saveCachedImage(
        _ image: UIImage,
        for url: URL,
        maximumPixelSize: CGFloat,
        fileManager: FileManager
    ) {
        guard let data = image.jpegData(compressionQuality: 0.82),
              let cacheURL = cachedImageURL(
                for: url,
                maximumPixelSize: maximumPixelSize,
                fileManager: fileManager
              ) else {
            return
        }

        try? data.write(to: cacheURL, options: [.atomic])
    }

    private static func thumbnailCacheDirectory(fileManager: FileManager) throws -> URL {
        let directory = SharedMemoStorage.storageDirectory(fileManager: fileManager)
            .appendingPathComponent("ImageThumbnailCache", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func cacheFilename(for url: URL, maximumPixelSize: CGFloat) -> String {
        let pixelKey = "px\(Int(maximumPixelSize.rounded()))"
        guard let sourceKey = cacheSourceKey(for: url) else {
            return fnv1a64([url.standardizedFileURL.path, pixelKey].joined(separator: "|"))
        }
        return "\(sourceKey)-\(pixelKey)"
    }

    private static func cacheSourceKey(for url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let modifiedAt = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        guard let fileSize = values?.fileSize, fileSize > 0 else {
            return nil
        }
        let rawKey = [
            url.standardizedFileURL.path,
            "\(fileSize)",
            "\(modifiedAt)"
        ].joined(separator: "|")

        return fnv1a64(rawKey)
    }

    private static func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
