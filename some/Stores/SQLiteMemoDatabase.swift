import Foundation
import SQLite3

struct MemoSearchMatch: Equatable {
    let id: UUID
    let rank: Int
}

final class SQLiteMemoDatabase {
    enum DatabaseError: Error {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
        case invalidID(String)
    }

    private let databaseURL: URL
    private var database: OpaquePointer?

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK else {
            throw DatabaseError.openFailed(Self.errorMessage(database))
        }

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try migrate()
        try rebuildSearchIndexIfNeeded()
        try rebuildAssetIndex()
    }

    deinit {
        sqlite3_close(database)
    }

    func fetchAll() throws -> [Memo] {
        let statement = try prepare("""
        SELECT id, text, created_at, updated_at, tags_json, is_pinned, is_archived
        FROM memos
        ORDER BY is_pinned DESC, created_at DESC;
        """)
        defer { sqlite3_finalize(statement) }

        var memos: [Memo] = []

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                memos.append(try memo(from: statement))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw DatabaseError.stepFailed(Self.errorMessage(database))
            }
        }

        return memos
    }

    func fetchAllRevisions() throws -> [MemoRevision] {
        let statement = try prepare("""
        SELECT id, memo_id, text, tags_json, created_at, memo_updated_at
        FROM memo_revisions
        ORDER BY created_at DESC;
        """)
        defer { sqlite3_finalize(statement) }

        var revisions: [MemoRevision] = []

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                revisions.append(try revision(from: statement))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw DatabaseError.stepFailed(Self.errorMessage(database))
            }
        }

        return revisions
    }

    func fetchAllAssets() throws -> [MemoAsset] {
        let statement = try prepare("""
        SELECT id, memo_id, kind, title, summary, uri, type_identifier, byte_count, created_at, updated_at
        FROM memo_assets
        ORDER BY created_at DESC, kind ASC, title ASC;
        """)
        defer { sqlite3_finalize(statement) }

        var assets: [MemoAsset] = []

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                assets.append(try asset(from: statement))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw DatabaseError.stepFailed(Self.errorMessage(database))
            }
        }

        return assets
    }

    func upsert(_ memo: Memo) throws {
        try upsert(memo, revision: nil)
    }

    func upsert(_ memo: Memo, revision: MemoRevision?) throws {
        try transaction {
            if let revision = revision {
                try insertRevisionRow(revision)
            }
            try upsertMemoRow(memo)
            try upsertSearchIndex(for: memo)
            try replaceAssets(for: memo)
        }
    }

    func upsert(_ memos: [Memo]) throws {
        try transaction {
            for memo in memos {
                try upsertMemoRow(memo)
                try upsertSearchIndex(for: memo)
                try replaceAssets(for: memo)
            }
        }
    }

    func delete(id: UUID) throws {
        try transaction {
            if let rowID = try rowID(for: id) {
                try deleteSearchIndex(rowID: rowID)
            }

            try deleteRevisions(memoID: id)
            try deleteAssets(memoID: id)

            let statement = try prepare("DELETE FROM memos WHERE id = ?;")
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)
            try stepDone(statement)
        }
    }

    func isEmpty() throws -> Bool {
        let statement = try prepare("SELECT COUNT(*) FROM memos;")
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(Self.errorMessage(database))
        }

        return sqlite3_column_int64(statement, 0) == 0
    }

    func replaceAll(memos: [Memo], revisions: [MemoRevision]) throws {
        try transaction {
            for memo in memos {
                try upsertMemoRow(memo)
                try upsertSearchIndex(for: memo)
                try replaceAssets(for: memo)
            }

            try execute("DELETE FROM memo_revisions;")
            for revision in revisions {
                try insertRevisionRow(revision)
            }
        }
    }

    func searchIDs(matching text: String, limit: Int = 250) throws -> [MemoSearchMatch] {
        let ftsQuery = Self.ftsQuery(from: text)
        guard !ftsQuery.isEmpty else {
            return []
        }

        let statement = try prepare("""
        SELECT id
        FROM memos_fts
        WHERE memos_fts MATCH ?
        ORDER BY rank
        LIMIT ?;
        """)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, ftsQuery, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var matches: [MemoSearchMatch] = []
        var rank = 0

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                let idText = Self.columnText(statement, index: 0)
                if let id = UUID(uuidString: idText) {
                    matches.append(MemoSearchMatch(id: id, rank: rank))
                    rank += 1
                }
            } else if result == SQLITE_DONE {
                break
            } else {
                throw DatabaseError.stepFailed(Self.errorMessage(database))
            }
        }

        return matches
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS memos (
            id TEXT PRIMARY KEY NOT NULL,
            text TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            tags_json TEXT NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_memos_created_at ON memos(created_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS idx_memos_archived ON memos(is_archived);")
        try execute("CREATE INDEX IF NOT EXISTS idx_memos_pinned ON memos(is_pinned);")
        try execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS memos_fts USING fts5(
            id UNINDEXED,
            text,
            tags,
            tokenize = 'unicode61'
        );
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS memo_revisions (
            id TEXT PRIMARY KEY NOT NULL,
            memo_id TEXT NOT NULL,
            text TEXT NOT NULL,
            tags_json TEXT NOT NULL,
            created_at REAL NOT NULL,
            memo_updated_at REAL NOT NULL
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_memo_revisions_memo_id ON memo_revisions(memo_id);")
        try execute("CREATE INDEX IF NOT EXISTS idx_memo_revisions_created_at ON memo_revisions(created_at DESC);")
        try execute("""
        CREATE TABLE IF NOT EXISTS memo_assets (
            id TEXT PRIMARY KEY NOT NULL,
            memo_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            summary TEXT,
            uri TEXT,
            type_identifier TEXT,
            byte_count INTEGER,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            FOREIGN KEY(memo_id) REFERENCES memos(id) ON DELETE CASCADE
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_memo_assets_memo_id ON memo_assets(memo_id);")
        try execute("CREATE INDEX IF NOT EXISTS idx_memo_assets_kind ON memo_assets(kind);")
        try execute("CREATE INDEX IF NOT EXISTS idx_memo_assets_created_at ON memo_assets(created_at DESC);")
    }

    private func rebuildSearchIndexIfNeeded() throws {
        guard try rowCount(table: "memos") != rowCount(table: "memos_fts") else {
            return
        }

        try execute("DELETE FROM memos_fts;")
        try execute("""
        INSERT INTO memos_fts(rowid, id, text, tags)
        SELECT rowid, id, text, tags_json FROM memos;
        """)
    }

    private func rebuildAssetIndex() throws {
        let memos = try fetchAll()
        try execute("DELETE FROM memo_assets;")
        for memo in memos {
            try replaceAssets(for: memo)
        }
    }

    private func rowCount(table: String) throws -> Int64 {
        let statement = try prepare("SELECT COUNT(*) FROM \(table);")
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(Self.errorMessage(database))
        }

        return sqlite3_column_int64(statement, 0)
    }

    private func upsertMemoRow(_ memo: Memo) throws {
        let statement = try prepare("""
        INSERT INTO memos (
            id, text, created_at, updated_at, tags_json, is_pinned, is_archived
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            text = excluded.text,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            tags_json = excluded.tags_json,
            is_pinned = excluded.is_pinned,
            is_archived = excluded.is_archived;
        """)
        defer { sqlite3_finalize(statement) }

        try bind(memo, to: statement)
        try stepDone(statement)
    }

    private func upsertSearchIndex(for memo: Memo) throws {
        guard let rowID = try rowID(for: memo.id) else { return }

        try deleteSearchIndex(rowID: rowID)

        let statement = try prepare("""
        INSERT INTO memos_fts(rowid, id, text, tags)
        VALUES (?, ?, ?, ?);
        """)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, rowID)
        sqlite3_bind_text(statement, 2, memo.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, memo.text, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, memo.tags.joined(separator: " "), -1, sqliteTransient)
        try stepDone(statement)
    }

    private func insertRevisionRow(_ revision: MemoRevision) throws {
        let statement = try prepare("""
        INSERT OR IGNORE INTO memo_revisions (
            id, memo_id, text, tags_json, created_at, memo_updated_at
        ) VALUES (?, ?, ?, ?, ?, ?);
        """)
        defer { sqlite3_finalize(statement) }

        try bind(revision, to: statement)
        try stepDone(statement)
    }

    private func replaceAssets(for memo: Memo) throws {
        try deleteAssets(memoID: memo.id)

        for asset in MemoAsset.assets(in: memo) {
            try insertAssetRow(asset)
        }
    }

    private func insertAssetRow(_ asset: MemoAsset) throws {
        let statement = try prepare("""
        INSERT OR REPLACE INTO memo_assets (
            id, memo_id, kind, title, summary, uri, type_identifier, byte_count, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """)
        defer { sqlite3_finalize(statement) }

        try bind(asset, to: statement)
        try stepDone(statement)
    }

    private func deleteRevisions(memoID: UUID) throws {
        let statement = try prepare("DELETE FROM memo_revisions WHERE memo_id = ?;")
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, memoID.uuidString, -1, sqliteTransient)
        try stepDone(statement)
    }

    private func deleteAssets(memoID: UUID) throws {
        let statement = try prepare("DELETE FROM memo_assets WHERE memo_id = ?;")
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, memoID.uuidString, -1, sqliteTransient)
        try stepDone(statement)
    }

    private func deleteSearchIndex(rowID: Int64) throws {
        let statement = try prepare("DELETE FROM memos_fts WHERE rowid = ?;")
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, rowID)
        try stepDone(statement)
    }

    private func rowID(for id: UUID) throws -> Int64? {
        let statement = try prepare("SELECT rowid FROM memos WHERE id = ?;")
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        } else if result == SQLITE_DONE {
            return nil
        } else {
            throw DatabaseError.stepFailed(Self.errorMessage(database))
        }
    }

    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            try work()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.stepFailed(Self.errorMessage(database))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(Self.errorMessage(database))
        }
        return statement
    }

    private func bind(_ memo: Memo, to statement: OpaquePointer?) throws {
        let tagsData = try JSONEncoder().encode(memo.tags)
        let tagsJSON = String(decoding: tagsData, as: UTF8.self)

        sqlite3_bind_text(statement, 1, memo.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, memo.text, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, memo.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 4, memo.updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, tagsJSON, -1, sqliteTransient)
        sqlite3_bind_int(statement, 6, memo.isPinned ? 1 : 0)
        sqlite3_bind_int(statement, 7, memo.isArchived ? 1 : 0)
    }

    private func bind(_ revision: MemoRevision, to statement: OpaquePointer?) throws {
        let tagsData = try JSONEncoder().encode(revision.tags)
        let tagsJSON = String(decoding: tagsData, as: UTF8.self)

        sqlite3_bind_text(statement, 1, revision.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, revision.memoID.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, revision.text, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, tagsJSON, -1, sqliteTransient)
        sqlite3_bind_double(statement, 5, revision.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 6, revision.memoUpdatedAt.timeIntervalSince1970)
    }

    private func bind(_ asset: MemoAsset, to statement: OpaquePointer?) throws {
        sqlite3_bind_text(statement, 1, asset.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, asset.memoID.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, asset.kind.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, asset.title, -1, sqliteTransient)
        bindNullableText(asset.summary, to: statement, index: 5)
        bindNullableText(asset.uri, to: statement, index: 6)
        bindNullableText(asset.typeIdentifier, to: statement, index: 7)
        if let byteCount = asset.byteCount {
            sqlite3_bind_int64(statement, 8, Int64(byteCount))
        } else {
            sqlite3_bind_null(statement, 8)
        }
        sqlite3_bind_double(statement, 9, asset.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 10, asset.updatedAt.timeIntervalSince1970)
    }

    private func bindNullableText(_ text: String?, to statement: OpaquePointer?, index: Int32) {
        if let text = text {
            sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(Self.errorMessage(database))
        }
    }

    private func memo(from statement: OpaquePointer?) throws -> Memo {
        let idText = Self.columnText(statement, index: 0)
        guard let id = UUID(uuidString: idText) else {
            throw DatabaseError.invalidID(idText)
        }

        let text = Self.columnText(statement, index: 1)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
        let tagsJSON = Self.columnText(statement, index: 4)
        let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []
        let isPinned = sqlite3_column_int(statement, 5) == 1
        let isArchived = sqlite3_column_int(statement, 6) == 1

        return Memo(
            id: id,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt,
            tags: tags,
            isPinned: isPinned,
            isArchived: isArchived
        )
    }

    private func revision(from statement: OpaquePointer?) throws -> MemoRevision {
        let idText = Self.columnText(statement, index: 0)
        let memoIDText = Self.columnText(statement, index: 1)
        guard let id = UUID(uuidString: idText) else {
            throw DatabaseError.invalidID(idText)
        }
        guard let memoID = UUID(uuidString: memoIDText) else {
            throw DatabaseError.invalidID(memoIDText)
        }

        let text = Self.columnText(statement, index: 2)
        let tagsJSON = Self.columnText(statement, index: 3)
        let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
        let memoUpdatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))

        return MemoRevision(
            id: id,
            memoID: memoID,
            text: text,
            tags: tags,
            createdAt: createdAt,
            memoUpdatedAt: memoUpdatedAt
        )
    }

    private func asset(from statement: OpaquePointer?) throws -> MemoAsset {
        let idText = Self.columnText(statement, index: 0)
        let memoIDText = Self.columnText(statement, index: 1)
        let kindText = Self.columnText(statement, index: 2)
        guard let id = UUID(uuidString: idText) else {
            throw DatabaseError.invalidID(idText)
        }
        guard let memoID = UUID(uuidString: memoIDText) else {
            throw DatabaseError.invalidID(memoIDText)
        }
        guard let kind = MemoAssetKind(rawValue: kindText) else {
            throw DatabaseError.stepFailed("Unknown memo asset kind: \(kindText)")
        }

        let byteCount: Int?
        if sqlite3_column_type(statement, 7) == SQLITE_NULL {
            byteCount = nil
        } else {
            byteCount = Int(sqlite3_column_int64(statement, 7))
        }

        return MemoAsset(
            id: id,
            memoID: memoID,
            kind: kind,
            title: Self.columnText(statement, index: 3),
            summary: Self.columnOptionalText(statement, index: 4),
            uri: Self.columnOptionalText(statement, index: 5),
            typeIdentifier: Self.columnOptionalText(statement, index: 6),
            byteCount: byteCount,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
        )
    }

    private static func columnText(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: text)
    }

    private static func columnOptionalText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return columnText(statement, index: index)
    }

    private static func errorMessage(_ database: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private static func ftsQuery(from text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(ftsToken)
            .joined(separator: " ")
    }

    private static func ftsToken(_ token: String) -> String {
        let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")

        if token.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil {
            return "\(escaped)*"
        }

        return "\"\(escaped)\""
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
