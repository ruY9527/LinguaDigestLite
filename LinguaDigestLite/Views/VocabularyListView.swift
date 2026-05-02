//
//  VocabularyListView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI

/// 生词本列表视图
struct VocabularyListView: View {
    @ObservedObject var viewModel: VocabularyViewModel

    @State private var showingReview: Bool = false
    @State private var searchText: String = ""
    @State private var showingAddCategory: Bool = false
    @State private var showingCategoryList: Bool = false
    @State private var showingFilteredList: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.vocabulary.isEmpty && !(viewModel.selectedCategory?.isAllCategory ?? true) {
                    emptyCategoryView
                } else if viewModel.vocabulary.isEmpty {
                    emptyStateView
                } else {
                    vocabularyContent
                }
            }
            .navigationTitle(L("nav.vocabulary"))
            .searchable(text: $searchText, prompt: L("search.vocabulary"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button {
                            viewModel.selectCategory(category)
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

                        Button {
                            viewModel.startReview()
                        } label: {
                            Image(systemName: "brain.head.profile")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingReviewMode) {
                ReviewView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: {
                viewModel.loadCategories()
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
            .onAppear {
                viewModel.reloadData()
            }
        }
    }

    /// 生词本内容
    private var vocabularyContent: some View {
        VStack(spacing: 0) {
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
}

/// 分类列表视图
struct CategoryListView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddCategory: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.categories, id: \.id) { category in
                    Button {
                        viewModel.selectCategory(category)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.color))
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                if let description = category.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(viewModel.vocabularyCountForCategory(category))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: category.color).opacity(0.2))
                                .cornerRadius(8)

                            if viewModel.selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !category.isDefault {
                            Button(role: .destructive) {
                                viewModel.deleteCategory(category)
                            } label: {
                                Label(L("common.delete"), systemImage: "trash")
                            }
                        }

                        Button {
                            // 编辑分类
                        } label: {
                            Label(L("common.edit"), systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle(L("nav.selectCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: {
                viewModel.loadCategories()
            }) {
                AddCategoryView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadCategories()
            }
        }
    }
}

