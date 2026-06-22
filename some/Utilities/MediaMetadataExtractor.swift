import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct MediaMetadata: Equatable {
    var duration: TimeInterval?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var byteCount: Int?

    var summary: String? {
        var parts: [String] = []

        if let duration = duration {
            parts.append(Self.formatDuration(duration))
        }

        if let pixelWidth = pixelWidth,
           let pixelHeight = pixelHeight,
           pixelWidth > 0,
           pixelHeight > 0 {
            parts.append("\(pixelWidth)x\(pixelHeight)")
        }

        if let byteCount = byteCount, byteCount > 0 {
            parts.append(SharedAttachmentStore.formatByteCount(byteCount))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum MediaMetadataExtractor {
    private static let summaryCache = NSCache<NSString, NSString>()

    static func summary(
        for attachment: SharedAttachment,
        fileManager: FileManager = .default
    ) -> String? {
        let cacheKey = "\(attachment.relativePath):\(attachment.typeIdentifier):\(attachment.byteCount)" as NSString
        if let cached = summaryCache.object(forKey: cacheKey) {
            return cached as String
        }

        guard let url = SharedAttachmentStore.url(for: attachment, fileManager: fileManager),
              let metadata = metadata(
                for: url,
                typeIdentifier: attachment.typeIdentifier,
                fallbackByteCount: attachment.byteCount,
                fileManager: fileManager
              ),
              let summary = metadata.summary else {
            return nil
        }

        summaryCache.setObject(summary as NSString, forKey: cacheKey)
        return summary
    }

    static func metadata(
        for url: URL,
        typeIdentifier: String? = nil,
        fallbackByteCount: Int? = nil,
        fileManager: FileManager = .default
    ) -> MediaMetadata? {
        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let type = typeIdentifier.flatMap(UTType.init) ?? resourceValues?.contentType
        let byteCount = resourceValues?.fileSize
            ?? fileByteCount(for: url, fileManager: fileManager)
            ?? fallbackByteCount

        var metadata = MediaMetadata(
            duration: nil,
            pixelWidth: nil,
            pixelHeight: nil,
            byteCount: byteCount
        )

        if type?.conforms(to: .movie) == true || type?.conforms(to: .audio) == true {
            let asset = AVURLAsset(url: url)
            metadata.duration = finiteSeconds(asset.duration)

            if type?.conforms(to: .movie) == true,
               let track = asset.tracks(withMediaType: .video).first {
                let transformedSize = track.naturalSize.applying(track.preferredTransform)
                metadata.pixelWidth = Int(abs(transformedSize.width).rounded())
                metadata.pixelHeight = Int(abs(transformedSize.height).rounded())
            }
        } else if type?.conforms(to: .image) == true {
            let dimensions = imageDimensions(for: url)
            metadata.pixelWidth = dimensions?.width
            metadata.pixelHeight = dimensions?.height
        }

        return metadata.summary == nil ? nil : metadata
    }

    private static func finiteSeconds(_ time: CMTime) -> TimeInterval? {
        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    private static func imageDimensions(for url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }

        return (width.intValue, height.intValue)
    }

    private static func fileByteCount(for url: URL, fileManager: FileManager) -> Int? {
        guard let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber else {
            return nil
        }

        return size.intValue
    }
}
