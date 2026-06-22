import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ScrapbookEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let memo: Memo
    @State private var layout: ScrapbookPageLayout
    @State private var selectedLayerID: UUID?
    @State private var statusText: String?

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
            HStack(spacing: 8) {
                addLayerButton(systemImage: "textformat", title: "文字") {
                    addTextLayer()
                }
                addLayerButton(systemImage: "seal", title: "贴纸") {
                    addStickerLayer()
                }
                addLayerButton(systemImage: "square.fill", title: "色块") {
                    addShapeLayer()
                }

                Spacer(minLength: 8)

                if let statusText = statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }

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

            VStack(alignment: .leading, spacing: 8) {
                Slider(value: scaleBinding(for: layer), in: 0.35...2.4)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("缩放")

                Slider(value: rotationBinding(for: layer), in: -45...45)
                    .tint(Color.accentGreen)
                    .accessibilityLabel("旋转")
            }
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0) * canvasScale, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.greenTint)
                    .overlay(Image(systemName: "photo").foregroundStyle(Color.accentGreen))
            }
        case .text:
            Text(layer.text ?? layer.title)
                .font(.system(size: max(8, CGFloat(layer.fontSize ?? 32) * canvasScale), weight: .semibold))
                .foregroundStyle(color(hex: layer.textColorHex) ?? Color.primaryText)
                .lineLimit(4)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.center)
        case .sticker:
            Text(layer.text ?? layer.title)
                .font(.system(size: max(8, CGFloat(layer.fontSize ?? 32) * canvasScale), weight: .semibold))
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
