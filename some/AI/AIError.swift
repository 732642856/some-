import Foundation

enum AIError: LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置里保存 OpenAI API Key。"
        case .emptyInput:
            return "没有可发送给 AI 的内容。"
        case .invalidResponse:
            return "AI 返回内容无法解析。"
        case let .apiError(statusCode, message):
            return "OpenAI 请求失败（\(statusCode)）：\(message)"
        case let .keychainError(status):
            return "Keychain 操作失败：\(status)"
        }
    }
}
