import Foundation
import SwiftUI
import UIKit

struct MemoDetailView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let memo: Memo
    @State private var text: String
    @State private var isEditing = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingHistory = false
    @State private var isShowingReferencePicker = false
    @State private var regionOCRAttachment: SharedAttachment?
    @State private var editErrorMessage: String?
    @State private var historyErrorMessage: String?
    @State private var transcriptionStatusText: String?
    @State private var transcribingAttachmentID: String?
    @State private var imageTextStatusText: String?
    @AppStorage("some.audioTranscriptionLanguage") private var transcriptionLanguageRawValue = AudioTranscriptionLanguage.automatic.rawValue
    @FocusState private var isFocused: Bool

    private var transcriptionLanguage: AudioTranscriptionLanguage {
        AudioTranscriptionLanguage.value(for: transcriptionLanguageRawValue)
    }

    init(memo: Memo) {
        self.memo = memo
        _text = State(initialValue: memo.text)
    }

    var body: some View {
        let currentMemo = store.memos.first(where: { $0.id == memo.id }) ?? memo
        let displayText = isEditing ? text : currentMemo.text
        let readableText = MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(displayText)
        )
        let attachments = SharedAttachmentStore.attachments(in: displayText)
        let referencedMemos = store.referencedMemos(from: currentMemo)
        let backlinkMemos = store.backlinkMemos(to: currentMemo)
        let referencedNotesByMemoID = referenceNotesByMemoID(in: currentMemo)
        let backlinkNotesByMemoID = backlinkNotesByMemoID(for: currentMemo, backlinks: backlinkMemos)

        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    if isEditing {
                        TextEditor(text: $text)
                            .focused($isFocused)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 18))
                            .lineSpacing(5)
                            .foregroundStyle(Color.primaryText)
                            .frame(minHeight: 260)

                        if let editErrorMessage = editErrorMessage {
                            Label(editErrorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.red)
                                .accessibilityIdentifier("memo-edit-error")
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if !readableText.isEmpty {
                                    MarkdownMemoTextView(text: readableText) { lineIndex in
                                        let originalLineIndex = SharedAttachmentStore.originalLineIndex(
                                            forVisibleLine: lineIndex,
                                            in: currentMemo.text
                                        ) ?? lineIndex
                                        store.toggleTask(currentMemo, lineIndex: originalLineIndex)
                                        if let updatedMemo = store.memos.first(where: { $0.id == currentMemo.id }) {
                                            text = updatedMemo.text
                                        }
                                    }
                                }

                                AttachmentPreviewList(attachments: attachments)

                                if !imageAttachments(in: attachments).isEmpty {
                                    imageTextSection(attachments: imageAttachments(in: attachments), memo: currentMemo)
                                }

                                if !audioAttachments(in: attachments).isEmpty {
                                    audioTranscriptionSection(
                                        attachments: audioAttachments(in: attachments),
                                        memo: currentMemo
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(minHeight: 260, alignment: .top)
                    }

                    HStack {
                        Label(DateFormatters.detail.string(from: currentMemo.createdAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)

                        Spacer()

                        Button {
                            store.togglePinned(currentMemo)
                        } label: {
                            Image(systemName: currentMemo.isPinned ? "pin.fill" : "pin")
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(currentMemo.isPinned ? Color.accentGold : Color.secondaryText)
                        .background(Color.subtleSurface)
                        .clipShape(Circle())
                        .accessibilityLabel(currentMemo.isPinned ? "取消置顶" : "置顶")

                        Button {
                            store.toggleArchived(currentMemo)
                            dismiss()
                        } label: {
                            Image(systemName: currentMemo.isArchived ? "tray.and.arrow.up" : "archivebox")
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.secondaryText)
                        .background(Color.subtleSurface)
                        .clipShape(Circle())
                        .accessibilityLabel(currentMemo.isArchived ? "恢复" : "归档")
                    }

                    if !TagParser.extractTags(from: readableText).isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(TagParser.extractTags(from: readableText), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentGreen)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(Color.greenTint)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if !isEditing {
                        MemoRelationSection(
                            referencedMemos: referencedMemos,
                            backlinkMemos: backlinkMemos,
                            referencedNotesByMemoID: referencedNotesByMemoID,
                            backlinkNotesByMemoID: backlinkNotesByMemoID,
                            onAddReference: {
                                isShowingReferencePicker = true
                            }
                        )
                    }

                    if !links(in: readableText).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("链接")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondaryText)

                            ForEach(links(in: readableText), id: \.absoluteString) { url in
                                Button {
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                            .font(.caption.weight(.semibold))
                                        Text(LinkExtractor.displayText(for: url))
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.up.forward")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(Color.accentGreen)
                                    .padding(.horizontal, 12)
                                    .frame(height: 38)
                                    .background(Color.greenTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("删除这条", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.red)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $isShowingReferencePicker) {
            MemoReferencePickerView(
                candidates: store.referenceCandidates(for: currentMemo),
                onSelect: { targetMemo, note in
                    if store.addReference(from: currentMemo, to: targetMemo, note: note),
                       let updatedMemo = store.memos.first(where: { $0.id == currentMemo.id }) {
                        text = updatedMemo.text
                    }
                    isShowingReferencePicker = false
                }
            )
        }
        .sheet(item: $regionOCRAttachment) { attachment in
            NavigationStack {
                ImageTextRegionPickerView(attachment: attachment) { region in
                    recognizeText(in: attachment, region: region, memo: currentMemo)
                }
            }
        }
        .navigationTitle(isEditing ? "编辑" : "详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button {
                        if store.update(currentMemo, text: text) {
                            editErrorMessage = nil
                            isEditing = false
                            isFocused = false
                        } else {
                            editErrorMessage = "保存失败，当前编辑内容已保留。"
                            isFocused = true
                        }
                    } label: {
                        Label("完成", systemImage: "checkmark")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    HStack(spacing: 8) {
                        Button {
                            historyErrorMessage = nil
                            isShowingHistory = true
                        } label: {
                            Label("历史", systemImage: "clock.arrow.circlepath")
                        }
                        .disabled(store.revisions(for: currentMemo).isEmpty)

                        Button {
                            text = currentMemo.text
                            editErrorMessage = nil
                            isEditing = true
                            DispatchQueue.main.async {
                                isFocused = true
                            }
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            MemoHistoryView(
                memo: currentMemo,
                revisions: store.revisions(for: currentMemo),
                errorMessage: historyErrorMessage,
                onRestore: { revision in
                    if store.restore(revision, for: currentMemo) {
                        if let updatedMemo = store.memos.first(where: { $0.id == currentMemo.id }) {
                            text = updatedMemo.text
                        }
                        historyErrorMessage = nil
                        isShowingHistory = false
                    } else {
                        historyErrorMessage = "恢复失败，请稍后再试。"
                    }
                }
            )
        }
        .confirmationDialog("删除这条闪念？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(memo)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .onChange(of: currentMemo.text) { newText in
            guard !isEditing else { return }
            text = newText
        }
    }

    private func links(in text: String) -> [URL] {
        LinkExtractor.urls(in: text)
    }

    private func audioAttachments(in attachments: [SharedAttachment]) -> [SharedAttachment] {
        attachments.filter(\.isAudio)
    }

    private func imageAttachments(in attachments: [SharedAttachment]) -> [SharedAttachment] {
        attachments.filter(\.isImage)
    }

    private func imageTextSection(attachments: [SharedAttachment], memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片文字")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            ForEach(attachments) { attachment in
                Button {
                    imageTextStatusText = nil
                    regionOCRAttachment = attachment
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.caption.weight(.semibold))
                        Text("框选识别 \(attachment.displayName)")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.greenTint)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if ClipFragmentExtractor.ocrProofreadingChecklist(in: memo.text) != nil {
                Button {
                    appendOCRProofreadingChecklist(to: memo)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.caption.weight(.semibold))
                        Text("生成 OCR 校对清单")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.greenTint)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let imageTextStatusText = imageTextStatusText {
                Text(imageTextStatusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private func audioTranscriptionSection(attachments: [SharedAttachment], memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("语音转写")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            Menu {
                ForEach(AudioTranscriptionLanguage.allCases) { language in
                    Button {
                        transcriptionLanguageRawValue = language.rawValue
                    } label: {
                        if language == transcriptionLanguage {
                            Label(language.title, systemImage: "checkmark")
                        } else {
                            Text(language.title)
                        }
                    }
                }
            } label: {
                Label(transcriptionLanguage.title, systemImage: "globe.asia.australia")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)

            ForEach(attachments) { attachment in
                Button {
                    transcribe(attachment, in: memo)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: transcribingAttachmentID == attachment.id ? "hourglass" : "text.bubble")
                            .font(.caption.weight(.semibold))
                        Text(transcribingAttachmentID == attachment.id ? "正在转写..." : "转写 \(attachment.displayName)")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.greenTint)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(transcribingAttachmentID != nil)
            }

            if let transcriptionStatusText = transcriptionStatusText {
                Text(transcriptionStatusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private func appendOCRProofreadingChecklist(to memo: Memo) {
        guard let checklist = ClipFragmentExtractor.ocrProofreadingChecklist(in: memo.text) else {
            imageTextStatusText = "没有可生成校对清单的 OCR 文本。"
            return
        }

        let updatedText = memo.text.appendingMemoSection(checklist)
        if store.update(memo, text: updatedText),
           let updatedMemo = store.memos.first(where: { $0.id == memo.id }) {
            text = updatedMemo.text
            imageTextStatusText = "已追加 OCR 校对清单"
        } else {
            imageTextStatusText = "OCR 校对清单保存失败。"
        }
    }

    private func recognizeText(in attachment: SharedAttachment, region: ImageTextRegion, memo: Memo) {
        guard let data = SharedAttachmentStore.data(for: attachment) else {
            imageTextStatusText = "找不到本地图片文件。"
            return
        }

        imageTextStatusText = "正在识别框选区域..."

        Task {
            let lines = await ImageTextRecognizer.recognizeTextLines(in: data, region: region)
            let appendedText = ImageTextRecognizer.memoText(
                for: attachment,
                recognizedLines: lines,
                region: region,
                includesAttachmentReference: false
            )

            await MainActor.run {
                regionOCRAttachment = nil

                guard let appendedText = appendedText else {
                    imageTextStatusText = "没有识别出可保存的文字。"
                    return
                }

                let latestMemo = store.memos.first(where: { $0.id == memo.id }) ?? memo
                let updatedText = latestMemo.text.appendingMemoSection(appendedText)
                if store.update(latestMemo, text: updatedText),
                   let updatedMemo = store.memos.first(where: { $0.id == memo.id }) {
                    text = updatedMemo.text
                    imageTextStatusText = "已追加框选文字"
                } else {
                    imageTextStatusText = "框选文字保存失败。"
                }
            }
        }
    }

    private func transcribe(_ attachment: SharedAttachment, in memo: Memo) {
        guard transcribingAttachmentID == nil else { return }
        guard let url = SharedAttachmentStore.url(for: attachment) else {
            transcriptionStatusText = "找不到本地音频文件。"
            return
        }

        transcribingAttachmentID = attachment.id
        transcriptionStatusText = "正在请求语音识别..."
        let language = transcriptionLanguage

        Task {
            do {
                let transcript = try await AudioTranscriber.transcribe(fileURL: url, language: language)
                let appendedText = AudioTranscriber.memoText(for: attachment, transcript: transcript, language: language)
                await MainActor.run {
                    defer {
                        transcribingAttachmentID = nil
                    }

                    guard let appendedText = appendedText else {
                        transcriptionStatusText = "没有识别出可保存的文字。"
                        return
                    }

                    let latestMemo = store.memos.first(where: { $0.id == memo.id }) ?? memo
                    let updatedText = latestMemo.text.appendingMemoSection(appendedText)
                    if store.update(latestMemo, text: updatedText),
                       let updatedMemo = store.memos.first(where: { $0.id == memo.id }) {
                        text = updatedMemo.text
                        transcriptionStatusText = "已追加语音转写"
                    } else {
                        transcriptionStatusText = "语音转写保存失败。"
                    }
                }
            } catch {
                await MainActor.run {
                    transcribingAttachmentID = nil
                    transcriptionStatusText = "语音转写失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func referenceNotesByMemoID(in memo: Memo) -> [UUID: String] {
        Dictionary(
            MemoReferenceParser.references(in: memo.text).compactMap { reference in
                guard let note = reference.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !note.isEmpty else {
                    return nil
                }
                return (reference.memoID, note)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func backlinkNotesByMemoID(for memo: Memo, backlinks: [Memo]) -> [UUID: String] {
        Dictionary(
            backlinks.compactMap { backlink in
                guard let note = MemoReferenceParser.references(in: backlink.text)
                    .first(where: { $0.memoID == memo.id })?
                    .note?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !note.isEmpty else {
                    return nil
                }
                return (backlink.id, note)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

private extension String {
    func appendingMemoSection(_ section: String) -> String {
        let trimmedBase = trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSection = section.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else {
            return trimmedSection
        }
        guard !trimmedSection.isEmpty else {
            return trimmedBase
        }
        return "\(trimmedBase)\n\n\(trimmedSection)"
    }
}

private struct ImageTextRegionPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let attachment: SharedAttachment
    let onRecognize: (ImageTextRegion) -> Void

    @State private var region = ImageTextRegion(x: 0.1, y: 0.16, width: 0.8, height: 0.48)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(attachment.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)

            if let image = image {
                ImageTextRegionSelectionCanvas(image: image, region: $region)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
                    .frame(maxHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    regionBadge("X", value: region.x)
                    regionBadge("Y", value: region.y)
                    regionBadge("W", value: region.width)
                    regionBadge("H", value: region.height)
                }
            } else {
                EmptyStateView(title: "无法读取图片")
                    .frame(maxWidth: .infinity, minHeight: 240)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Label("取消", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    onRecognize(region)
                    dismiss()
                } label: {
                    Label("识别区域", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(Color.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(self.image == nil)
            }
        }
        .padding(18)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("框选图片文字")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var image: UIImage? {
        guard let url = SharedAttachmentStore.url(for: attachment) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func regionBadge(_ label: String, value: Double) -> some View {
        Text("\(label) \(Int(value * 100))")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(Color.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.subtleSurface)
            .clipShape(Capsule())
    }
}

private struct ImageTextRegionSelectionCanvas: View {
    let image: UIImage
    @Binding var region: ImageTextRegion

    @State private var dragStartRegion: ImageTextRegion?
    @State private var resizeStartRegion: ImageTextRegion?

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = fittedImageSize(in: geometry.size)
            let canvasOrigin = CGPoint(
                x: (geometry.size.width - canvasSize.width) / 2,
                y: (geometry.size.height - canvasSize.height) / 2
            )
            let selectionRect = rect(for: region, in: canvasSize).offsetBy(
                dx: canvasOrigin.x,
                dy: canvasOrigin.y
            )

            ZStack {
                Color.surface

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Path { path in
                    path.addRect(CGRect(origin: canvasOrigin, size: canvasSize))
                    path.addRect(selectionRect)
                }
                .fill(Color.black.opacity(0.34), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentGreen.opacity(0.16))
                    )
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(x: selectionRect.midX, y: selectionRect.midY)
                    .gesture(dragGesture(canvasSize: canvasSize))

                resizeHandle(at: CGPoint(x: selectionRect.maxX, y: selectionRect.maxY), canvasSize: canvasSize)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func resizeHandle(at point: CGPoint, canvasSize: CGSize) -> some View {
        Circle()
            .fill(Color.surface)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 3)
            .position(point)
            .gesture(resizeGesture(canvasSize: canvasSize))
            .accessibilityLabel("调整识别区域大小")
    }

    private func fittedImageSize(in availableSize: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0,
              availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }

        let scale = min(
            availableSize.width / image.size.width,
            availableSize.height / image.size.height
        )
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func rect(for region: ImageTextRegion, in size: CGSize) -> CGRect {
        CGRect(
            x: region.x * size.width,
            y: region.y * size.height,
            width: max(36, region.width * size.width),
            height: max(36, region.height * size.height)
        )
    }

    private func dragGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRegion == nil {
                    dragStartRegion = region
                }
                guard let start = dragStartRegion,
                      canvasSize.width > 0,
                      canvasSize.height > 0 else {
                    return
                }

                let nextX = min(max(start.x + value.translation.width / canvasSize.width, 0), 1 - start.width)
                let nextY = min(max(start.y + value.translation.height / canvasSize.height, 0), 1 - start.height)
                region = ImageTextRegion(x: nextX, y: nextY, width: start.width, height: start.height)
            }
            .onEnded { _ in
                dragStartRegion = nil
            }
    }

    private func resizeGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStartRegion == nil {
                    resizeStartRegion = region
                }
                guard let start = resizeStartRegion,
                      canvasSize.width > 0,
                      canvasSize.height > 0 else {
                    return
                }

                let minimumWidth = min(0.98, 44 / canvasSize.width)
                let minimumHeight = min(0.98, 44 / canvasSize.height)
                let nextWidth = max(minimumWidth, start.width + value.translation.width / canvasSize.width)
                let nextHeight = max(minimumHeight, start.height + value.translation.height / canvasSize.height)
                region = ImageTextRegion(x: start.x, y: start.y, width: nextWidth, height: nextHeight)
            }
            .onEnded { _ in
                resizeStartRegion = nil
            }
    }
}

private struct MemoRelationSection: View {
    let referencedMemos: [Memo]
    let backlinkMemos: [Memo]
    let referencedNotesByMemoID: [UUID: String]
    let backlinkNotesByMemoID: [UUID: String]
    let onAddReference: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("引用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                Button(action: onAddReference) {
                    Label("添加", systemImage: "plus.circle")
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .accessibilityLabel("添加引用")
            }

            if !referencedMemos.isEmpty {
                relationGroup(
                    title: "指向",
                    memos: referencedMemos,
                    systemImage: "arrow.up.forward",
                    notesByMemoID: referencedNotesByMemoID
                )
            }

            if !backlinkMemos.isEmpty {
                relationGroup(
                    title: "被引用",
                    memos: backlinkMemos,
                    systemImage: "arrow.down.backward",
                    notesByMemoID: backlinkNotesByMemoID
                )
            }
        }
    }

    private func relationGroup(
        title: String,
        memos: [Memo],
        systemImage: String,
        notesByMemoID: [UUID: String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tertiaryText)

            ForEach(memos) { memo in
                NavigationLink(value: memo.id) {
                    HStack(spacing: 9) {
                        Image(systemName: "doc.text")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentGreen)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(MemoReferenceParser.title(for: memo))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(1)

                            Text(DateFormatters.row.localizedString(for: memo.createdAt, relativeTo: Date()))
                                .font(.caption2)
                                .foregroundStyle(Color.secondaryText)

                            if let note = notesByMemoID[memo.id] {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(minHeight: 48)
                    .background(Color.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MemoReferencePickerView: View {
    let candidates: [Memo]
    let onSelect: (Memo, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var referenceNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if filteredCandidates.isEmpty {
                    VStack(spacing: 14) {
                        referenceNoteField
                        EmptyStateView(title: candidates.isEmpty ? "没有可引用的记录" : "没有匹配的记录")
                    }
                    .padding(18)
                } else {
                    List {
                        Section {
                            referenceNoteField
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(filteredCandidates) { candidate in
                                Button {
                                    onSelect(candidate, normalizedReferenceNote)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(MemoReferenceParser.title(for: candidate))
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.primaryText)
                                            .lineLimit(2)

                                        Text(DateFormatters.row.localizedString(for: candidate.createdAt, relativeTo: Date()))
                                            .font(.caption)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("添加引用")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索要引用的记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var normalizedReferenceNote: String? {
        let trimmed = referenceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var referenceNoteField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("引用批注", systemImage: "quote.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tertiaryText)

            TextField("记录为什么引用它", text: $referenceNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Color.primaryText)
                .padding(10)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )
        }
    }

    private var filteredCandidates: [Memo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return candidates
        }

        return candidates.filter { candidate in
            candidate.text.localizedCaseInsensitiveContains(query)
                || candidate.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

private struct MemoHistoryView: View {
    let memo: Memo
    let revisions: [MemoRevision]
    let errorMessage: String?
    let onRestore: (MemoRevision) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let errorMessage = errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }

                        ForEach(revisions) { revision in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(DateFormatters.detail.string(from: revision.createdAt))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.primaryText)
                                        Text("原更新时间 \(DateFormatters.detail.string(from: revision.memoUpdatedAt))")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondaryText)
                                    }

                                    Spacer()

                                    Button {
                                        onRestore(revision)
                                    } label: {
                                        Label("恢复", systemImage: "arrow.uturn.backward")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color.accentGreen)
                                }

                                Text(Self.previewText(for: revision.text))
                                    .font(.footnote)
                                    .lineLimit(4)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(14)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("历史版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private static func previewText(for text: String) -> String {
        SharedAttachmentStore.displayTextWithoutAttachmentReferences(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
