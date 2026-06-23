import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

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

        let cropped = crop(CGImage: normalized, preset: recipe.cropPreset, adjustment: recipe.cropAdjustment) ?? normalized
        let backgroundProcessed = applyBackground(recipe.background, to: cropped) ?? cropped
        let subjectProcessed = applySubjectExtraction(recipe.subjectExtraction, to: backgroundProcessed) ?? backgroundProcessed
        let cleaned = applyCleanupPatches(to: subjectProcessed, patches: recipe.cleanupPatches) ?? subjectProcessed
        let filtered = applyFilter(to: cleaned, filter: recipe.filter) ?? cleaned
        return drawDecorations(on: filtered, recipe: recipe)
    }

    static func outputFilename(source: SharedAttachment, recipe: ImageEditRecipe) -> String {
        let baseName = (source.filename as NSString).deletingPathExtension
        var suffixParts = [recipe.filter.rawValue, recipe.cropPreset.rawValue]
        if recipe.layoutPreset != .manual {
            suffixParts.append(recipe.layoutPreset.rawValue)
        }
        if recipe.cropAdjustment.isAdjusted {
            suffixParts.append("freecrop")
        }
        if !recipe.cleanupPatches.isEmpty {
            suffixParts.append("cleanup")
        }
        if recipe.background.mode != .original {
            suffixParts.append("background")
        }
        if recipe.subjectExtraction.mode != .none {
            suffixParts.append(recipe.subjectExtraction.hasSelectionPoint ? "selectedsubject" : "subject")
        }
        let suffix = suffixParts
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

    private static func crop(
        CGImage image: CGImage,
        preset: ImageEditRecipe.CropPreset,
        adjustment: ImageEditRecipe.CropAdjustment
    ) -> CGImage? {
        guard preset.aspectRatio != nil || adjustment.isAdjusted else {
            return image
        }

        let width = Double(image.width)
        let height = Double(image.height)
        let aspectRatio = preset.aspectRatio ?? (width / height)
        let currentRatio = width / height
        let baseCropWidth: Double
        let baseCropHeight: Double

        if currentRatio > aspectRatio {
            baseCropHeight = height
            baseCropWidth = height * aspectRatio
        } else {
            baseCropWidth = width
            baseCropHeight = width / aspectRatio
        }

        let adjustment = adjustment.clamped()
        let scale = adjustment.scale
        let cropWidth = max(1, min(width, baseCropWidth / scale))
        let cropHeight = max(1, min(height, baseCropHeight / scale))
        let desiredCenterX = adjustment.x * width
        let desiredCenterY = adjustment.y * height
        let originX = min(max(desiredCenterX - cropWidth / 2, 0), max(0, width - cropWidth))
        let originY = min(max(desiredCenterY - cropHeight / 2, 0), max(0, height - cropHeight))

        let rect = CGRect(
            x: originX,
            y: originY,
            width: cropWidth,
            height: cropHeight
        ).integral
        return image.cropping(to: rect)
    }

    private static func applyBackground(
        _ background: ImageEditRecipe.Background,
        to image: CGImage
    ) -> CGImage? {
        guard background.mode != .original else {
            return image
        }

        let size = CGSize(width: image.width, height: image.height)
        let rect = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            switch background.mode {
            case .original:
                UIImage(cgImage: image).draw(in: rect)
            case .solid:
                color(hex: background.colorHex, fallback: .white).setFill()
                UIRectFill(rect)
                drawInsetImage(image, background: background, in: rect)
            case .softBlur:
                let radius = CGFloat(max(4, min(background.blurRadius, 80)))
                if let blurred = blurredImage(from: image, radius: radius) {
                    UIImage(cgImage: blurred).draw(in: rect)
                } else {
                    UIImage(cgImage: image).draw(in: rect)
                }
                drawInsetImage(image, background: background, in: rect)
            }
        }
        return rendered.cgImage
    }

    private static func drawInsetImage(
        _ image: CGImage,
        background: ImageEditRecipe.Background,
        in rect: CGRect
    ) {
        let inset = max(0, min(background.inset, 0.28)) * min(rect.width, rect.height)
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        let imageRect = aspectFitRect(
            imageSize: CGSize(width: image.width, height: image.height),
            containerRect: insetRect
        )
        let cornerRadius = max(0, CGFloat(background.cornerRadius))
        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius)
        UIGraphicsGetCurrentContext()?.saveGState()
        path.addClip()
        UIImage(cgImage: image).draw(in: imageRect)
        UIGraphicsGetCurrentContext()?.restoreGState()
    }

    private static func aspectFitRect(imageSize: CGSize, containerRect: CGRect) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerRect.width > 0,
              containerRect.height > 0 else {
            return containerRect
        }

        let scale = min(containerRect.width / imageSize.width, containerRect.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: containerRect.midX - width / 2,
            y: containerRect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func applyCleanupPatches(
        to image: CGImage,
        patches: [ImageEditRecipe.CleanupPatch]
    ) -> CGImage? {
        guard !patches.isEmpty else {
            return image
        }

        let size = CGSize(width: image.width, height: image.height)
        let rect = CGRect(origin: .zero, size: size)
        let maxPatchRadius = patches
            .map { max(8, normalized($0.radius) * min(size.width, size.height)) }
            .max() ?? 18
        guard let blurred = blurredImage(from: image, radius: maxPatchRadius * 0.28) else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            UIImage(cgImage: image).draw(in: rect)
            let blurredImage = UIImage(cgImage: blurred)

            for patch in patches {
                drawCleanupPatch(
                    patch,
                    blurredImage: blurredImage,
                    imageRect: rect,
                    canvasSize: size
                )
            }
        }
        return rendered.cgImage
    }

    private static func applySubjectExtraction(
        _ subjectExtraction: ImageEditRecipe.SubjectExtraction,
        to image: CGImage
    ) -> CGImage? {
        switch subjectExtraction.mode {
        case .none:
            return image
        case .person:
            return personSubjectImage(from: image)
        case .object:
            return foregroundSubjectImage(from: image, selection: subjectExtraction)
        }
    }

    private static func personSubjectImage(from image: CGImage) -> CGImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let maskBuffer = request.results?.first?.pixelBuffer else {
            return image
        }

        let input = CIImage(cgImage: image)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
            .transformed(by: CGAffineTransform(
                scaleX: input.extent.width / CGFloat(CVPixelBufferGetWidth(maskBuffer)),
                y: input.extent.height / CGFloat(CVPixelBufferGetHeight(maskBuffer))
            ))
            .cropped(to: input.extent)
        let transparentBackground = CIImage(color: .clear).cropped(to: input.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = transparentBackground
        blend.maskImage = mask

        guard let output = blend.outputImage else {
            return image
        }
        return context.createCGImage(output, from: input.extent)
    }

    private static func foregroundSubjectImage(from image: CGImage, selection: ImageEditRecipe.SubjectExtraction) -> CGImage? {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            return image
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let selectedInstances = selectedForegroundInstances(in: observation, selection: selection),
              let maskedBuffer = try? observation.generateMaskedImage(
                  ofInstances: selectedInstances,
                  from: handler,
                  croppedToInstancesExtent: false
              ) else {
            return image
        }

        let output = CIImage(cvPixelBuffer: maskedBuffer)
        return context.createCGImage(output, from: output.extent)
    }

    @available(iOS 17.0, macOS 14.0, *)
    private static func selectedForegroundInstances(
        in observation: VNInstanceMaskObservation,
        selection: ImageEditRecipe.SubjectExtraction
    ) -> IndexSet? {
        guard selection.mode == .object,
              let selectionX = selection.selectionX,
              let selectionY = selection.selectionY else {
            return observation.allInstances
        }

        let instanceMask = observation.instanceMask
        let imageX = Int((selectionX * Double(CVPixelBufferGetWidth(instanceMask) - 1)).rounded())
        let imageY = Int((selectionY * Double(CVPixelBufferGetHeight(instanceMask) - 1)).rounded())
        guard let instanceIndex = foregroundInstanceIndex(atX: imageX, y: imageY, in: instanceMask),
              observation.allInstances.contains(instanceIndex) else {
            return observation.allInstances
        }
        return IndexSet(integer: instanceIndex)
    }

    private static func foregroundInstanceIndex(atX x: Int, y: Int, in pixelBuffer: CVPixelBuffer) -> Int? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else {
            return nil
        }

        let clampedX = min(max(x, 0), width - 1)
        let clampedY = min(max(y, 0), height - 1)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == kCVPixelFormatType_OneComponent8 else {
            return nil
        }
        let row = baseAddress.advanced(by: clampedY * bytesPerRow)
        let value = row.assumingMemoryBound(to: UInt8.self)[clampedX]
        return value > 0 ? Int(value) : nil
    }

    private static func blurredImage(from image: CGImage, radius: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input.clampedToExtent()
        blur.radius = Float(max(2, min(radius, 80)))
        guard let output = blur.outputImage?.cropped(to: input.extent) else {
            return nil
        }
        return context.createCGImage(output, from: input.extent)
    }

    private static func drawCleanupPatch(
        _ patch: ImageEditRecipe.CleanupPatch,
        blurredImage: UIImage,
        imageRect: CGRect,
        canvasSize: CGSize
    ) {
        let radius = max(8, normalized(patch.radius) * min(canvasSize.width, canvasSize.height))
        let center = CGPoint(
            x: normalized(patch.x) * canvasSize.width,
            y: normalized(patch.y) * canvasSize.height
        )
        let patchRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let softness = max(0.2, normalized(patch.softness))

        for index in 0..<8 {
            let progress = CGFloat(index + 1) / 8
            let inset = radius * (1 - progress)
            let alpha = min(0.2, 0.04 + 0.035 * progress) * softness
            let ellipse = UIBezierPath(ovalIn: patchRect.insetBy(dx: inset, dy: inset))
            UIGraphicsGetCurrentContext()?.saveGState()
            ellipse.addClip()
            blurredImage.draw(in: imageRect, blendMode: .normal, alpha: alpha)
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
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
