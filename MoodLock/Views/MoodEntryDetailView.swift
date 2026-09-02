import SwiftUI

/// PRD §3: reached by tapping a row in the history list — this is where
/// voice notes actually live, not a popup right after logging the mood.
struct MoodEntryDetailView: View {
    @Bindable var entry: MoodEntry
    @AppStorage("voiceRecordingEnabled") private var voiceRecordingEnabled = false

    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var micPermissionDenied = false

    /// Drives the entrance animation: the icon starts large and centered,
    /// then settles into its normal top-left spot as the label fades in.
    @State private var headerSettled = false

    private var hasVoiceNote: Bool { entry.audioURL != nil || entry.transcribedText != nil }

    /// Manual typing, kept separate from `transcribedText` (which is only
    /// ever written by SpeechTranscriber) so the two never get conflated.
    private var noteBinding: Binding<String> {
        Binding(
            get: { entry.note ?? "" },
            set: { entry.note = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    MoodCrescentIcon(level: entry.moodLevel, size: headerSettled ? 28 : 96)
                    if headerSettled {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.moodLevel.label).font(.headline)
                            Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: headerSettled ? .leading : .center)
                .padding(.vertical, headerSettled ? 0 : 20)
            }

            Section("文字备注") {
                TextField("写点什么…", text: noteBinding, axis: .vertical)
                    .lineLimit(3...8)
            }

            if voiceRecordingEnabled || hasVoiceNote {
                Section("语音备注") {
                    voiceSection
                }
            }
        }
        .navigationTitle("记录详情")
        .toolbar {
            if voiceRecordingEnabled && !hasVoiceNote {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleRecording) {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
                headerSettled = true
            }
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        if let text = entry.transcribedText {
            Text(text)
        } else if let audioURL = entry.audioURL {
            HStack {
                Button {
                    player.togglePlayback(url: audioURL)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                Text("原始录音")
                Spacer()
            }

            Button {
                transcribe(audioURL: audioURL)
            } label: {
                if isTranscribing {
                    ProgressView()
                } else {
                    Text("转文字归档")
                }
            }
            .disabled(isTranscribing)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } else {
            if micPermissionDenied {
                Text("没有麦克风权限，请到系统设置里开启。")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("点右上角的按钮开始录音。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            entry.audioURL = recorder.stop()
        } else {
            recorder.requestPermissionAndStart { granted in
                micPermissionDenied = !granted
            }
        }
    }

    private func transcribe(audioURL: URL) {
        isTranscribing = true
        errorMessage = nil
        Task {
            do {
                let text = try await SpeechTranscriber.transcribe(fileURL: audioURL)
                entry.transcribedText = text
                entry.audioURL = nil
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                // String(localized:), not a bare literal — errorMessage is a
                // stored String, and Text(errorMessage) below reads it as a
                // runtime value, which skips Text's automatic Catalog
                // lookup for literals.
                errorMessage = String(localized: "转文字失败，请重试，或保留原始录音。")
            }
            isTranscribing = false
        }
    }
}
