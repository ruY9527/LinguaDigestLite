//
//  ReaderViewModel.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import AVFoundation
import Combine

/// 单词分析结果
struct WordAnalysis {
    var partOfSpeech: String?
    var lemma: String?
}

/// 阅读器ViewModel
class ReaderViewModel: ObservableObject {
    @Published private(set) var article: Article

    @Published var content: String = ""
    @Published var isLoadingContent: Bool = true
    @Published var isFavorite: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var currentReadingProgress: Double?

    // 单词查询相关
    @Published var showingWordDefinition: Bool = false
    @Published var showingSystemDictionarySheet: Bool = false
    @Published var selectedWord: String?
    @Published var selectedWordDefinition: String?
    @Published var selectedWordDefinitions: [String] = []
    @Published var selectedWordPartOfSpeech: String?
    @Published var selectedWordContext: String?
    @Published var wordAnalysis: WordAnalysis?
    @Published var selectedCategoryForWord: VocabularyCategory?
    @Published var categories: [VocabularyCategory] = []

    private let databaseManager = DatabaseManager.shared
    private let feedService = FeedService.shared
    private let dictionaryService = DictionaryService.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    init(article: Article) {
        self.article = article
        self.isFavorite = article.isFavorite

        loadContent()
        loadCategories()
    }

    // MARK: - 文章内容

    /// 加载文章全文内容
    func loadContent() {
        isLoadingContent = true

        Task {
            let existingContent = bestAvailableLocalContent()
            let shouldFetchRemoteFullContent = existingContent.count < 800 ||
                existingContent.components(separatedBy: "\n\n").count < 4

            if !shouldFetchRemoteFullContent {
                await MainActor.run {
                    self.content = existingContent
                    self.isLoadingContent = false
                }
            } else {
                do {
                    let (fullContent, htmlContent) = try await feedService.fetchFullArticleContent(from: article.link)
                    await MainActor.run {
                        let cleanedContent = FeedService.sanitizeReadableArticleText(fullContent) ?? FeedService.cleanHTMLContent(fullContent)
                        self.content = cleanedContent.isEmpty ? self.bestAvailableLocalContent() : cleanedContent
                        self.article.content = self.content
                        self.article.htmlContent = htmlContent
                        self.databaseManager.updateArticle(self.article)
                        self.isLoadingContent = false
                    }
                } catch {
                    await MainActor.run {
                        self.content = self.bestAvailableLocalContent()
                        self.isLoadingContent = false
                    }
                }
            }
        }
    }

    /// 标记文章为已读
    func markAsRead() {
        databaseManager.markArticleAsRead(article)
        article.isRead = true
    }

    /// 切换收藏状态
    func toggleFavorite() {
        let newFavoriteStatus = databaseManager.toggleArticleFavorite(article)
        isFavorite = newFavoriteStatus
        article.isFavorite = newFavoriteStatus
    }

    // MARK: - 朗读

