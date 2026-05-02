//
//  FeedListView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// RSS源列表视图
struct FeedListView: View {
    @ObservedObject var viewModel: FeedViewModel

    @State private var showingAddFeed: Bool = false
    @State private var newFeedTitle: String = ""
    @State private var newFeedUrl: String = ""
    @State private var showingErrorMessage: Bool = false
    @State private var showingRebuildConfirmation: Bool = false
    @State private var showingRefreshLog: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.feeds.isEmpty {
                    emptyStateView
                } else {
                    feedList
                }
            }
            .navigationTitle(L("nav.feeds"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showingRebuildConfirmation = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.circle")
                        }

                        Button {
                            viewModel.loadRefreshLogs()
                            showingRefreshLog = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFeed = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshAllFeeds()
            }
            .sheet(isPresented: $showingAddFeed) {
                AddFeedSheet(
                    title: $newFeedTitle,
                    url: $newFeedUrl,
                    onAdd: {
                        Task {
                            await viewModel.addFeed(title: newFeedTitle, feedUrl: newFeedUrl)
                        }
                        showingAddFeed = false
                        newFeedTitle = ""
                        newFeedUrl = ""
                    },
                    onCancel: {
                        showingAddFeed = false
                        newFeedTitle = ""
                        newFeedUrl = ""
                    }
                )
            }
            .sheet(isPresented: $showingRefreshLog) {
                RefreshLogView(viewModel: viewModel)
            }
            .alert(L("common.error"), isPresented: $showingErrorMessage) {
                Button(L("common.ok"), role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? L("error.unknown"))
            }
            .alert(L("action.resubscribeAll"), isPresented: $showingRebuildConfirmation) {
                Button(L("common.cancel"), role: .cancel) { }
                Button(L("action.resubscribe"), role: .destructive) {
                    Task {
                        await viewModel.rebuildAllBuiltInSubscriptions()
                    }
                }
            } message: {
                Text(L("alert.resubscribeMsg"))
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showingErrorMessage = newValue != nil
            }
        }
    }

    /// RSS源列表
    private var feedList: some View {
        List {
            if let summary = viewModel.lastRefreshSummary {
                Section {
                    Button {
                        viewModel.loadRefreshLogs()
                        showingRefreshLog = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.lastRefreshHadFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(viewModel.lastRefreshHadFailure ? .orange : .green)
                            Text(summary)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // 内置RSS源
            Section(L("section.builtInFeeds")) {
                ForEach(viewModel.builtInFeeds, id: \.id) { feed in
                    let refreshing = viewModel.isRefreshing(feed.id)
                    FeedRowView(
                        feed: feed,
                        lastRefreshLog: viewModel.latestRefreshLog(for: feed.id),
                        isRefreshing: refreshing,
                        onToggleActive: {
                            viewModel.toggleFeedActive(feed)
                        }
                    )
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await viewModel.refreshFeed(feed) }
                        } label: {
                            Label(refreshing ? L("action.refreshing") : L("action.refresh"), systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                        .disabled(refreshing)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewModel.toggleFeedActive(feed)
                        } label: {
                            Label(feed.isActive ? L("action.disable") : L("action.enable"), systemImage: feed.isActive ? "pause" : "play")
                        }
                        .tint(feed.isActive ? .gray : .green)
                        .disabled(refreshing)
                    }
                }
            }

            // 用户添加的RSS源
            if !viewModel.userFeeds.isEmpty {
                Section(L("section.myFeeds")) {
                    ForEach(viewModel.userFeeds, id: \.id) { feed in
                        let refreshing = viewModel.isRefreshing(feed.id)
                        FeedRowView(
                            feed: feed,
                            lastRefreshLog: viewModel.latestRefreshLog(for: feed.id),
                            isRefreshing: refreshing,
                            onToggleActive: {
                                viewModel.toggleFeedActive(feed)
                            }
                        )
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.refreshFeed(feed) }
                            } label: {
                                Label(refreshing ? L("action.refreshing") : L("action.refresh"), systemImage: "arrow.clockwise")
                            }
                            .tint(.blue)
                            .disabled(refreshing)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewModel.toggleFeedActive(feed)
                            } label: {
                                Label(feed.isActive ? L("action.disable") : L("action.enable"), systemImage: feed.isActive ? "pause" : "play")
                            }
                            .tint(feed.isActive ? .gray : .green)
                            .disabled(refreshing)

                            Button(role: .destructive) {
                                viewModel.deleteFeed(feed)
                            } label: {
                                Label(L("common.delete"), systemImage: "trash")
                            }
                            .disabled(refreshing)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                ProgressView(L("status.processing"))
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(L("empty.noFeeds"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L("empty.noFeedsHint"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                showingAddFeed = true
            } label: {
                Text(L("action.addFeed"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// RSS源行视图
struct FeedRowView: View {
    let feed: Feed
    let lastRefreshLog: RefreshLogEntry?
    let isRefreshing: Bool
    let onToggleActive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // RSS源图标 / 刷新中转圈
            if isRefreshing {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else if let imageUrl = feed.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                            .clipped()
                    case .failure:
                        feedIconPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    @unknown default:
                        feedIconPlaceholder
                    }
                }
            } else {
                feedIconPlaceholder
            }

            // RSS源信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(feed.title)
                        .font(.headline)
                        .lineLimit(1)

                    // 用户备注标签
                    if let notes = feed.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }

                if let description = feed.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // 刷新状态行
                if isRefreshing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(L("status.refreshing"))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                } else if let log = lastRefreshLog {
                    HStack(spacing: 4) {
                        if log.isSuccess {
                            Text(String(format: L("status.refreshSuccess"), log.addedCount))
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text(log.errorDetail)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(log.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if let lastUpdated = feed.lastUpdated {
                    Text(String(format: L("status.lastUpdated"), formatDate(lastUpdated)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 活跃状态指示器
            Circle()
                .fill(feed.isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleActive()
        }
    }

    /// RSS源图标占位
    private var feedIconPlaceholder: some View {
        Image(systemName: "newspaper.fill")
            .foregroundColor(.gray)
            .frame(width: 40, height: 40)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// 添加RSS源弹窗
struct AddFeedSheet: View {
    @Binding var title: String
    @Binding var url: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(L("feed.info")) {
                    TextField(L("feed.name"), text: $title)
                        .textContentType(.name)

                    TextField(L("feed.url"), text: $url)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section {
                    Button {
                        onAdd()
                    } label: {
                        HStack {
                            Spacer()
                            Text(L("common.add"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(title.isEmpty || url.isEmpty)

                    Button {
                        onCancel()
                    } label: {
                        HStack {
                            Spacer()
                            Text(L("common.cancel"))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(L("nav.addFeed"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
