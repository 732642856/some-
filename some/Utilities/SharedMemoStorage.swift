import Foundation

enum SharedMemoStorage {
    enum Requirement {
        case sharedContainerPreferred
        case sharedContainerRequired
    }

    enum StorageError: LocalizedError {
        case missingSharedContainer(String)

        var errorDescription: String? {
            switch self {
            case .missingSharedContainer(let identifier):
                return "App Group “\(identifier)”不可用，请确认主 App 和分享扩展启用了同一个 App Group。"
            }
        }
    }

    static var appGroupIdentifier: String {
        let configuredIdentifier = Bundle.main.object(forInfoDictionaryKey: "SomeAppGroupIdentifier") as? String
        let trimmedIdentifier = configuredIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedIdentifier = trimmedIdentifier,
           !trimmedIdentifier.isEmpty,
           !trimmedIdentifier.hasPrefix("$(") {
            return trimmedIdentifier
        }
        return "group.com.732642856.some"
    }

    struct URLs {
        let fileURL: URL
        let backupFileURL: URL
        let databaseURL: URL
    }

    static func storageDirectory(fileManager: FileManager = .default) -> URL {
        (try? storageDirectory(
            fileManager: fileManager,
            requirement: .sharedContainerPreferred
        )) ?? documentsDirectory(fileManager: fileManager)
    }

    static func storageDirectory(
        fileManager: FileManager = .default,
        requirement: Requirement
    ) throws -> URL {
        try resolveStorageDirectory(
            standardDirectory: documentsDirectory(fileManager: fileManager),
            sharedDirectory: sharedDocumentsDirectory(fileManager: fileManager),
            appGroupIdentifier: appGroupIdentifier,
            requirement: requirement,
            fileManager: fileManager
        )
    }

    static func urls(filename: String = "some-memos.json") -> URLs {
        (try? urls(
            filename: filename,
            requirement: .sharedContainerPreferred
        )) ?? urls(
            filename: filename,
            storageDirectory: documentsDirectory(),
            standardDirectory: documentsDirectory()
        )
    }

    static func urls(
        filename: String = "some-memos.json",
        requirement: Requirement
    ) throws -> URLs {
        let standardDirectory = documentsDirectory()
        let storageDirectory = try Self.storageDirectory(requirement: requirement)

        return urls(
            filename: filename,
            storageDirectory: storageDirectory,
            standardDirectory: standardDirectory
        )
    }

    static func resolveStorageDirectory(
        standardDirectory: URL,
        sharedDirectory: URL?,
        appGroupIdentifier: String,
        requirement: Requirement,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let sharedDirectory = sharedDirectory else {
            if requirement == .sharedContainerRequired {
                throw StorageError.missingSharedContainer(appGroupIdentifier)
            }

            try fileManager.createDirectory(
                at: standardDirectory,
                withIntermediateDirectories: true
            )
            return standardDirectory
        }

        try fileManager.createDirectory(
            at: sharedDirectory,
            withIntermediateDirectories: true
        )
        return sharedDirectory
    }

    private static func urls(
        filename: String,
        storageDirectory: URL,
        standardDirectory: URL
    ) -> URLs {
        try? FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )

        migrateFromStandardDocumentsIfNeeded(
            filename: filename,
            standardDirectory: standardDirectory,
            storageDirectory: storageDirectory
        )

        let fileURL = storageDirectory.appendingPathComponent(filename)
        return URLs(
            fileURL: fileURL,
            backupFileURL: fileURL.deletingPathExtension().appendingPathExtension("bak.json"),
            databaseURL: fileURL.deletingPathExtension().appendingPathExtension("sqlite")
        )
    }

    private static func documentsDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private static func sharedDocumentsDirectory(fileManager: FileManager = .default) -> URL? {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent("Documents", isDirectory: true)
    }

    private static func migrateFromStandardDocumentsIfNeeded(
        filename: String,
        standardDirectory: URL,
        storageDirectory: URL
    ) {
        guard standardDirectory.path != storageDirectory.path else { return }

        let legacyFileURL = standardDirectory.appendingPathComponent(filename)
        let sharedFileURL = storageDirectory.appendingPathComponent(filename)
        copyIfNeeded(from: legacyFileURL, to: sharedFileURL)

        let legacyBackupURL = legacyFileURL.deletingPathExtension().appendingPathExtension("bak.json")
        let sharedBackupURL = sharedFileURL.deletingPathExtension().appendingPathExtension("bak.json")
        copyIfNeeded(from: legacyBackupURL, to: sharedBackupURL)

        let legacyDatabaseURL = legacyFileURL.deletingPathExtension().appendingPathExtension("sqlite")
        let sharedDatabaseURL = sharedFileURL.deletingPathExtension().appendingPathExtension("sqlite")
        copyIfNeeded(from: legacyDatabaseURL, to: sharedDatabaseURL)
        copyIfNeeded(
            from: URL(fileURLWithPath: legacyDatabaseURL.path + "-wal"),
            to: URL(fileURLWithPath: sharedDatabaseURL.path + "-wal")
        )
        copyIfNeeded(
            from: URL(fileURLWithPath: legacyDatabaseURL.path + "-shm"),
            to: URL(fileURLWithPath: sharedDatabaseURL.path + "-shm")
        )
    }

    private static func copyIfNeeded(from source: URL, to destination: URL) {
        guard FileManager.default.fileExists(atPath: source.path),
              !FileManager.default.fileExists(atPath: destination.path) else {
            return
        }

        try? FileManager.default.copyItem(at: source, to: destination)
    }
}
