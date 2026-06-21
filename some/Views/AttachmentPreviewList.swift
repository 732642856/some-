import SwiftUI
import UIKit

struct AttachmentPreviewList: View {
    let attachments: [SharedAttachment]
    var compact = false
    var allowsSharing = true

    var body: some View {
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                ForEach(attachments) { attachment in
                    attachmentRow(attachment)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func attachmentRow(_ attachment: SharedAttachment) -> some View {
        if allowsSharing, let url = SharedAttachmentStore.url(for: attachment) {
            ShareLink(item: url) {
                rowContent(attachment)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(attachment)
        }
    }

    private func rowContent(_ attachment: SharedAttachment) -> some View {
        HStack(spacing: 10) {
            preview(for: attachment)

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)

                Text(detailText(for: attachment))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if allowsSharing {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: compact ? 46 : 54)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func preview(for attachment: SharedAttachment) -> some View {
        if attachment.isImage,
           let url = SharedAttachmentStore.url(for: attachment),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: attachment.isImage ? "photo" : "doc")
                .font(.system(size: compact ? 16 : 18, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
                .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                .background(Color.greenTint)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func detailText(for attachment: SharedAttachment) -> String {
        let sizeText = attachment.byteCount > 0
            ? SharedAttachmentStore.formatByteCount(attachment.byteCount)
            : "本地附件"
        return attachment.isImage ? "图片 · \(sizeText)" : "文件 · \(sizeText)"
    }
}
