import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImageEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let attachment: SharedAttachment

    @State private var title: String
    @State private var layoutPreset: ImageEditRecipe.LayoutPreset = .manual
    @State private var filter: ImageEditRecipe.Filter = .fresh
    @State private var cropPreset: ImageEditRecipe.CropPreset = .original
    @State private var cropX: Double = 0.5
    @State private var cropY: Double = 0.5
    @State private var cropScale: Double = 1
    @State private var borderWidth: Double = 18
    @State private var borderColorHex = "#FFFFFF"
    @State private var backgroundMode: ImageEditRecipe.Background.Mode = .original
    @State private var backgroundColorHex = "#F8DCE8"
    @State private var backgroundBlurRadius: Double = 22
    @State private var backgroundInset: Double = 0.06
    @State private var backgroundCornerRadius: Double = 28
    @State private var subjectExtractionMode: ImageEditRecipe.SubjectExtraction.Mode = .none
    @State private var subjectSelectionX: Double?
    @State private var subjectSelectionY: Double?
    @State private var cleanupX: Double = 0.5
    @State private var cleanupY: Double = 0.5
    @State private var cleanupRadius: Double = 0.08
    @State private var cleanupPatches: [ImageEditRecipe.CleanupPatch] = []
    @State private var cleanupAuthorized = false
    @State private var caption = ""
    @State private var sticker = ""
    @State private var note = ""
    @State private var editMode: ImageEditorMode = .crop
    @State private var sourceImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var statusText: String?

    init(attachment: SharedAttachment) {
        self.attachment = attachment
        _title = State(initialValue: (attachment.displayName as NSString).deletingPathExtension)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                preview
                controls
            }
            .padding(18)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("图片编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            sourceImage = loadSourceImage()
            refreshPreview()
        }
        .onChange(of: layoutPreset) { preset in applyLayoutPreset(preset) }
        .onChange(of: filter) { _ in refreshPreview() }
        .onChange(of: cropPreset) { _ in refreshPreview() }
        .onChange(of: cropX) { _ in refreshPreview() }
        .onChange(of: cropY) { _ in refreshPreview() }
        .onChange(of: cropScale) { _ in refreshPreview() }
        .onChange(of: borderWidth) { _ in refreshPreview() }
        .onChange(of: borderColorHex) { _ in refreshPreview() }
        .onChange(of: backgroundMode) { _ in refreshPreview() }
        .onChange(of: backgroundColorHex) { _ in refreshPreview() }
        .onChange(of: backgroundBlurRadius) { _ in refreshPreview() }
        .onChange(of: backgroundInset) { _ in refreshPreview() }
        .onChange(of: backgroundCornerRadius) { _ in refreshPreview() }
        .onChange(of: subjectExtractionMode) { mode in
            if mode != .object {
                subjectSelectionX = nil
                subjectSelectionY = nil
            }
            refreshPreview()
        }
        .onChange(of: subjectSelectionX) { _ in refreshPreview() }
        .onChange(of: subjectSelectionY) { _ in refreshPreview() }
        .onChange(of: cleanupPatches) { _ in refreshPreview() }
        .onChange(of: caption) { _ in refreshPreview() }
        .onChange(of: sticker) { _ in refreshPreview() }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("预览", systemImage: "photo")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.surface)

                if editMode == .crop, let image = sourceImage ?? previewImage {
                    ImageCropSelectionCanvas(
                        image: image,
                        cropPreset: cropPreset,
                        cropX: $cropX,
                        cropY: $cropY,
                        cropScale: $cropScale
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if editMode == .subject, let image = sourceImage ?? previewImage {
                    ImageSubjectSelectionCanvas(
                        image: image,
                        selectionX: $subjectSelectionX,
                        selectionY: $subjectSelectionY
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if editMode == .cleanup, let image = previewImage {
                    ImageCleanupSelectionCanvas(
                        image: image,
                        cleanupX: $cleanupX,
                        cleanupY: $cleanupY,
                        cleanupRadius: cleanupRadius,
                        patches: cleanupPatches
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if let previewImage = previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )

            Picker("模式", selection: $editMode) {
                ForEach(ImageEditorMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("作品名称", text: $title)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("滤镜", selection: $filter) {
                ForEach(ImageEditRecipe.Filter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("模板", selection: $layoutPreset) {
                ForEach(ImageEditRecipe.LayoutPreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.accentGreen)

            Picker("比例", selection: $cropPreset) {
                ForEach(ImageEditRecipe.CropPreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            cropControls
            backgroundControls
            subjectExtractionControls
            cleanupControls

            VStack(alignment: .leading, spacing: 8) {
                Label("边框", systemImage: "square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                Slider(value: $borderWidth, in: 0...64, step: 2)
                    .tint(Color.accentGreen)

                HStack(spacing: 8) {
                    ForEach(borderSwatches, id: \.self) { hex in
                        Button {
                            borderColorHex = hex
                        } label: {
                            Circle()
                                .fill(color(hex: hex) ?? Color.white)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(borderColorHex == hex ? Color.accentGreen : Color.border, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(hex)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("文字", text: $caption)
                TextField("贴纸", text: $sticker)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("备注", text: $note)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let statusText = statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var recipe: ImageEditRecipe {
        ImageEditRecipe(
            sourceAttachmentPath: attachment.relativePath,
            filter: filter,
            layoutPreset: layoutPreset,
            cropPreset: cropPreset,
            cropAdjustment: ImageEditRecipe.CropAdjustment(x: cropX, y: cropY, scale: cropScale),
            border: ImageEditRecipe.Border(colorHex: borderColorHex, width: borderWidth),
            background: ImageEditRecipe.Background(
                mode: backgroundMode,
                colorHex: backgroundColorHex,
                blurRadius: backgroundBlurRadius,
                cornerRadius: backgroundCornerRadius,
                inset: backgroundInset
            ),
            subjectExtraction: ImageEditRecipe.SubjectExtraction(
                mode: subjectExtractionMode,
                selectionX: subjectSelectionX,
                selectionY: subjectSelectionY
            ),
            textOverlays: caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [
                layoutPreset.textOverlay(text: caption.trimmingCharacters(in: .whitespacesAndNewlines))
            ],
            stickerOverlays: sticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [
                layoutPreset.stickerOverlay(text: sticker.trimmingCharacters(in: .whitespacesAndNewlines))
            ],
            cleanupPatches: cleanupPatches
        )
    }

    private func applyLayoutPreset(_ preset: ImageEditRecipe.LayoutPreset) {
        guard preset != .manual else {
            refreshPreview()
            return
        }

        filter = preset.filter
        cropPreset = preset.cropPreset
        borderColorHex = preset.border.colorHex
        borderWidth = preset.border.width
        backgroundMode = preset.background.mode
        backgroundColorHex = preset.background.colorHex
        backgroundBlurRadius = preset.background.blurRadius
        backgroundInset = preset.background.inset
        backgroundCornerRadius = preset.background.cornerRadius
        subjectExtractionMode = .none
        subjectSelectionX = nil
        subjectSelectionY = nil
        if caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let defaultCaption = preset.defaultCaption {
            caption = defaultCaption
        }
        if sticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let defaultSticker = preset.defaultSticker {
            sticker = defaultSticker
        }
        editMode = .decorate
        refreshPreview()
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("裁剪微调", systemImage: "crop")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Button("重置") {
                    cropX = 0.5
                    cropY = 0.5
                    cropScale = 1
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentGreen)
            }

            Slider(value: $cropScale, in: 1...3, step: 0.05) {
                Text("缩放")
            }
            .tint(Color.accentGreen)

            HStack(spacing: 8) {
                Slider(value: $cropX, in: 0...1, step: 0.01) {
                    Text("左右")
                }
                Slider(value: $cropY, in: 0...1, step: 0.01) {
                    Text("上下")
                }
            }
            .tint(Color.accentGreen)
        }
        .padding(10)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cleanupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("授权清理", systemImage: "bandage")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Text("\(cleanupPatches.count)处")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }

            Toggle("已获授权", isOn: $cleanupAuthorized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .tint(Color.accentGreen)

            HStack(spacing: 8) {
                Slider(value: $cleanupX, in: 0...1, step: 0.01) {
                    Text("左右")
                }
                Slider(value: $cleanupY, in: 0...1, step: 0.01) {
                    Text("上下")
                }
            }
            .tint(Color.accentGreen)

            Slider(value: $cleanupRadius, in: 0.03...0.18, step: 0.01) {
                Text("范围")
            }
            .tint(Color.accentGreen)

            HStack(spacing: 8) {
                Button {
                    guard cleanupAuthorized else {
                        statusText = "需确认图片授权"
                        return
                    }
                    guard cleanupPatches.count < 6 else {
                        statusText = "最多添加 6 处清理点"
                        return
                    }
                    cleanupPatches.append(
                        ImageEditRecipe.CleanupPatch(
                            x: cleanupX,
                            y: cleanupY,
                            radius: cleanupRadius
                        )
                    )
                } label: {
                    Label("添加", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .disabled(!cleanupAuthorized)

                Button {
                    cleanupPatches.removeAll()
                } label: {
                    Label("清空", systemImage: "xmark.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .disabled(cleanupPatches.isEmpty)
            }
        }
        .padding(10)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("背景", systemImage: "rectangle.on.rectangle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            Picker("背景", selection: $backgroundMode) {
                ForEach(ImageEditRecipe.Background.Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if backgroundMode != .original {
                HStack(spacing: 8) {
                    ForEach(backgroundSwatches, id: \.self) { hex in
                        Button {
                            backgroundColorHex = hex
                        } label: {
                            Circle()
                                .fill(color(hex: hex) ?? Color.white)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(backgroundColorHex == hex ? Color.accentGreen : Color.border, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(hex)
                    }
                }

                if backgroundMode == .softBlur {
                    Slider(value: $backgroundBlurRadius, in: 4...60, step: 2) {
                        Text("柔化")
                    }
                    .tint(Color.accentGreen)
                }

                Slider(value: $backgroundInset, in: 0...0.18, step: 0.01) {
                    Text("留白")
                }
                .tint(Color.accentGreen)

                Slider(value: $backgroundCornerRadius, in: 0...72, step: 2) {
                    Text("圆角")
                }
                .tint(Color.accentGreen)
            }
        }
        .padding(10)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subjectExtractionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("主体", systemImage: "person.crop.rectangle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            Picker("主体", selection: $subjectExtractionMode) {
                ForEach(ImageEditRecipe.SubjectExtraction.Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if subjectExtractionMode == .object {
                HStack(spacing: 10) {
                    Button {
                        editMode = .subject
                        if subjectSelectionX == nil || subjectSelectionY == nil {
                            subjectSelectionX = 0.5
                            subjectSelectionY = 0.5
                        }
                    } label: {
                        Label("点选主体", systemImage: "scope")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentGreen)

                    Button {
                        subjectSelectionX = nil
                        subjectSelectionY = nil
                    } label: {
                        Label("全部主体", systemImage: "rectangle.3.group")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .disabled(subjectSelectionX == nil || subjectSelectionY == nil)

                    Spacer()

                    if let subjectSelectionX = subjectSelectionX,
                       let subjectSelectionY = subjectSelectionY {
                        Text("\(Int(subjectSelectionX * 100))/\(Int(subjectSelectionY * 100))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var borderSwatches: [String] {
        ["#FFFFFF", "#F8DCE8", "#DDEBF7", "#E8F3EE", "#1D222B"]
    }

    private var backgroundSwatches: [String] {
        ["#F8DCE8", "#DDEBF7", "#E8F3EE", "#FDF8FA", "#1D222B"]
    }

    private func refreshPreview() {
        guard let sourceImage = sourceImage ?? loadSourceImage(),
              let cgImage = ImageEditRenderer.renderedImage(sourceImage: sourceImage, recipe: recipe) else {
            previewImage = nil
            return
        }

        previewImage = UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: .up)
    }

    private func save() {
        guard store.addImageEdit(
            title: title,
            sourceAttachment: attachment,
            recipe: recipe,
            note: note
        ) != nil else {
            statusText = "保存失败"
            return
        }

        statusText = "已保存图片作品"
        dismiss()
    }

    private func loadSourceImage() -> UIImage? {
        guard let url = SharedAttachmentStore.url(for: attachment) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func color(hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}

private enum ImageEditorMode: String, CaseIterable, Hashable {
    case crop
    case subject
    case cleanup
    case decorate

    var title: String {
        switch self {
        case .crop: return "裁剪"
        case .subject: return "主体"
        case .cleanup: return "清理"
        case .decorate: return "修饰"
        }
    }
}

private struct ImageCropSelectionCanvas: View {
    let image: UIImage
    let cropPreset: ImageEditRecipe.CropPreset
    @Binding var cropX: Double
    @Binding var cropY: Double
    @Binding var cropScale: Double

    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var scaleStart: Double?

    var body: some View {
        GeometryReader { proxy in
            let imageRect = aspectFitRect(
                imageSize: image.size,
                containerSize: proxy.size
            )
            let cropRect = cropSelectionRect(in: imageRect)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                cropDimOverlay(imageRect: imageRect, cropRect: cropRect)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 2)

                cropGrid(in: cropRect)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(imageRect: imageRect))
            .simultaneousGesture(magnificationGesture())
        }
    }

    private func cropDimOverlay(imageRect: CGRect, cropRect: CGRect) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.34))
                .frame(width: imageRect.width, height: cropRect.minY - imageRect.minY)
                .position(x: imageRect.midX, y: (imageRect.minY + cropRect.minY) / 2)

            Rectangle()
                .fill(Color.black.opacity(0.34))
                .frame(width: imageRect.width, height: imageRect.maxY - cropRect.maxY)
                .position(x: imageRect.midX, y: (cropRect.maxY + imageRect.maxY) / 2)

            Rectangle()
                .fill(Color.black.opacity(0.34))
                .frame(width: cropRect.minX - imageRect.minX, height: cropRect.height)
                .position(x: (imageRect.minX + cropRect.minX) / 2, y: cropRect.midY)

            Rectangle()
                .fill(Color.black.opacity(0.34))
                .frame(width: imageRect.maxX - cropRect.maxX, height: cropRect.height)
                .position(x: (cropRect.maxX + imageRect.maxX) / 2, y: cropRect.midY)
        }
        .allowsHitTesting(false)
    }

    private func cropGrid(in rect: CGRect) -> some View {
        Path { path in
            for index in 1..<3 {
                let x = rect.minX + rect.width * CGFloat(index) / 3
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))

                let y = rect.minY + rect.height * CGFloat(index) / 3
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.48), lineWidth: 1)
        .allowsHitTesting(false)
    }

    private func dragGesture(imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartX == nil {
                    dragStartX = cropX
                    dragStartY = cropY
                }

                let width = max(imageRect.width, 1)
                let height = max(imageRect.height, 1)
                let adjustment = ImageEditRecipe.CropAdjustment(
                    x: dragStartX ?? cropX,
                    y: dragStartY ?? cropY,
                    scale: cropScale
                ).applyingDrag(
                    widthDelta: Double(value.translation.width),
                    heightDelta: Double(value.translation.height),
                    imageWidth: Double(width),
                    imageHeight: Double(height)
                )
                cropX = adjustment.x
                cropY = adjustment.y
                cropScale = adjustment.scale
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if scaleStart == nil {
                    scaleStart = cropScale
                }
                let adjustment = ImageEditRecipe.CropAdjustment(
                    x: cropX,
                    y: cropY,
                    scale: scaleStart ?? cropScale
                ).applyingMagnification(Double(value))
                cropX = adjustment.x
                cropY = adjustment.y
                cropScale = adjustment.scale
            }
            .onEnded { _ in
                scaleStart = nil
            }
    }

    private func cropSelectionRect(in imageRect: CGRect) -> CGRect {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return .zero
        }

        let currentRatio = Double(imageRect.width / imageRect.height)
        let aspectRatio = cropPreset.aspectRatio ?? currentRatio
        let baseWidth: CGFloat
        let baseHeight: CGFloat

        if currentRatio > aspectRatio {
            baseHeight = imageRect.height
            baseWidth = imageRect.height * CGFloat(aspectRatio)
        } else {
            baseWidth = imageRect.width
            baseHeight = imageRect.width / CGFloat(aspectRatio)
        }

        let adjustment = ImageEditRecipe.CropAdjustment(x: cropX, y: cropY, scale: cropScale).clamped()
        let scale = CGFloat(adjustment.scale)
        let width = max(32, min(imageRect.width, baseWidth / scale))
        let height = max(32, min(imageRect.height, baseHeight / scale))
        let centerX = imageRect.minX + CGFloat(adjustment.x) * imageRect.width
        let centerY = imageRect.minY + CGFloat(adjustment.y) * imageRect.height
        let originX = min(max(centerX - width / 2, imageRect.minX), imageRect.maxX - width)
        let originY = min(max(centerY - height / 2, imageRect.minY), imageRect.maxY - height)

        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

private struct ImageSubjectSelectionCanvas: View {
    let image: UIImage
    @Binding var selectionX: Double?
    @Binding var selectionY: Double?

    var body: some View {
        GeometryReader { proxy in
            let imageRect = aspectFitRect(imageSize: image.size, containerSize: proxy.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if let selectionX = selectionX,
                   let selectionY = selectionY {
                    subjectMarker(x: selectionX, y: selectionY, imageRect: imageRect)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectionX = clamped(Double((value.location.x - imageRect.minX) / max(imageRect.width, 1)))
                        selectionY = clamped(Double((value.location.y - imageRect.minY) / max(imageRect.height, 1)))
                    }
            )
        }
    }

    private func subjectMarker(x: Double, y: Double, imageRect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentGold.opacity(0.22))
                .frame(width: 48, height: 48)
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 30, height: 30)
            Circle()
                .fill(Color.accentGold)
                .frame(width: 10, height: 10)
        }
        .position(
            x: imageRect.minX + CGFloat(clamped(x)) * imageRect.width,
            y: imageRect.minY + CGFloat(clamped(y)) * imageRect.height
        )
        .shadow(color: Color.black.opacity(0.28), radius: 6, x: 0, y: 2)
        .allowsHitTesting(false)
    }
}

private struct ImageCleanupSelectionCanvas: View {
    let image: UIImage
    @Binding var cleanupX: Double
    @Binding var cleanupY: Double
    let cleanupRadius: Double
    let patches: [ImageEditRecipe.CleanupPatch]

    var body: some View {
        GeometryReader { proxy in
            let imageRect = aspectFitRect(imageSize: image.size, containerSize: proxy.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                ForEach(patches) { patch in
                    cleanupMarker(
                        x: patch.x,
                        y: patch.y,
                        radius: patch.radius,
                        imageRect: imageRect,
                        color: Color.accentGreen.opacity(0.52)
                    )
                }

                cleanupMarker(
                    x: cleanupX,
                    y: cleanupY,
                    radius: cleanupRadius,
                    imageRect: imageRect,
                    color: Color.white.opacity(0.7)
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        cleanupX = clamped(Double((value.location.x - imageRect.minX) / max(imageRect.width, 1)))
                        cleanupY = clamped(Double((value.location.y - imageRect.minY) / max(imageRect.height, 1)))
                    }
            )
        }
    }

    private func cleanupMarker(
        x: Double,
        y: Double,
        radius: Double,
        imageRect: CGRect,
        color: Color
    ) -> some View {
        let diameter = max(20, min(imageRect.width, imageRect.height) * CGFloat(radius) * 2)
        return Circle()
            .stroke(color, lineWidth: 2)
            .background(Circle().fill(color.opacity(0.16)))
            .frame(width: diameter, height: diameter)
            .position(
                x: imageRect.minX + CGFloat(clamped(x)) * imageRect.width,
                y: imageRect.minY + CGFloat(clamped(y)) * imageRect.height
            )
            .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 2)
            .allowsHitTesting(false)
    }
}

private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0,
          imageSize.height > 0,
          containerSize.width > 0,
          containerSize.height > 0 else {
        return .zero
    }

    let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    return CGRect(
        x: (containerSize.width - width) / 2,
        y: (containerSize.height - height) / 2,
        width: width,
        height: height
    )
}

private func clamped(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
