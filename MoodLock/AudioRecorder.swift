import Foundation
import AVFoundation

/// PRD §4: voice recording is in-app only (Widget/lock screen can't get
/// microphone access — an extension-sandbox limitation, not a bug).
@Observable
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private(set) var isRecording = false
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestPermissionAndStart(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard granted else {
                    completion(false)
                    return
                }
                self?.start()
                completion(true)
            }
        }
    }

    private func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let recordingsDirectory = AppGroup.containerURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        let url = recordingsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder.delegate = self
        recorder.record()
        self.recorder = recorder
        self.recordingURL = url
        self.isRecording = true
    }

    /// Stops recording and returns the saved file's URL, or nil if nothing was recorded.
    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
        defer { recorder = nil }
        return recordingURL
    }

    /// Discards the in-progress recording without keeping the file.
    func cancel() {
        recorder?.stop()
        recorder?.deleteRecording()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
        recorder = nil
        recordingURL = nil
    }
}
