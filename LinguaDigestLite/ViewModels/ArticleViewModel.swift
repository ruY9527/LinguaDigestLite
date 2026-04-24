//
//  ArticleViewModel.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import Combine

/// 文章列表ViewModel
class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFeedId: UUID?
    @Published var showingFavoritesOnly: Bool = false
    @Published var showingUnreadOnly: Bool = false

    private let databaseManager = DatabaseManager.shared
    private let feedService = FeedService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadArticles()
    }

    /// 加载文章
    func loadArticles() {
        isLoading = true

        if showingFavoritesOnly {
            articles = databaseManager.fetchFavoriteArticles()
        } else if showingUnreadOnly {
            articles = databaseManager.fetchUnreadArticles()
        } else if let feedId = selectedFeedId {
            articles = databaseManager.fetchArticles(for: feedId)
        } else {
            articles = databaseManager.fetchAllArticles()
        }

        isLoading = false
    }

    /// 选择RSS源
    func selectFeed(feedId: UUID?) {
        selectedFeedId = feedId
        showingFavoritesOnly = false
        showingUnreadOnly = false
        loadArticles()
    }

    /// 显示收藏文章
    func showFavorites() {
        showingFavoritesOnly = true
        showingUnreadOnly = false
        selectedFeedId = nil
        loadArticles()
    }

    /// 显示未读文章
    func showUnread() {
        showingFavoritesOnly = false
        showingUnreadOnly = true
        selectedFeedId = nil
        loadArticles()
    }

    /// 显示所有文章
    func showAll() {
        showingFavoritesOnly = false
        showingUnreadOnly = false
        selectedFeedId = nil
        loadArticles()
    }

    /// 标记文章为已读
    func markAsRead(_ article: Article) {
        databaseManager.markArticleAsRead(article)
        loadArticles()
    }

    /// 切换收藏状态
    func toggleFavorite(_ article: Article) {
        databaseManager.toggleArticleFavorite(article)
        loadArticles()
    }

    /// 删除文章
    func deleteArticle(_ article: Article) {
        databaseManager.deleteArticle(article)
        loadArticles()
    }

    /// 获取文章全文内容
    func fetchFullContent(for article: Article) async -> Article {
        guard article.content == nil || article.content?.isEmpty == true else {
            return article
        }

        isLoading = true

        do {
            let (content, htmlContent) = try await feedService.fetchFullArticleContent(from: article.link)

            await MainActor.run {
                isLoading = false
            }

            var updatedArticle = article
            updatedArticle.content = content
            updatedArticle.htmlContent = htmlContent

            return updatedArticle
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "获取全文失败: \(error.localizedDescription)"
            }
            return article
        }
    }

    /// 搜索文章
    func searchArticles(query: String) {
        guard !query.isEmpty else {
            loadArticles()
            return
        }

        isLoading = true

        articles = databaseManager.fetchAllArticles().filter { article in
            article.title.lowercased().contains(query.lowercased()) ||
            article.summary?.lowercased().contains(query.lowercased()) ?? false
        }

        isLoading = false
    }

    /// 未读文章数量
    var unreadCount: Int {
        databaseManager.fetchUnreadArticles().count
    }

    /// 收藏文章数量
    var favoriteCount: Int {
        databaseManager.fetchFavoriteArticles().count
    }

    /// 文章总数
    var totalCount: Int {
        articles.count
    }
}