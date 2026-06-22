import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImageEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let attachment: SharedAttachment

    @State private var title: String
    @State private var filter: ImageEditRecipe.Filter = .fresh
    @State private var cropPreset: ImageEditRecipe.CropPreset = .original
    @State private var borderWidth: Double = 18
    @State private var borderColorHex = "#FFFFFF"
    @State private var caption = ""
    @State private var sticker = ""
    @State private var note = ""
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
        .onAppear(perform: refreshPreview)
        .onChange(of: filter) { _ in refreshPreview() }
        .onChange(of: cropPreset) { _ in refreshPreview() }
        .onChange(of: borderWidth) { _ in refreshPreview() }
        .onChange(of: borderColorHex) { _ in refreshPreview() }
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

                if let previewImage = previewImage {
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

            Picker("比例", selection: $cropPreset) {
                ForEach(ImageEditRecipe.CropPreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

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
            cropPreset: cropPreset,
            border: ImageEditRecipe.Border(colorHex: borderColorHex, width: borderWidth),
            textOverlays: caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [
                ImageEditRecipe.TextOverlay(text: caption.trimmingCharacters(in: .whitespacesAndNewlines))
            ],
            stickerOverlays: sticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [
                ImageEditRecipe.StickerOverlay(text: sticker.trimmingCharacters(in: .whitespacesAndNewlines))
            ]
        )
    }

    private var borderSwatches: [String] {
        ["#FFFFFF", "#F8DCE8", "#DDEBF7", "#E8F3EE", "#1D222B"]
    }

    private func refreshPreview() {
        guard let sourceImage = sourceImage(),
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

    private func sourceImage() -> UIImage? {
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
