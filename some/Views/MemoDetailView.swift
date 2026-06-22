import Foundation
import SwiftUI

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
    @State private var editErrorMessage: String?
    @State private var historyErrorMessage: String?
    @State private var transcriptionStatusText: String?
    @State private var transcribingAttachmentID: String?
    @FocusState private var isFocused: Bool

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
                onSelect: { targetMemo in
                    if store.addReference(from: currentMemo, to: targetMemo),
                       let updatedMemo = store.memos.first(where: { $0.id == currentMemo.id }) {
                        text = updatedMemo.text
                    }
                    isShowingReferencePicker = false
                }
            )
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

    private func audioTranscriptionSection(attachments: [SharedAttachment], memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("语音转写")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

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

    private func transcribe(_ attachment: SharedAttachment, in memo: Memo) {
        guard transcribingAttachmentID == nil else { return }
        guard let url = SharedAttachmentStore.url(for: attachment) else {
            transcriptionStatusText = "找不到本地音频文件。"
            return
        }

        transcribingAttachmentID = attachment.id
        transcriptionStatusText = "正在请求语音识别..."

        Task {
            do {
                let transcript = try await AudioTranscriber.transcribe(fileURL: url)
                let appendedText = AudioTranscriber.memoText(for: attachment, transcript: transcript)
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

private struct MemoRelationSection: View {
    let referencedMemos: [Memo]
    let backlinkMemos: [Memo]
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
                relationGroup(title: "指向", memos: referencedMemos, systemImage: "arrow.up.forward")
            }

            if !backlinkMemos.isEmpty {
                relationGroup(title: "被引用", memos: backlinkMemos, systemImage: "arrow.down.backward")
            }
        }
    }

    private func relationGroup(title: String, memos: [Memo], systemImage: String) -> some View {
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
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 48)
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
    let onSelect: (Memo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if filteredCandidates.isEmpty {
                    EmptyStateView(title: candidates.isEmpty ? "没有可引用的记录" : "没有匹配的记录")
                        .padding(18)
                } else {
                    List(filteredCandidates) { candidate in
                        Button {
                            onSelect(candidate)
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
