import Foundation
import UniformTypeIdentifiers

struct SharedAttachment: Equatable, Identifiable {
    let id: String
    let filename: String
    let relativePath: String
    let typeIdentifier: String
    let byteCount: Int

    var displayName: String {
        filename
    }

    var isImage: Bool {
        UTType(typeIdentifier)?.conforms(to: .image) == true
    }

    var isVideo: Bool {
        UTType(typeIdentifier)?.conforms(to: .movie) == true
    }

    var isAudio: Bool {
        UTType(typeIdentifier)?.conforms(to: .audio) == true
    }

    var referenceLine: String {
        "[附件: \(filename)](\(referenceURI))"
    }

    var referenceURI: String {
        "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(relativePath))"
    }
}

enum SharedAttachmentStore {
    static let directoryName = "Attachments"
    static let referenceScheme = "some-attachment"
    private static let referencePathAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()

    static func save(
        data: Data,
        suggestedFilename: String?,
        typeIdentifier: String?,
        fileManager: FileManager = .default,
        storageRequirement: SharedMemoStorage.Requirement = .sharedContainerPreferred
    ) throws -> SharedAttachment {
        let type = typeIdentifier.flatMap(UTType.init)
        let filename = makeUniqueFilename(
            suggestedFilename: suggestedFilename,
            type: type,
            fileManager: fileManager,
            storageRequirement: storageRequirement
        )
        let directory = try attachmentsDirectory(
            fileManager: fileManager,
            storageRequirement: storageRequirement
        )
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: [.atomic])

