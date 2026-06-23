import CryptoKit
import Foundation
import NaturalLanguage

struct SemanticMemoResult: Identifiable, Equatable {
    let memo: Memo
    let score: Double
    let matchedTerms: [String]

    init(memo: Memo, score: Double, matchedTerms: [String] = []) {
        self.memo = memo
        self.score = score
        self.matchedTerms = matchedTerms
    }

    var id: UUID { memo.id }

    var percentage: Int {
        max(0, min(100, Int((score * 100).rounded())))
    }
}

struct SemanticEmbeddingCache: Sendable {
    private var storage: [String: Entry] = [:]
    private var accessCounter = 0
    private let maxEntryCount: Int

    init(snapshot: Snapshot = Snapshot(), maxEntryCount: Int = 1_000) {
        storage = snapshot.entries
        accessCounter = snapshot.entries.values.map(\.lastAccessedAt).max() ?? 0
        self.maxEntryCount = max(1, maxEntryCount)
        pruneIfNeeded()
    }

    mutating func lookup(inputs: [String], modelID: String) -> Lookup {
        let requests: [Request] = inputs.map { input in
            let normalizedInput = normalizedInput(input)
            let normalizedModelID = normalizedModelID(modelID)
            return Request(
                input: normalizedInput,
                modelID: normalizedModelID,
                cacheKey: cacheKey(input: normalizedInput, modelID: normalizedModelID)
            )
        }
        var missingRequests: [Request] = []
        var seenMissing = Set<Request>()
        var embeddings: [[Double]?] = []
        requests.forEach { request in
            guard var entry = storage[request.cacheKey] else {
                if !request.input.isEmpty, seenMissing.insert(request).inserted {
                    missingRequests.append(request)
                }
                embeddings.append(nil)
                return
            }
            entry.lastAccessedAt = nextAccessCounter()
            storage[request.cacheKey] = entry
            embeddings.append(entry.embedding)
        }

        return Lookup(
            embeddings: embeddings,
            missingRequests: missingRequests
        )
    }

    mutating func store(_ embeddings: [[Double]], for requests: [Request]) throws {
        guard embeddings.count == requests.count else {
            throw AIError.invalidResponse
        }

        zip(requests, embeddings).forEach { request, embedding in
            storage[request.cacheKey] = Entry(
                embedding: embedding,
                lastAccessedAt: nextAccessCounter()
            )
        }
        pruneIfNeeded()
    }

    func snapshot() -> Snapshot {
        Snapshot(entries: storage)
    }

    mutating func removeAll() {
        storage.removeAll()
    }

    struct Snapshot: Codable, Equatable, Sendable {
        var entries: [String: Entry]

        init(entries: [String: Entry] = [:]) {
            self.entries = entries
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let entries = try? container.decode([String: Entry].self, forKey: .entries) {
                self.entries = entries
                return
            }
            let legacyEntries = try container.decode([String: [Double]].self, forKey: .entries)
            entries = legacyEntries.mapValues { embedding in
                Entry(embedding: embedding, lastAccessedAt: 0)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case entries
        }
    }

    struct Entry: Codable, Equatable, Sendable {
        let embedding: [Double]
        var lastAccessedAt: Int
    }

    struct Lookup: Sendable {
        let embeddings: [[Double]?]
        let missingRequests: [Request]

        var missingInputs: [String] {
            missingRequests.map(\.input)
        }
    }

    struct Request: Hashable, Sendable {
        let input: String
        let modelID: String
        fileprivate let cacheKey: String
    }

    private func normalizedInput(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedModelID(_ modelID: String) -> String {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "text-embedding-3-small" : trimmed
    }

    private func cacheKey(input: String, modelID: String) -> String {
        let payload = "\(modelID)\u{1F}some.semantic.embedding.v1\u{1F}\(input)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        return "\(modelID)#\(fingerprint)"
    }

    private mutating func nextAccessCounter() -> Int {
        accessCounter += 1
        return accessCounter
    }

    private mutating func pruneIfNeeded() {
        guard storage.count > maxEntryCount else { return }
        let overflowCount = storage.count - maxEntryCount
        let entriesToRemove = storage
            .sorted { lhs, rhs in
                if lhs.value.lastAccessedAt == rhs.value.lastAccessedAt {
                    return lhs.key < rhs.key
                }
                return lhs.value.lastAccessedAt < rhs.value.lastAccessedAt
            }
            .prefix(overflowCount)

        entriesToRemove.forEach { entry in
            storage.removeValue(forKey: entry.key)
        }
    }
}

struct SemanticEmbeddingDiskCache: Sendable {
    let fileURL: URL

