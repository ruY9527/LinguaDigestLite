//
//  ArticleListView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 文章列表视图
struct ArticleListView: View {
    @ObservedObject var viewModel: ArticleViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @Binding var selectedTab: Int

    @State private var searchText: String = ""
    @State private var selectedArticle: Article?
    @State private var showingReader: Bool = false
    @State private var showingSourceInfoArticle: Article? = nil  // 当前显示来源信息的文章
    @State private var sourceInfoPosition: CGPoint = .zero  // 来源信息卡片位置

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 筛选栏
                    filterBar

                    // 文章列表
                    articleList
                }
                
                // 悬浮来源信息卡片（全局显示）
                if let article = showingSourceInfoArticle {
                    sourceInfoPopupCard(article: article)
                }
            }
            .navigationTitle(L("nav.articles"))
            .searchable(text: $searchText, prompt: L("search.articles"))
            .onChange(of: searchText) { newValue in
                viewModel.searchArticles(query: newValue)
            }
            .refreshable {
                viewModel.loadArticles()
            }
            .sheet(isPresented: $showingReader) {
                if let article = selectedArticle {
                    ReaderView(article: article)
                }
            }
        }
    }

    /// 筛选栏
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 全部按钮
            FilterButton(
                title: L("filter.all"),
                isSelected: !viewModel.showingFavoritesOnly && !viewModel.showingUnreadOnly && viewModel.selectedFeedId == nil,
                count: viewModel.totalCount
            ) {
                viewModel.showAll()
            }

            // 未读按钮
            FilterButton(
                title: L("filter.unread"),
                isSelected: viewModel.showingUnreadOnly,
                count: viewModel.unreadCount
            ) {
                viewModel.showUnread()
            }

            // 收藏按钮
            FilterButton(
                title: L("filter.favorites"),
                isSelected: viewModel.showingFavoritesOnly,
                count: viewModel.favoriteCount
            ) {
                viewModel.showFavorites()
            }

            Spacer()

            // 刷新按钮
            Button {
                Task {
                    await feedViewModel.refreshAllFeeds()
                    viewModel.loadArticles()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    /// 文章列表
    private var articleList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView(L("common.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.articles.isEmpty {
                contextualEmptyState
            } else {
                List {
                    ForEach(viewModel.articles, id: \.id) { article in
                        ArticleRowView(
                            article: article,
                            feeds: feedViewModel.feeds,
                            showingSourceInfo: showingSourceInfoArticle?.id == article.id,
                            onSourceInfoTap: { position in
                                // 关闭其他悬浮卡片，显示当前文章的
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if showingSourceInfoArticle?.id == article.id {
                                        showingSourceInfoArticle = nil  // 关闭
                                    } else {
                                        showingSourceInfoArticle = article  // 打开
                                        sourceInfoPosition = position
                                    }
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 点击文章时关闭悬浮卡片
                            if showingSourceInfoArticle != nil {
                                showingSourceInfoArticle = nil
                            }
                            selectedArticle = article
                            showingReader = true
                            viewModel.markAsRead(article)
                        }
                        .swipeActions(edge: .trailing) {
                            // 收藏按钮
                            Button {
                                viewModel.toggleFavorite(article)
                            } label: {
                                Label(
                                    article.isFavorite ? L("action.unfavorite") : L("action.favorite"),
                                    systemImage: article.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(article.isFavorite ? .gray : .yellow)

                            // 删除按钮：收藏界面真正删除，其他界面跳过收藏文章
                            if viewModel.showingFavoritesOnly {
                                Button(role: .destructive) {
                                    viewModel.deleteFavoriteArticle(article)
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                            } else if !article.isFavorite {
                                Button(role: .destructive) {
                                    viewModel.deleteArticle(article)
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                // 滚动时关闭悬浮卡片
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        if showingSourceInfoArticle != nil {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showingSourceInfoArticle = nil
                            }
                        }
                    }
                )
            }
        }
    }

    /// 悬浮来源信息卡片
    private func sourceInfoPopupCard(article: Article) -> some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    // 卡片内容
                    VStack(alignment: .leading, spacing: 12) {
                        // 来源标题
                        HStack {
                            Image(systemName: "newspaper.fill")
                                .foregroundColor(.blue)
                            Text(L("source.info"))
                                .font(.headline)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSourceInfoArticle = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Divider()
                        
                        // 信息内容 - 自适应宽度
                        VStack(alignment: .leading, spacing: 8) {
                            // 来源名称
                            InfoRow(icon: "globe", label: L("source.label"), value: getSourceName(article))
                            
                            // 作者
                            if let author = article.author, !author.isEmpty {
                                InfoRow(icon: "person", label: L("source.author"), value: author)
                            }
                            
                            // 发布时间
                            InfoRow(icon: "calendar", label: L("source.published"), value: formatPublishedDate(article.publishedAt))
                            
                            // 同步时间
                            InfoRow(icon: "clock.arrow.circlepath", label: L("source.synced"), value: getSyncTimeDescription(article))
                            
                            // 链接
                            if let feed = getFeedForArticle(article) {
                                InfoRow(icon: "link", label: "RSS", value: extractHost(from: feed.feedUrl))
                            }
                            
                            // 阅读进度
                            if article.readingProgress > 0 {
                                InfoRow(icon: "book.open", label: L("source.progress"), value: String(format: L("source.progressValue"), Int(article.readingProgress * 100)))
                            }
                        }
                        
                        Divider()
                        
                        // 操作按钮
                        HStack(spacing: 12) {
                            Button {
                                if let url = URL(string: article.link) {
                                    UIApplication.shared.open(url)
                                }
                                showingSourceInfoArticle = nil
                            } label: {
                                Label(L("action.openOriginal"), systemImage: "safari")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Button {
                                UIPasteboard.general.string = article.link
                                showingSourceInfoArticle = nil
                            } label: {
                                Label(L("action.copyLink"), systemImage: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            // 收藏状态
                            if article.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                    )
                }
                // 自适应宽度：屏幕宽度的90%，最小280，最大400
                .frame(maxWidth: min(max(geometry.size.width * 0.9, 280), 400))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .zIndex(100)
        // 点击卡片外部关闭
        .background(
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSourceInfoArticle = nil
                    }
                }
        )
    }
    
    /// 获取文章来源名称
    private func getSourceName(_ article: Article) -> String {
        if let feed = getFeedForArticle(article) {
            return feed.title
        }
        return L("source.unknown")
    }

    /// 获取文章对应的Feed
    private func getFeedForArticle(_ article: Article) -> Feed? {
        if let feedId = article.feedId {
            return feedViewModel.feeds.first { $0.id == feedId }
        }
        return nil
    }
    
    /// 获取同步时间描述
    private func getSyncTimeDescription(_ article: Article) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: article.fetchedAt, relativeTo: Date())
    }
    
    /// 格式化发布日期（为空时回退到当前时间）
    private func formatPublishedDate(_ date: Date?) -> String {
        let effectiveDate = date ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        return formatter.string(from: effectiveDate)
    }
    
    /// 提取URL主机名
    private func extractHost(from urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.host ?? urlString
        }
        return urlString
    }

    /// 根据当前筛选模式显示不同的空状态
    @ViewBuilder
    private var contextualEmptyState: some View {
        if viewModel.showingFavoritesOnly {
            // 收藏为空：引导用户去浏览文章并收藏
            emptyState(
                icon: "star",
                title: L("empty.noFavorites"),
                subtitle: L("empty.noFavoritesHint"),
                buttonTitle: L("action.browseAll"),
                buttonAction: { viewModel.showAll() }
            )
        } else if viewModel.showingUnreadOnly {
            // 未读为空：所有文章都已读
            emptyState(
                icon: "checkmark.circle",
                title: L("empty.noUnread"),
                subtitle: L("empty.noUnreadHint"),
                buttonTitle: nil,
                buttonAction: nil
            )
        } else {
            // 全部为空：引导用户去订阅页添加源
            emptyState(
                icon: "newspaper",
                title: L("empty.noArticles"),
                subtitle: L("empty.noArticlesHint"),
                buttonTitle: L("action.goToAddFeed"),
                buttonAction: { selectedTab = 1 }
            )
        }
    }

    /// 通用空状态视图
    private func emptyState(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String?,
        buttonAction: (() -> Void)?
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 筛选按钮
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(isSelected ? .blue : .gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// 文章行视图
struct ArticleRowView: View {
    let article: Article
    let feeds: [Feed]
    let showingSourceInfo: Bool
    let onSourceInfoTap: (CGPoint) -> Void
    
    /// 获取文章来源信息
    private var sourceFeed: Feed? {
        if let feedId = article.feedId {
            return feeds.first { $0.id == feedId }
        }
        return nil
    }
    
    /// 来源名称
    private var sourceName: String {
        sourceFeed?.title ?? L("source.unknown")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 文章图片
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 60)
                            .cornerRadius(8)
                            .clipped()
                    case .failure:
                        placeholderImage
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 60)
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }

            // 文章信息
            VStack(alignment: .leading, spacing: 6) {
                // 标题
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(article.isRead ? .secondary : .primary)

                // 摘要
                if let summary = article.summary, !summary.isEmpty {
                    Text(FeedService.cleanHTMLContent(summary).prefix(150))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // 元信息
                HStack(spacing: 8) {
                    if article.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }

                    if !article.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }

                    Text(article.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                    
                    // 来源标签（点击显示悬浮信息）
                    sourceTagButton
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .background(
            // 高亮显示当前选中的文章
            showingSourceInfo ? Color.blue.opacity(0.1) : Color.clear
        )
    }

    /// 来源标签按钮
    private var sourceTagButton: some View {
        Button {
            // 获取按钮位置（用于定位悬浮卡片）
            let globalPosition = CGPoint(x: 0, y: 0)  // 使用全局卡片，不需要精确位置
            onSourceInfoTap(globalPosition)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showingSourceInfo ? "info.circle.fill" : "newspaper")
                    .font(.caption2)
                    .foregroundColor(showingSourceInfo ? .blue : .gray)
                Text(sourceName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundColor(showingSourceInfo ? .blue : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(showingSourceInfo ? Color.blue.opacity(0.25) : Color.gray.opacity(0.15))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    /// 占位图片
    private var placeholderImage: some View {
        Image(systemName: "newspaper.fill")
            .foregroundColor(.gray)
            .frame(width: 80, height: 60)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

/// 信息行视图
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 18)
            
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}