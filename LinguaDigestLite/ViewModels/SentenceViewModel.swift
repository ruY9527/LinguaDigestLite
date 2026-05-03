//
//  SentenceViewModel.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import Combine

/// 收藏句子管理 ViewModel
class SentenceViewModel: ObservableObject {
    @Published var sentences: [SavedSentence] = []
    @Published var categories: [VocabularyCategory] = []
    @Published var selectedCategory: VocabularyCategory?
    @Published var searchText: String = ""
    @Published var showingEditSheet: Bool = false
    @Published var currentEditSentence: SavedSentence?
    @Published var navigateToArticleId: UUID?

    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        observeSentenceChanges()
        loadCategories()
        loadSentences()
    }

    // MARK: - 数据加载

    func reloadData() {
        loadCategories()
        loadSentences()
    }

    func loadCategories() {
        categories = databaseManager.fetchAllCategories()
    }

    func loadSentences() {
        if let categoryId = selectedCategory?.id {
            sentences = databaseManager.fetchSentences(for: categoryId)
        } else {
            sentences = databaseManager.fetchAllSentences()
        }
    }

    // MARK: - 分类选择

    func selectCategory(_ category: VocabularyCategory) {
        if category.isAllCategory {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
        loadSentences()
    }

    // MARK: - 句子操作

    func deleteSentence(_ sentence: SavedSentence) {
        databaseManager.deleteSentence(sentence)
        loadSentences()
    }

    func updateSentence(_ sentence: SavedSentence) {
        databaseManager.updateSentence(sentence)
        loadSentences()
    }

    func updateNotes(for sentence: SavedSentence, notes: String) {
        var updated = sentence
        updated.notes = notes.isEmpty ? nil : notes
        databaseManager.updateSentence(updated)
        loadSentences()
    }

    func updateTranslation(for sentence: SavedSentence, translation: String) {
        var updated = sentence
        updated.translation = translation.isEmpty ? nil : translation
        databaseManager.updateSentence(updated)
        loadSentences()
    }

    // MARK: - 搜索和筛选

    var filteredSentences: [SavedSentence] {
        guard !searchText.isEmpty else { return sentences }
        let query = searchText.lowercased()
        return sentences.filter {
            $0.sentence.lowercased().contains(query) ||
            ($0.translation?.lowercased().contains(query) ?? false) ||
            ($0.notes?.lowercased().contains(query) ?? false) ||
            ($0.articleTitle?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - 统计

    func sentenceCount(for categoryId: UUID? = nil) -> Int {
        databaseManager.sentenceCount(for: categoryId)
    }

    var totalSentenceCount: Int {
        databaseManager.sentenceCount()
    }

    // MARK: - 跳转到原文

    func jumpToSource(for sentence: SavedSentence) {
        guard let articleId = sentence.articleId else { return }
        navigateToArticleId = articleId
    }

    // MARK: - 通知监听

    private func observeSentenceChanges() {
        NotificationCenter.default.publisher(for: .sentenceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadSentences()
            }
            .store(in: &cancellables)
    }
}
