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
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.feeds.isEmpty {
                    emptyStateView
                } else {
                    feedList
                }
            }
            .navigationTitle("订阅源")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingRebuildConfirmation = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle")
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
            .alert("错误", isPresented: $showingErrorMessage) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .alert("重新订阅全部内置RSS？", isPresented: $showingRebuildConfirmation) {
                Button("取消", role: .cancel) { }
                Button("重新订阅", role: .destructive) {
                    Task {
                        await viewModel.rebuildAllBuiltInSubscriptions()
                    }
                }
            } message: {
                Text("这会重建所有内置订阅源，并重新抓取文章内容。")
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showingErrorMessage = newValue != nil
            }
        }
    }
    
    /// RSS源列表
    private var feedList: some View {
        List {
            // 内置RSS源
            Section("内置订阅源") {
                ForEach(viewModel.builtInFeeds, id: \.id) { feed in
                    FeedRowView(feed: feed) {
                        viewModel.toggleFeedActive(feed)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewModel.toggleFeedActive(feed)
                        } label: {
                            Label(feed.isActive ? "禁用" : "启用", systemImage: feed.isActive ? "pause" : "play")
                        }
                        .tint(feed.isActive ? .gray : .green)
                    }
                }
            }
            
            // 用户添加的RSS源
            if !viewModel.userFeeds.isEmpty {
                Section("我的订阅源") {
                    ForEach(viewModel.userFeeds, id: \.id) { feed in
                        FeedRowView(feed: feed) {
                            viewModel.toggleFeedActive(feed)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewModel.toggleFeedActive(feed)
                            } label: {
                                Label(feed.isActive ? "禁用" : "启用", systemImage: feed.isActive ? "pause" : "play")
                            }
                            .tint(feed.isActive ? .gray : .green)
                            
                            Button(role: .destructive) {
                                viewModel.deleteFeed(feed)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                ProgressView("刷新中...")
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
            
            Text("暂无订阅源")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请添加RSS订阅源以获取文章内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showingAddFeed = true
            } label: {
                Text("添加订阅源")
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
    let onToggleActive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // RSS源图标
            if let imageUrl = feed.imageUrl, let url = URL(string: imageUrl) {
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

                if let lastUpdated = feed.lastUpdated {
                    Text("最后更新: \(formatDate(lastUpdated))")
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
                Section("RSS源信息") {
                    TextField("名称", text: $title)
                        .textContentType(.name)
                    
                    TextField("RSS链接", text: $url)
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
                            Text("添加")
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
                            Text("取消")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("添加订阅源")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
