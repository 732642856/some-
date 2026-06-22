import AVFoundation
import PhotosUI
import SwiftUI
import LinkPresentation
import UIKit
import UniformTypeIdentifiers

struct QuickCaptureView: View {
    @EnvironmentObject private var store: MemoStore
    @AppStorage("some.quickDraft") private var text = ""
    @State private var statusText: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var cameraCaptureMode: QuickCameraCaptureMode = .photo
    @State private var isShowingFileImporter = false
    @State private var isImportingMedia = false
    @State private var isClippingWebPage = false
    @State private var pendingWebClip: ExtractedWebClip?
    @State private var pendingClipFragments: [ClipFragment] = []
    @State private var selectedClipFragmentIDs: Set<String> = []
    @StateObject private var audioRecorder = QuickAudioRecorder()
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

            if let pendingWebClip {
                webClipSelectionView(pendingWebClip)
            }

            if let statusText = statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            VStack(spacing: 10) {
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
                    .disabled(isImportingMedia || audioRecorder.isRecording)
                    .accessibilityLabel("导入照片或视频")

                    Button {
                        guard canUseCamera else {
                            statusText = "当前设备不可用相机。"
                            return
                        }
                        cameraCaptureMode = .photo
                        isShowingCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .background(Color.subtleSurface)
                    .clipShape(Circle())
                    .disabled(isImportingMedia || audioRecorder.isRecording || !canUseCamera)
                    .opacity(canUseCamera ? 1 : 0.35)
                    .accessibilityLabel("拍照导入")

                    Button {
                        guard canRecordVideo else {
                            statusText = "当前设备不可用视频拍摄。"
                            return
                        }
                        cameraCaptureMode = .video
                        isShowingCamera = true
                    } label: {
                        Image(systemName: "video")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .background(Color.subtleSurface)
                    .clipShape(Circle())
                    .disabled(isImportingMedia || audioRecorder.isRecording || !canRecordVideo)
                    .opacity(canRecordVideo ? 1 : 0.35)
                    .accessibilityLabel("拍视频导入")

                    Button {
                        toggleRecording()
                    } label: {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(audioRecorder.isRecording ? Color.white : Color.secondaryText)
                    .background(audioRecorder.isRecording ? Color.accentGold : Color.subtleSurface)
                    .clipShape(Circle())
                    .disabled(isImportingMedia || isClippingWebPage)
                    .accessibilityLabel(audioRecorder.isRecording ? "停止录音" : "开始录音")

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
                    .disabled(isImportingMedia || audioRecorder.isRecording)
                    .accessibilityLabel("导入文件")

                    Button {
                        clipFirstURL()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .background(Color.subtleSurface)
                    .clipShape(Circle())
                    .disabled(isClippingWebPage || detectedURLs.isEmpty || audioRecorder.isRecording)
                    .opacity(detectedURLs.isEmpty ? 0.35 : 1)
                    .accessibilityLabel("摘录网页")

                    if isImportingMedia {
                        ProgressView()
                            .tint(Color.accentGreen)
                            .frame(width: 28, height: 34)
                    }

                    if isClippingWebPage {
                        ProgressView()
                            .tint(Color.accentGreen)
                            .frame(width: 28, height: 34)
                    }

                    Spacer(minLength: 0)
                }

                if audioRecorder.isRecording {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                        Text("正在录音 \(audioRecorder.elapsedText)")
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentGold)
                }

                HStack {
                    Text("草稿自动保存")
                        .font(.caption)
                        .foregroundStyle(Color.tertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 12)

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
                    .disabled(trimmedText.isEmpty || audioRecorder.isRecording)
                }
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
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView(
                mode: cameraCaptureMode,
                onImage: { image in
                    isShowingCamera = false
                    importCapturedImage(image)
                },
                onVideo: { url in
                    isShowingCamera = false
                    importCapturedVideo(url)
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
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

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canRecordVideo: Bool {
        UIImagePickerController.availableMediaTypes(for: .camera)?.contains(UTType.movie.identifier) == true
    }

    private func submit() {
        if store.addMemo(text: text) != nil {
            text = ""
            statusText = "已保存"
            clearPendingWebClip()
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
                    let note = await importNote(for: attachment, type: type, data: data)
                    let imported = await MainActor.run {
                        store.addAttachmentMemo(attachment, note: note) != nil
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

    private func importCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            statusText = "拍照导入失败：无法读取图片。"
            return
        }

        isImportingMedia = true
        statusText = "正在导入拍摄图片..."

        Task {
            do {
                let attachment = try SharedAttachmentStore.save(
                    data: data,
                    suggestedFilename: importedFilename(prefix: "camera", type: .jpeg),
                    typeIdentifier: UTType.jpeg.identifier
                )
                let note = await importNote(
                    for: attachment,
                    type: .jpeg,
                    data: data,
                    fallbackNote: "拍照导入"
                )
                let imported = await MainActor.run {
                    store.addAttachmentMemo(attachment, note: note) != nil
                }
                await MainActor.run {
                    isImportingMedia = false
                    statusText = importStatus(imported: imported ? 1 : 0, failed: imported ? 0 : 1)
                }
            } catch {
                await MainActor.run {
                    isImportingMedia = false
                    statusText = "拍照导入失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func importCapturedVideo(_ url: URL) {
        let type = UTType(filenameExtension: url.pathExtension) ?? .movie

        isImportingMedia = true
        statusText = "正在导入拍摄视频..."

        Task {
            do {
                let attachment = try SharedAttachmentStore.save(
                    fileAt: url,
                    suggestedFilename: importedFilename(prefix: "camera-video", type: type),
                    typeIdentifier: type.identifier
                )
                let imported = await MainActor.run {
                    store.addAttachmentMemo(attachment, note: "拍摄视频") != nil
                }
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    isImportingMedia = false
                    statusText = importStatus(imported: imported ? 1 : 0, failed: imported ? 0 : 1)
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    isImportingMedia = false
                    statusText = "拍摄视频导入失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                try await audioRecorder.start()
                await MainActor.run {
                    statusText = "正在录音..."
                }
            } catch {
                await MainActor.run {
                    statusText = "录音失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func stopRecording() {
        guard let url = audioRecorder.stop() else {
            statusText = "录音失败：没有可保存的音频。"
            return
        }

        isImportingMedia = true
        statusText = "正在保存录音..."

        Task {
            do {
                let attachment = try SharedAttachmentStore.save(
                    fileAt: url,
                    suggestedFilename: importedFilename(prefix: "recording", type: .mpeg4Audio),
                    typeIdentifier: UTType.mpeg4Audio.identifier
                )
                let imported = await MainActor.run {
                    store.addAttachmentMemo(attachment, note: "录音") != nil
                }
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    isImportingMedia = false
                    statusText = importStatus(imported: imported ? 1 : 0, failed: imported ? 0 : 1)
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    isImportingMedia = false
                    statusText = "录音保存失败：\(error.localizedDescription)"
                }
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
                        let data = type.conforms(to: .image) ? SharedAttachmentStore.data(for: attachment) : nil
                        let note = await importNote(for: attachment, type: type, data: data)
                        let imported = await MainActor.run {
                            store.addAttachmentMemo(attachment, note: note) != nil
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

    private func importNote(
        for attachment: SharedAttachment,
        type: UTType,
        data: Data?,
        fallbackNote: String? = nil
    ) async -> String {
        guard type.conforms(to: .image), let data = data else {
            return fallbackNote ?? importNote(for: type)
        }

        let recognizedLines = await ImageTextRecognizer.recognizeText(in: data)
        return ImageTextRecognizer.memoText(for: attachment, recognizedLines: recognizedLines)
            ?? fallbackNote
            ?? importNote(for: type)
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

    private func clipFirstURL() {
        guard let url = detectedURLs.first else { return }

        isClippingWebPage = true
        statusText = "正在摘录网页..."
        clearPendingWebClip()

        Task {
            let clip = await RemoteWebClipFetcher.clip(from: url)
            await MainActor.run {
                isClippingWebPage = false
                let fragments = clipFragments(for: clip)
                if fragments.isEmpty {
                    saveWebClip(clip, selectedFragments: [])
                } else {
                    pendingWebClip = clip
                    pendingClipFragments = fragments
                    selectedClipFragmentIDs = Set(fragments.prefix(4).map(\.id))
                    statusText = "已提取网页重点，选择片段后保存。"
                }
            }
        }
    }

    private func clipFragments(for clip: ExtractedWebClip) -> [ClipFragment] {
        let webText = LinkExtractor.webClipText(
            title: clip.title ?? LinkExtractor.displayText(for: clip.url),
            url: clip.url,
            summary: clip.summary,
            highlights: clip.highlights
        )
        let combinedText = [webText, text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return ClipFragmentExtractor.fragments(in: combinedText)
    }

    @ViewBuilder
    private func webClipSelectionView(_ clip: ExtractedWebClip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .foregroundStyle(Color.accentGreen)
                Text(clip.title ?? LinkExtractor.displayText(for: clip.url))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(selectedClipFragmentIDs.count)/\(pendingClipFragments.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.tertiaryText)
            }

            ForEach(pendingClipFragments) { fragment in
                Button {
                    toggleClipFragment(fragment)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedClipFragmentIDs.contains(fragment.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedClipFragmentIDs.contains(fragment.id) ? Color.accentGreen : Color.tertiaryText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fragment.source == .web ? "网页" : "OCR")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(fragment.source == .web ? Color.accentGreen : Color.accentGold)
                            Text(fragment.text)
                                .font(.caption)
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    saveWebClip(clip, selectedFragments: selectedClipFragments())
                } label: {
                    Label("保存摘录", systemImage: "tray.and.arrow.down.fill")
                        .font(.caption.weight(.semibold))
                        .frame(height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .background(selectedClipFragmentIDs.isEmpty ? Color.disabled : Color.accentGreen)
                .clipShape(Capsule())
                .disabled(selectedClipFragmentIDs.isEmpty)

                Button {
                    clearPendingWebClip()
                    statusText = "已取消网页摘录。"
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.surface)
                .clipShape(Circle())

                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func toggleClipFragment(_ fragment: ClipFragment) {
        if selectedClipFragmentIDs.contains(fragment.id) {
            selectedClipFragmentIDs.remove(fragment.id)
        } else {
            selectedClipFragmentIDs.insert(fragment.id)
        }
    }

    private func selectedClipFragments() -> [ClipFragment] {
        pendingClipFragments.filter { selectedClipFragmentIDs.contains($0.id) }
    }

    private func saveWebClip(_ clip: ExtractedWebClip, selectedFragments: [ClipFragment]) {
        let title = clip.title ?? LinkExtractor.displayText(for: clip.url)
        let content = ClipFragmentExtractor.selectedWebClipContent(
            title: title,
            summary: clip.summary,
            fragments: selectedFragments
        )
        let clipText = LinkExtractor.webClipText(
            title: title,
            url: clip.url,
            summary: content.summary,
            highlights: content.highlights
        )
        let memoText = [clipText, content.mergedFragmentsText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let saved = store.addMemo(text: memoText) != nil
        if saved {
            clearPendingWebClip()
        }
        statusText = saved ? "已保存网页摘录" : "网页摘录保存失败。"
    }

    private func clearPendingWebClip() {
        pendingWebClip = nil
        pendingClipFragments = []
        selectedClipFragmentIDs = []
    }

}

private enum QuickCameraCaptureMode {
    case photo
    case video
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let mode: QuickCameraCaptureMode
    let onImage: (UIImage) -> Void
    let onVideo: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        switch mode {
        case .photo:
            picker.cameraCaptureMode = .photo
        case .video:
            picker.mediaTypes = [UTType.movie.identifier]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeHigh
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onVideo: onVideo, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let onVideo: (URL) -> Void
        private let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onVideo: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onVideo = onVideo
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaURL = info[.mediaURL] as? URL {
                onVideo(mediaURL)
                return
            }

            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }

            onImage(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

@MainActor
private final class QuickAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedText = "00:00"

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?
    private var startedAt: Date?

    func start() async throws {
        guard !isRecording else { return }

        let granted = await requestPermission()
        guard granted else {
            throw RecordingError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = temporaryRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()
        guard recorder.record() else {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            throw RecordingError.startFailed
        }

        self.recorder = recorder
        recordingURL = url
        startedAt = Date()
        elapsedText = "00:00"
        isRecording = true
        startTimer()
    }

    func stop() -> URL? {
        guard isRecording else { return nil }

        recorder?.stop()
        stopTimer()
        recorder = nil
        startedAt = nil
        isRecording = false
        elapsedText = "00:00"

        let url = recordingURL
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return url
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            _ = self.stop()
        }
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedText()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedText() {
        guard let startedAt = startedAt else {
            elapsedText = "00:00"
            return
        }

        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
        elapsedText = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func temporaryRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("some-recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }

    enum RecordingError: LocalizedError {
        case permissionDenied
        case startFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "没有麦克风权限。"
            case .startFailed:
                return "录音没有成功开始。"
            }
        }
    }
}

private enum RemoteWebClipFetcher {
    static func clip(from url: URL) async -> ExtractedWebClip {
        do {
            let html = try await fetchHTML(from: url)
            return WebClipExtractor.clip(from: url, html: html)
        } catch {
            if let metadataTitle = try? await metadataTitle(for: url) {
                return WebClipExtractor.fallbackClip(for: url, title: metadataTitle)
            }

            return WebClipExtractor.fallbackClip(for: url)
        }
    }

    private static func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let response = response as? HTTPURLResponse,
           !(200..<400).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private static func metadataTitle(for url: URL) async throws -> String? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { [provider] metadata, error in
                _ = provider
                if let metadata = metadata {
                    continuation.resume(returning: metadata.title)
                } else {
                    continuation.resume(throwing: error ?? URLError(.cannotParseResponse))
                }
            }
        }
    }
}
