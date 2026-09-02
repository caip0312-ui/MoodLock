import Foundation
import Speech

/// PRD §3/§4: "转文字归档" — turns a recorded note into text, in-app only.
enum SpeechTranscriber {
    enum TranscribeError: Error {
        case permissionDenied
        case recognizerUnavailable
    }

    static func transcribe(fileURL: URL) async throws -> String {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else { throw TranscribeError.permissionDenied }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            throw TranscribeError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
