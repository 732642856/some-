import SwiftUI
import UIKit

struct MemoRowView: View {
    @EnvironmentObject private var store: MemoStore
    let memo: Memo

    var body: some View {
        let displayText = SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        let attachments = SharedAttachmentStore.attachments(in: memo.text)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    if !displayText.isEmpty {
                        MarkdownMemoTextView(text: displayText)
                    }

                    AttachmentPreviewList(attachments: attachments, compact: true, allowsSharing: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentGold)
                        .padding(.top, 2)
                }

                if memo.isArchived {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 2)
                }
            }

            if !links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(links.prefix(2), id: \.absoluteString) { url in
                        Label(LinkExtractor.displayText(for: url), systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(Color.accentGreen)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(Color.greenTint)
                            .clipShape(Capsule())
                    }

                    if links.count > 2 {
                        Text("+\(links.count - 2)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }

            HStack(spacing: 8) {
                Label(DateFormatters.row.localizedString(for: memo.createdAt, relativeTo: Date()), systemImage: "clock")
                    .labelStyle(.titleAndIcon)

                if !memo.tags.isEmpty {
                    ForEach(memo.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .foregroundStyle(Color.accentGreen)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
            }
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
        .contextMenu {
            Button {
                store.togglePinned(memo)
            } label: {
                Label(memo.isPinned ? "取消置顶" : "置顶", systemImage: memo.isPinned ? "pin.slash" : "pin")
            }
            Button {
                store.toggleArchived(memo)
            } label: {
                Label(memo.isArchived ? "恢复" : "归档", systemImage: memo.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            Button {
                UIPasteboard.general.string = memo.text
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            ShareLink(item: memo.text) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                store.delete(memo)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var links: [URL] {
        LinkExtractor.urls(in: memo.text)
    }
}
