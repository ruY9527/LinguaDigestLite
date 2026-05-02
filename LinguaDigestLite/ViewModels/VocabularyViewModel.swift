//
//  VocabularyViewModel.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import Combine

/// 生词筛选状态类型
enum VocabularyFilterType: String, CaseIterable {
    case all = "总数"
    case mastered = "已掌握"
    case learning = "学习中"
    case reviewToday = "待复习"

    var displayName: String {
        switch self {
        case .all: return L("stat.total")
        case .mastered: return L("stat.mastered")
        case .learning: return L("stat.learning")
        case .reviewToday: return L("stat.reviewDue")
        }
    }

    var color: String {
        switch self {
        case .all: return "#007AFF"      // 蓝色
        case .mastered: return "#34C759" // 绿色
        case .learning: return "#FF9500" // 橙色
        case .reviewToday: return "#FF3B30" // 红色
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "book.fill"
        case .mastered: return "checkmark.seal.fill"
        case .learning: return "book.pages.fill"
        case .reviewToday: return "clock.fill"
        }
    }
}

/// 生词本ViewModel
class VocabularyViewModel: ObservableObject {
    @Published var vocabulary: [Vocabulary] = []
    @Published var todayReviewWords: [Vocabulary] = []
    @Published var categories: [VocabularyCategory] = []
    @Published var selectedCategory: VocabularyCategory?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingReviewMode: Bool = false
    @Published var showingCategoryManagement: Bool = false
    @Published var currentReviewWord: Vocabulary?
    @Published var reviewCompletedCount: Int = 0
    
    /// 筛选状态
    @Published var filterType: VocabularyFilterType = .all
    @Published var showingFilteredList: Bool = false
    @Published private(set) var hasAnyVocabulary: Bool = false