    /// 朗读文章
    func speakArticle() {
        guard !content.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: content)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0

        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }

    /// 停止朗读
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentReadingProgress = nil
    }

    /// 朗读单个单词
    func speakWord(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4

        speechSynthesizer.speak(utterance)
    }

    // MARK: - 单词查询

    /// 查询单词
    func lookupWord(_ word: String) {
        selectedWord = word

        // 获取单词分析（词性、原形等）
        let pos = dictionaryService.getPartOfSpeech(for: word)
        let lemma = dictionaryService.getLemma(for: word)
        wordAnalysis = WordAnalysis(partOfSpeech: pos, lemma: lemma)

        // 使用离线词典的词性（更准确）
        if let dictPos = dictionaryService.getPartOfSpeechFromDictionary(for: word) {
            selectedWordPartOfSpeech = dictPos
        } else {
            selectedWordPartOfSpeech = pos
        }

        // 获取中文释义（优先使用离线词典）
        let definitions = dictionaryService.getDefinitions(for: word)
        if !definitions.isEmpty {
            selectedWordDefinitions = definitions
            selectedWordDefinition = definitions.joined(separator: "；")
        } else if dictionaryService.hasSystemDefinition(for: word) {
            // 如果离线词典没有，但系统词典有，提示用户可查看系统词典
            selectedWordDefinitions = []
            selectedWordDefinition = "点击下方「打开原文」可使用系统词典查看详细释义"
        } else {
            selectedWordDefinitions = []
            selectedWordDefinition = nil
        }

        // 获取上下文（从文章中查找）
        selectedWordContext = extractContextForWord(word)

        let hasSystemDefinition = dictionaryService.hasSystemDefinition(for: word)
        showingSystemDictionarySheet = hasSystemDefinition
        showingWordDefinition = !hasSystemDefinition
    }

    /// 关闭单词定义卡片
    func closeWordDefinition() {
        showingWordDefinition = false
        showingSystemDictionarySheet = false
        selectedWord = nil
        selectedWordDefinition = nil
        selectedWordDefinitions = []
        selectedWordPartOfSpeech = nil
        selectedWordContext = nil
        wordAnalysis = nil
        selectedCategoryForWord = nil
    }

    /// 从文章中提取单词上下文
    private func extractContextForWord(_ word: String) -> String? {
        guard !content.isEmpty else { return nil }

        let lowercasedContent = content.lowercased()
        let lowercasedWord = word.lowercased()

        if let range = lowercasedContent.range(of: lowercasedWord) {
            let nsRange = NSRange(range, in: content)
            let contextLength = 50
            let start = max(0, nsRange.location - contextLength)
            let end = min(content.count, nsRange.location + nsRange.length + contextLength)

            let startIndex = content.index(content.startIndex, offsetBy: start)
            let endIndex = content.index(content.startIndex, offsetBy: end)

            let context = content[startIndex..<endIndex]
            return "...\(context)..."
        }

        return nil
    }

    // MARK: - 生词本

    /// 加载分类列表
    func loadCategories() {
        categories = databaseManager.fetchAllCategories()
        // 默认选择第一个分类（或"全部"）
        selectedCategoryForWord = categories.first
    }

    /// 添加单词到生词本
    func addToVocabulary(word: String, context: String?, categoryId: UUID?) {
        // 获取释义（优先使用离线词典）
        var definitionToSave: String? = nil
        
        // 如果当前有释义且不为空，使用它
        if let currentDef = selectedWordDefinition, !currentDef.isEmpty {
            definitionToSave = currentDef
        } else {
            // 否则尝试从离线词典获取
            definitionToSave = dictionaryService.getDefinition(for: word)
        }
        
        let vocabulary = Vocabulary(
            word: word,
            definition: definitionToSave,
            partOfSpeech: selectedWordPartOfSpeech,
            exampleSentence: context,
            articleId: article.id,
            categoryId: categoryId,
            contextSnippet: context
        )

        databaseManager.addVocabulary(vocabulary)
    }

    // MARK: - 文章信息

    /// 来源名称
    var sourceName: String {
        if let feedId = article.feedId {
            let feeds = databaseManager.fetchAllFeeds()
            if let feed = feeds.first(where: { $0.id == feedId }) {
                return feed.title
            }
        }
        return "未知来源"
    }

    /// 发布日期描述
    var publishedDateDescription: String {
        guard let publishedAt = article.publishedAt else {
            return "未知日期"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }

    /// 发布日期格式化显示
    var publishedDate: String {
        guard let publishedAt = article.publishedAt else {
            return "未知"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        return formatter.string(from: publishedAt)
    }

    var displaySummary: String? {
        guard let summary = article.summary else { return nil }
        let cleaned = FeedService.cleanHTMLContent(summary)
        guard !cleaned.isEmpty, cleaned != content else { return nil }
        return cleaned
    }

    var estimatedReadingMinutes: Int {
        let wordCount = max(content.split(whereSeparator: \.isWhitespace).count, 1)
        return max(1, Int(ceil(Double(wordCount) / 220.0)))
    }

    private func bestAvailableLocalContent() -> String {
        let candidates = [
            article.content,
            article.summary,
            article.htmlContent
        ]

        for candidate in candidates {
            let cleaned = FeedService.sanitizeReadableArticleText(candidate) ?? FeedService.cleanHTMLContent(candidate ?? "")
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return ""
    }
}
