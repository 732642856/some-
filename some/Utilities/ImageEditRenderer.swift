import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum ImageEditRenderer {
    private static let context = CIContext()

    static func render(sourceImage: UIImage, recipe: ImageEditRecipe) -> Data? {
        guard let cgImage = renderedImage(sourceImage: sourceImage, recipe: recipe) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: .up).pngData()
    }

    static func renderedImage(sourceImage: UIImage, recipe: ImageEditRecipe) -> CGImage? {
        guard let normalized = normalizedImage(sourceImage).cgImage else {
            return nil
        }

        let cropped = crop(CGImage: normalized, preset: recipe.cropPreset) ?? normalized
        let filtered = applyFilter(to: cropped, filter: recipe.filter) ?? cropped
        return drawDecorations(on: filtered, recipe: recipe)
    }

    static func outputFilename(source: SharedAttachment, recipe: ImageEditRecipe) -> String {
        let baseName = (source.filename as NSString).deletingPathExtension
        let suffix = [recipe.filter.rawValue, recipe.cropPreset.rawValue]
            .filter { !$0.isEmpty && $0 != "original" }
            .joined(separator: "-")
        let decoratedSuffix = suffix.isEmpty ? "edited" : "edited-\(suffix)"
        return "\(baseName)-\(decoratedSuffix).png"
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func crop(CGImage image: CGImage, preset: ImageEditRecipe.CropPreset) -> CGImage? {
        guard let aspectRatio = preset.aspectRatio else {
            return image
        }

        let width = Double(image.width)
        let height = Double(image.height)
        let currentRatio = width / height
        let cropWidth: Double
        let cropHeight: Double

        if currentRatio > aspectRatio {
            cropHeight = height
            cropWidth = height * aspectRatio
        } else {
            cropWidth = width
            cropHeight = width / aspectRatio
        }

        let rect = CGRect(
            x: (width - cropWidth) / 2,
            y: (height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        ).integral
        return image.cropping(to: rect)
    }

    private static func applyFilter(to image: CGImage, filter: ImageEditRecipe.Filter) -> CGImage? {
        guard filter != .original else {
            return image
        }

        let input = CIImage(cgImage: image)
        let output: CIImage?

        switch filter {
        case .original:
            output = input
        case .fresh:
            let controls = CIFilter.colorControls()
            controls.inputImage = input
            controls.saturation = 1.08
            controls.brightness = 0.04
            controls.contrast = 0.96
            output = controls.outputImage
        case .warm:
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = input
            temperature.neutral = CIVector(x: 6500, y: 0)
            temperature.targetNeutral = CIVector(x: 5200, y: 0)
            output = temperature.outputImage
        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = input
            output = mono.outputImage
        case .vivid:
            let controls = CIFilter.colorControls()
            controls.inputImage = input
            controls.saturation = 1.25
            controls.brightness = 0.02
            controls.contrast = 1.08
            output = controls.outputImage
        }

        guard let output = output else {
            return nil
        }

        return context.createCGImage(output, from: output.extent)
    }

    private static func drawDecorations(on image: CGImage, recipe: ImageEditRecipe) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))

            drawBorder(recipe.border, in: CGRect(origin: .zero, size: size))
            drawTextOverlays(recipe.textOverlays, size: size)
            drawStickerOverlays(recipe.stickerOverlays, size: size)
            context.cgContext.setBlendMode(.normal)
        }
        return rendered.cgImage
    }

    private static func drawBorder(_ border: ImageEditRecipe.Border, in rect: CGRect) {
        guard border.width > 0 else {
            return
        }

        let width = max(1, CGFloat(border.width))
        let insetRect = rect.insetBy(dx: width / 2, dy: width / 2)
        let path = UIBezierPath(roundedRect: insetRect, cornerRadius: width * 1.6)
        color(hex: border.colorHex, fallback: .white).setStroke()
        path.lineWidth = width
        path.stroke()
    }

    private static func drawTextOverlays(_ overlays: [ImageEditRecipe.TextOverlay], size: CGSize) {
        for overlay in overlays where !overlay.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let font = UIFont.systemFont(ofSize: CGFloat(overlay.fontSize), weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color(hex: overlay.colorHex, fallback: .label)
            ]
            let maxWidth = size.width * 0.82
            let textSize = overlay.text.boundingRect(
                with: CGSize(width: maxWidth, height: size.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).integral.size
            let origin = CGPoint(
                x: normalized(overlay.x) * size.width - textSize.width / 2,
                y: normalized(overlay.y) * size.height - textSize.height / 2
            )
            overlay.text.draw(in: CGRect(origin: origin, size: textSize), withAttributes: attributes)
        }
    }

    private static func drawStickerOverlays(_ overlays: [ImageEditRecipe.StickerOverlay], size: CGSize) {
        for overlay in overlays where !overlay.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let font = UIFont.systemFont(ofSize: CGFloat(overlay.fontSize), weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(red: 0.35, green: 0.45, blue: 0.41, alpha: 1)
            ]
            let stickerSize = overlay.text.size(withAttributes: attributes)
            let padding = CGSize(width: 28, height: 16)
            let rect = CGRect(
                x: normalized(overlay.x) * size.width - (stickerSize.width + padding.width) / 2,
                y: normalized(overlay.y) * size.height - (stickerSize.height + padding.height) / 2,
                width: stickerSize.width + padding.width,
                height: stickerSize.height + padding.height
            )
            UIColor(red: 0.93, green: 0.97, blue: 0.95, alpha: 0.88).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
            overlay.text.draw(
                at: CGPoint(x: rect.minX + padding.width / 2, y: rect.minY + padding.height / 2),
                withAttributes: attributes
            )
        }
    }

    private static func normalized(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }

    private static func color(hex: String, fallback: UIColor) -> UIColor {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return fallback
        }

        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1
        )
    }
}