        return SharedAttachment(
            id: filename,
            filename: filename,
            relativePath: filename,
            typeIdentifier: type?.identifier ?? typeIdentifier ?? UTType.data.identifier,
            byteCount: data.count
        )
    }

    static func save(
        fileAt sourceURL: URL,
        suggestedFilename: String?,
        typeIdentifier: String?,
        fileManager: FileManager = .default,
        storageRequirement: SharedMemoStorage.Requirement = .sharedContainerPreferred
    ) throws -> SharedAttachment {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try? sourceURL.resourceValues(forKeys: [.nameKey, .contentTypeKey, .fileSizeKey])
        let resolvedType = values?.contentType?.identifier
            ?? (typeIdentifier == UTType.fileURL.identifier ? nil : typeIdentifier)
        let resolvedFilename = suggestedFilename ?? values?.name ?? sourceURL.lastPathComponent
        let type = resolvedType.flatMap(UTType.init)
        let filename = makeUniqueFilename(
            suggestedFilename: resolvedFilename,
            type: type,
            fileManager: fileManager,
            storageRequirement: storageRequirement
        )
        let directory = try attachmentsDirectory(
            fileManager: fileManager,
            storageRequirement: storageRequirement
        )
        let destinationURL = directory.appendingPathComponent(filename, isDirectory: false)
        try copyFileAtomically(from: sourceURL, to: destinationURL, fileManager: fileManager)
        let byteCount = destinationURL.fileByteCount(fileManager: fileManager)
            ?? values?.fileSize
            ?? 0

        return SharedAttachment(
            id: filename,
            filename: filename,
            relativePath: filename,
            typeIdentifier: type?.identifier ?? resolvedType ?? UTType.data.identifier,
            byteCount: byteCount
        )
    }

    static func attachments(in text: String) -> [SharedAttachment] {
        let pattern = #"\[附件: ([^\]]+)\]\(some-attachment://([^)]+)\)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = text as NSString
        let lines = text.components(separatedBy: .newlines)
        let recognizedTextBodyIndexes = recognizedTextBodyLineIndexes(in: lines)
        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )

        return matches.compactMap { match in
            let lineIndex = lineIndex(containing: match.range.location, in: nsText)
            guard !recognizedTextBodyIndexes.contains(lineIndex) else {
                return nil
            }

            guard
                let nameRange = Range(match.range(at: 1), in: text),
                let pathRange = Range(match.range(at: 2), in: text)
            else {
                return nil
            }

            let filename = String(text[nameRange])
            guard let relativePath = safeRelativePath(decodedReferencePath(String(text[pathRange]))) else {
                return nil
            }
            return attachment(filename: filename, relativePath: relativePath)
        }
    }

    static func displayTextWithoutAttachmentReferences(_ text: String) -> String {
        visibleTextModel(for: text).text
    }

    static func originalLineIndex(forVisibleLine visibleLineIndex: Int, in text: String) -> Int? {
        let lineMap = visibleTextModel(for: text).originalLineIndices
        guard lineMap.indices.contains(visibleLineIndex) else { return nil }
        return lineMap[visibleLineIndex]
    }

    static func url(for attachment: SharedAttachment, fileManager: FileManager = .default) -> URL? {
        guard
            let relativePath = safeRelativePath(attachment.relativePath),
            let directory = try? attachmentsDirectory(fileManager: fileManager)
        else {
            return nil
        }

        let standardizedDirectory = directory.standardizedFileURL
        let candidate = standardizedDirectory
            .appendingPathComponent(relativePath, isDirectory: false)
            .standardizedFileURL
        guard isContained(candidate, in: standardizedDirectory) else {
            return nil
        }
        return candidate
    }

    static func delete(_ attachment: SharedAttachment, fileManager: FileManager = .default) {
        guard let url = url(for: attachment, fileManager: fileManager) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    static func data(for attachment: SharedAttachment, fileManager: FileManager = .default) -> Data? {
        guard let url = url(for: attachment, fileManager: fileManager) else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    static func exists(_ attachment: SharedAttachment, fileManager: FileManager = .default) -> Bool {
        guard let url = url(for: attachment, fileManager: fileManager) else {
            return false
        }

        return fileManager.fileExists(atPath: url.path)
    }

    static func restore(
        data: Data,
        filename: String,
        relativePath: String,
        typeIdentifier: String,
        fileManager: FileManager = .default,
        storageRequirement: SharedMemoStorage.Requirement = .sharedContainerPreferred
    ) throws -> SharedAttachment {
        guard let safePath = safeRelativePath(relativePath) else {
            return try save(
                data: data,
                suggestedFilename: filename,
                typeIdentifier: typeIdentifier,
                fileManager: fileManager,
                storageRequirement: storageRequirement
            )
        }

        let candidate = SharedAttachment(
            id: safePath,
            filename: filename,
            relativePath: safePath,
            typeIdentifier: typeIdentifier,
            byteCount: data.count
        )

        if let existingURL = url(for: candidate, fileManager: fileManager),
           fileManager.fileExists(atPath: existingURL.path) {
            if (try? Data(contentsOf: existingURL)) == data {
                return candidate
            }

            return try save(
                data: data,
                suggestedFilename: filename,
                typeIdentifier: typeIdentifier,
                fileManager: fileManager,
                storageRequirement: storageRequirement
            )
        }

        guard let restoreURL = url(for: candidate, fileManager: fileManager) else {
            return try save(
                data: data,
                suggestedFilename: filename,
                typeIdentifier: typeIdentifier,
                fileManager: fileManager,
                storageRequirement: storageRequirement
            )
        }

        try data.write(to: restoreURL, options: [.atomic])
        return candidate
    }

    static func replacingAttachmentReferences(
        in text: String,
        remapping: [String: SharedAttachment]
    ) -> String {
        guard !remapping.isEmpty else { return text }

        let pattern = #"\[附件: ([^\]]+)\]\(some-attachment://([^)]+)\)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )

        var output = ""
        var cursor = text.startIndex
        for match in matches {
            guard
                let fullRange = Range(match.range(at: 0), in: text),
                let pathRange = Range(match.range(at: 2), in: text)
            else {
                continue
            }

            output.append(contentsOf: text[cursor..<fullRange.lowerBound])
            let relativePath = decodedReferencePath(String(text[pathRange]))
            if let replacement = remapping[relativePath] {
                output.append(replacement.referenceLine)
            } else {
                output.append(contentsOf: text[fullRange])
            }
            cursor = fullRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }

    static func deleteUnreferencedAttachments(
        referencedBy texts: [String],
        olderThan expiration: TimeInterval = 86_400,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        guard let directory = try? attachmentsDirectory(fileManager: fileManager),
              let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let referencedPaths = Set(texts.flatMap { text in
            attachments(in: text).map(\.relativePath)
        })

        for file in files where !referencedPaths.contains(file.lastPathComponent) {
            guard let modifiedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) >= expiration else {
                continue
            }
            try? fileManager.removeItem(at: file)
        }
    }

    static func formatByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    static func encodedReferencePath(_ path: String) -> String {
        path.addingPercentEncoding(withAllowedCharacters: referencePathAllowedCharacters) ?? path
    }

    private static func attachment(filename: String, relativePath: String) -> SharedAttachment? {
        guard let relativePath = safeRelativePath(relativePath) else {
            return nil
        }

        let fileURL = url(
            for: SharedAttachment(
                id: relativePath,
                filename: filename,
                relativePath: relativePath,
                typeIdentifier: UTType.data.identifier,
                byteCount: 0
            )
        )
        let values = fileURL.flatMap { try? $0.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey]) }
        let typeIdentifier = values?.contentType?.identifier
            ?? UTType(filenameExtension: URL(fileURLWithPath: filename).pathExtension)?.identifier
            ?? UTType.data.identifier
        let byteCount = values?.fileSize ?? 0

        return SharedAttachment(
            id: relativePath,
            filename: filename,
            relativePath: relativePath,
            typeIdentifier: typeIdentifier,
            byteCount: byteCount
        )
    }

    private static func attachmentsDirectory(
        fileManager: FileManager = .default,
        storageRequirement: SharedMemoStorage.Requirement = .sharedContainerPreferred
    ) throws -> URL {
        let root = try SharedMemoStorage.storageDirectory(
            fileManager: fileManager,
            requirement: storageRequirement
        )
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private struct VisibleTextModel {
        let text: String
        let originalLineIndices: [Int]
    }

    private static func visibleTextModel(for text: String) -> VisibleTextModel {
        var rows = text.components(separatedBy: "\n").enumerated().compactMap { index, line -> (Int, String)? in
            attachments(in: line).isEmpty ? (index, line) : nil
        }

        while let first = rows.first,
              first.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.removeFirst()
        }

        while let last = rows.last,
              last.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.removeLast()
        }

        return VisibleTextModel(
            text: rows.map { $0.1 }.joined(separator: "\n"),
            originalLineIndices: rows.map { $0.0 }
        )
    }

    private static func safeRelativePath(_ path: String) -> String? {
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

    private static func lineIndex(containing location: Int, in text: NSString) -> Int {
        var index = 0
        var position = 0

        while position < location {
            let lineRange = text.lineRange(for: NSRange(location: position, length: 0))
            guard NSMaxRange(lineRange) <= location else {
                return index
            }
            position = NSMaxRange(lineRange)
            index += 1
        }

        return index
    }

    private static func recognizedTextBodyLineIndexes(in lines: [String]) -> Set<Int> {
        var indexes = Set<Int>()
        var isInRecognizedText = false
        var hasRecognizedContent = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if isRecognizedTextHeader(trimmed) {
                isInRecognizedText = true
                hasRecognizedContent = false
                continue
            }

            guard isInRecognizedText else {
                continue
            }

            if trimmed.isEmpty {
                if hasRecognizedContent {
                    isInRecognizedText = false
                    hasRecognizedContent = false
                }
                continue
            }

            indexes.insert(index)
            hasRecognizedContent = true
        }

        return indexes
    }

    private static func isRecognizedTextHeader(_ line: String) -> Bool {
        line == "识别文字：" || line == "识别文字:" || line == "OCR：" || line == "OCR:"
    }

    private static func isContained(_ fileURL: URL, in directoryURL: URL) -> Bool {
        let directoryPath = directoryURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return filePath.hasPrefix(directoryPath + "/")
    }

    private static func makeUniqueFilename(
        suggestedFilename: String?,
        type: UTType?,
        fileManager: FileManager,
        storageRequirement: SharedMemoStorage.Requirement
    ) -> String {
        let directory = (try? attachmentsDirectory(
            fileManager: fileManager,
            storageRequirement: storageRequirement
        ))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let sanitized = sanitizedFilename(suggestedFilename, type: type)
        let baseURL = URL(fileURLWithPath: sanitized)
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let pathExtension = baseURL.pathExtension

        var candidate = sanitized
        var index = 2
        while fileManager.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = pathExtension.isEmpty
                ? "\(baseName)-\(index)"
                : "\(baseName)-\(index).\(pathExtension)"
            index += 1
        }
        return candidate
    }

    private static func copyFileAtomically(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager
    ) throws {
        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
        defer {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        try fileManager.copyItem(at: sourceURL, to: temporaryURL)
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    private static func sanitizedFilename(_ suggestedFilename: String?, type: UTType?) -> String {
        let rawCandidate = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmed = rawCandidate
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
            .replacingOccurrences(of: "\n", with: " ")
        let fallbackName = "attachment-\(UUID().uuidString)"
        let rawName = safeRelativePath(trimmed) ?? fallbackName
        let url = URL(fileURLWithPath: rawName)

        if url.pathExtension.isEmpty, let preferredExtension = type?.preferredFilenameExtension {
            return "\(rawName).\(preferredExtension)"
        }

        return rawName
    }

    private static func decodedReferencePath(_ path: String) -> String {
        path.removingPercentEncoding ?? path
    }
}

private extension URL {
    func fileByteCount(fileManager: FileManager) -> Int? {
        if let resourceSize = try? resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return resourceSize
        }

        let attributes = try? fileManager.attributesOfItem(atPath: path)
        return (attributes?[.size] as? NSNumber)?.intValue
    }
}
