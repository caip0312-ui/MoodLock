import SwiftUI
import SwiftData
import Charts

/// PRD §8.1/§12 step 5, updated for the v17 revision (min→max range instead
/// of average-only on the heatmap and trend line, plus the optional
/// month-wide time-of-day scatter view).
struct ChartsView: View {
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var allEntries: [MoodEntry]
    @State private var selectedDay: SelectedDay?

    private var thisMonthEntries: [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        return allEntries.filter {
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private var distributionCounts: [(level: MoodLevel, count: Int)] {
        MoodLevel.allCases.map { level in
            (level, thisMonthEntries.filter { $0.moodLevel == level }.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ChartCard(title: "本月心情热力图") {
                    MonthHeatmapView(entries: thisMonthEntries) { day in
                        selectedDay = SelectedDay(date: day)
                    }
                }
                ChartCard(title: "本月心情趋势") {
                    if thisMonthEntries.isEmpty {
                        ContentUnavailableView("本月还没有记录", systemImage: "chart.xyaxis.line")
                    } else {
                        TrendLineChart(entries: thisMonthEntries)
                            .frame(height: 220)
                    }
                }
                ChartCard(title: "本月心情分布") {
                    if thisMonthEntries.isEmpty {
                        ContentUnavailableView("本月还没有记录", systemImage: "chart.bar")
                    } else {
                        Chart(distributionCounts, id: \.level) { item in
                            BarMark(
                                x: .value("档位", item.level.label),
                                y: .value("次数", item.count)
                            )
                            .foregroundStyle(item.level.color)
                        }
                        .frame(height: 220)
                    }
                }
                NavigationLink {
                    MonthMoodScatterView(entries: thisMonthEntries)
                } label: {
                    HStack {
                        Text("查看本月心情时刻分布（可选深度视图）")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("图表")
        .sheet(item: $selectedDay) { selection in
            NavigationStack {
                DayDetailView(
                    date: selection.date,
                    entries: entries(on: selection.date)
                )
            }
        }
    }

    private func entries(on day: Date) -> [MoodEntry] {
        let calendar = Calendar.current
        return allEntries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Manual card container standing in for `Form`'s `Section`. A `Form`/`List`
/// row hosting a `LazyVGrid` of `aspectRatio`-sized cells triggered UIKit's
/// self-sizing feedback loop (repeated ±1pt oscillation → fatal
/// "recursive layout loop" crash), so charts live in a plain ScrollView
/// instead of a List-backed container.
private struct ChartCard<Content: View>: View {
    // LocalizedStringKey, not String — a plain String property defeats
    // Text's automatic String Catalog lookup (Text(someStringVar) binds to
    // the verbatim initializer), even though every call site passes a
    // literal. LocalizedStringKey preserves the literal-ness through the
    // property so localization keeps working.
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// PRD §8.1 step 2 (v17 revision): one cell per day, filled with a gradient
/// from that day's *lowest* to *highest* mood level — not a single average
/// color. A single-record day (or a day where every entry is the same
/// level) degenerates to a solid color for free, since both gradient stops
/// are equal; only a day with real swings shows a visible gradient. This
/// replaces the earlier "average level, rounded" scheme, which silently
/// painted a wildly swinging day the same flat gray as a genuinely calm
/// one. Empty days are a plain gray placeholder. A small count badge in the
/// top-right corner appears only when a day has more than one entry.
private struct MonthHeatmapView: View {
    let entries: [MoodEntry]
    let onSelectDay: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    // Locale-aware instead of a hardcoded Chinese array — the index
    // ordering is always Sunday...Saturday regardless of the calendar's
    // firstWeekday, which matches the Sunday-anchored `weekday - 1` math
    // `monthDays` already does below.
    private var weekdaySymbols: [String] { calendar.veryShortWeekdaySymbols }

    private var monthDays: [Date?] {
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now),
              let firstDay = calendar.dateInterval(of: .day, for: monthInterval.start)?.start else {
            return []
        }
        let leadingBlanks = calendar.component(.weekday, from: firstDay) - 1
        let dayCount = calendar.range(of: .day, in: .month, for: now)?.count ?? 0
        let days: [Date?] = (0..<dayCount).map { calendar.date(byAdding: .day, value: $0, to: firstDay) }
        return Array(repeating: nil, count: leadingBlanks) + days
    }

    private var statsByDay: [Date: DayCellStat] {
        var grouped: [Date: [MoodLevel]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            grouped[day, default: []].append(entry.moodLevel)
        }
        return grouped.compactMapValues { levels in
            guard let minLevel = levels.min(by: { $0.rawValue < $1.rawValue }),
                  let maxLevel = levels.max(by: { $0.rawValue < $1.rawValue }) else {
                return nil
            }
            return DayCellStat(minLevel: minLevel, maxLevel: maxLevel, count: levels.count)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let day = calendar.startOfDay(for: date)
                        HeatmapDayCell(date: date, stat: statsByDay[day]) {
                            onSelectDay(day)
                        }
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DayCellStat {
    let minLevel: MoodLevel
    let maxLevel: MoodLevel
    let count: Int
}

private struct HeatmapDayCell: View {
    let date: Date
    let stat: DayCellStat?
    let onTap: () -> Void

    var body: some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        RoundedRectangle(cornerRadius: 4)
            .fill(fillStyle)
            .frame(height: 32)
            .overlay {
                Text("\(dayNumber)")
                    .font(.system(size: 9))
                    .foregroundStyle(stat == nil ? Color.secondary : Color.white)
            }
            .overlay(alignment: .topTrailing) {
                if let stat, stat.count > 1 {
                    Text("\(stat.count)")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .offset(x: 4, y: -4)
                }
            }
            .onTapGesture {
                if stat != nil { onTap() }
            }
    }

    private var fillStyle: AnyShapeStyle {
        guard let stat else { return AnyShapeStyle(Color.gray.opacity(0.15)) }
        return AnyShapeStyle(
            LinearGradient(colors: [stat.minLevel.color, stat.maxLevel.color], startPoint: .leading, endPoint: .trailing)
        )
    }
}

private struct DailyAverage: Identifiable {
    let date: Date
    let average: Double
    let minValue: Double
    let maxValue: Double
    var id: Date { date }
}

/// PRD §8.1 step 3 (v17 revision): daily-average trend line with a neutral
/// baseline, a warm/cool fill split above/below it, and — new in v17 — a
/// thin high/low rule at each point (a K-line-style range tick) spanning
/// that day's lowest to highest level. On a calm day the tick is short or
/// invisible; only a day with real swings shows a visibly long one. This is
/// the same "don't let the average alone stand for the day" fix as the
/// heatmap's min→max gradient — average and range together, not average
/// alone. Days with no entries are neither interpolated across nor filled —
/// the data is split into runs of consecutive calendar days, and each run
/// is rendered as its own chart series (via `.foregroundStyle(by:)` + an
/// explicit scale mapping every run's series key to the same color), which
/// stops Swift Charts from connecting a line/area across a gap day. The
/// high/low RuleMark doesn't need this treatment — it's drawn per-point
/// with a literal (non-`by:`) foregroundStyle, so it never joins across x
/// values in the first place. This is the same reason the heatmap doesn't
/// use `Form`: keeping presentation logic out of anything that silently
/// "helpfully" connects/sizes things across gaps.
private struct TrendLineChart: View {
    let entries: [MoodEntry]

    private static let baseline = 3.0
    private static let warmColor = Color(light: "#f0a273", dark: "#f5b58c")
    private static let coolColor = Color(light: "#6da7ec", dark: "#86c0f7")

    private var dailyAverages: [DailyAverage] {
        let calendar = Calendar.current
        var grouped: [Date: [Int]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            grouped[day, default: []].append(entry.moodLevel.rawValue)
        }
        return grouped.compactMap { day, rawValues in
            guard let minValue = rawValues.min(), let maxValue = rawValues.max() else { return nil }
            let average = Double(rawValues.reduce(0, +)) / Double(rawValues.count)
            return DailyAverage(date: day, average: average, minValue: Double(minValue), maxValue: Double(maxValue))
        }
        .sorted { $0.date < $1.date }
    }

    private var runs: [[DailyAverage]] {
        let calendar = Calendar.current
        var result: [[DailyAverage]] = []
        for point in dailyAverages {
            if let lastRun = result.last, let lastDate = lastRun.last?.date,
               calendar.date(byAdding: .day, value: 1, to: lastDate) == point.date {
                result[result.count - 1].append(point)
            } else {
                result.append([point])
            }
        }
        return result
    }

    private var seriesDomain: [String] {
        runs.indices.flatMap { ["line-\($0)", "warm-\($0)", "cool-\($0)"] }
    }

    private var seriesRange: [Color] {
        runs.indices.flatMap { _ in [Color.primary, Self.warmColor.opacity(0.35), Self.coolColor.opacity(0.35)] }
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("基准", Self.baseline))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(dash: [4, 4]))
            ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                ForEach(run) { point in
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        yStart: .value("下限", min(point.average, Self.baseline)),
                        yEnd: .value("基准", Self.baseline)
                    )
                    .foregroundStyle(by: .value("系列", "cool-\(index)"))
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        yStart: .value("基准", Self.baseline),
                        yEnd: .value("上限", max(point.average, Self.baseline))
                    )
                    .foregroundStyle(by: .value("系列", "warm-\(index)"))
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("心情", point.average)
                    )
                    .foregroundStyle(by: .value("系列", "line-\(index)"))
                    .symbol(.circle)
                    RuleMark(
                        x: .value("日期", point.date, unit: .day),
                        yStart: .value("当天最低", point.minValue),
                        yEnd: .value("当天最高", point.maxValue)
                    )
                    .foregroundStyle(.primary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
        }
        .chartForegroundStyleScale(domain: seriesDomain, range: seriesRange)
        .chartLegend(.hidden)
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5])
        }
    }
}

/// PRD §8.1 step 4: tapping a heatmap day opens this — every entry from that
/// day plotted on a 24-hour axis, connected by a plain timeline line with
/// each point colored by its own mood level (unlike the trend line, there's
/// no gap-run splitting needed here since every point belongs to one day).
private struct DayDetailView: View {
    let date: Date
    let entries: [MoodEntry]

    private var dayStart: Date { Calendar.current.startOfDay(for: date) }
    private var dayEnd: Date { Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if entries.isEmpty {
                    ContentUnavailableView("这天没有记录", systemImage: "clock")
                } else {
                    Chart {
                        ForEach(entries) { entry in
                            LineMark(
                                x: .value("时间", entry.timestamp),
                                y: .value("心情", entry.moodLevel.rawValue)
                            )
                            .foregroundStyle(.secondary.opacity(0.5))
                        }
                        ForEach(entries) { entry in
                            PointMark(
                                x: .value("时间", entry.timestamp),
                                y: .value("心情", entry.moodLevel.rawValue)
                            )
                            .foregroundStyle(entry.moodLevel.color)
                            .symbolSize(80)
                        }
                    }
                    .chartXScale(domain: dayStart...dayEnd)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYScale(domain: 1...5)
                    .chartYAxis {
                        AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                            AxisGridLine()
                            if let level = value.as(Int.self).flatMap(MoodLevel.init(rawValue:)) {
                                AxisValueLabel(level.label)
                            }
                        }
                    }
                    .frame(height: 220)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            HStack {
                                MoodCrescentIcon(level: entry.moodLevel, size: 20)
                                Text(entry.timestamp, format: .dateTime.hour().minute())
                                Spacer()
                                Text(entry.moodLevel.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(date.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// PRD §8.1 optional deep view (new in v17): every raw entry in the month
/// plotted at its actual date and time-of-day, with zero per-day
/// summarizing — the heatmap/trend line intentionally compress each day
/// down to a range, and this is the escape hatch for the information that
/// compression throws away. It's a third-layer entry (a link at the bottom
/// of the chart list), not something shown on the first screen — a whole
/// month of un-summarized points is the "more crowded" tradeoff the PRD
/// explicitly accepts for this view alone.
private struct MonthMoodScatterView: View {
    let entries: [MoodEntry]

    private var monthRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            return now...now
        }
        return interval.start...interval.end
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if entries.isEmpty {
                    ContentUnavailableView("本月还没有记录", systemImage: "chart.dots.scatter")
                } else {
                    Chart(entries) { entry in
                        PointMark(
                            x: .value("日期", Calendar.current.startOfDay(for: entry.timestamp), unit: .day),
                            y: .value("时间", hourOfDay(entry.timestamp))
                        )
                        .foregroundStyle(entry.moodLevel.color)
                        .symbolSize(50)
                    }
                    .chartXScale(domain: monthRange)
                    .chartYScale(domain: 0...24)
                    .chartYAxis {
                        AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                            AxisGridLine()
                            if let hour = value.as(Int.self) {
                                AxisValueLabel("\(hour):00")
                            }
                        }
                    }
                    .frame(height: 340)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("心情时刻分布")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hourOfDay(_ date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour) + Double(minute) / 60
    }
}

#Preview {
    NavigationStack {
        ChartsView()
    }
    .modelContainer(for: MoodEntry.self, inMemory: true)
}
