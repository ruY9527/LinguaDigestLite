import Foundation
import Combine

/// RSS源管理ViewModel
class FeedViewModel: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshSummary: String?
    @Published var lastRefreshHadFailure: Bool = false
    @Published var refreshLogs: [RefreshLogEntry] = []
    @Published var refreshingFeedIds: Set<UUID> = []

    private let feedService = FeedService.shared
    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let maxConcurrency = 3

    init() {
        loadFeeds()
        loadRefreshLogs()
    }

    /// 加载所有RSS源
    func loadFeeds() {
        databaseManager.syncBuiltInFeeds()
        feeds = databaseManager.fetchAllFeeds()
    }

    /// 刷新指定的RSS源
    func refreshFeed(_ feed: Feed) async {
        guard !refreshingFeedIds.contains(feed.id) else { return }

        await MainActor.run {
            refreshingFeedIds.insert(feed.id)
            errorMessage = nil
            lastRefreshSummary = nil
        }

        let result = await performRefresh(feed)
        switch result {
        case .success(let addedCount):
            await MainActor.run {
                refreshingFeedIds.remove(feed.id)
                loadFeeds()
                loadRefreshLogs()
                lastRefreshHadFailure = false
                lastRefreshSummary = addedCount > 0
                    ? String(format: L("refreshSummary.hasNew"), feed.title, addedCount)
                    : String(format: L("refreshSummary.noNew"), feed.title)
            }
        case .failure(let error):
            await MainActor.run {
                refreshingFeedIds.remove(feed.id)
                loadRefreshLogs()
                lastRefreshHadFailure = true
                let detail = Self.errorDetail(error)
                lastRefreshSummary = String(format: L("refreshSummary.failed"), feed.title)
                errorMessage = String(format: L("refreshSummary.failedDetail"), detail)
            }
        }
    }

    /// 执行单次刷新并记录日志（支持条件请求）
    private func performRefresh(_ feed: Feed) async -> Result<Int, Error> {
        do {
            let fetchResult = try await feedService.parseFeed(
                from: feed.feedUrl,
                etag: feed.etag,
                lastModified: feed.lastModified
            )

            // 304 Not Modified
            if fetchResult.notModified {
                var updatedFeed = feed
                updatedFeed.lastRefreshTime = Date()
                updatedFeed.consecutiveErrors = 0
                databaseManager.updateFeed(updatedFeed)

                let log = RefreshLogEntry(
                    feedId: feed.id,
                    feedTitle: feed.title,
                    isSuccess: true,
                    addedCount: 0
                )
                databaseManager.addRefreshLog(log)
                return .success(0)
            }

            // 200 OK - process articles
            let articlesWithFeedId = fetchResult.articles.map { article -> Article in
                var newArticle = article
                newArticle.feedId = feed.id
                return newArticle
            }

            let addedCount = databaseManager.addArticles(articlesWithFeedId)

            var updatedFeed = feed
            updatedFeed.lastUpdated = Date()
            updatedFeed.lastRefreshTime = Date()
            updatedFeed.etag = fetchResult.etag ?? feed.etag
            updatedFeed.lastModified = fetchResult.lastModified ?? feed.lastModified
            updatedFeed.consecutiveErrors = 0
            databaseManager.updateFeed(updatedFeed)

            let log = RefreshLogEntry(
                feedId: feed.id,
                feedTitle: feed.title,
                isSuccess: true,
                addedCount: addedCount
            )
            databaseManager.addRefreshLog(log)

            return .success(addedCount)
        } catch {
            let statusCode: Int?
            if case FeedError.httpError(let code) = error {
                statusCode = code
            } else {
                statusCode = nil
            }

            // Track consecutive errors for sorting
            var updatedFeed = feed
            updatedFeed.consecutiveErrors += 1
            databaseManager.updateFeed(updatedFeed)

            let log = RefreshLogEntry(
                feedId: feed.id,
                feedTitle: feed.title,
                isSuccess: false,
                errorMessage: error.localizedDescription,
                statusCode: statusCode
            )
            databaseManager.addRefreshLog(log)

            return .failure(error)
        }
    }

    /// 刷新所有活跃的RSS源（并发执行，最大并发数3）
    func refreshAllFeeds() async {
        let activeFeeds = databaseManager.fetchActiveFeeds()
        let activeIds = Set(activeFeeds.map(\.id))

        await MainActor.run {
            refreshingFeedIds = activeIds
            errorMessage = nil
            lastRefreshSummary = nil
        }

        // Filter feeds that need refreshing (smart interval)
        let feedsToRefresh = activeFeeds.filter { shouldRefresh($0) }
        let skippedCount = activeFeeds.count - feedsToRefresh.count

        var totalAdded = 0
        var successCount = 0
        var failureCount = 0
        var failedNames: [String] = []

        await withTaskGroup(of: (UUID, Result<Int, Error>).self) { group in
            var feedIterator = feedsToRefresh.makeIterator()

            // Launch initial batch (up to maxConcurrency)
            var activeTasks = 0
            while activeTasks < maxConcurrency, let feed = feedIterator.next() {
                let feedCopy = feed
                group.addTask { [weak self] in
                    let result = await self?.performRefresh(feedCopy) ?? .failure(FeedError.invalidResponse)
                    return (feedCopy.id, result)
                }
                activeTasks += 1
            }

            // Process results and launch next feeds
            for await (feedId, result) in group {
                switch result {
                case .success(let count):
                    totalAdded += count
                    successCount += 1
                case .failure:
                    failureCount += 1
                    if let feed = feedsToRefresh.first(where: { $0.id == feedId }) {
                        failedNames.append(feed.title)
                    }
                }

                await MainActor.run {
                    refreshingFeedIds.remove(feedId)
                }

                // Launch next feed
                if let feed = feedIterator.next() {
                    let feedCopy = feed
                    group.addTask { [weak self] in
                        let result = await self?.performRefresh(feedCopy) ?? .failure(FeedError.invalidResponse)
                        return (feedCopy.id, result)
                    }
                }
            }
        }

        // Run cleanup after full refresh
        databaseManager.cleanupOldArticles()

        // Capture results for MainActor closure
        let finalTotalAdded = totalAdded
        let finalSuccessCount = successCount
        let finalFailureCount = failureCount
        let finalFailedNames = failedNames

        await MainActor.run {
            loadFeeds()
            loadRefreshLogs()
            lastRefreshHadFailure = finalFailureCount > 0

            if finalFailureCount > 0 {
                let failedPart = finalFailedNames.count <= 2
                    ? finalFailedNames.joined(separator: L("list.separator"))
                    : String(format: L("refreshSummary.failedNames"), finalFailedNames.prefix(2).joined(separator: L("list.separator")), finalFailedNames.count)
                lastRefreshSummary = String(format: L("refreshSummary.partial"), finalSuccessCount, finalFailureCount, failedPart)
            } else if finalTotalAdded > 0 {
                lastRefreshSummary = String(format: L("refreshSummary.allSuccess"), finalSuccessCount, finalTotalAdded)
            } else if skippedCount > 0 {
                lastRefreshSummary = String(format: L("refreshSummary.allSuccessNoNew"), finalSuccessCount)
            } else {
                lastRefreshSummary = String(format: L("refreshSummary.allSuccessNoNew"), finalSuccessCount)
            }
        }
    }

    /// Check if a feed should be refreshed based on its update interval
    private func shouldRefresh(_ feed: Feed) -> Bool {
        guard let lastRefresh = feed.lastRefreshTime else {
            return true // Never refreshed
        }
        let intervalMinutes = max(feed.updateInterval, 15) // Minimum 15 minutes
        let nextRefreshTime = lastRefresh.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        return Date() >= nextRefreshTime
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
            let fetchResult = try await feedService.parseFeed(from: feedUrl)

            let newFeed = Feed(
                title: fetchResult.feed?.title ?? title,
                link: fetchResult.feed?.link ?? "",
                feedUrl: feedUrl,
                description: fetchResult.feed?.description,
                notes: notes,
                imageUrl: fetchResult.feed?.imageUrl,
                etag: fetchResult.etag,
                lastModified: fetchResult.lastModified
            )

            let savedFeed = databaseManager.addFeed(newFeed)

            let articlesWithFeedId = fetchResult.articles.map { article -> Article in
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
                errorMessage = String(format: L("error.addFeedFailed"), error.localizedDescription)
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

    /// 获取内置RSS源（错误源排到最后）
    var builtInFeeds: [Feed] {
        feeds.filter { $0.isBuiltIn }.sorted { a, b in
            if a.consecutiveErrors == 0 && b.consecutiveErrors > 0 { return true }
            if a.consecutiveErrors > 0 && b.consecutiveErrors == 0 { return false }
            return false // keep original order within same group
        }
    }

    /// 获取用户添加的RSS源（错误源排到最后）
    var userFeeds: [Feed] {
        feeds.filter { !$0.isBuiltIn }.sorted { a, b in
            if a.consecutiveErrors == 0 && b.consecutiveErrors > 0 { return true }
            if a.consecutiveErrors > 0 && b.consecutiveErrors == 0 { return false }
            return false
        }
    }

    /// 加载刷新日志
    func loadRefreshLogs() {
        refreshLogs = databaseManager.fetchAllRefreshLogs()
    }

    /// 获取指定源的最近一条刷新日志
    func latestRefreshLog(for feedId: UUID) -> RefreshLogEntry? {
        databaseManager.latestRefreshLog(for: feedId)
    }

    /// 指定源是否正在刷新
    func isRefreshing(_ feedId: UUID) -> Bool {
        refreshingFeedIds.contains(feedId)
    }

    /// 提取错误的关键信息，便于用户理解
    static func errorDetail(_ error: Error) -> String {
        if let feedError = error as? FeedError {
            switch feedError {
            case .httpError(let code):
                return String(format: L("error.http"), code)
            case .networkError:
                return L("error.networkFailed")
            case .invalidURL:
                return L("error.invalidLink")
            case .invalidResponse:
                return L("error.serverError")
            case .parseError:
                return L("error.contentParseFailed")
            case .invalidEncoding:
                return L("error.encodingError")
            }
        }
        return error.localizedDescription
    }

    /// 清除所有刷新日志
    func clearAllRefreshLogs() {
        databaseManager.clearAllRefreshLogs()
        lastRefreshSummary = nil
        loadRefreshLogs()
    }
}
