import Foundation
import SwiftData

/// PRD §9 data model. Fields beyond this step (audioURL, transcribedText,
/// skinImageURL, doodleData) are kept per the "data structure stays ahead of
/// the UI" principle in §1.1, even though nothing writes them yet.
@Model
final class MoodEntry {
    var id: UUID
    var timestamp: Date
    var moodLevel: MoodLevel
    var note: String?
    var audioURL: URL?
    var transcribedText: String?
    var source: MoodSource
    /// PRD §7: set by the local anomaly-detection rule (≥3 entries within 60s
    /// spanning ≥2 mood levels), not a confirmation gate — flagged entries are
    /// still stored and counted normally, only surfaced in a dismissible banner.
    var flaggedAnomalous: Bool
    var skinImageURL: URL?
    var doodleData: Data?

    init(
        moodLevel: MoodLevel,
        timestamp: Date = .now,
        source: MoodSource = .inApp,
        flaggedAnomalous: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.moodLevel = moodLevel
        self.source = source
        self.flaggedAnomalous = flaggedAnomalous
    }
}
