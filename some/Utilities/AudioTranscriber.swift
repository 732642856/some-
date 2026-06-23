import Foundation
import Speech

enum AudioTranscriber {
    static func transcribe(fileURL: URL, language: AudioTranscriptionLanguage = .automatic) async throws -> String {
        try await transcribe(fileURL: fileURL, locale: language.locale ?? .current)
    }

    static func transcribe(fileURL: URL, locale: Locale = .current) async throws -> String {
        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            let continuationBox = RecognitionContinuationBox(continuation: continuation)
            let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuationBox.resume(with: .failure(error))
                    return
                }

                guard let result = result, result.isFinal else { return }

                let transcript = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if transcript.isEmpty {
                    continuationBox.resume(with: .failure(TranscriptionError.emptyResult))
                } else {
                    continuationBox.resume(with: .success(transcript))
                }
            }
            continuationBox.recognitionTask = recognitionTask
        }
    }

    static func memoText(
        for attachment: SharedAttachment,
        transcript: String,
        language: AudioTranscriptionLanguage = .automatic
    ) -> String? {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            return nil
        }

        let title = language == .automatic
            ? "语音转写：\(attachment.displayName)"
            : "语音转写：\(attachment.displayName)（\(language.title)）"

        return """
        \(title)

        \(cleanedTranscript)
        """
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case onDeviceRecognitionUnavailable
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "没有语音识别权限。"
            case .recognizerUnavailable:
                return "当前语音识别服务不可用。"
            case .onDeviceRecognitionUnavailable:
                return "当前设备或语言不支持本机语音转写。"
            case .emptyResult:
                return "没有识别出可保存的文字。"
            }
        }
    }

    private final class RecognitionContinuationBox {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<String, Error>?
        var recognitionTask: SFSpeechRecognitionTask?

        init(continuation: CheckedContinuation<String, Error>) {
            self.continuation = continuation
        }

        func resume(with result: Result<String, Error>) {
            lock.lock()
            guard let continuation = continuation else {
                lock.unlock()
                return
            }
            self.continuation = nil
            let task = recognitionTask
            lock.unlock()

            task?.cancel()
            continuation.resume(with: result)
        }
    }
}

enum AudioTranscriptionLanguage: String, CaseIterable, Identifiable {
    case automatic
    case mandarin
    case english
    case cantonese
    case japanese
    case korean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .mandarin: return "普通话"
        case .english: return "英语"
        case .cantonese: return "粤语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        }
    }

    var locale: Locale? {
        switch self {
        case .automatic: return nil
        case .mandarin: return Locale(identifier: "zh_CN")
        case .english: return Locale(identifier: "en_US")
        case .cantonese: return Locale(identifier: "zh_HK")
        case .japanese: return Locale(identifier: "ja_JP")
        case .korean: return Locale(identifier: "ko_KR")
        }
    }

    static func value(for rawValue: String) -> AudioTranscriptionLanguage {
        AudioTranscriptionLanguage(rawValue: rawValue) ?? .automatic
    }
}
