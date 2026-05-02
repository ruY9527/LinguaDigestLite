import SwiftUI

struct RefreshLogView: View {
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFeedId: UUID?
    @State private var showingClearConfirmation = false

    private var filteredLogs: [RefreshLogEntry] {
        if let feedId = selectedFeedId {
            return viewModel.refreshLogs.filter { $0.feedId == feedId }
        }
        return viewModel.refreshLogs
    }

    private struct LogGroup: Identifiable {
        let date: String
        let logs: [RefreshLogEntry]
        var id: String { date }
    }

    private var groupedLogs: [LogGroup] {
        let grouped = Dictionary(grouping: filteredLogs) { log in
            log.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { LogGroup(date: $0.key, logs: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.refreshLogs.isEmpty {
                    emptyView
                } else {
                    logList
                }
            }
            .navigationTitle(L("nav.refreshLog"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.refreshLogs.isEmpty {
                        Button(L("action.clearAll"), role: .destructive) {
                            showingClearConfirmation = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.done")) { dismiss() }
                }
            }
            .alert(L("alert.clearLog"), isPresented: $showingClearConfirmation) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("common.clear"), role: .destructive) {
                    viewModel.clearAllRefreshLogs()
                }
            } message: {
                Text(L("alert.clearLogMsg"))
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(L("empty.noLogs"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L("empty.noLogsHint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        List {
            if !viewModel.feeds.isEmpty {
                Section(L("section.filterByFeed")) {
                    feedFilterBar
                }
            }

            ForEach(groupedLogs) { group in
                Section(group.date) {
                    ForEach(group.logs) { log in
                        LogRowView(log: log)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var feedFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: L("common.all"),
                    isSelected: selectedFeedId == nil,
                    action: { selectedFeedId = nil }
                )
                ForEach(viewModel.feeds) { feed in
                    FilterChip(
                        title: feed.title,
                        isSelected: selectedFeedId == feed.id,
                        action: { selectedFeedId = feed.id }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

private struct LogRowView: View {
    let log: RefreshLogEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(log.isSuccess ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.feedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if log.isSuccess {
                    Text(String(format: L("log.addedArticles"), log.addedCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(log.errorDetail)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }

                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
