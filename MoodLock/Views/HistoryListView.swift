import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @Query(filter: #Predicate<MoodEntry> { $0.flaggedAnomalous })
    private var flaggedEntries: [MoodEntry]

    @State private var showingFlagged = false

    var body: some View {
        List {
            if !flaggedEntries.isEmpty {
                AnomalyBanner(count: flaggedEntries.count) {
                    showingFlagged = true
                } onDismiss: {
                    for entry in flaggedEntries {
                        entry.flaggedAnomalous = false
                    }
                }
            }
            ForEach(entries) { entry in
                NavigationLink {
                    MoodEntryDetailView(entry: entry)
                } label: {
                    MoodHistoryRow(entry: entry)
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("还没有记录", systemImage: "circle.dashed")
            }
        }
        .navigationTitle("历史记录")
        .sheet(isPresented: $showingFlagged) {
            FlaggedEntriesView(entries: flaggedEntries)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

private struct MoodHistoryRow: View {
    let entry: MoodEntry

    var body: some View {
        HStack(spacing: 12) {
            MoodCrescentIcon(level: entry.moodLevel, size: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.moodLevel.label)
                Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// PRD §7: swipe-to-delete is the baseline error-recovery mechanism — no
/// confirmation gate, no dedicated review flow, just an easy undo.
private struct AnomalyBanner: View {
    let count: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("检测到 \(count) 条心情记录短时间内变化异常")
                    .font(.subheadline)
                Text("点击查看")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .listRowBackground(Color.yellow.opacity(0.15))
    }
}

private struct FlaggedEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let entries: [MoodEntry]

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        MoodEntryDetailView(entry: entry)
                    } label: {
                        MoodHistoryRow(entry: entry)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("没有异常记录", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("疑似异常记录")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}
