import UIKit

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

    static func outputFilename(title: String) -> String {
        "\(sanitizedFilename(title))-scrapbook-\(DateFormatters.filename.string(from: Date())).png"
    }

    static func export(layout: ScrapbookPageLayout, title: String, format: ExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("some-exports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let filename: String
        switch format {
        case .png:
            filename = outputFilename(title: title)
        case .pdf:
            filename = "\(sanitizedFilename(title))-scrapbook-\(DateFormatters.filename.string(from: Date())).\(format.fileExtension)"
        }
        let url = directory.appendingPathComponent(filename, isDirectory: false)

        switch format {
        case .png:
            guard let data = pngData(layout: layout) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url, options: [.atomic])
        case .pdf:
            try writePDF(layout: layout, to: url)
        }

        return url
    }

    private static func writePDF(layout: ScrapbookPageLayout, to url: URL) throws {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: max(1, CGFloat(layout.canvasWidth)),
            height: max(1, CGFloat(layout.canvasHeight))
        )
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            draw(layout, in: context.cgContext)
        }
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
            image.drawAspectFill(in: rect)
        } else {
            color(hex: layer.backgroundColorHex, fallback: UIColor(red: 0.91, green: 0.96, blue: 0.93, alpha: 1)).setFill()
            UIBezierPath(rect: rect).fill()
            drawText("图片", layer: layer, in: rect)
        }

        context.restoreGState()
        drawShadow(layer, around: path, context: context)
    }

    private static func drawText(_ text: String, layer: ScrapbookLayer, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: CGFloat(layer.fontSize ?? 32), weight: .semibold),
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

private extension UIImage {
    func drawAspectFill(in rect: CGRect) {
        guard size.width > 0, size.height > 0 else {
            return
        }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        draw(in: drawRect)
    }
}