    private let databaseManager = DatabaseManager.shared
    private let dictionaryService = DictionaryService.shared
    private let speechService = SpeechService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        observeVocabularyChanges()
        loadCategories()
        loadVocabulary()
    }

    private func observeVocabularyChanges() {
        NotificationCenter.default.publisher(for: .vocabularyDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadData()
            }
            .store(in: &cancellables)
    }

    /// 加载分类
    func loadCategories() {
        categories = databaseManager.fetchAllCategories()
        // 如果当前选中的分类不在列表中，或者没有选中，默认选中“全部”
        if selectedCategory == nil || !categories.contains(where: { $0.id == selectedCategory?.id }) {
            selectedCategory = allCategory
        }
    }

    /// 加载所有生词
    func loadVocabulary() {
        let categoryId = selectedCategory?.isAllCategory == true ? nil : selectedCategory?.id
        vocabulary = databaseManager.fetchVocabulary(for: categoryId)
        hasAnyVocabulary = categoryId == nil ? !vocabulary.isEmpty : databaseManager.vocabularyCount(for: nil) > 0

        guard !vocabulary.isEmpty else {
            todayReviewWords = []
            return
        }

        backfillVocabularyDefinitionsIfNeeded()
        todayReviewWords = databaseManager.fetchTodayReviewVocabulary(for: categoryId)
    }

    /// 下拉刷新：重新加载分类和生词数据
    func reloadData() {
        loadCategories()
        loadVocabulary()
    }
    
    /// 根据筛选类型获取单词列表
    func filteredVocabularyForType(_ type: VocabularyFilterType) -> [Vocabulary] {
        switch type {
        case .all:
            return vocabulary
        case .mastered:
            return vocabulary.filter { $0.masteredLevel >= 4 }
        case .learning:
            return vocabulary.filter { $0.masteredLevel > 0 && $0.masteredLevel < 4 }
        case .reviewToday:
            return todayReviewWords
        }
    }
    
    /// 设置筛选类型并打开筛选列表
    func setFilterAndShowList(_ type: VocabularyFilterType) {
        filterType = type
        showingFilteredList = true
    }
    
    /// 获取筛选状态的单词数量
    func countForFilterType(_ type: VocabularyFilterType) -> Int {
        switch type {
        case .all:
            return totalVocabularyCount
        case .mastered:
            return masteredVocabularyCount
        case .learning:
            return vocabulary.count - masteredVocabularyCount - todayReviewCount
        case .reviewToday:
            return todayReviewCount
        }
    }
    
    /// 学习中单词数量
    var learningVocabularyCount: Int {
        vocabulary.count - masteredVocabularyCount - todayReviewCount
    }

    /// 选择分类
    func selectCategory(_ category: VocabularyCategory) {
        guard selectedCategory?.id != category.id else { return }
        selectedCategory = category

        // 全局没有任何生词时，切回“全部”只需要切换空态，不必重复走数据库加载链路。
        if category.isAllCategory && !hasAnyVocabulary {
            vocabulary = []
            todayReviewWords = []
            return
        }

        loadVocabulary()
    }

    /// 切换到“全部”分类
    func showAllVocabulary() {
        guard let category = allCategory else { return }
        selectCategory(category)
    }

    /// 添加分类
    func addCategory(name: String, description: String?, color: String, icon: String) {
        let category = VocabularyCategory(
            name: name,
            description: description,
            color: color,
            icon: icon,
            isDefault: false
        )
        print("📝 Creating category: \(name)")
        databaseManager.addCategory(category)
        loadCategories()
        print("📋 Categories after add: \(categories.map { $0.name })")
    }

    /// 更新分类
    func updateCategory(_ category: VocabularyCategory) {
        databaseManager.updateCategory(category)
        loadCategories()
    }

    /// 删除分类
    func deleteCategory(_ category: VocabularyCategory) {
        databaseManager.deleteCategory(category)
        loadCategories()
        // 如果删除的是当前选中的分类，切换到全部
        if selectedCategory?.id == category.id {
            selectedCategory = allCategory
            loadVocabulary()
        }
    }

    /// 添加生词
    func addVocabulary(word: String, definition: String? = nil, phonetic: String? = nil, partOfSpeech: String? = nil, context: String? = nil, articleId: UUID? = nil, categoryId: UUID? = nil) {
        let vocab = Vocabulary(
            word: word,
            definition: definition,
            phonetic: phonetic,
            partOfSpeech: partOfSpeech,
            exampleSentence: nil,
            articleId: articleId,
            categoryId: categoryId,
            contextSnippet: context
        )

        databaseManager.addVocabulary(vocab)
        loadVocabulary()
    }

    /// 更新生词分类
    func updateVocabularyCategory(_ vocab: Vocabulary, categoryId: UUID?) {
        databaseManager.updateVocabularyCategory(vocab, categoryId: categoryId)
        loadVocabulary()
    }

    /// 删除生词
    func deleteVocabulary(_ vocab: Vocabulary) {
        databaseManager.deleteVocabulary(vocab)
        loadVocabulary()
    }

    /// 搜索生词
    func searchVocabulary(_ word: String) -> Vocabulary? {
        return vocabulary.first { $0.word.lowercased() == word.lowercased() }
    }

    /// 检查单词是否在生词本中
    func isInVocabulary(_ word: String) -> Bool {
        return vocabulary.contains { $0.word.lowercased() == word.lowercased() }
    }

    /// 开始今日复习
    func startReview() {
        showingReviewMode = true
        reviewCompletedCount = 0

        if todayReviewWords.isEmpty {
            // 没有待复习的单词
            showingReviewMode = false
        } else {
            currentReviewWord = todayReviewWords.first
        }
    }

    /// 完成当前单词复习
    /// - Parameter quality: 复习质量评分 (0-5)
    func completeCurrentReview(quality: Int) {
        guard let word = currentReviewWord else { return }

        var updatedWord = word
        updatedWord.updateReview(quality: quality)

        databaseManager.updateVocabulary(updatedWord)

        // 移到下一个单词
        reviewCompletedCount += 1

        if reviewCompletedCount < todayReviewWords.count {
            currentReviewWord = todayReviewWords[reviewCompletedCount]
        } else {
            // 所有单词复习完成
            showingReviewMode = false
            currentReviewWord = nil
            loadVocabulary()
        }
    }

    /// 跳过当前单词
    func skipCurrentReview() {
        reviewCompletedCount += 1

        if reviewCompletedCount < todayReviewWords.count {
            currentReviewWord = todayReviewWords[reviewCompletedCount]
        } else {
            showingReviewMode = false
            currentReviewWord = nil
            loadVocabulary()
        }
    }

    /// 结束复习
    func endReview() {
        showingReviewMode = false
        currentReviewWord = nil
        loadVocabulary()
    }

    /// 朗读单词
    func speakWord(_ word: String) {
        speechService.speakWord(word)
    }

    /// 生词总数
    var totalVocabularyCount: Int {
        vocabulary.count
    }

    /// 已掌握生词数量
    var masteredVocabularyCount: Int {
        vocabulary.filter { $0.masteredLevel >= 4 }.count
    }

    /// 今日待复习数量
    var todayReviewCount: Int {
        todayReviewWords.count
    }

    /// 学习进度百分比
    var learningProgress: Double {
        if vocabulary.isEmpty { return 0 }
        return Double(masteredVocabularyCount) / Double(vocabulary.count)
    }

    /// 获取分类的生词数量
    func vocabularyCountForCategory(_ category: VocabularyCategory) -> Int {
        if category.isAllCategory {
            return databaseManager.vocabularyCount(for: nil)
        }
        return databaseManager.vocabularyCount(for: category.id)
    }

    private var allCategory: VocabularyCategory? {
        categories.first(where: \.isAllCategory) ?? categories.first
    }

    /// 获取生词统计信息
    var statistics: VocabularyStatistics {
        let mastered = vocabulary.filter { $0.masteredLevel >= 4 }.count
        let learning = vocabulary.filter { $0.masteredLevel > 0 && $0.masteredLevel < 4 }.count
        let new = vocabulary.filter { $0.masteredLevel == 0 }.count

        return VocabularyStatistics(
            total: vocabulary.count,
            mastered: mastered,
            learning: learning,
            new: new,
            reviewToday: todayReviewCount
        )
    }

    /// 为历史数据补全缺失的释义，避免生词本点击后无内容可展示。
    private func backfillVocabularyDefinitionsIfNeeded() {
        var hasUpdates = false

        for index in vocabulary.indices {
            if vocabulary[index].definition?.isEmpty ?? true,
               let definition = dictionaryService.getDefinition(for: vocabulary[index].word),
               !definition.isEmpty {
                vocabulary[index].definition = definition
                hasUpdates = true
            }

            if vocabulary[index].partOfSpeech?.isEmpty ?? true,
               let partOfSpeech = dictionaryService.getPartOfSpeechFromDictionary(for: vocabulary[index].word) {
                vocabulary[index].partOfSpeech = partOfSpeech
                hasUpdates = true
            }

            // 补全按词性分组的释义
            if vocabulary[index].groupedDefinitions == nil || vocabulary[index].groupedDefinitions?.isEmpty == true {
                let grouped = dictionaryService.getGroupedDefinitions(for: vocabulary[index].word)
                if !grouped.isEmpty {
                    vocabulary[index].groupedDefinitions = grouped.map { PosDefinitions(pos: $0.pos, definitions: $0.definitions) }
                    hasUpdates = true
                }
            }

            // 补全英文释义
            if vocabulary[index].englishDefinition == nil || vocabulary[index].englishDefinition?.isEmpty == true {
                if let englishDef = dictionaryService.getEnglishDefinition(for: vocabulary[index].word) {
                    vocabulary[index].englishDefinition = englishDef
                    hasUpdates = true
                }
            }
        }

        if hasUpdates {
            for item in vocabulary {
                databaseManager.updateVocabulary(item)
            }
        }
    }
}

/// 生词统计信息
struct VocabularyStatistics {
    var total: Int
    var mastered: Int
    var learning: Int
    var new: Int
    var reviewToday: Int

    var description: String {
        String(format: L("vocab.statsSummary"), total, mastered, learning, new, reviewToday)
    }
}
