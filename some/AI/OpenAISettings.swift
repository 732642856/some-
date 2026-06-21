import Combine
import Foundation

final class OpenAISettings: ObservableObject {
    static let shared = OpenAISettings()

    @Published private(set) var apiKey: String = ""
    @Published var responsesModel: String {
        didSet {
            defaults.set(responsesModel, forKey: Self.responsesModelKey)
        }
    }
    @Published var embeddingModel: String {
        didSet {
            defaults.set(embeddingModel, forKey: Self.embeddingModelKey)
        }
    }

    private static let responsesModelKey = "some.openai.responsesModel"
    private static let embeddingModelKey = "some.openai.embeddingModel"

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(service: "some", account: "openai-api-key")
    ) {
        self.defaults = defaults
        self.keychain = keychain
        responsesModel = defaults.string(forKey: Self.responsesModelKey) ?? "gpt-4o-mini"
        embeddingModel = defaults.string(forKey: Self.embeddingModelKey) ?? "text-embedding-3-small"
        apiKey = (try? keychain.read()) ?? ""
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIError.missingAPIKey
        }

        try keychain.save(trimmed)
        apiKey = trimmed
    }

    func clearAPIKey() throws {
        try keychain.delete()
        apiKey = ""
    }

    func makeClient() throws -> OpenAIClient {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIError.missingAPIKey
        }

        return OpenAIClient(
            apiKey: trimmed,
            responsesModel: responsesModel.trimmingCharacters(in: .whitespacesAndNewlines),
            embeddingModel: embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
