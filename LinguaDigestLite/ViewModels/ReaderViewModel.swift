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
    @Published var selectedWordGroupedDefinitions: [(pos: String, definitions: [String])] = []
    @Published var selectedWordEnglishDefinition: String?
    
    // 句子翻译相关
    @Published var showingSentenceTranslation: Bool = false
    @Published var selectedSentence: String?
    @Published var selectedSentenceRange: NSRange?
    @Published var showingTranslationMenu: Bool = false
    @Published var availableTranslationServices: [TranslationServiceType] = []

    private let databaseManager = DatabaseManager.shared
    private let feedService = FeedService.shared
    private let dictionaryService = DictionaryService.shared
    private let translationService = TranslationService.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    init(article: Article) {
        self.article = article
        self.isFavorite = article.isFavorite
        
        // 初始化可用翻译服务列表
        availableTranslationServices = translationService.availableTranslationServiceTypes()

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
        // 确保文章包含最新内容再收藏（快照会保存完整内容）
        if !content.isEmpty {
            article.content = content
            databaseManager.updateArticle(article)
        }
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
    
    /// 朗读句子
    func speakSentence(_ sentence: String) {
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        
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

        // 获取按词性分组的释义（支持一词多义）
        let grouped = dictionaryService.getGroupedDefinitions(for: word)
        selectedWordGroupedDefinitions = grouped

        // 获取英文释义
        selectedWordEnglishDefinition = dictionaryService.getEnglishDefinition(for: word)

        // 获取中文释义（优先使用离线词典）
        let definitions = dictionaryService.getDefinitions(for: word)
        if !definitions.isEmpty {
            selectedWordDefinitions = definitions
            selectedWordDefinition = definitions.joined(separator: "；")
        } else if dictionaryService.hasSystemDefinition(for: word) {
            selectedWordDefinitions = []
            selectedWordDefinition = L("hint.systemDictPrompt")
        } else {
            selectedWordDefinitions = []
            selectedWordDefinition = nil
        }

        // 获取上下文（从文章中查找）
        selectedWordContext = extractContextForWord(word)

        // 优先展示 ECDICT 离线释义悬浮卡片；仅当离线词典无结果时回退到系统词典
        let hasOfflineDefinitions = !definitions.isEmpty
        showingWordDefinition = hasOfflineDefinitions
        showingSystemDictionarySheet = !hasOfflineDefinitions && dictionaryService.hasSystemDefinition(for: word)
    }

    /// 关闭单词定义卡片
    func closeWordDefinition() {
        showingWordDefinition = false
        showingSystemDictionarySheet = false
        selectedWord = nil
        selectedWordDefinition = nil
        selectedWordDefinitions = []
        selectedWordGroupedDefinitions = []
        selectedWordEnglishDefinition = nil
        selectedWordPartOfSpeech = nil
        selectedWordContext = nil
        wordAnalysis = nil
        selectedCategoryForWord = nil
    }
    
    // MARK: - 句子翻译
    
    /// 选择句子进行翻译
    func selectSentenceForTranslation(_ sentence: String, range: NSRange? = nil) {
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSentence.count >= 5 else { return }
        
        selectedSentence = trimmedSentence
        selectedSentenceRange = range
        showingSentenceTranslation = true
        
        // 自动使用系统翻译
        translateSelectedSentence()
    }
    
    /// 翻译选中的句子
    func translateSelectedSentence() {
        guard let sentence = selectedSentence, !sentence.isEmpty else { return }
        
        // 使用系统翻译
        translationService.translateWithSystemApp(text: sentence)
    }
    
    /// 使用指定翻译服务翻译
    func translateWithService(type: TranslationServiceType) {
        guard let sentence = selectedSentence, !sentence.isEmpty else { return }
        translationService.translate(text: sentence, serviceType: type)
    }
    
    /// 获取快速翻译预览（使用词典组合）
    func getQuickTranslationPreview() -> String? {
        guard let sentence = selectedSentence else { return nil }
        return translationService.quickTranslateSentence(sentence)
    }
    
    /// 关闭句子翻译
    func closeSentenceTranslation() {
        showingSentenceTranslation = false
        selectedSentence = nil
        selectedSentenceRange = nil
    }
    
    /// 显示翻译服务选择菜单
    func showTranslationMenu() {
        showingTranslationMenu = true
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

        // 转换分组释义为可存储格式
        let posDefs: [PosDefinitions]? = selectedWordGroupedDefinitions.isEmpty ? nil :
            selectedWordGroupedDefinitions.map { PosDefinitions(pos: $0.pos, definitions: $0.definitions) }

        // 获取英文释义
        let englishDef = selectedWordEnglishDefinition ?? dictionaryService.getEnglishDefinition(for: word)

        let vocabulary = Vocabulary(
            word: word,
            definition: definitionToSave,
            partOfSpeech: selectedWordPartOfSpeech,
            exampleSentence: context,
            articleId: article.id,
            categoryId: categoryId,
            contextSnippet: context,
            groupedDefinitions: posDefs,
            englishDefinition: englishDef
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
        return L("source.unknown")
    }

    /// 发布日期描述（publishedAt 为空时回退到 fetchedAt）
    var publishedDateDescription: String {
        let date = article.publishedAt ?? article.fetchedAt
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 发布日期格式化显示（publishedAt 为空时回退到 fetchedAt）
    var publishedDate: String {
        let date = article.publishedAt ?? article.fetchedAt
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        return formatter.string(from: date)
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
