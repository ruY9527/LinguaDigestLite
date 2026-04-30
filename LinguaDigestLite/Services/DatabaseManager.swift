//
//  DatabaseManager.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 数据库管理器（简化版，使用UserDefaults和FileManager）
class DatabaseManager {
    static let shared = DatabaseManager()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    // 存储键
    private let feedsKey = "linguadigest_feeds"
    private let articlesKey = "linguadigest_articles"
    private let favoriteArticlesKey = "linguadigest_favorite_articles"
    private let vocabularyKey = "linguadigest_vocabulary"
    private let categoriesKey = "linguadigest_categories"

    private init() {
        initializeBuiltInFeeds()
        initializeCategories()
    }

    /// 初始化内置RSS源
    private func initializeBuiltInFeeds() {
        syncBuiltInFeeds()
    }

    /// 初始化默认分类
    private func initializeCategories() {
        let storedCategories = loadCategories()
        
        if storedCategories.isEmpty {
            // 添加默认分类
            saveCategories(VocabularyCategory.defaultCategories)
        }
    }

    // MARK: - 文件存储路径

    private func getStoragePath() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("LinguaDigestLite")

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir
    }

    // MARK: - Feed 操作

    private func loadFeeds() -> [Feed] {
        if let data = defaults.data(forKey: feedsKey),
           let feeds = try? JSONDecoder().decode([Feed].self, from: data) {
            return feeds
        }
        return []
    }

    private func saveFeeds(_ feeds: [Feed]) {
        if let data = try? JSONEncoder().encode(feeds) {
            defaults.set(data, forKey: feedsKey)
        }
    }

    /// 获取所有RSS源
    func fetchAllFeeds() -> [Feed] {
        return loadFeeds()
    }

    /// 获取活跃的RSS源
    func fetchActiveFeeds() -> [Feed] {
        return loadFeeds().filter { $0.isActive }
    }

    /// 同步内置RSS源定义，确保标题、链接和描述保持最新。
    func syncBuiltInFeeds() {
        var storedFeeds = loadFeeds()
        let builtInCatalog = Feed.builtInFeeds
        let catalogByURL = Dictionary(uniqueKeysWithValues: builtInCatalog.map { ($0.feedUrl, $0) })

        for index in storedFeeds.indices {
            guard storedFeeds[index].isBuiltIn,
                  let catalogFeed = catalogByURL[storedFeeds[index].feedUrl] else {
                continue
            }

            storedFeeds[index].title = catalogFeed.title
            storedFeeds[index].link = catalogFeed.link
            storedFeeds[index].description = catalogFeed.description
            storedFeeds[index].imageUrl = storedFeeds[index].imageUrl ?? catalogFeed.imageUrl
            storedFeeds[index].isBuiltIn = true
        }

        let existingURLs = Set(storedFeeds.filter { $0.isBuiltIn }.map(\.feedUrl))
        let missingBuiltIns = builtInCatalog.filter { !existingURLs.contains($0.feedUrl) }
        storedFeeds.append(contentsOf: missingBuiltIns)

        storedFeeds.removeAll { feed in
            feed.isBuiltIn && !catalogByURL.keys.contains(feed.feedUrl)
        }

        saveFeeds(storedFeeds)
    }

    /// 重建所有内置RSS订阅，并删除其旧文章缓存（保留收藏文章）。
    func resetBuiltInFeeds() {
        syncBuiltInFeeds()
        let builtInFeedIds = Set(loadFeeds().filter { $0.isBuiltIn }.map(\.id))

        var articles = loadArticles()
        articles.removeAll { article in
            guard !article.isFavorite else { return false }
            if let feedId = article.feedId {
                return builtInFeedIds.contains(feedId)
            }
            return false
        }
        saveArticles(articles)
    }

    /// 添加RSS源
    func addFeed(_ feed: Feed) -> Feed {
        var feeds = loadFeeds()
        feeds.append(feed)
        saveFeeds(feeds)
        return feed
    }

    /// 删除RSS源（保留收藏文章）
    func deleteFeed(_ feed: Feed) {
        var feeds = loadFeeds()
        feeds.removeAll { $0.id == feed.id }
        saveFeeds(feeds)

        // 删除相关文章（跳过收藏文章）
        var articles = loadArticles()
        articles.removeAll { $0.feedId == feed.id && !$0.isFavorite }
        saveArticles(articles)
    }

    /// 更新RSS源
    func updateFeed(_ feed: Feed) {
        var feeds = loadFeeds()
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
            saveFeeds(feeds)
        }
    }

    // MARK: - Article 操作

    private func loadArticles() -> [Article] {
        var articles: [Article] = []
        if let data = defaults.data(forKey: articlesKey),
           let decoded = try? JSONDecoder().decode([Article].self, from: data) {
            articles = decoded
        }

        // 合并收藏存储中的文章，确保收藏文章不会丢失
        let favorites = loadFavoriteArticles()
        for fav in favorites {
            if !articles.contains(where: { $0.id == fav.id }) {
                // 主存储中缺失的收藏文章，补回
                var restored = fav
                restored.isFavorite = true
                articles.insert(restored, at: 0)
            } else if let idx = articles.firstIndex(where: { $0.id == fav.id }) {
                // 主存储中存在，用收藏快照补全可能缺失的 content
                if articles[idx].content == nil || articles[idx].content?.isEmpty == true {
                    if let savedContent = fav.content, !savedContent.isEmpty {
                        articles[idx].content = savedContent
                        articles[idx].htmlContent = fav.htmlContent
                    }
                }
                articles[idx].isFavorite = true
            }
        }

        return articles
    }

    private func saveArticles(_ articles: [Article]) {
        // 分批保存，避免UserDefaults限制
        // 收藏文章始终保留，只截断非收藏的旧文章
        let favorites = articles.filter { $0.isFavorite }
        let nonFavorites = articles.filter { !$0.isFavorite }
        let maxNonFavorites = max(0, 500 - favorites.count)
        let toSave = favorites + Array(nonFavorites.suffix(maxNonFavorites))

        if let data = try? JSONEncoder().encode(toSave) {
            defaults.set(data, forKey: articlesKey)
        }
    }

    // MARK: - 收藏文章存储

    /// 加载收藏文章
    private func loadFavoriteArticles() -> [Article] {
        if let data = defaults.data(forKey: favoriteArticlesKey),
           let articles = try? JSONDecoder().decode([Article].self, from: data) {
            return articles
        }
        return []
    }

    /// 保存收藏文章
    private func saveFavoriteArticles(_ articles: [Article]) {
        if let data = try? JSONEncoder().encode(articles) {
            defaults.set(data, forKey: favoriteArticlesKey)
        }
    }

    /// 获取所有文章
    func fetchAllArticles() -> [Article] {
        return loadArticles()
    }

    /// 获取指定RSS源的文章
    func fetchArticles(for feedId: UUID) -> [Article] {
        return loadArticles().filter { $0.feedId == feedId }
    }

    /// 获取收藏文章（从独立收藏存储读取）
    func fetchFavoriteArticles() -> [Article] {
        return loadFavoriteArticles()
    }

    /// 获取未读文章
    func fetchUnreadArticles() -> [Article] {
        return loadArticles().filter { !$0.isRead }
    }

    /// 添加文章
    func addArticle(_ article: Article) -> Article {
        var articles = loadArticles()
        articles.insert(article, at: 0)
        saveArticles(articles)
        return article
    }

    /// 更新文章
    func updateArticle(_ article: Article) {
        var articles = loadArticles()
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index] = article
            saveArticles(articles)
        }
    }

    /// 检查文章是否已存在
    func articleExists(link: String) -> Bool {
        return loadArticles().contains { $0.link == link }
    }

    /// 批量添加文章（跳过已存在的，但更新内容）
    func addArticles(_ articles: [Article]) -> Int {
        var storedArticles = loadArticles()
        var addedCount = 0

        for article in articles {
            if let existingIndex = storedArticles.firstIndex(where: { $0.link == article.link }) {
                // 文章已存在，检查是否需要更新内容
                let existingArticle = storedArticles[existingIndex]
                // 如果新文章有更好的内容（更长），则更新
                if let newContent = article.content, !newContent.isEmpty {
                    let existingContentLength = existingArticle.content?.count ?? 0
                    if newContent.count > existingContentLength {
                        storedArticles[existingIndex].content = article.content
                    }
                }
                // 如果新文章有图片URL而旧文章没有，则更新
                if let newImageUrl = article.imageUrl, !newImageUrl.isEmpty,
                   existingArticle.imageUrl == nil || existingArticle.imageUrl?.isEmpty == true {
                    storedArticles[existingIndex].imageUrl = article.imageUrl
                }
            } else {
                // 新文章，添加到列表
                storedArticles.insert(article, at: 0)
                addedCount += 1
            }
        }

        saveArticles(storedArticles)
        return addedCount
    }

    /// 标记文章为已读
    func markArticleAsRead(_ article: Article) {
        var articles = loadArticles()
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isRead = true
            saveArticles(articles)
        }
    }

    /// 切换文章收藏状态
    func toggleArticleFavorite(_ article: Article) -> Bool {
        var articles = loadArticles()
        guard let index = articles.firstIndex(where: { $0.id == article.id }) else { return false }

        let newStatus = !articles[index].isFavorite
        articles[index].isFavorite = newStatus
        saveArticles(articles)

        if newStatus {
            // 收藏：将文章快照存入收藏存储
            var favorites = loadFavoriteArticles()
            if !favorites.contains(where: { $0.id == article.id }) {
                var snapshot = articles[index]
                snapshot.isFavorite = true
                favorites.insert(snapshot, at: 0)
                saveFavoriteArticles(favorites)
            }
        } else {
            // 取消收藏：从收藏存储中移除
            var favorites = loadFavoriteArticles()
            favorites.removeAll { $0.id == article.id }
            saveFavoriteArticles(favorites)
        }

        return newStatus
    }

    /// 更新阅读进度
    func updateReadingProgress(_ article: Article, progress: Double) {
        var articles = loadArticles()
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].readingProgress = progress
            saveArticles(articles)
        }
    }

    /// 删除文章（跳过收藏文章，收藏文章只能通过 deleteFavoriteArticle 删除）
    func deleteArticle(_ article: Article) {
        var articles = loadArticles()
        articles.removeAll { $0.id == article.id && !$0.isFavorite }
        saveArticles(articles)
    }

    /// 真正删除收藏文章（从收藏存储和普通存储中同时移除）
    func deleteFavoriteArticle(_ article: Article) {
        // 从收藏存储中移除
        var favorites = loadFavoriteArticles()
        favorites.removeAll { $0.id == article.id }
        saveFavoriteArticles(favorites)

        // 从普通存储中移除
        var articles = loadArticles()
        articles.removeAll { $0.id == article.id }
        saveArticles(articles)
    }

    // MARK: - Category 操作

    private func loadCategories() -> [VocabularyCategory] {
        if let data = defaults.data(forKey: categoriesKey) {
            do {
                let categories = try JSONDecoder().decode([VocabularyCategory].self, from: data)
                print("✅ Loaded \(categories.count) categories from UserDefaults")
                return categories.sorted(by: { $0.order < $1.order })
            } catch {
                print("❌ Failed to decode categories: \(error)")
            }
        }
        print("⚠️ No categories found in UserDefaults")
        return []
    }

    private func saveCategories(_ categories: [VocabularyCategory]) {
        do {
            let data = try JSONEncoder().encode(categories)
            defaults.set(data, forKey: categoriesKey)
            defaults.synchronize()
            print("✅ Saved \(categories.count) categories to UserDefaults")
        } catch {
            print("❌ Failed to encode categories: \(error)")
        }
    }

    /// 获取所有分类
    func fetchAllCategories() -> [VocabularyCategory] {
        return loadCategories()
    }

    /// 添加分类
    func addCategory(_ category: VocabularyCategory) -> VocabularyCategory {
        var categories = loadCategories()
        var newCategory = category
        newCategory.order = categories.count
        categories.append(newCategory)
        print("📝 Adding category: \(newCategory.name), order: \(newCategory.order)")
        saveCategories(categories)
        return newCategory
    }

    /// 更新分类
    func updateCategory(_ category: VocabularyCategory) {
        var categories = loadCategories()
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories(categories)
        }
    }

    /// 删除分类
    func deleteCategory(_ category: VocabularyCategory) {
        // 不允许删除默认分类
        if category.isDefault { return }
        
        var categories = loadCategories()
        categories.removeAll { $0.id == category.id }
        saveCategories(categories)
        
        // 将该分类下的生词移到"全部"分类
        let allCategoryId = VocabularyCategory.allCategory.id
        var vocabList = loadVocabulary()
        for i in vocabList.indices {
            if vocabList[i].categoryId == category.id {
                vocabList[i].categoryId = nil // 移除分类，归入全部
            }
        }
        saveVocabulary(vocabList)
    }

    /// 获取分类
    func fetchCategory(by id: UUID) -> VocabularyCategory? {
        return loadCategories().first { $0.id == id }
    }

    // MARK: - Vocabulary 操作

    private func loadVocabulary() -> [Vocabulary] {
        if let data = defaults.data(forKey: vocabularyKey),
           let vocab = try? JSONDecoder().decode([Vocabulary].self, from: data) {
            return vocab
        }
        return []
    }

    private func saveVocabulary(_ vocabulary: [Vocabulary]) {
        if let data = try? JSONEncoder().encode(vocabulary) {
            defaults.set(data, forKey: vocabularyKey)
        }
    }

    /// 获取所有生词
    func fetchAllVocabulary() -> [Vocabulary] {
        return loadVocabulary()
    }

    /// 获取指定分类的生词
    func fetchVocabulary(for categoryId: UUID?) -> [Vocabulary] {
        let vocabList = loadVocabulary()
        if categoryId == nil {
            return vocabList
        }
        return vocabList.filter { $0.categoryId == categoryId }
    }

    /// 获取今日需要复习的生词
    func fetchTodayReviewVocabulary(for categoryId: UUID? = nil) -> [Vocabulary] {
        let vocabList = loadVocabulary().filter { $0.needsReviewToday }
        if categoryId == nil {
            return vocabList
        }
        return vocabList.filter { $0.categoryId == categoryId }
    }

    /// 搜索生词
    func searchVocabulary(_ word: String) -> Vocabulary? {
        return loadVocabulary().first { $0.word.lowercased() == word.lowercased() }
    }

    /// 添加生词
    func addVocabulary(_ vocabulary: Vocabulary) -> Vocabulary {
        var vocabList = loadVocabulary()

        // 检查是否已存在
        if let existingIndex = vocabList.firstIndex(where: { $0.word.lowercased() == vocabulary.word.lowercased() }) {
            var existing = vocabList[existingIndex]

            // 用新查询到的数据补全历史记录，避免旧词条一直没有释义。
            if (existing.definition?.isEmpty ?? true), let definition = vocabulary.definition, !definition.isEmpty {
                existing.definition = definition
            }
            if (existing.partOfSpeech?.isEmpty ?? true), let partOfSpeech = vocabulary.partOfSpeech, !partOfSpeech.isEmpty {
                existing.partOfSpeech = partOfSpeech
            }
            if (existing.phonetic?.isEmpty ?? true), let phonetic = vocabulary.phonetic, !phonetic.isEmpty {
                existing.phonetic = phonetic
            }
            if (existing.contextSnippet?.isEmpty ?? true), let contextSnippet = vocabulary.contextSnippet, !contextSnippet.isEmpty {
                existing.contextSnippet = contextSnippet
            }
            if existing.exampleSentence == nil, let exampleSentence = vocabulary.exampleSentence, !exampleSentence.isEmpty {
                existing.exampleSentence = exampleSentence
            }
            if existing.categoryId == nil {
                existing.categoryId = vocabulary.categoryId
            }

            vocabList[existingIndex] = existing
            saveVocabulary(vocabList)
            return existing
        }

        vocabList.append(vocabulary)
        saveVocabulary(vocabList)
        return vocabulary
    }

    /// 更新生词
    func updateVocabulary(_ vocabulary: Vocabulary) {
        var vocabList = loadVocabulary()
        if let index = vocabList.firstIndex(where: { $0.id == vocabulary.id }) {
            vocabList[index] = vocabulary
            saveVocabulary(vocabList)
        }
    }

    /// 更新生词分类
    func updateVocabularyCategory(_ vocabulary: Vocabulary, categoryId: UUID?) {
        var vocabList = loadVocabulary()
        if let index = vocabList.firstIndex(where: { $0.id == vocabulary.id }) {
            vocabList[index].categoryId = categoryId
            saveVocabulary(vocabList)
        }
    }

    /// 删除生词
    func deleteVocabulary(_ vocabulary: Vocabulary) {
        var vocabList = loadVocabulary()
        vocabList.removeAll { $0.id == vocabulary.id }
        saveVocabulary(vocabList)
    }

    /// 获取生词数量
    func vocabularyCount(for categoryId: UUID? = nil) -> Int {
        let vocabList = loadVocabulary()
        if categoryId == nil {
            return vocabList.count
        }
        return vocabList.filter { $0.categoryId == categoryId }.count
    }

    /// 获取已掌握生词数量
    func masteredVocabularyCount(for categoryId: UUID? = nil) -> Int {
        let vocabList = loadVocabulary().filter { $0.masteredLevel >= 4 }
        if categoryId == nil {
            return vocabList.count
        }
        return vocabList.filter { $0.categoryId == categoryId }.count
    }
}