    init(
        directory: URL = SharedMemoStorage.storageDirectory()
            .appendingPathComponent("AICache", isDirectory: true),
        filename: String = "semantic-embeddings.json"
    ) {
        fileURL = directory.appendingPathComponent(filename, isDirectory: false)
    }

    func load() -> SemanticEmbeddingCache.Snapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(File.self, from: data),
              file.version == Self.currentVersion else {
            return SemanticEmbeddingCache.Snapshot()
        }
        return file.snapshot
    }

    var summary: Summary {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let byteCount = attributes[.size] as? NSNumber else {
            return Summary(entryCount: 0, byteCount: 0)
        }
        return Summary(
            entryCount: load().entries.count,
            byteCount: byteCount.intValue
        )
    }

    func save(_ snapshot: SemanticEmbeddingCache.Snapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let file = File(version: Self.currentVersion, snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: [.atomic])
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private static let currentVersion = 1

    struct Summary: Equatable, Sendable {
        let entryCount: Int
        let byteCount: Int
    }

    private struct File: Codable, Equatable, Sendable {
        let version: Int
        let snapshot: SemanticEmbeddingCache.Snapshot
    }
}

private actor SemanticEmbeddingCacheStore {
    private var cache: SemanticEmbeddingCache
    private let diskCache: SemanticEmbeddingDiskCache

    init(diskCache: SemanticEmbeddingDiskCache = SemanticEmbeddingDiskCache()) {
        self.diskCache = diskCache
        cache = SemanticEmbeddingCache(snapshot: diskCache.load())
    }

    func lookup(inputs: [String], modelID: String) -> SemanticEmbeddingCache.Lookup {
        cache.lookup(inputs: inputs, modelID: modelID)
    }

    func store(_ embeddings: [[Double]], for requests: [SemanticEmbeddingCache.Request]) throws {
        try cache.store(embeddings, for: requests)
        try? diskCache.save(cache.snapshot())
    }

    func removeAll() throws {
        cache.removeAll()
        try diskCache.remove()
    }
}

enum SemanticSearchEngine {
    private static let embeddingCacheStore = SemanticEmbeddingCacheStore()

    static func localSearch(
        query: String,
        memos: [Memo],
        limit: Int = 8,
        excluding excludedID: UUID? = nil
    ) -> [SemanticMemoResult] {
        let queryTerms = localSearchTerms(in: query)
        guard !queryTerms.isEmpty else {
            return []
        }
        let totalQueryWeight = queryTerms.values.reduce(0) { $0 + $1.weight }

        return memos
            .filter { !$0.isArchived }
            .filter { $0.id != excludedID }
            .compactMap { memo -> SemanticMemoResult? in
                let memoTerms = localSearchTerms(in: memo.text)
                guard !memoTerms.isEmpty else {
                    return nil
                }

                let sharedTerms = queryTerms.keys.filter { memoTerms[$0] != nil }
                guard !sharedTerms.isEmpty else {
                    return nil
                }

                let sharedWeight = sharedTerms.reduce(0) { partial, key in
                    partial + min(queryTerms[key]?.weight ?? 0, memoTerms[key]?.weight ?? 0)
                }
                let memoWeight = memoTerms.values.reduce(0) { $0 + $1.weight }
                let coverage = sharedWeight / totalQueryWeight
                let density = sharedWeight / memoWeight
                let score = min(1, (coverage * 0.75) + (density * 0.25))
                let matchedTerms = visibleMatchedTerms(
                    from: sharedTerms.compactMap { queryTerms[$0] }
                )
                return SemanticMemoResult(memo: memo, score: score, matchedTerms: matchedTerms)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.memo.createdAt > rhs.memo.createdAt
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    static func search(
        query: String,
        memos: [Memo],
        client: OpenAIClient,
        limit: Int = 8,
        excluding excludedID: UUID? = nil
    ) async throws -> [SemanticMemoResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIError.emptyInput
        }

        let candidates = memos
            .filter { !$0.isArchived }
            .filter { $0.id != excludedID }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !candidates.isEmpty else {
            return []
        }

        let embeddings = try await cachedSearchEmbeddings(
            query: trimmed,
            candidateTexts: candidates.map(\.text),
            modelID: client.normalizedEmbeddingModel,
            client: client
        )

        return zip(candidates, embeddings.candidates)
            .map { memo, embedding in
                SemanticMemoResult(
                    memo: memo,
                    score: cosineSimilarity(embeddings.query, embedding)
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.memo.createdAt > rhs.memo.createdAt
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    static func clearEmbeddingCache() async {
        try? await embeddingCacheStore.removeAll()
    }

    static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return 0
        }

        let dot = zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 }
        let lhsMagnitude = sqrt(lhs.reduce(0) { $0 + $1 * $1 })
        let rhsMagnitude = sqrt(rhs.reduce(0) { $0 + $1 * $1 })

        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            return 0
        }

        return dot / (lhsMagnitude * rhsMagnitude)
    }

