import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ImageThumbnailGenerator {
    struct CacheMaintenanceResult: Equatable {
        var warmedCount: Int
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
            "\(cacheKey(for: url, maximumPixelSize: maximumPixelSize)).jpg",
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

    private static func cacheKey(for url: URL, maximumPixelSize: CGFloat) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let modifiedAt = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        let fileSize = values?.fileSize ?? 0
        let rawKey = [
            url.standardizedFileURL.path,
            "\(fileSize)",
            "\(modifiedAt)",
            "\(Int(maximumPixelSize.rounded()))"
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
