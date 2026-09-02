import Foundation
import SwiftData

/// PRD §7 local anomaly rule: ≥3 same-source entries within 60s spanning
/// ≥2 distinct mood levels get flagged — never blocks the write, only
/// surfaces a dismissible banner in the history list. PRD v20 §7 adds a
/// second, independent rule ahead of it: a same-source, same-level tap
/// within 10 minutes of the last one merges into it instead of creating a
/// new row — this is the "venting repeat-tap" case (someone mashing the
/// same button as a stress outlet), the opposite failure mode from the
/// anomaly rule's "different levels in a burst" case. Because a merge never
/// inserts a new row, the fetch that finds a merge candidate keeps matching
/// the *original* row of the streak for as long as taps keep arriving
/// within 10 minutes of it — so the anchor point never drifts and its
/// timestamp is never touched, exactly as PRD v20 specifies ("只保留第一条
/// 记录,时间戳不更新"). Callers don't need to branch on the outcome: UI
/// feedback (haptics/animation) fires unconditionally at the call site
/// regardless of whether this ends up merging or actually inserting.
enum AnomalyDetector {
    static let anomalyWindow: TimeInterval = 60
    static let minCount = 3
    static let minDistinctLevels = 2
    static let mergeWindow: TimeInterval = 600

    static func insert(_ entry: MoodEntry, into context: ModelContext) {
        // Only the timestamp range goes into the #Predicate — SwiftData's
        // predicate translation is unreliable comparing custom enum
        // attributes directly, so source/level filtering happens in-memory.
        // One fetch at the wider (merge) window covers both checks below.
        let fetchStart = entry.timestamp.addingTimeInterval(-mergeWindow)
        let upperBound = entry.timestamp
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { candidate in
                candidate.timestamp >= fetchStart && candidate.timestamp <= upperBound
            }
        )
        let recentAnySource = (try? context.fetch(descriptor)) ?? []
        let recentSameSource = recentAnySource.filter { $0.source == entry.source }

        let hasRecentSameLevel = recentSameSource.contains { $0.moodLevel == entry.moodLevel }
        if hasRecentSameLevel {
            return
        }

        context.insert(entry)

        let anomalyWindowStart = entry.timestamp.addingTimeInterval(-anomalyWindow)
        let recentForAnomaly = recentSameSource.filter { $0.timestamp >= anomalyWindowStart } + [entry]
        let distinctLevels = Set(recentForAnomaly.map(\.moodLevel))
        guard recentForAnomaly.count >= minCount, distinctLevels.count >= minDistinctLevels else { return }

        for candidate in recentForAnomaly {
            candidate.flaggedAnomalous = true
        }
    }
}
