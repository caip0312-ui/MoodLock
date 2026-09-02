import AppIntents
import SwiftData
import WidgetKit

/// Runs in the widget extension process when a mood circle is tapped —
/// writes straight into the shared App Group store so the main app sees it
/// on next read, no manual sync needed.
struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "记录心情"
    static var description = IntentDescription("从 Widget 记录一次心情等级")

    @Parameter(title: "心情等级")
    var moodLevelRawValue: Int

    @Parameter(title: "来源")
    var sourceRawValue: String

    init() {
        self.moodLevelRawValue = MoodLevel.neutral.rawValue
        self.sourceRawValue = MoodSource.homeScreenWidget.rawValue
    }

    init(moodLevel: MoodLevel, source: MoodSource) {
        self.moodLevelRawValue = moodLevel.rawValue
        self.sourceRawValue = source.rawValue
    }

    func perform() async throws -> some IntentResult {
        let level = MoodLevel(rawValue: moodLevelRawValue) ?? .neutral
        let source = MoodSource(rawValue: sourceRawValue) ?? .homeScreenWidget

        let configuration = ModelConfiguration(url: AppGroup.modelStoreURL)
        let container = try ModelContainer(for: MoodEntry.self, configurations: configuration)
        let context = ModelContext(container)

        // PRD §7: no confirmation gate — every source writes straight to
        // history; the §7 anomaly rule runs locally at insert time.
        AnomalyDetector.insert(MoodEntry(moodLevel: level, source: source), into: context)
        try context.save()

        WidgetCenter.shared.reloadTimelines(ofKind: "MoodLockWidget")
        return .result()
    }
}
