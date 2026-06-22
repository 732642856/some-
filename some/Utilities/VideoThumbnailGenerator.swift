import AVFoundation
import UIKit

enum VideoThumbnailGenerator {
    static func image(
        for url: URL,
        at seconds: Double = 0.5,
        maximumSize: CGSize = CGSize(width: 512, height: 512),
        usesDiskCache: Bool = true,
        fileManager: FileManager = .default
    ) -> UIImage? {
        if usesDiskCache,
           let cachedImage = cachedImage(
            for: url,
            at: seconds,
            maximumSize: maximumSize,
            fileManager: fileManager
           ) {
            return cachedImage
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize

        let image = copyImage(using: generator, at: seconds) ?? (seconds > 0 ? copyImage(using: generator, at: 0) : nil)
        if usesDiskCache, let image = image {
            saveCachedImage(
                image,
                for: url,
                at: seconds,
                maximumSize: maximumSize,
                fileManager: fileManager
            )
        }

        return image
    }

    static func cachedImageURL(
        for url: URL,
        at seconds: Double = 0.5,
        maximumSize: CGSize = CGSize(width: 512, height: 512),
        fileManager: FileManager = .default
    ) -> URL? {
        guard let cacheDirectory = try? thumbnailCacheDirectory(fileManager: fileManager) else {
            return nil
        }

        return cacheDirectory.appendingPathComponent(
            "\(cacheKey(for: url, at: seconds, maximumSize: maximumSize, fileManager: fileManager)).jpg",
            isDirectory: false
        )
    }

    static func removeCachedImage(
        for url: URL,
        at seconds: Double = 0.5,
        maximumSize: CGSize = CGSize(width: 512, height: 512),
        fileManager: FileManager = .default
    ) {
        guard let url = cachedImageURL(
            for: url,
            at: seconds,
            maximumSize: maximumSize,
            fileManager: fileManager
        ) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    private static func cachedImage(
        for url: URL,
        at seconds: Double,
        maximumSize: CGSize,
        fileManager: FileManager
    ) -> UIImage? {
        guard let cacheURL = cachedImageURL(
            for: url,
            at: seconds,
            maximumSize: maximumSize,
            fileManager: fileManager
        ), fileManager.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        return UIImage(contentsOfFile: cacheURL.path)
    }

    private static func saveCachedImage(
        _ image: UIImage,
        for url: URL,
        at seconds: Double,
        maximumSize: CGSize,
        fileManager: FileManager
    ) {
        guard let data = image.jpegData(compressionQuality: 0.82),
              let cacheURL = cachedImageURL(
                for: url,
                at: seconds,
                maximumSize: maximumSize,
                fileManager: fileManager
              ) else {
            return
        }

        try? data.write(to: cacheURL, options: [.atomic])
    }

    private static func thumbnailCacheDirectory(fileManager: FileManager) throws -> URL {
        let directory = SharedMemoStorage.storageDirectory(fileManager: fileManager)
            .appendingPathComponent("ThumbnailCache", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func cacheKey(
        for url: URL,
        at seconds: Double,
        maximumSize: CGSize,
        fileManager: FileManager
    ) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let modifiedAt = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        let fileSize = values?.fileSize ?? 0
        let rawKey = [
            url.standardizedFileURL.path,
            "\(fileSize)",
            "\(modifiedAt)",
            "\(Int(seconds * 1000))",
            "\(Int(maximumSize.width.rounded()))x\(Int(maximumSize.height.rounded()))"
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

    private static func copyImage(using generator: AVAssetImageGenerator, at seconds: Double) -> UIImage? {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
