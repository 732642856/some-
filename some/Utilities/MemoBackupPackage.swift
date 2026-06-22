import Foundation
import ZIPFoundation

@MainActor
enum MemoBackupPackage {
    static let fileExtension = "somebackup"
    private static let manifestFilename = "manifest.json"
    private static let attachmentsDirectoryName = "attachments"

    static func export(from store: MemoStore) throws -> URL {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("some-exports", isDirectory: true)
            .appendingPathComponent("some-backup-\(timestamp()).\(fileExtension)", isDirectory: false)

        try FileManager.default.createDirectory(
            at: packageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? FileManager.default.removeItem(at: packageURL)

        let archive = try store.makeBackupArchive(includeInlineAttachmentData: false)
        let manifestData = try JSONEncoder.memoEncoder.encode(archive)
        let zip = try Archive(url: packageURL, accessMode: .create)

        try zip.addEntry(
            with: manifestFilename,
            type: .file,
            uncompressedSize: Int64(manifestData.count),
            provider: { position, size -> Data in
                let start = Int(position)
                let end = start + size
                return manifestData.subdata(in: start..<end)
            }
        )

        for attachment in archive.attachments {
            guard let sourceURL = SharedAttachmentStore.url(for: sharedAttachment(from: attachment)) else {
                throw MemoBackupPackageError.missingAttachmentData(attachment.filename)
            }
            try zip.addEntry(
                with: "\(attachmentsDirectoryName)/\(attachment.relativePath)",
                fileURL: sourceURL
            )
        }

        return packageURL
    }

    static func importPackage(at packageURL: URL, into store: MemoStore) throws -> Int {
        let accessed = packageURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                packageURL.stopAccessingSecurityScopedResource()
            }
        }

        let zip = try Archive(url: packageURL, accessMode: .read)
        guard let manifestEntry = zip[manifestFilename] else {
            throw MemoBackupPackageError.missingManifest
        }

        var manifestData = Data()
        _ = try zip.extract(manifestEntry) { chunk in
            manifestData.append(chunk)
        }

        let archive = try JSONDecoder.memoDecoder.decode(MemoBackupArchive.self, from: manifestData)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("some-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let hydratedAttachments = try archive.attachments.map { attachment -> MemoBackupAttachment in
            guard let safeRelativePath = safeAttachmentRelativePath(attachment.relativePath) else {
                throw MemoBackupPackageError.unsafeAttachmentPath(attachment.relativePath)
            }

            if attachment.base64Data != nil {
                return attachment
            }

            let entryPath = "\(attachmentsDirectoryName)/\(safeRelativePath)"
            guard let entry = zip[entryPath] else {
                throw MemoBackupPackageError.missingAttachmentData(attachment.filename)
            }

            let outputURL = temporaryDirectory.appendingPathComponent(safeRelativePath, isDirectory: false)
            _ = try zip.extract(entry, to: outputURL)
            let data = try Data(contentsOf: outputURL)
            return MemoBackupAttachment(
                filename: attachment.filename,
                relativePath: safeRelativePath,
                typeIdentifier: attachment.typeIdentifier,
                base64Data: data.base64EncodedString()
            )
        }

        let hydratedArchive = MemoBackupArchive(
            version: archive.version,
            exportedAt: archive.exportedAt,
            memos: archive.memos,
            attachments: hydratedAttachments,
            revisions: archive.revisions
        )
        return try store.importBackupArchive(hydratedArchive)
    }

    private static func sharedAttachment(from attachment: MemoBackupAttachment) -> SharedAttachment {
        SharedAttachment(
            id: attachment.relativePath,
            filename: attachment.filename,
            relativePath: attachment.relativePath,
            typeIdentifier: attachment.typeIdentifier,
            byteCount: 0
        )
    }

    private static func safeAttachmentRelativePath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains(":"),
              trimmed.range(of: "\0") == nil
        else {
            return nil
        }
        return trimmed
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum MemoBackupPackageError: LocalizedError {
    case invalidPackage
    case missingManifest
    case missingAttachmentData(String)
    case unsafeAttachmentPath(String)

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            return "备份文件不是有效的 some 备份。"
        case .missingManifest:
            return "备份文件缺少清单。"
        case .missingAttachmentData(let filename):
            return "完整备份缺少附件“\(filename)”。"
        case .unsafeAttachmentPath(let path):
            return "完整备份包含不安全的附件路径“\(path)”。"
        }
    }
}
