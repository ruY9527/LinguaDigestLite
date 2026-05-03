//
//  VocabularyListView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 内容类型枚举
enum VocabularyContentType: String, CaseIterable {
    case words
    case sentences
}

/// 生词本列表视图
struct VocabularyListView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @ObservedObject var sentenceViewModel: SentenceViewModel
    @Binding var selectedTab: Int
    @Binding var navigateToArticleId: UUID?

    @State private var showingReview: Bool = false
    @State private var searchText: String = ""
    @State private var showingAddCategory: Bool = false
    @State private var showingCategoryList: Bool = false
    @State private var showingFilteredList: Bool = false
    @State private var selectedContentType: VocabularyContentType = .words

    var body: some View {
        NavigationStack {
            Group {
                if selectedContentType == .sentences {
                    sentenceContent
                } else if viewModel.vocabulary.isEmpty && !(viewModel.selectedCategory?.isAllCategory ?? true) {
                    emptyCategoryView
                } else if viewModel.vocabulary.isEmpty {
                    emptyStateView
                } else {
                    vocabularyContent
                }
            }
            .navigationTitle(L("nav.vocabulary"))
            .searchable(text: $searchText, prompt: selectedContentType == .words ? L("search.vocabulary") : L("search.sentences"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button {
                            viewModel.selectCategory(category)
                            sentenceViewModel.selectCategory(category)
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                Text(category.name)
                                Spacer()
                                if viewModel.selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let category = viewModel.selectedCategory {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.color))
                            Text(category.name)
                                .font(.headline)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingAddCategory = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                        }

                        if selectedContentType == .words {
                            Button {
                                viewModel.startReview()
                            } label: {
                                Image(systemName: "brain.head.profile")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingReviewMode) {
                ReviewView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: {
                viewModel.loadCategories()
                sentenceViewModel.loadCategories()
            }) {
                AddCategoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCategoryList, onDismiss: {
                viewModel.loadCategories()
            }) {
                CategoryListView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFilteredList) {
                FilteredVocabularyListView(viewModel: viewModel, filterType: viewModel.filterType)
            }
            .sheet(isPresented: $sentenceViewModel.showingEditSheet) {
                if let sentence = sentenceViewModel.currentEditSentence {
                    SentenceDetailView(sentence: sentence, sentenceViewModel: sentenceViewModel)
                }
            }
            .onReceive(sentenceViewModel.$navigateToArticleId) { articleId in
                if let articleId {
                    navigateToArticleId = articleId
                    sentenceViewModel.navigateToArticleId = nil
                }
            }
            .onAppear {
                viewModel.reloadData()
                sentenceViewModel.reloadData()
            }
        }
    }

    /// 生词本内容
    private var vocabularyContent: some View {
        VStack(spacing: 0) {
            // 内容类型切换
            contentTypePicker

            // 当前分类标题
            if let category = viewModel.selectedCategory {
                categoryHeaderView(category)
            }

            // 统计卡片
            statisticsCard

            // 生词列表
            vocabularyList
        }
    }

    /// 句子内容
    private var sentenceContent: some View {
        VStack(spacing: 0) {
            // 内容类型切换
            contentTypePicker

            // 当前分类标题
            if let category = sentenceViewModel.selectedCategory {
                sentenceCategoryHeaderView(category)
            }

            // 句子统计卡片
            sentenceStatisticsCard

            // 句子列表
            sentenceList
        }
    }

    /// 内容类型切换器
    private var contentTypePicker: some View {
        Picker(L("nav.vocabulary"), selection: $selectedContentType) {
            Text(L("tab.words")).tag(VocabularyContentType.words)
            Text(L("tab.sentences")).tag(VocabularyContentType.sentences)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// 分类头部视图
    private func categoryHeaderView(_ category: VocabularyCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(Color(hex: category.color))

            Text(category.name)
                .font(.headline)

            if let description = category.description {
                Text("- \(description)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: L("vocab.countSuffix"), viewModel.vocabulary.count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    /// 统计卡片
    private var statisticsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatItem(title: L("stat.total"), value: viewModel.totalVocabularyCount, color: .blue)
                StatItem(title: L("stat.mastered"), value: viewModel.masteredVocabularyCount, color: .green)
                StatItem(title: L("stat.learning"), value: viewModel.vocabulary.count - viewModel.masteredVocabularyCount - viewModel.todayReviewCount, color: .orange)
                StatItem(title: L("stat.reviewDue"), value: viewModel.todayReviewCount, color: .red)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * viewModel.learningProgress, height: 8)
                }
            }
            .frame(height: 8)

            if viewModel.todayReviewCount > 0 {
                Button {
                    viewModel.startReview()
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text(String(format: L("action.startReview"), viewModel.todayReviewCount))
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }

    /// 生词列表
    private var vocabularyList: some View {
        List {
            ForEach(filteredVocabulary, id: \.id) { vocab in
                VocabularyRowView(vocabulary: vocab, categories: getCategoriesForVocabulary(vocab)) {
                    viewModel.speakWord(vocab.word)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteVocabulary(vocab)
                    } label: {
                        Label(L("common.delete"), systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        // 移动到其他分类
                    } label: {
                        Label(L("action.move"), systemImage: "folder")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.reloadData()
        }
    }

    /// 获取生词所属分类
    private func getCategoriesForVocabulary(_ vocab: Vocabulary) -> [VocabularyCategory] {
        let categoryIds = vocab.categoryIds.isEmpty ? (vocab.categoryId.map { [$0] } ?? []) : vocab.categoryIds
        return viewModel.categories.filter { categoryIds.contains($0.id) }
    }

    /// 筛选后的生词列表
    private var filteredVocabulary: [Vocabulary] {
        if searchText.isEmpty {
            return viewModel.vocabulary
        }
        return viewModel.vocabulary.filter { vocab in
            vocab.word.lowercased().contains(searchText.lowercased()) ||
            vocab.definition?.lowercased().contains(searchText.lowercased()) ?? false
        }
    }

    /// 空分类视图
    private var emptyCategoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(L("empty.noVocabInCategory"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L("empty.noVocabInCategoryHint"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                viewModel.showAllVocabulary()
            } label: {
                Text(L("action.showAllVocab"))
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(L("empty.noVocab"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L("empty.noVocabHint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 句子相关视图

    /// 句子分类头部
    private func sentenceCategoryHeaderView(_ category: VocabularyCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(Color(hex: category.color))
            Text(category.name)
                .font(.headline)
            if let description = category.description {
                Text("- \(description)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: L("sentence.countSuffix"), sentenceViewModel.sentenceCount(for: category.id)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    /// 句子统计卡片
    private var sentenceStatisticsCard: some View {
        HStack(spacing: 20) {
            StatItem(title: L("stat.sentences"), value: sentenceViewModel.totalSentenceCount, color: .blue)
            StatItem(title: L("stat.total"), value: sentenceViewModel.totalSentenceCount, color: .green)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }

    /// 句子列表
    private var sentenceList: some View {
        Group {
            if filteredSentences.isEmpty {
                sentenceEmptyStateView
            } else {
                List {
                    ForEach(filteredSentences, id: \.id) { sentence in
                        SentenceRowView(
                            sentence: sentence,
                            categories: getCategoriesForSentence(sentence),
                            onSpeak: {
                                SpeechService.shared.speak(sentence.sentence)
                            },
                            onJumpToSource: {
                                navigateToArticleId = sentence.articleId
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                sentenceViewModel.deleteSentence(sentence)
                            } label: {
                                Label(L("common.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                sentenceViewModel.currentEditSentence = sentence
                                sentenceViewModel.showingEditSheet = true
                            } label: {
                                Label(L("common.edit"), systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    sentenceViewModel.reloadData()
                }
            }
        }
    }

    /// 筛选后的句子列表
    private var filteredSentences: [SavedSentence] {
        if searchText.isEmpty {
            return sentenceViewModel.sentences
        }
        let query = searchText.lowercased()
        return sentenceViewModel.sentences.filter {
            $0.sentence.lowercased().contains(query) ||
            ($0.translation?.lowercased().contains(query) ?? false) ||
            ($0.articleTitle?.lowercased().contains(query) ?? false)
        }
    }

    /// 获取句子所属分类
    private func getCategoriesForSentence(_ sentence: SavedSentence) -> [VocabularyCategory] {
        sentenceViewModel.categories.filter { sentence.categoryIds.contains($0.id) }
    }

    /// 句子空状态
    private var sentenceEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(L("empty.noSentences"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L("empty.noSentencesHint"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 篩選生词列表视图

/// 篩選生词列表视图
struct FilteredVocabularyListView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    let filterType: VocabularyFilterType
    @Environment(\.dismiss) private var dismiss

    @State private var filteredVocabularies: [Vocabulary] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredVocabularies, id: \.id) { vocabulary in
                    VocabularyRowView(
                        vocabulary: vocabulary,
                        categories: categoriesForVocabulary(vocabulary),
                        onSpeak: {
                            viewModel.speakWord(vocabulary.word)
                        }
                    )
                }
            }
            .navigationTitle(filterType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                filteredVocabularies = viewModel.filteredVocabularyForType(filterType)
            }
        }
    }

    private func categoriesForVocabulary(_ vocabulary: Vocabulary) -> [VocabularyCategory] {
        let categoryIds = vocabulary.categoryIds.isEmpty ? (vocabulary.categoryId.map { [$0] } ?? []) : vocabulary.categoryIds
        return viewModel.categories.filter { categoryIds.contains($0.id) }
    }
}
