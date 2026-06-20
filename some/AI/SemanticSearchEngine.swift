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
}
