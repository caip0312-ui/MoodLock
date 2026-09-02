import Foundation
import AVFoundation

/// Simple playback wrapper for listening back to a recorded note before
/// deciding whether to transcribe it (see MoodEntryDetailView).
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private var currentURL: URL?

    func togglePlayback(url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        if player == nil || currentURL != url {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            currentURL = url
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = true
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
