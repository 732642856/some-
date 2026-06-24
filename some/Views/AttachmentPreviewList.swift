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
           let url = SharedAttachmentStore.url(for: attachment) {
            ImageThumbnailPreview(
                url: url,
                size: compact ? 32 : 38,
                cornerRadius: 6,
                fallbackSystemImage: iconName(for: attachment)
            )
        } else if attachment.isVideo,
                  let url = SharedAttachmentStore.url(for: attachment) {
            VideoThumbnailPreview(
                url: url,
                size: compact ? 32 : 38,
                cornerRadius: 6,
                fallbackSystemImage: iconName(for: attachment)
            )
        } else {
            Image(systemName: iconName(for: attachment))
                .font(.system(size: compact ? 16 : 18, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
                .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                .background(Color.greenTint)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func detailText(for attachment: SharedAttachment) -> String {
        if let summary = MediaMetadataExtractor.summary(for: attachment) {
            return "\(typeLabel(for: attachment)) · \(summary)"
        }

        if attachment.byteCount > 0 {
            return "\(typeLabel(for: attachment)) · \(SharedAttachmentStore.formatByteCount(attachment.byteCount))"
        }

        return "\(typeLabel(for: attachment)) · 本地附件"
    }

    private func iconName(for attachment: SharedAttachment) -> String {
        if attachment.isImage {
            return "photo"
        }

        if attachment.isVideo {
            return "video"
        }

        if attachment.isAudio {
            return "waveform"
        }

        return "doc"
    }

    private func typeLabel(for attachment: SharedAttachment) -> String {
        if attachment.isImage {
            return "图片"
        }

        if attachment.isVideo {
            return "视频"
        }

        if attachment.isAudio {
            return "音频"
        }

        return "文件"
    }
}

struct ImageThumbnailPreview: View {
    let url: URL
    let size: CGFloat
    var cornerRadius: CGFloat = 8
    var fallbackSystemImage = "photo"

    @State private var image: UIImage?
    @State private var requestedURL: URL?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: max(14, size * 0.42), weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.greenTint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
        .onAppear(perform: requestThumbnailIfNeeded)
    }

    private func requestThumbnailIfNeeded() {
        guard requestedURL != url else {
            return
        }

        requestedURL = url
        image = nil
        let thumbnailURL = url
        let pixelSize = size * 3

        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnail = ImageThumbnailGenerator.image(
                for: thumbnailURL,
                maximumPixelSize: pixelSize
            )
            DispatchQueue.main.async {
                guard requestedURL == thumbnailURL else {
                    return
                }
                image = thumbnail
            }
        }
    }
}

struct VideoThumbnailPreview: View {
    let url: URL
    let size: CGFloat
    var cornerRadius: CGFloat = 8
    var fallbackSystemImage = "video"

    @State private var image: UIImage?
    @State private var requestedURL: URL?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: max(14, size * 0.42), weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.greenTint)
            }

            if image != nil {
                Circle()
                    .fill(Color.black.opacity(0.46))
                    .frame(width: max(18, size * 0.44), height: max(18, size * 0.44))
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: max(8, size * 0.18), weight: .bold))
                            .foregroundStyle(Color.white)
                            .offset(x: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
        .onAppear(perform: requestThumbnailIfNeeded)
    }

    private func requestThumbnailIfNeeded() {
        guard requestedURL != url else {
            return
        }

        requestedURL = url
        image = nil
        let thumbnailURL = url
        let pixelSize = CGSize(width: size * 3, height: size * 3)

        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnail = VideoThumbnailGenerator.image(for: thumbnailURL, maximumSize: pixelSize)
            DispatchQueue.main.async {
                guard requestedURL == thumbnailURL else {
                    return
                }
                image = thumbnail
            }
        }
    }
}