/// 添加分类视图
struct AddCategoryView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String = "folder"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L("section.categoryInfo")) {
                    TextField(L("category.namePlaceholder"), text: $name)
                    TextField(L("category.descPlaceholder"), text: $description)
                }
                
                Section(L("section.color")) {
                    HStack(spacing: 12) {
                        ForEach(VocabularyCategory.availableColors, id: \.hex) { color in
                            Button {
                                selectedColor = color.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section(L("section.icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VocabularyCategory.availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        if !name.isEmpty {
                            viewModel.addCategory(
                                name: name,
                                description: description.isEmpty ? nil : description,
                                color: selectedColor,
                                icon: selectedIcon
                            )
                            // 延迟dismiss，确保数据保存完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(L("action.createCategory"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle(L("nav.newCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 统计项
struct StatItem: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 生词行视图
struct VocabularyRowView: View {
    let vocabulary: Vocabulary
    let categories: [VocabularyCategory]
    let onSpeak: () -> Void
    
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        headerRow
                        metadataRow

                        if !isExpanded {
                            exampleSection
                            reviewSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                speakButton
            }

            if isExpanded {
                definitionSection
                englishDefinitionSection
                exampleSection
                reviewSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(vocabulary.word)
                        .font(.headline)
                    
                    if let phonetic = vocabulary.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let partOfSpeech = vocabulary.partOfSpeech {
                    Text(DictionaryService.displayNameForPartOfSpeech(partOfSpeech))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if !categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(categories.prefix(2)), id: \.id) { category in
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text(category.name)
                                .font(.caption2)
                        }
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: category.color).opacity(0.15))
                        .cornerRadius(4)
                    }

                    if categories.count > 2 {
                        Text("+\(categories.count - 2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(4)
                    }
                }
            }
            
            masteryIndicator
        }
    }
    
    @ViewBuilder
    private var metadataRow: some View {
        let totalDefs = totalDefinitionCount
        if totalDefs > 0 {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .foregroundColor(isExpanded ? .blue : .secondary)

                Text(isExpanded ? L("vocab.expandDef") : L("vocab.showDef"))
                    .font(.caption)
                    .foregroundColor(isExpanded ? .blue : .secondary)

                if !isExpanded {
                    Text(String(format: L("vocab.totalDefs"), totalDefs))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(6)
                }

                Spacer()
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)

                Text(L("vocab.noDef"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }

    private var totalDefinitionCount: Int {
        if let grouped = vocabulary.groupedDefinitions, !grouped.isEmpty {
            return grouped.reduce(0) { $0 + $1.definitions.count }
        }
        return definitionItems.count
    }
    
    @ViewBuilder
    private var definitionSection: some View {
        if isExpanded {
            if let grouped = vocabulary.groupedDefinitions, !grouped.isEmpty {
                // 按词性分组展示释义
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { groupIndex, group in
                        VStack(alignment: .leading, spacing: 6) {
                            if groupIndex > 0 {
                                Divider()
                            }
                            Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                .cornerRadius(4)

                            ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, def in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.blue)
                                        .frame(minWidth: 20, alignment: .trailing)
                                    Text(def)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(10)
            } else if !definitionItems.isEmpty {
                // 回退：从单字符串解析释义
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(definitionItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var englishDefinitionSection: some View {
        if isExpanded, let englishDef = vocabulary.englishDefinition, !englishDef.isEmpty {
            let normalizedDef = englishDef.replacingOccurrences(of: "\\n", with: "\n")
            VStack(alignment: .leading, spacing: 4) {
                Text(L("section.chineseDef"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ScrollView(.vertical, showsIndicators: true) {
                    Text(normalizedDef)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var exampleSection: some View {
        if let example = vocabulary.contextSnippet {
            VStack(alignment: .leading, spacing: 4) {
                if isExpanded {
                    Text(L("section.originalContext"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(example)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(isExpanded ? 3 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var reviewSection: some View {
        if vocabulary.reviewCount > 0 {
            Text(String(format: L("vocab.nextReview"), vocabulary.nextReviewDescription))
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
    
    private var speakButton: some View {
        Button {
            onSpeak()
        } label: {
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isExpanded ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isExpanded ? Color.blue.opacity(0.18) : Color.gray.opacity(0.08), lineWidth: 1)
            )
    }
    
    private var definitionItems: [String] {
        guard let definition = vocabulary.definition, !definition.isEmpty else {
            return []
        }
        return DictionaryService.shared.splitDefinitions(definition)
    }

    /// 掌握程度指示器
    private var masteryIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < vocabulary.masteredLevel ? masteryColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    /// 掌握程度颜色
    private var masteryColor: Color {
        switch vocabulary.masteredLevel {
        case 0: return .gray
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}

/// 复习视图
struct ReviewView: View {
    @ObservedObject var viewModel: VocabularyViewModel

    @State private var showingAnswer: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 进度指示
                progressHeader

                // 单词卡片
                wordCard

                // 评分按钮
                ratingButtons
            }
            .padding()
            .navigationTitle(L("nav.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.endReview()
                    } label: {
                        Text(L("action.end"))
                    }
                }
            }
        }
    }

    /// 进度头部
    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text(String(format: L("review.progress"), viewModel.reviewCompletedCount, viewModel.todayReviewWords.count))
                .font(.headline)

            ProgressView(value: Double(viewModel.reviewCompletedCount), total: Double(viewModel.todayReviewWords.count))
                .progressViewStyle(.linear)
        }
    }

    /// 单词卡片
    private var wordCard: some View {
        VStack(spacing: 16) {
            if let word = viewModel.currentReviewWord {
                // 单词（正面）- 可点击显示答案
                Button {
                    showingAnswer = true
                } label: {
                    Text(word.word)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // 提示文字
                if !showingAnswer {
                    Text(L("review.tapToSeeDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 音标
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // 朗读按钮
                Button {
                    viewModel.speakWord(word.word)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                Divider()
                    .padding(.vertical, 8)

                // 答案（背面）
                if showingAnswer {
                    VStack(alignment: .leading, spacing: 8) {
                        // 词性
                        if let pos = word.partOfSpeech, !pos.isEmpty {
                            Text(DictionaryService.displayNameForPartOfSpeech(pos))
                                .font(.subheadline)
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(pos)))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(6)
                        }

                        // 释义 - 按词性分组展示
                        Text(L("section.definitionLabel"))
                            .font(.headline)

                        if let grouped = word.groupedDefinitions, !grouped.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(grouped.enumerated()), id: \.offset) { groupIndex, group in
                                    VStack(alignment: .leading, spacing: 6) {
                                        if groupIndex > 0 {
                                            Divider()
                                        }
                                        Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                            .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                            .cornerRadius(4)

                                        ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, def in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("\(index + 1).")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.blue)
                                                    .frame(minWidth: 20, alignment: .trailing)
                                                Text(def)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else if let savedDef = word.definition, !savedDef.isEmpty {
                            definitionListView(savedDef)
                        } else if let offlineDef = DictionaryService.shared.getDefinition(for: word.word) {
                            definitionListView(offlineDef)
                        } else {
                            Text(L("review.noDef"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        // 英文释义
                        if let englishDef = word.englishDefinition, !englishDef.isEmpty {
                            let normalizedDef = englishDef.replacingOccurrences(of: "\\n", with: "\n")
                            Text(L("section.englishDefLabel"))
                                .font(.headline)
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(normalizedDef)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 100)
                        }
                        // 原文上下文
                        if let context = word.contextSnippet, !context.isEmpty {
                            Text(L("section.originalLabel"))
                                .font(.headline)
                            Text(context)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button {
                        showingAnswer = true
                    } label: {
                        Text(L("action.showAnswer"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text(L("review.completed"))
                    .font(.title)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    /// 评分按钮
    private var ratingButtons: some View {
        Group {
            if showingAnswer && viewModel.currentReviewWord != nil {
                VStack(spacing: 12) {
                    Text(L("review.ratePrompt"))
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach([0, 1, 2, 3, 4, 5], id: \.self) { quality in
                            Button {
                                viewModel.completeCurrentReview(quality: quality)
                                showingAnswer = false
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(quality)")
                                        .font(.title3)
                                        .fontWeight(.bold)

                                    Text(ratingDescription(quality))
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(width: 50, height: 60)
                                .background(ratingColor(quality))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if viewModel.currentReviewWord == nil {
                // 复习完成
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text(L("review.allDone"))
                        .font(.title2)

                    Button {
                        viewModel.endReview()
                    } label: {
                        Text(L("action.backToVocab"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                // 跳过按钮
                Button {
                    viewModel.skipCurrentReview()
                    showingAnswer = false
                } label: {
                    Text(L("common.skip"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 评分描述
    private func ratingDescription(_ quality: Int) -> String {
        switch quality {
        case 0: return L("rating.forget")
        case 1: return L("rating.familiar")
        case 2: return L("rating.barely")
        case 3: return L("rating.correct")
        case 4: return L("rating.easy")
        case 5: return L("rating.perfect")
        default: return ""
        }
    }

    /// 评分颜色
    private func ratingColor(_ quality: Int) -> Color {
        switch quality {
        case 0: return .red.opacity(0.2)
        case 1: return .red.opacity(0.3)
        case 2: return .orange.opacity(0.3)
        case 3: return .yellow.opacity(0.3)
        case 4: return .green.opacity(0.3)
        case 5: return .blue.opacity(0.3)
        default: return .gray.opacity(0.2)
        }
    }

    private func definitionListView(_ definition: String) -> some View {
        let items = DictionaryService.shared.splitDefinitions(definition)
        return Group {
            if items.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(item)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(definition)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
