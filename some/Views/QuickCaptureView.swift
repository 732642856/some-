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
    @State private var isShowingFileImporter = false
    @State private var isImportingMedia = false
    @State private var isClippingWebPage = false
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
                    .disabled(isImportingMedia)
                    .accessibilityLabel("导入照片或视频")

                    Button {
                        guard canUseCamera else {
                            statusText = "当前设备不可用相机。"
                            return
                        }
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
                onImage: { image in
                    isShowingCamera = false
                    importCapturedImage(image)
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

        Task {
            let clip = await WebClipExtractor.clip(from: url)
            await MainActor.run {
                let saved = store.addWebClip(
                    url: clip.url,
                    title: clip.title,
                    summary: clip.summary,
                    highlights: clip.highlights
                ) != nil
                isClippingWebPage = false
                statusText = saved ? "已保存网页摘录" : "网页摘录保存失败。"
            }
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
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
        recorder.record()

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

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        _ = stop()
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

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "没有麦克风权限。"
            }
        }
    }
}

private struct ExtractedWebClip {
    let url: URL
    let title: String?
    let summary: String?
    let highlights: [String]
}

private enum WebClipExtractor {
    static func clip(from url: URL) async -> ExtractedWebClip {
        do {
            let html = try await fetchHTML(from: url)
            let paragraphs = paragraphHighlights(in: html)
            let title = firstNonEmpty(
                metaContent(named: "og:title", in: html),
                metaContent(named: "twitter:title", in: html),
                titleTag(in: html),
                LinkExtractor.displayText(for: url)
            )
            let summary = firstNonEmpty(
                metaContent(named: "description", in: html),
                metaContent(named: "og:description", in: html),
                metaContent(named: "twitter:description", in: html),
                paragraphs.first
            )
            let highlights = paragraphs
                .filter { $0 != summary }
                .prefix(4)
                .map { $0 }
            return ExtractedWebClip(url: url, title: title, summary: summary, highlights: Array(highlights))
        } catch {
            if let metadataTitle = try? await metadataTitle(for: url) {
                return ExtractedWebClip(
                    url: url,
                    title: firstNonEmpty(metadataTitle, LinkExtractor.displayText(for: url)),
                    summary: nil,
                    highlights: []
                )
            }

            return ExtractedWebClip(
                url: url,
                title: LinkExtractor.displayText(for: url),
                summary: nil,
                highlights: []
            )
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

    private static func titleTag(in html: String) -> String? {
        firstMatch(pattern: #"<title[^>]*>(.*?)</title>"#, in: html)
    }

    private static func metaContent(named name: String, in html: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta[^>]*(?:name|property)\s*=\s*["']\#(escapedName)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#,
            #"<meta[^>]*content\s*=\s*["']([^"']*)["'][^>]*(?:name|property)\s*=\s*["']\#(escapedName)["'][^>]*>"#
        ]

        for pattern in patterns {
            if let value = firstMatch(pattern: pattern, in: html) {
                return value
            }
        }

        return nil
    }

    private static func paragraphHighlights(in html: String) -> [String] {
        matches(pattern: #"<p[^>]*>(.*?)</p>"#, in: html)
            .map(cleanHTML)
            .filter { $0.count >= 24 }
            .reduce(into: [String]()) { result, paragraph in
                guard !result.contains(paragraph), result.count < 5 else { return }
                result.append(paragraph)
            }
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        matches(pattern: pattern, in: text).first.map(cleanHTML)
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).compactMap { result in
            guard result.numberOfRanges >= 2 else { return nil }
            return nsText.substring(with: result.range(at: 1))
        }
    }

    private static func cleanHTML(_ rawText: String) -> String {
        let withoutTags = rawText.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return decodeEntities(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
