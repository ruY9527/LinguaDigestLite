//
//  FeedViewModel.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import Combine

/// RSS源管理ViewModel
class FeedViewModel: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let feedService = FeedService.shared
    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFeeds()
    }

    /// 加载所有RSS源
    func loadFeeds() {
        databaseManager.syncBuiltInFeeds()
        feeds = databaseManager.fetchAllFeeds()
    }

    /// 刷新指定的RSS源
    func refreshFeed(_ feed: Feed) async {
        isLoading = true
        errorMessage = nil

        do {
            let (_, articles) = try await feedService.parseFeed(from: feed.feedUrl)

            // 更新文章并关联feedId
            let articlesWithFeedId = articles.map { article -> Article in
                var newArticle = article
                newArticle.feedId = feed.id
                return newArticle
            }

            // 保存到数据库
            let addedCount = databaseManager.addArticles(articlesWithFeedId)

            // 更新feed最后更新时间
            var updatedFeed = feed
            updatedFeed.lastUpdated = Date()
            databaseManager.updateFeed(updatedFeed)

            await MainActor.run {
                isLoading = false
                loadFeeds()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "刷新RSS源失败: \(error.localizedDescription)"
            }
        }
    }

    /// 刷新所有活跃的RSS源
    func refreshAllFeeds() async {
        isLoading = true
        errorMessage = nil

        let activeFeeds = databaseManager.fetchActiveFeeds()
        var totalAdded = 0

        for feed in activeFeeds {
            do {
                let (_, articles) = try await feedService.parseFeed(from: feed.feedUrl)

                let articlesWithFeedId = articles.map { article -> Article in
                    var newArticle = article
                    newArticle.feedId = feed.id
                    return newArticle
                }

                totalAdded += databaseManager.addArticles(articlesWithFeedId)

                var updatedFeed = feed
                updatedFeed.lastUpdated = Date()
                databaseManager.updateFeed(updatedFeed)
            } catch {
                // 继续处理其他源
                print("Failed to refresh feed: \(feed.title) - \(error)")
            }
        }

        await MainActor.run {
            isLoading = false
            loadFeeds()
        }
    }

    /// 重新订阅所有内置RSS源，并重新抓取文章。
    func rebuildAllBuiltInSubscriptions() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        databaseManager.resetBuiltInFeeds()
        await refreshAllFeeds()
    }

    /// 添加新的RSS源
    func addFeed(title: String, feedUrl: String, notes: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            // 先解析RSS源获取信息
            let (parsedFeed, articles) = try await feedService.parseFeed(from: feedUrl)

            // 使用解析到的信息或用户提供的标题
            let newFeed = Feed(
                title: parsedFeed?.title ?? title,
                link: parsedFeed?.link ?? "",
                feedUrl: feedUrl,
                description: parsedFeed?.description,
                notes: notes,
                imageUrl: parsedFeed?.imageUrl
            )

            // 保存RSS源
            let savedFeed = databaseManager.addFeed(newFeed)

            // 保存文章
            let articlesWithFeedId = articles.map { article -> Article in
                var newArticle = article
                newArticle.feedId = savedFeed.id
                return newArticle
            }
            databaseManager.addArticles(articlesWithFeedId)

            await MainActor.run {
                isLoading = false
                loadFeeds()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "添加RSS源失败: \(error.localizedDescription)"
            }
        }
    }

    /// 更新RSS源备注
    func updateFeedNotes(_ feed: Feed, notes: String?) {
        var updatedFeed = feed
        updatedFeed.notes = notes
        databaseManager.updateFeed(updatedFeed)
        loadFeeds()
    }

    /// 删除RSS源
    func deleteFeed(_ feed: Feed) {
        databaseManager.deleteFeed(feed)
        loadFeeds()
    }

    /// 切换RSS源活跃状态
    func toggleFeedActive(_ feed: Feed) {
        var updatedFeed = feed
        updatedFeed.isActive = !updatedFeed.isActive
        databaseManager.updateFeed(updatedFeed)
        loadFeeds()
    }

    /// 获取活跃RSS源数量
    var activeFeedsCount: Int {
        feeds.filter { $0.isActive }.count
    }

    /// 获取内置RSS源
    var builtInFeeds: [Feed] {
        feeds.filter { $0.isBuiltIn }
    }

    /// 获取用户添加的RSS源
    var userFeeds: [Feed] {
        feeds.filter { !$0.isBuiltIn }
    }
}
