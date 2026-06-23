import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ScrapbookRenderer {
    enum ExportFormat {
        case png
        case pdf

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .pdf: return "pdf"
            }
        }
    }

    static func image(for layout: ScrapbookPageLayout, scale: CGFloat = 1) -> UIImage {
        let size = CGSize(
            width: max(1, CGFloat(layout.canvasWidth) * scale),
            height: max(1, CGFloat(layout.canvasHeight) * scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            draw(layout, in: context.cgContext)
        }
    }

    static func pngData(layout: ScrapbookPageLayout, scale: CGFloat = 1) -> Data? {
        image(for: layout, scale: scale).pngData()
    }

    static func pdfData(layout: ScrapbookPageLayout) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pdfBounds(for: layout))
        return renderer.pdfData { context in
            context.beginPage()
            draw(layout, in: context.cgContext)
        }
    }

    static func data(layout: ScrapbookPageLayout, format: ExportFormat) throws -> Data {
        switch format {
        case .png:
            guard let data = pngData(layout: layout) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        case .pdf:
            return pdfData(layout: layout)
        }
    }

    static func outputFilename(title: String, format: ExportFormat = .png) -> String {
        "\(sanitizedFilename(title))-scrapbook-\(DateFormatters.filename.string(from: Date())).\(format.fileExtension)"
    }

    static func export(layout: ScrapbookPageLayout, title: String, format: ExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("some-exports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let filename = outputFilename(title: title, format: format)
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data(layout: layout, format: format).write(to: url, options: [.atomic])

        return url
    }

    private static func writePDF(layout: ScrapbookPageLayout, to url: URL) throws {
        try pdfData(layout: layout).write(to: url, options: [.atomic])
    }

    private static func pdfBounds(for layout: ScrapbookPageLayout) -> CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: max(1, CGFloat(layout.canvasWidth)),
            height: max(1, CGFloat(layout.canvasHeight))
        )
    }

    private static func draw(_ layout: ScrapbookPageLayout, in context: CGContext) {
        let canvasRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(layout.canvasWidth),
            height: CGFloat(layout.canvasHeight)
        )
        color(hex: layout.backgroundColorHex, fallback: .white).setFill()
        context.fill(canvasRect)

        for layer in layout.layers {
            context.saveGState()
            context.translateBy(x: CGFloat(layer.x), y: CGFloat(layer.y))
            context.rotate(by: CGFloat(layer.rotation * .pi / 180))
            context.scaleBy(x: CGFloat(layer.scale), y: CGFloat(layer.scale))
            let rect = CGRect(
                x: -CGFloat(layer.width) / 2,
                y: -CGFloat(layer.height) / 2,
                width: CGFloat(layer.width),
                height: CGFloat(layer.height)
            )
            draw(layer, in: rect, context: context)
            context.restoreGState()
        }
    }

    private static func draw(_ layer: ScrapbookLayer, in rect: CGRect, context: CGContext) {
        switch layer.kind {
        case .image:
            drawImageLayer(layer, in: rect, context: context)
        case .text:
            drawText(layer.text ?? layer.title, layer: layer, in: rect)
        case .sticker:
            drawSticker(layer, in: rect)
        case .border:
            drawBorder(layer, in: rect)
        case .shape:
            drawShape(layer, in: rect, context: context)
        }
    }

    private static func drawImageLayer(_ layer: ScrapbookLayer, in rect: CGRect, context: CGContext) {
        let radius = CGFloat(layer.cornerRadius ?? 0)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        context.saveGState()
        path.addClip()

        if let attachmentPath = layer.attachmentPath,
           let url = SharedAttachmentStore.url(for: attachment(relativePath: attachmentPath)),
           let image = UIImage(contentsOfFile: url.path) {
            ScrapbookImageFilterRenderer.image(image, applying: layer.imageFilter).drawAspectFill(
                in: rect,
                cropX: layer.imageCropX,
                cropY: layer.imageCropY,
                cropScale: layer.imageCropScale
            )
        } else {
            color(hex: layer.backgroundColorHex, fallback: UIColor(red: 0.91, green: 0.96, blue: 0.93, alpha: 1)).setFill()
            UIBezierPath(rect: rect).fill()
            drawText("图片", layer: layer, in: rect)
        }

        context.restoreGState()
        drawImageBorder(layer, in: rect)
        drawShadow(layer, around: path, context: context)
    }

    private static func drawImageBorder(_ layer: ScrapbookLayer, in rect: CGRect) {
        guard let borderWidth = layer.borderWidth, borderWidth > 0 else {
            return
        }

        let inset = CGFloat(borderWidth) / 2
        let path = UIBezierPath(
            roundedRect: rect.insetBy(dx: inset, dy: inset),
            cornerRadius: max(0, CGFloat(layer.cornerRadius ?? 0) - inset)
        )
        color(hex: layer.borderColorHex, fallback: .white).setStroke()
        path.lineWidth = CGFloat(borderWidth)
        path.stroke()
    }

    private static func drawText(_ text: String, layer: ScrapbookLayer, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: layer),
            .foregroundColor: color(hex: layer.textColorHex, fallback: .label),
            .paragraphStyle: paragraph
        ]
        let insetRect = rect.insetBy(dx: 12, dy: 10)
        text.draw(in: insetRect, withAttributes: attributes)
    }

    private static func drawSticker(_ layer: ScrapbookLayer, in rect: CGRect) {
        let radius = CGFloat(layer.cornerRadius ?? rect.height / 2)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        color(hex: layer.backgroundColorHex, fallback: UIColor(red: 0.93, green: 0.97, blue: 0.95, alpha: 1)).setFill()
        path.fill()
        drawText(layer.text ?? layer.title, layer: layer, in: rect)
    }

    private static func drawBorder(_ layer: ScrapbookLayer, in rect: CGRect) {
        let path = UIBezierPath(
            roundedRect: rect,
            cornerRadius: CGFloat(layer.cornerRadius ?? 0)
        )
        color(hex: layer.borderColorHex, fallback: UIColor(red: 0.84, green: 0.87, blue: 0.92, alpha: 1)).setStroke()
        path.lineWidth = max(1, CGFloat(layer.borderWidth ?? 4))
        path.stroke()
    }

    private static func drawShape(_ layer: ScrapbookLayer, in rect: CGRect, context: CGContext) {
        let path = UIBezierPath(
            roundedRect: rect,
            cornerRadius: CGFloat(layer.cornerRadius ?? 0)
        )
        drawShadow(layer, around: path, context: context)
        color(hex: layer.backgroundColorHex, fallback: UIColor(red: 0.95, green: 0.93, blue: 0.98, alpha: 1)).setFill()
        path.fill()
    }

    private static func drawShadow(_ layer: ScrapbookLayer, around path: UIBezierPath, context: CGContext) {
        guard let opacity = layer.shadowOpacity, opacity > 0 else {
            return
        }
        context.saveGState()
        UIColor.black.withAlphaComponent(CGFloat(min(max(opacity, 0), 0.35))).setStroke()
        context.setShadow(offset: CGSize(width: 0, height: 12), blur: 22)
        path.lineWidth = 0.1
        path.stroke()
        context.restoreGState()
    }

    private static func attachment(relativePath: String) -> SharedAttachment {
        SharedAttachment(
            id: relativePath,
            filename: relativePath,
            relativePath: relativePath,
            typeIdentifier: "public.image",
            byteCount: 0
        )
    }

    private static func sanitizedFilename(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        return cleaned.isEmpty ? "scrapbook" : cleaned
    }

    private static func font(for layer: ScrapbookLayer) -> UIFont {
        let size = CGFloat(layer.fontSize ?? 32)

        switch ScrapbookStyleCatalog.normalizedFontKey(layer.fontName) {
        case "serif":
            return UIFont.systemFont(ofSize: size, weight: .semibold).withSerifDesign()
        case "mono":
            return UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
        case "handwritten":
            let base = UIFont.systemFont(ofSize: size, weight: .medium).withRoundedDesign()
            return UIFont(descriptor: base.fontDescriptor.withSymbolicTraits(.traitItalic) ?? base.fontDescriptor, size: size)
        case "caption":
            return UIFont.systemFont(ofSize: size, weight: .medium).withRoundedDesign()
        default:
            return UIFont.systemFont(ofSize: size, weight: .semibold).withRoundedDesign()
        }
    }

    private static func color(hex: String?, fallback: UIColor) -> UIColor {
        guard let hex = hex else {
            return fallback
        }
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

enum ScrapbookImageFilterRenderer {
    private static let ciContext = CIContext(options: nil)

    static func image(_ image: UIImage, applying filter: ScrapbookLayer.ImageFilter) -> UIImage {
        guard filter != .original,
              let cgImage = image.cgImage,
              let filtered = cgImage(cgImage, applying: filter) else {
            return image
        }

        return UIImage(cgImage: filtered, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func cgImage(_ image: CGImage, applying filter: ScrapbookLayer.ImageFilter) -> CGImage? {
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

        return ciContext.createCGImage(output, from: output.extent)
    }
}

enum ScrapbookExportShareFile {
    static func url(for attachment: SharedAttachment, fileManager: FileManager = .default) -> URL? {
        guard
            let url = SharedAttachmentStore.url(for: attachment, fileManager: fileManager),
            fileManager.fileExists(atPath: url.path)
        else {
            return nil
        }

        return url
    }
}

private extension UIFont {
    func withRoundedDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    func withSerifDesign() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.serif) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private extension UIImage {
    func drawAspectFill(in rect: CGRect, cropX: Double = 0.5, cropY: Double = 0.5, cropScale: Double = 1) {
        guard size.width > 0, size.height > 0 else {
            return
        }
        let cropScale = min(max(CGFloat(cropScale.isFinite ? cropScale : 1), 1), 3)
        let cropX = min(max(CGFloat(cropX.isFinite ? cropX : 0.5), 0), 1)
        let cropY = min(max(CGFloat(cropY.isFinite ? cropY : 0.5), 0), 1)
        let scale = max(rect.width / size.width, rect.height / size.height) * cropScale
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let maxOffsetX = max(0, drawSize.width - rect.width)
        let maxOffsetY = max(0, drawSize.height - rect.height)
        let drawRect = CGRect(
            x: rect.minX - (maxOffsetX * cropX),
            y: rect.minY - (maxOffsetY * cropY),
            width: drawSize.width,
            height: drawSize.height
        )
        draw(in: drawRect)
    }
}
