import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Home Screen: 5-in-a-row (systemMedium) / Lock Screen: 3-in-a-row (accessoryRectangular)

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct MoodLockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                // PRD v20 §6: cut to 3 coarse levels (难过/一般/开心) — HIG's
                // published accessoryRectangular specs put this slot at
                // 153–172pt wide depending on device, so 5 segments can
                // never clear Apple's 44pt tap-target guideline (34pt at
                // best) but 3 comfortably can on every current iPhone.
                // Equal-width frames (not fixed spacing) is what actually
                // guarantees that across the different per-device widths.
                // No text labels — system forces monochrome here, so shape
                // + haptics are the only reliable encoding (PRD §8).
                MoodPickerRow(
                    levels: [.unpleasant, .neutral, .pleasant],
                    source: .lockScreenWidget,
                    circleSize: 34,
                    showLabels: false
                )
            default: // .systemMedium
                // PRD v20 §6: desktop widget moved from systemSmall (square)
                // to systemMedium specifically so the full 5 levels have
                // room to breathe (~364×170pt vs. a cramped square), and so
                // there's space for the text labels PRD §8 restored —
                // desktop isn't lock-screen-constrained (full color, no
                // width crunch), so it carries the full shape+color+text
                // encoding.
                MoodPickerRow(
                    levels: MoodLevel.allCases,
                    source: .homeScreenWidget,
                    circleSize: 40,
                    showLabels: true
                )
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// PRD §6: fixed tap targets, no continuous drag — each circle is its own
/// Button(intent:) so a tap writes immediately without opening the app.
/// Equal-width `.frame(maxWidth: .infinity)` segments (not a fixed
/// spacing/circleSize pair) is what makes the lock-screen 3-level layout
/// actually clear 44pt on every device width without hand-tuning per size
/// class.
struct MoodPickerRow: View {
    let levels: [MoodLevel]
    let source: MoodSource
    let circleSize: CGFloat
    let showLabels: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels) { level in
                Button(intent: LogMoodIntent(moodLevel: level, source: source)) {
                    VStack(spacing: 4) {
                        MoodCrescentIcon(level: level, size: circleSize)
                        if showLabels {
                            Text(level.label)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(level.label)
            }
        }
    }
}

struct MoodLockWidget: Widget {
    let kind: String = "MoodLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoodLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MoodLock")
        .description("心情快速记录。")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

// MARK: - Lock Screen circular slot: single button, user picks which mood
// level to bind. accessoryCircular is far too small for 5 independent tap
// targets, so instead of a placeholder each instance is configurable:
// long-press → Edit Widget lets the user assign one MoodLevel to it. Users
// who want quick access to several levels just add several instances.
struct SelectMoodLevelIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择心情档位"
    static var description = IntentDescription("选择这个小组件要记录的心情档位")

    @Parameter(title: "心情档位", default: .neutral)
    var moodLevel: MoodLevel
}

struct SingleMoodEntry: TimelineEntry {
    let date: Date
    let moodLevel: MoodLevel
}

struct SingleMoodProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleMoodEntry {
        SingleMoodEntry(date: .now, moodLevel: .neutral)
    }

    func snapshot(for configuration: SelectMoodLevelIntent, in context: Context) async -> SingleMoodEntry {
        SingleMoodEntry(date: .now, moodLevel: configuration.moodLevel)
    }

    func timeline(for configuration: SelectMoodLevelIntent, in context: Context) async -> Timeline<SingleMoodEntry> {
        Timeline(entries: [SingleMoodEntry(date: .now, moodLevel: configuration.moodLevel)], policy: .never)
    }
}

struct MoodLockSingleWidgetEntryView: View {
    var entry: SingleMoodProvider.Entry

    var body: some View {
        Button(intent: LogMoodIntent(moodLevel: entry.moodLevel, source: .lockScreenWidget)) {
            GeometryReader { geo in
                MoodCrescentIcon(level: entry.moodLevel, size: min(geo.size.width, geo.size.height))
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityLabel(entry.moodLevel.label)
    }
}

struct MoodLockSingleWidget: Widget {
    // Bumped from "MoodLockSingleWidget": existing placed instances cache
    // their configuration parameter schema (the 5-case moodLevel picker) at
    // the time they were first added to the Lock Screen, tied to this kind
    // string. Reinstalling the app doesn't refresh that per-instance cache,
    // which is why an already-placed instance kept showing only the
    // `.neutral` default with no other options to pick from even after the
    // app's AppIntents metadata was confirmed correct at the build level.
    // Changing the kind forces old instances to go stale (they'll need to
    // be removed and re-added) so a fresh instance is guaranteed to read
    // the current schema instead of a possibly-outdated cached one.
    let kind: String = "MoodLockSingleWidgetV2"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMoodLevelIntent.self, provider: SingleMoodProvider()) { entry in
            MoodLockSingleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MoodLock 单档")
        .description("选择一个心情档位，固定放在锁屏上快速记录，长按可随时更换档位。")
        .supportedFamilies([.accessoryCircular])
    }
}
