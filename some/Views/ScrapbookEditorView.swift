import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ScrapbookEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let memo: Memo
    @State private var layout: ScrapbookPageLayout
    @State private var selectedLayerID: UUID?
    @State private var selectedImageAssetID: UUID?
    @State private var statusText: String?
    @State private var exportedDocument: ExportedDocument?

    init(memo: Memo) {
        self.memo = memo
        _layout = State(initialValue: ScrapbookPageLayout.layout(in: memo.text) ?? ScrapbookPageLayout())
        _selectedLayerID = State(initialValue: ScrapbookPageLayout.layout(in: memo.text)?.layers.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorCanvas
                .padding(.horizontal, 14)
                .padding(.top, 14)

            Divider()
                .padding(.top, 12)

            inspector
                .padding(14)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("编辑手帐")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("关闭")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveLayout()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .accessibilityLabel("保存手帐")
            }
        }
        .sheet(item: $exportedDocument) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var editorCanvas: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / max(layout.canvasWidth, 1),
                proxy.size.height / max(layout.canvasHeight, 1)
            )
            let canvasSize = CGSize(
                width: layout.canvasWidth * scale,
                height: layout.canvasHeight * scale
            )

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)

                ZStack {
                    Rectangle()
                        .fill(color(hex: layout.backgroundColorHex) ?? Color.surface)

                    ForEach(layout.layers.indices, id: \.self) { index in
                        EditableScrapbookLayerView(
                            layer: $layout.layers[index],
                            canvasScale: scale,
                            isSelected: selectedLayerID == layout.layers[index].id,
                            onSelect: {
                                selectedLayerID = layout.layers[index].id
                            }
                        )
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 470)
    }

    @ViewBuilder
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                addLayerButton(systemImage: "textformat", title: "文字") {
                    addTextLayer()
                }
                addLayerButton(systemImage: "seal", title: "贴纸") {
                    addStickerLayer()
                }
                addLayerButton(systemImage: "square.fill", title: "色块") {
                    addShapeLayer()
                }
                addLayerButton(systemImage: "rectangle.dashed", title: "花边") {
                    addBorderLayer()
                }
                addLayerButton(systemImage: "photo", title: "图片") {
                    addSelectedImageLayer()
                }
                .disabled(selectedImageAttachment == nil)
                addLayerButton(systemImage: "square.and.arrow.up", title: "导出") {
                    exportLayout()
                }
                addLayerButton(systemImage: "doc.richtext", title: "PDF") {
                    exportPDF()
                }

                if let statusText = statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                        .frame(height: 34)
                }
            }

            if !imageAttachmentAssets.isEmpty {
                Picker("图片素材", selection: $selectedImageAssetID) {
                    Text("选择图片").tag(Optional<UUID>.none)
                    ForEach(imageAttachmentAssets) { asset in
                        Text(asset.title).tag(Optional(asset.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accentGreen)
            }

            colorSwatches(
                title: "画布底色",
                values: ScrapbookStyleCatalog.canvasColorHexes,
                selection: canvasColorBinding
            )

            if let index = selectedLayerIndex {
                selectedLayerInspector(layer: $layout.layers[index])
            } else {
                EmptyStateView(title: "选择一个图层")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func selectedLayerInspector(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(layer.wrappedValue.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)

                Spacer()

                iconButton("square.3.layers.3d.top.filled", label: "上移图层") {
                    moveSelectedLayerForward()
                }
                iconButton("square.3.layers.3d.down.right", label: "下移图层") {
                    moveSelectedLayerBackward()
                }
                iconButton("doc.on.doc", label: "复制图层") {
                    duplicateSelectedLayer()
                }
                iconButton("trash", label: "删除图层", role: .destructive) {
                    deleteSelectedLayer()
                }
            }

            if layer.wrappedValue.kind == .text || layer.wrappedValue.kind == .sticker {
                TextField("内容", text: textBinding(for: layer))
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if layer.wrappedValue.kind == .text || layer.wrappedValue.kind == .sticker {
                fontPresetControls(layer: layer)
                colorSwatches(
                    title: "文字色",
                    values: ScrapbookStyleCatalog.textColorHexes,
                    selection: textColorBinding(for: layer)
                )
            }

            if layer.wrappedValue.kind == .sticker {
                stickerPresetControls(layer: layer)
                colorSwatches(
                    title: "贴纸底色",
                    values: ScrapbookStyleCatalog.fillColorHexes,
                    selection: backgroundColorBinding(for: layer)
                )
            }

            if layer.wrappedValue.kind == .shape {
                colorSwatches(
                    title: "色块底色",
                    values: ScrapbookStyleCatalog.fillColorHexes,
                    selection: backgroundColorBinding(for: layer)
                )
            }

            if layer.wrappedValue.kind == .border {
                borderPresetControls(layer: layer)
                colorSwatches(
                    title: "花边颜色",
                    values: ScrapbookStyleCatalog.borderColorHexes,
                    selection: borderColorBinding(for: layer)
                )
            }

            if layer.wrappedValue.kind == .image {
                imageCompositionControls(layer: layer)
                imageFilterControls(layer: layer)
                colorSwatches(
                    title: "相框颜色",
                    values: ScrapbookStyleCatalog.borderColorHexes,
                    selection: borderColorBinding(for: layer)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Slider(value: scaleBinding(for: layer), in: 0.35...2.4)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("缩放")

                Slider(value: rotationBinding(for: layer), in: -45...45)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("旋转")
            }

            dimensionControls(layer: layer)
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var selectedLayerIndex: Int? {
        guard let selectedLayerID = selectedLayerID else {
            return nil
        }
        return layout.layers.firstIndex { $0.id == selectedLayerID }
    }

    private var imageAttachmentAssets: [MemoAsset] {
        store.assets.filter { asset in
            guard (asset.kind == .attachment || asset.kind == .screenshot || asset.kind == .imageEdit),
                  let type = asset.typeIdentifier.flatMap(UTType.init) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }

    private var selectedImageAttachment: SharedAttachment? {
        guard let selectedImageAssetID = selectedImageAssetID,
              let asset = imageAttachmentAssets.first(where: { $0.id == selectedImageAssetID }),
              let attachment = AttachmentReferenceResolver.attachment(from: asset) else {
            return nil
        }

        return attachment
    }

    private var canvasColorBinding: Binding<String> {
        Binding(
            get: { layout.backgroundColorHex },
            set: { layout.backgroundColorHex = $0 }
        )
    }

    private func addLayerButton(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 11)
                .frame(height: 34)
                .foregroundStyle(Color.accentGreen)
                .background(Color.greenTint)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ systemImage: String, label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.accentGreen)
        .background(role == .destructive ? Color.red.opacity(0.08) : Color.greenTint)
        .clipShape(Capsule())
        .accessibilityLabel(label)
    }

    private func fontPresetControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            controlLabel("字体")
            FlowLayout(spacing: 8) {
                ForEach(ScrapbookStyleCatalog.fontPresets) { preset in
                    presetChip(
                        title: preset.title,
                        isSelected: ScrapbookStyleCatalog.normalizedFontKey(layer.wrappedValue.fontName) == preset.id
                    ) {
                        var updated = layer.wrappedValue
                        ScrapbookStyleCatalog.applyFontPreset(preset, to: &updated)
                        layer.wrappedValue = updated
                    }
                }
            }
        }
    }

    private func stickerPresetControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            controlLabel("贴纸")
            FlowLayout(spacing: 8) {
                ForEach(ScrapbookStyleCatalog.stickerPresets) { preset in
                    presetChip(
                        title: preset.title,
                        isSelected: layer.wrappedValue.text == preset.text
                    ) {
                        var updated = layer.wrappedValue
                        ScrapbookStyleCatalog.applyStickerPreset(preset, to: &updated)
                        layer.wrappedValue = updated
                    }
                }
            }
        }
    }

    private func borderPresetControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            controlLabel("花边")
            FlowLayout(spacing: 8) {
                ForEach(ScrapbookStyleCatalog.borderPresets) { preset in
                    presetChip(
                        title: preset.title,
                        isSelected: layer.wrappedValue.title == preset.title
                    ) {
                        var updated = layer.wrappedValue
                        ScrapbookStyleCatalog.applyBorderPreset(preset, to: &updated)
                        layer.wrappedValue = updated
                    }
                }
            }
        }
    }

    private func imageCompositionControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                controlLabel("照片构图")
                Spacer()
                Button("复位") {
                    layer.wrappedValue.imageCropX = 0.5
                    layer.wrappedValue.imageCropY = 0.5
                    layer.wrappedValue.imageCropScale = 1
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentGreen)
            }

            Slider(value: imageCropXBinding(for: layer), in: 0...1)
                .tint(Color.accentGreen)
                .accessibilityLabel("照片横向取景")
            Slider(value: imageCropYBinding(for: layer), in: 0...1)
                .tint(Color.accentGreen)
                .accessibilityLabel("照片纵向取景")
            Slider(value: imageCropScaleBinding(for: layer), in: 1...3)
                .tint(Color.accentGreen)
                .accessibilityLabel("照片取景放大")
        }
    }

    private func imageFilterControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            controlLabel("照片滤镜")
            FlowLayout(spacing: 8) {
                ForEach(ScrapbookLayer.ImageFilter.allCases, id: \.self) { filter in
                    presetChip(
                        title: filter.title,
                        isSelected: layer.wrappedValue.imageFilter == filter
                    ) {
                        layer.wrappedValue.imageFilter = filter
                    }
                }
            }
        }
    }

    private func colorSwatches(title: String, values: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            controlLabel(title)
            FlowLayout(spacing: 8) {
                ForEach(values, id: \.self) { hex in
                    Button {
                        selection.wrappedValue = hex
                    } label: {
                        Circle()
                            .fill(color(hex: hex) ?? Color.white)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(selection.wrappedValue == hex ? Color.accentGreen : Color.border, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(hex)")
                }
            }
        }
    }

    private func dimensionControls(layer: Binding<ScrapbookLayer>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if layer.wrappedValue.kind == .text || layer.wrappedValue.kind == .sticker {
                controlLabel("字号")
                Slider(value: fontSizeBinding(for: layer), in: 20...72)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("字号")
            }

            if layer.wrappedValue.kind == .sticker || layer.wrappedValue.kind == .shape || layer.wrappedValue.kind == .image || layer.wrappedValue.kind == .border {
                controlLabel("圆角")
                Slider(value: cornerRadiusBinding(for: layer), in: 0...72)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("圆角")
            }

            if layer.wrappedValue.kind == .border {
                controlLabel("线宽")
                Slider(value: borderWidthBinding(for: layer), in: 1...24)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("花边线宽")
            }

            if layer.wrappedValue.kind == .image {
                controlLabel("相框线宽")
                Slider(value: imageBorderWidthBinding(for: layer), in: 0...28)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("相框线宽")
            }
        }
    }

    private func presetChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .foregroundStyle(isSelected ? Color.white : Color.secondaryText)
                .background(isSelected ? Color.accentGreen : Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func controlLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.secondaryText)
    }

    private func textBinding(for layer: Binding<ScrapbookLayer>) -> Binding<String> {
        Binding(
            get: { layer.wrappedValue.text ?? layer.wrappedValue.title },
            set: { value in
                layer.wrappedValue.text = value
                layer.wrappedValue.title = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? layer.wrappedValue.kind.title : value
            }
        )
    }

    private func scaleBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.scale },
            set: { layer.wrappedValue.scale = min(max($0, 0.35), 2.4) }
        )
    }

    private func rotationBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.rotation },
            set: { layer.wrappedValue.rotation = min(max($0, -45), 45) }
        )
    }

    private func fontSizeBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.fontSize ?? 32 },
            set: { layer.wrappedValue.fontSize = min(max($0, 20), 72) }
        )
    }

    private func cornerRadiusBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.cornerRadius ?? 0 },
            set: { layer.wrappedValue.cornerRadius = min(max($0, 0), 72) }
        )
    }

    private func borderWidthBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.borderWidth ?? 4 },
            set: { layer.wrappedValue.borderWidth = min(max($0, 1), 24) }
        )
    }

    private func textColorBinding(for layer: Binding<ScrapbookLayer>) -> Binding<String> {
        Binding(
            get: { layer.wrappedValue.textColorHex ?? "#46525A" },
            set: { layer.wrappedValue.textColorHex = $0 }
        )
    }

    private func backgroundColorBinding(for layer: Binding<ScrapbookLayer>) -> Binding<String> {
        Binding(
            get: { layer.wrappedValue.backgroundColorHex ?? "#EEF7F3" },
            set: { layer.wrappedValue.backgroundColorHex = $0 }
        )
    }

    private func borderColorBinding(for layer: Binding<ScrapbookLayer>) -> Binding<String> {
        Binding(
            get: { layer.wrappedValue.borderColorHex ?? "#D7DDEA" },
            set: { layer.wrappedValue.borderColorHex = $0 }
        )
    }

    private func imageCropXBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.imageCropX },
            set: { layer.wrappedValue.imageCropX = min(max($0, 0), 1) }
        )
    }

    private func imageCropYBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.imageCropY },
            set: { layer.wrappedValue.imageCropY = min(max($0, 0), 1) }
        )
    }

    private func imageCropScaleBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.imageCropScale },
            set: { layer.wrappedValue.imageCropScale = min(max($0, 1), 3) }
        )
    }

    private func imageBorderWidthBinding(for layer: Binding<ScrapbookLayer>) -> Binding<Double> {
        Binding(
            get: { layer.wrappedValue.borderWidth ?? 0 },
            set: { layer.wrappedValue.borderWidth = min(max($0, 0), 28) }
        )
    }

    private func addTextLayer() {
        let layer = ScrapbookLayer(
            kind: .text,
            title: "新文字",
            text: "新文字",
            x: layout.canvasWidth / 2,
            y: layout.canvasHeight / 2,
            width: 520,
            height: 130,
            fontName: "rounded",
            fontSize: 46,
            textColorHex: "#46525A"
        )
        layout.layers.append(layer)
        selectedLayerID = layer.id
    }

    private func addStickerLayer() {
        let layer = ScrapbookLayer(
            kind: .sticker,
            title: "贴纸",
            text: "贴纸",
            x: layout.canvasWidth / 2,
            y: layout.canvasHeight * 0.78,
            width: 260,
            height: 72,
            rotation: -4,
            fontName: "rounded",
            fontSize: 30,
            textColorHex: "#597469",
            backgroundColorHex: "#EEF7F3",
            cornerRadius: 36
        )
        layout.layers.append(layer)
        selectedLayerID = layer.id
    }

    private func addShapeLayer() {
        let layer = ScrapbookLayer(
            kind: .shape,
            title: "色块",
            x: layout.canvasWidth / 2,
            y: layout.canvasHeight * 0.64,
            width: 420,
            height: 180,
            backgroundColorHex: "#F2EEF8",
            cornerRadius: 28,
            shadowOpacity: 0.08
        )
        layout.layers.append(layer)
        selectedLayerID = layer.id
    }

    private func addBorderLayer() {
        let preset = ScrapbookStyleCatalog.borderPresets.first
        let layer = ScrapbookLayer(
            kind: .border,
            title: preset?.title ?? "花边",
            x: layout.canvasWidth / 2,
            y: layout.canvasHeight / 2,
            width: max(240, layout.canvasWidth - 90),
            height: max(320, layout.canvasHeight - 130),
            borderColorHex: preset?.borderColorHex ?? "#D7DDEA",
            borderWidth: preset?.borderWidth ?? 8,
            cornerRadius: preset?.cornerRadius ?? 38,
            shadowOpacity: preset?.shadowOpacity ?? 0
        )
        layout.layers.append(layer)
        selectedLayerID = layer.id
    }

    private func addSelectedImageLayer() {
        guard let attachment = selectedImageAttachment else {
            statusText = "先选择图片素材"
            return
        }

        let layer = ScrapbookLayer(
            kind: .image,
            title: attachment.displayName,
            attachmentPath: attachment.relativePath,
            x: layout.canvasWidth / 2,
            y: layout.canvasHeight * 0.46,
            width: min(760, layout.canvasWidth * 0.72),
            height: min(620, layout.canvasHeight * 0.44),
            borderColorHex: "#FFFFFF",
            borderWidth: 0,
            cornerRadius: 24,
            shadowOpacity: 0.12
        )
        layout.layers.append(layer)
        selectedLayerID = layer.id
        statusText = "已添加图片"
    }

    private func moveSelectedLayerForward() {
        guard let index = selectedLayerIndex, index < layout.layers.count - 1 else {
            return
        }
        layout.layers.swapAt(index, index + 1)
    }

    private func moveSelectedLayerBackward() {
        guard let index = selectedLayerIndex, index > 0 else {
            return
        }
        layout.layers.swapAt(index, index - 1)
    }

    private func duplicateSelectedLayer() {
        guard let index = selectedLayerIndex else {
            return
        }
        var copy = layout.layers[index]
        copy.id = UUID()
        copy.x += 44
        copy.y += 44
        copy.title = "\(copy.title) 副本"
        layout.layers.insert(copy, at: index + 1)
        selectedLayerID = copy.id
    }

    private func deleteSelectedLayer() {
        guard let index = selectedLayerIndex else {
            return
        }
        layout.layers.remove(at: index)
        selectedLayerID = layout.layers.indices.contains(index)
            ? layout.layers[index].id
            : layout.layers.last?.id
    }

    private func saveLayout() {
        guard store.updateScrapbookLayout(layout, for: memo) else {
            statusText = "保存失败"
            return
        }
        statusText = "已保存"
    }

    private func exportLayout() {
        guard let export = try? store.exportScrapbookLayoutForSharing(
            layout,
            title: MemoReferenceParser.title(for: memo),
            for: memo,
            format: .png
        ) else {
            statusText = "导出失败"
            return
        }
        exportedDocument = ExportedDocument(url: export.url)
        statusText = "已导出 \(export.attachment.displayName)"
    }

    private func exportPDF() {
        guard let export = try? store.exportScrapbookLayoutForSharing(
            layout,
            title: MemoReferenceParser.title(for: memo),
            for: memo,
            format: .pdf
        ) else {
            statusText = "PDF导出失败"
            return
        }
        exportedDocument = ExportedDocument(url: export.url)
        statusText = "已导出 \(export.attachment.displayName)"
    }

    private func color(hex: String?) -> Color? {
        guard let hex = hex else { return nil }
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

private struct EditableScrapbookLayerView: View {
    @Binding var layer: ScrapbookLayer

    let canvasScale: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var dragBase: ScrapbookLayer?
    @State private var scaleBase: Double?
    @State private var rotationBase: Double?

    var body: some View {
        layerContent
            .frame(
                width: layer.width * canvasScale,
                height: layer.height * canvasScale
            )
            .scaleEffect(layer.scale)
            .rotationEffect(.degrees(layer.rotation))
            .position(x: layer.x * canvasScale, y: layer.y * canvasScale)
            .overlay(selectionOverlay)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .gesture(moveGesture)
            .simultaneousGesture(scaleGesture)
            .simultaneousGesture(rotationGesture)
    }

    @ViewBuilder
    private var layerContent: some View {
        switch layer.kind {
        case .image:
            if let attachmentPath = layer.attachmentPath,
               let url = SharedAttachmentStore.url(for: attachment(relativePath: attachmentPath)),
               let image = UIImage(contentsOfFile: url.path) {
                GeometryReader { proxy in
                    let previewImage = ScrapbookImageFilterRenderer.image(image, applying: layer.imageFilter)
                    let drawRect = imageDrawRect(
                        imageSize: previewImage.size,
                        viewSize: proxy.size,
                        cropX: layer.imageCropX,
                        cropY: layer.imageCropY,
                        cropScale: layer.imageCropScale
                    )

                    Image(uiImage: previewImage)
                        .resizable()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .offset(x: drawRect.minX, y: drawRect.minY)
                }
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0) * canvasScale, style: .continuous))
                .overlay(imageBorderOverlay)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.greenTint)
                    .overlay(Image(systemName: "photo").foregroundStyle(Color.accentGreen))
            }
        case .text:
            Text(layer.text ?? layer.title)
                .font(scrapbookFont(for: layer, size: max(8, CGFloat(layer.fontSize ?? 32) * canvasScale)))
                .foregroundStyle(color(hex: layer.textColorHex) ?? Color.primaryText)
                .lineLimit(4)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.center)
        case .sticker:
            Text(layer.text ?? layer.title)
                .font(scrapbookFont(for: layer, size: max(8, CGFloat(layer.fontSize ?? 32) * canvasScale)))
                .foregroundStyle(color(hex: layer.textColorHex) ?? Color.accentGreen)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color(hex: layer.backgroundColorHex) ?? Color.greenTint)
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 28) * canvasScale, style: .continuous))
        case .border:
            RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0) * canvasScale, style: .continuous)
                .stroke(color(hex: layer.borderColorHex) ?? Color.border, lineWidth: max(1, CGFloat(layer.borderWidth ?? 4) * canvasScale))
        case .shape:
            RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0) * canvasScale, style: .continuous)
                .fill(color(hex: layer.backgroundColorHex) ?? Color.greenTint)
                .shadow(color: Color.black.opacity(layer.shadowOpacity ?? 0), radius: 8, y: 4)
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentGreen, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.accentGreen)
                        .frame(width: 12, height: 12)
                        .offset(x: 6, y: -6)
                }
        }
    }

    @ViewBuilder
    private var imageBorderOverlay: some View {
        if layer.kind == .image, let width = layer.borderWidth, width > 0 {
            RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0) * canvasScale, style: .continuous)
                .stroke(color(hex: layer.borderColorHex) ?? Color.white, lineWidth: CGFloat(width) * canvasScale)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragBase == nil {
                    dragBase = layer
                    onSelect()
                }
                guard let dragBase = dragBase else { return }
                layer.x = dragBase.x + value.translation.width / canvasScale
                layer.y = dragBase.y + value.translation.height / canvasScale
            }
            .onEnded { _ in
                dragBase = nil
            }
    }

    private var scaleGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if scaleBase == nil {
                    scaleBase = layer.scale
                    onSelect()
                }
                let base = scaleBase ?? layer.scale
                layer.scale = min(max(base * value, 0.35), 2.4)
            }
            .onEnded { _ in
                scaleBase = nil
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                if rotationBase == nil {
                    rotationBase = layer.rotation
                    onSelect()
                }
                layer.rotation = (rotationBase ?? layer.rotation) + value.degrees
            }
            .onEnded { _ in
                rotationBase = nil
            }
    }

    private func attachment(relativePath: String) -> SharedAttachment {
        SharedAttachment(
            id: relativePath,
            filename: relativePath,
            relativePath: relativePath,
            typeIdentifier: UTType.image.identifier,
            byteCount: 0
        )
    }

    private func imageDrawRect(
        imageSize: CGSize,
        viewSize: CGSize,
        cropX: Double,
        cropY: Double,
        cropScale: Double
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }

        let cropScale = min(max(CGFloat(cropScale.isFinite ? cropScale : 1), 1), 3)
        let cropX = min(max(CGFloat(cropX.isFinite ? cropX : 0.5), 0), 1)
        let cropY = min(max(CGFloat(cropY.isFinite ? cropY : 0.5), 0), 1)
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height) * cropScale
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let maxOffsetX = max(0, drawSize.width - viewSize.width)
        let maxOffsetY = max(0, drawSize.height - viewSize.height)

        return CGRect(
            x: -maxOffsetX * cropX,
            y: -maxOffsetY * cropY,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private func color(hex: String?) -> Color? {
        guard let hex = hex else { return nil }
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

    private func scrapbookFont(for layer: ScrapbookLayer, size: CGFloat) -> Font {
        switch ScrapbookStyleCatalog.normalizedFontKey(layer.fontName) {
        case "serif":
            return .system(size: size, weight: .semibold, design: .serif)
        case "mono":
            return .system(size: size, weight: .semibold, design: .monospaced)
        case "handwritten":
            return .system(size: size, weight: .medium, design: .rounded).italic()
        case "caption":
            return .system(size: size, weight: .medium, design: .rounded)
        default:
            return .system(size: size, weight: .semibold, design: .rounded)
        }
    }
}

private extension ScrapbookLayer.Kind {
    var title: String {
        switch self {
        case .image: return "图片"
        case .text: return "文字"
        case .sticker: return "贴纸"
        case .border: return "边框"
        case .shape: return "色块"
        }
    }
}
