import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct QuickCaptureView: View {
    @EnvironmentObject private var store: MemoStore
    @AppStorage("some.quickDraft") private var text = ""
    @State private var statusText: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingFileImporter = false
    @State private var isImportingMedia = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(minHeight: 118)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)

                if text.isEmpty {
                    Text("写下一条闪念... 用 #项目/子类 归类")
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
            }

            if !tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagSuggestions, id: \.self) { tag in
                            Button {
                                applyTag(tag)
                            } label: {
                                Label(tag, systemImage: "number")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.primaryText)
                            .background(Color.subtleSurface)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            if let firstURL = detectedURLs.first {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(Color.accentGreen)
                    Text(LinkExtractor.displayText(for: firstURL))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(detectedURLs.count > 1 ? "+\(detectedURLs.count - 1)" : "链接")
                        .foregroundStyle(Color.tertiaryText)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let statusText = statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            HStack(spacing: 10) {
                Button {
                    text = ""
                    statusText = nil
                    isFocused = true
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.subtleSurface)
                .clipShape(Circle())
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0.35 : 1)
                .accessibilityLabel("清空")

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 12,
                    matching: .any(of: [.images, .videos])
                ) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.subtleSurface)
                .clipShape(Circle())
                .disabled(isImportingMedia)
                .accessibilityLabel("导入照片或视频")

                Button {
                    isShowingFileImporter = true
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.subtleSurface)
                .clipShape(Circle())
                .disabled(isImportingMedia)
                .accessibilityLabel("导入文件")

                if isImportingMedia {
                    ProgressView()
                        .tint(Color.accentGreen)
                        .frame(width: 28, height: 34)
                }

                Spacer()

                Text("草稿自动保存")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)

                Button {
                    submit()
                } label: {
                    Label("保存并继续", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 112)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(trimmedText.isEmpty ? Color.disabled : Color.accentGreen)
                .clipShape(Capsule())
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentGreen.opacity(0.65) : Color.border, lineWidth: 1)
        )
        .task {
            isFocused = true
        }
        .onChange(of: selectedPhotoItems) { items in
            importPhotoItems(items)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var detectedURLs: [URL] {
        LinkExtractor.urls(in: text)
    }

    private var tagSuggestions: [String] {
        guard let query = currentTagQuery else { return [] }

        return Array(store.activeTags
            .filter { tag in
                query.isEmpty || tag.localizedCaseInsensitiveContains(query)
            }
            .prefix(5))
    }

    private var currentTagQuery: String? {
        guard let tail = text.split(whereSeparator: { $0.isWhitespace }).last,
              tail.hasPrefix("#") else {
            return nil
        }

        return String(tail.dropFirst())
    }

    private var importableContentTypes: [UTType] {
        [.image, .movie, .audio, .pdf, .text, .data]
    }

    private func submit() {
        if store.addMemo(text: text) != nil {
            text = ""
            statusText = "已保存"
        } else {
            statusText = "保存失败，草稿已保留。"
        }
        isFocused = true
    }

    private func applyTag(_ tag: String) {
        guard let query = currentTagQuery,
              let range = text.range(of: "#\(query)", options: .backwards) else {
            text += text.isEmpty || text.hasSuffix(" ") ? "#\(tag) " : " #\(tag) "
            isFocused = true
            return
        }

        text.replaceSubrange(range, with: "#\(tag) ")
        isFocused = true
    }

    private func importPhotoItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isImportingMedia = true
        statusText = "正在导入素材..."

        Task {
            var importedCount = 0
            var failedCount = 0

            for item in items {
                let type = preferredContentType(for: item)

                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        failedCount += 1
                        continue
                    }

                    let attachment = try SharedAttachmentStore.save(
                        data: data,
                        suggestedFilename: importedFilename(prefix: filenamePrefix(for: type), type: type),
                        typeIdentifier: type.identifier
                    )
                    let imported = await MainActor.run {
                        store.addAttachmentMemo(attachment, note: importNote(for: type)) != nil
                    }
                    importedCount += imported ? 1 : 0
                    failedCount += imported ? 0 : 1
                } catch {
                    failedCount += 1
                }
            }

            await MainActor.run {
                selectedPhotoItems = []
                isImportingMedia = false
                statusText = importStatus(imported: importedCount, failed: failedCount)
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }

            isImportingMedia = true
            statusText = "正在导入素材..."

            Task {
                var importedCount = 0
                var failedCount = 0

                for url in urls {
                    do {
                        let attachment = try SharedAttachmentStore.save(
                            fileAt: url,
                            suggestedFilename: nil,
                            typeIdentifier: nil
                        )
                        let type = UTType(attachment.typeIdentifier) ?? .data
                        let imported = await MainActor.run {
                            store.addAttachmentMemo(attachment, note: importNote(for: type)) != nil
                        }
                        importedCount += imported ? 1 : 0
                        failedCount += imported ? 0 : 1
                    } catch {
                        failedCount += 1
                    }
                }

                await MainActor.run {
                    isImportingMedia = false
                    statusText = importStatus(imported: importedCount, failed: failedCount)
                }
            }
        } catch {
            statusText = "导入失败：\(error.localizedDescription)"
        }
    }

    private func preferredContentType(for item: PhotosPickerItem) -> UTType {
        if let type = item.supportedContentTypes.first(where: { $0.conforms(to: .movie) }) {
            return type
        }

        if let type = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) {
            return type
        }

        return item.supportedContentTypes.first ?? .data
    }

    private func filenamePrefix(for type: UTType) -> String {
        if type.conforms(to: .movie) {
            return "video"
        }

        if type.conforms(to: .image) {
            return "photo"
        }

        return "asset"
    }

    private func importNote(for type: UTType) -> String {
        if type.conforms(to: .movie) {
            return "导入视频"
        }

        if type.conforms(to: .audio) {
            return "导入音频"
        }

        if type.conforms(to: .image) {
            return "导入图片"
        }

        return "导入文件"
    }

    private func importedFilename(prefix: String, type: UTType) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let suffix = String(UUID().uuidString.prefix(8))
        let basename = "\(prefix)-\(timestamp)-\(suffix)"

        guard let pathExtension = type.preferredFilenameExtension else {
            return basename
        }

        return "\(basename).\(pathExtension)"
    }

    private func importStatus(imported: Int, failed: Int) -> String {
        if imported > 0, failed > 0 {
            return "已导入 \(imported) 个素材，\(failed) 个失败。"
        }

        if imported > 0 {
            return "已导入 \(imported) 个素材"
        }

        return failed > 0 ? "没有导入素材，\(failed) 个失败。" : "没有导入素材"
    }
}
