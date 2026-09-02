import SwiftUI
import AppIntents

/// Five-level mood scale. Raw values map directly to PRD §9 `moodLevel` (1...5).
/// AppEnum conformance lets this be picked in a Widget's "Edit Widget" UI —
/// see SelectMoodLevelIntent for the lock-screen single-button widget.
enum MoodLevel: Int, Codable, CaseIterable, Identifiable, AppEnum {
    case veryUnpleasant = 1
    case unpleasant = 2
    case neutral = 3
    case pleasant = 4
    case veryPleasant = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .veryUnpleasant: "很难过"
        case .unpleasant: "难过"
        case .neutral: "一般"
        case .pleasant: "开心"
        case .veryPleasant: "很开心"
        }
    }

    /// PRD §8 diverging palette (cool = negative, warm = positive, gray = neutral).
    /// Dark-mode values are placeholders (mood_chart_mockup.html referenced in the PRD
    /// isn't in this repo) — swap in the real values once that mockup is available.
    var color: Color {
        switch self {
        case .veryUnpleasant: Color(light: "#1c5cab", dark: "#4a8fd9")
        case .unpleasant: Color(light: "#6da7ec", dark: "#86c0f7")
        case .neutral: Color(light: "#9c9b95", dark: "#b0afaa")
        case .pleasant: Color(light: "#f0a273", dark: "#f5b58c")
        case .veryPleasant: Color(light: "#eb6834", dark: "#ff8a52")
        }
    }

    /// PRD §8: how far the eraser circle sits from center, as a fraction of
    /// the icon's diameter. Smaller = more overlap between the two same-size
    /// circles = thinner remaining sliver; 0 = no bite at all ("一般").
    var crescentOffsetFraction: Double {
        switch self {
        case .veryUnpleasant, .veryPleasant: 0.32
        case .unpleasant, .pleasant: 0.52
        case .neutral: 0
        }
    }

    /// PRD §8: which side gets bitten. Confirmed against the reference art:
    /// sad levels erase from above (solid mass sits at the bottom), happy
    /// levels erase from below (solid mass sits at the top) — this is the
    /// opposite of literal frown/smile mouth-shape logic, but matches the
    /// approved reference. Re-verify visually if this changes.
    var crescentEraseDirection: Double {
        switch self {
        case .veryUnpleasant, .unpleasant: 1
        case .neutral: 0
        case .pleasant, .veryPleasant: -1
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "心情档位"

    static var caseDisplayRepresentations: [MoodLevel: DisplayRepresentation] = [
        .veryUnpleasant: "很难过",
        .unpleasant: "难过",
        .neutral: "一般",
        .pleasant: "开心",
        .veryPleasant: "很开心",
    ]
}
