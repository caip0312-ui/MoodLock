import SwiftUI
import SwiftData

/// Homepage design follows the "Soft Blob Mascot" direction from the
/// MoodLock Homepage Directions canvas — warm gradient backdrop, a blob
/// mascot (MoodBlobView) colored by the most recent mood, and the 5
/// crescent mood buttons condensed into a card below it. This is an
/// explicit, user-requested departure from PRD §8's "no illustrated
/// mascot/character" rule; PRD.md itself is not edited here.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var allEntries: [MoodEntry]
    @State private var pulsingLevel: MoodLevel?

    private var lastLevel: MoodLevel? { allEntries.first?.moodLevel }

    /// PRD v20 §8: the backdrop follows the current mood color, but must
    /// read as "ambient tone" rather than "another data-carrying color" —
    /// so it's the mood hue pushed to low saturation / high brightness,
    /// never the raw icon color. Derived from the same `MoodLevel.color`
    /// everything else uses (not a second hardcoded palette), just with
    /// saturation cut to under a third and brightness pushed up, so it can
    /// never be confused with the vivid tone the crescent icons and charts
    /// use for the identical level.
    private var ambientBackgroundColors: [Color] {
        let base = lastLevel?.color ?? MoodLevel.neutral.color
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        UIColor(base).getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return [
            Color(hue: hue, saturation: sat * 0.16, brightness: min(bri + 0.34, 0.99)),
            Color(hue: hue, saturation: sat * 0.26, brightness: min(bri + 0.18, 0.97)),
            Color(hue: hue, saturation: sat * 0.36, brightness: min(bri + 0.04, 0.93)),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: ambientBackgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: lastLevel)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(light: "#f7bf95", dark: "#f7bf95").opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 130
                        )
                    )
                    .frame(width: 210, height: 210)
                    .position(x: 20, y: 60)

                VStack(spacing: 0) {
                    Spacer()

                    MoodBlobView(level: lastLevel, size: 180)

                    Spacer()

                    HStack(spacing: 0) {
                        ForEach(MoodLevel.allCases) { level in
                            MoodButton(level: level, isPulsing: pulsingLevel == level, size: 50) {
                                logMood(level)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            // PRD v20 §8.2: the Home Screen icon already shows "MoodLock"
            // once — repeating it as a nav title inside the app is
            // redundant, so no .navigationTitle here.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // PRD §8.2: "导航入口从文字改为图标形式,集中放置" — the three
                // entries live in one grouped cluster now, not split across
                // the leading/trailing corners.
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")

                    NavigationLink {
                        HistoryListView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("历史")

                    NavigationLink {
                        ChartsView()
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("图表")
                }
            }
        }
    }

    private func logMood(_ level: MoodLevel) {
        AnomalyDetector.insert(MoodEntry(moodLevel: level), into: modelContext)
        pulsingLevel = level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if pulsingLevel == level {
                pulsingLevel = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
