import AVFoundation
import UIKit

enum VideoThumbnailGenerator {
    static func image(
        for url: URL,
        at seconds: Double = 0.5,
        maximumSize: CGSize = CGSize(width: 512, height: 512)
    ) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize

        if let image = copyImage(using: generator, at: seconds) {
            return image
        }

        guard seconds > 0 else {
            return nil
        }
        return copyImage(using: generator, at: 0)
    }

    private static func copyImage(using generator: AVAssetImageGenerator, at seconds: Double) -> UIImage? {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
