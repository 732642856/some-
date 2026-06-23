import Foundation

struct SemanticMemoResult: Identifiable, Equatable {
    let memo: Memo
    let score: Double

    var id: UUID { memo.id }

    var percentage: Int {
        max(0, min(100, Int((score * 100).rounded())))
    }
}

enum SemanticSearchEngine {
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

        return memos
            .filter { !$0.isArchived }
            .filter { $0.id != excludedID }
            .compactMap { memo -> SemanticMemoResult? in
                let memoTerms = localSearchTerms(in: memo.text)
                guard !memoTerms.isEmpty else {
                    return nil
                }

                let sharedTerms = queryTerms.intersection(memoTerms)
                guard !sharedTerms.isEmpty else {
                    return nil
                }

                let coverage = Double(sharedTerms.count) / Double(queryTerms.count)
                let density = Double(sharedTerms.count) / Double(memoTerms.count)
                let score = min(1, (coverage * 0.75) + (density * 0.25))
                return SemanticMemoResult(memo: memo, score: score)
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

        let embeddings = try await client.embed([trimmed] + candidates.map(\.text))
        guard let queryEmbedding = embeddings.first else {
            throw AIError.invalidResponse
        }

        return zip(candidates, embeddings.dropFirst())
            .map { memo, embedding in
                SemanticMemoResult(
                    memo: memo,
                    score: cosineSimilarity(queryEmbedding, embedding)
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

    private static func localSearchTerms(in text: String) -> Set<String> {
        let separators = CharacterSet(charactersIn: " \n\t，。！？、；：,.!?;:()（）[]【】<>《》\"“”'‘’")
        let rawTerms = text
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var terms = Set<String>()
        rawTerms.forEach { term in
            guard !term.hasPrefix("#") else {
                terms.insert(String(term.dropFirst()))
                return
            }
            guard term.count >= 2 else { return }
            terms.insert(term)

            if term.count >= 4 {
                let characters = Array(term)
                for index in 0..<(characters.count - 1) {
                    terms.insert(String(characters[index...(index + 1)]))
                }
            }
        }
        return terms
    }
}