    private static func localSearchTerms(in text: String) -> [String: LocalSearchTerm] {
        let separators = CharacterSet(charactersIn: " \n\t，。！？、；：,.!?;:()（）[]【】<>《》\"“”'‘’")
        let lowercasedText = text.lowercased()
        let rawTerms = lowercasedText
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var terms: [String: LocalSearchTerm] = [:]
        rawTerms.forEach { term in
            if term.hasPrefix("#") {
                let tag = String(term.dropFirst())
                insertLocalSearchTerm(key: "tag:\(tag)", display: "#\(tag)", weight: 2.2, into: &terms)
                insertLocalSearchTerm(key: tag, display: tag, weight: 1.4, into: &terms)
                return
            }

            guard term.count >= 2 else { return }
            insertLocalSearchTerm(key: term, display: term, weight: 1.4, into: &terms)

            if term.count >= 4, containsCompactScript(in: term) {
                let characters = Array(term)
                for index in 0..<(characters.count - 1) {
                    let fragment = String(characters[index...(index + 1)])
                    insertLocalSearchTerm(key: fragment, display: fragment, weight: 0.45, into: &terms)
                }
            }
        }

        naturalLanguageTokens(in: lowercasedText).forEach { token in
            guard token.count >= 2 else { return }
            insertLocalSearchTerm(key: token, display: token, weight: 1.1, into: &terms)
        }

        return terms
    }

    private static func naturalLanguageTokens(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { return true }
            tokens.append(token)
            return true
        }
        return tokens
    }

    private static func insertLocalSearchTerm(
        key: String,
        display: String,
        weight: Double,
        into terms: inout [String: LocalSearchTerm]
    ) {
        if let existing = terms[key], existing.weight >= weight {
            return
        }
        terms[key] = LocalSearchTerm(display: display, weight: weight)
    }

    private static func visibleMatchedTerms(from terms: [LocalSearchTerm]) -> [String] {
        var seenDisplays = Set<String>()
        var tagDisplays = Set<String>()
        let hasStrongTerms = terms.contains { $0.weight >= 1 }

        return terms
            .sorted()
            .compactMap { term in
                guard !hasStrongTerms || term.weight >= 1 else {
                    return nil
                }

                let normalizedDisplay = term.display.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedDisplay.isEmpty else {
                    return nil
                }

                if normalizedDisplay.hasPrefix("#") {
                    tagDisplays.insert(String(normalizedDisplay.dropFirst()))
                } else if tagDisplays.contains(normalizedDisplay) {
                    return nil
                }

                guard seenDisplays.insert(normalizedDisplay).inserted else {
                    return nil
                }

                return normalizedDisplay
            }
    }

    private static func containsCompactScript(in term: String) -> Bool {
        term.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }

    private struct LocalSearchTerm: Comparable {
        let display: String
        let weight: Double

        static func < (lhs: LocalSearchTerm, rhs: LocalSearchTerm) -> Bool {
            if lhs.weight == rhs.weight {
                return lhs.display < rhs.display
            }
            return lhs.weight > rhs.weight
        }
    }

    private static func cachedSearchEmbeddings(
        query: String,
        candidateTexts: [String],
        modelID: String,
        client: OpenAIClient
    ) async throws -> (query: [Double], candidates: [[Double]]) {
        var lookup = await embeddingCacheStore.lookup(inputs: candidateTexts, modelID: modelID)
        let fetchedEmbeddings = try await client.embed([query] + lookup.missingInputs)
        guard let queryEmbedding = fetchedEmbeddings.first else {
            throw AIError.invalidResponse
        }

        let fetchedCandidateEmbeddings = Array(fetchedEmbeddings.dropFirst())
        if !lookup.missingRequests.isEmpty {
            try await embeddingCacheStore.store(
                fetchedCandidateEmbeddings,
                for: lookup.missingRequests
            )
            lookup = await embeddingCacheStore.lookup(inputs: candidateTexts, modelID: modelID)
        }

        let embeddings = lookup.embeddings.compactMap { $0 }
        guard embeddings.count == candidateTexts.count else {
            throw AIError.invalidResponse
        }
        return (queryEmbedding, embeddings)
    }
}
