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

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.vocabulary.isEmpty && viewModel.selectedCategory?.name != "全部" {
                    emptyCategoryView
                } else if viewModel.vocabulary.isEmpty {
                    emptyStateView
                } else {
                    vocabularyContent
                }
            }
            .navigationTitle("生词本")
            .searchable(text: $searchText, prompt: "搜索单词")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingCategoryList = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
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
            .onAppear {
                viewModel.loadCategories()
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
            
            Text("\(viewModel.vocabulary.count)词")
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
                StatItem(title: "总数", value: viewModel.totalVocabularyCount, color: .blue)
                StatItem(title: "已掌握", value: viewModel.masteredVocabularyCount, color: .green)
                StatItem(title: "学习中", value: viewModel.vocabulary.count - viewModel.masteredVocabularyCount - viewModel.todayReviewCount, color: .orange)
                StatItem(title: "待复习", value: viewModel.todayReviewCount, color: .red)
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
                        Text("开始今日复习 (\(viewModel.todayReviewCount)词)")
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
                VocabularyRowView(vocabulary: vocab, category: getCategoryForVocabulary(vocab)) {
                    viewModel.speakWord(vocab.word)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteVocabulary(vocab)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        // 移动到其他分类
                    } label: {
                        Label("移动", systemImage: "folder")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }
    
    /// 获取生词所属分类
    private func getCategoryForVocabulary(_ vocab: Vocabulary) -> VocabularyCategory? {
        if let categoryId = vocab.categoryId {
            return viewModel.categories.first { $0.id == categoryId }
        }
        return nil
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

            Text("该分类暂无生词")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("添加生词时可选择此分类")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                viewModel.selectCategory(viewModel.categories.first { $0.name == "全部" } ?? viewModel.categories[0])
            } label: {
                Text("查看全部生词")
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

            Text("暂无生词")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在阅读文章时点击单词可添加到生词本")
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
                                Label("删除", systemImage: "trash")
                            }
                        }

                        Button {
                            // 编辑分类
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 显示添加分类界面
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
                Section("分类信息") {
                    TextField("分类名称", text: $name)
                    TextField("描述（可选）", text: $description)
                }
                
                Section("颜色") {
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
                
                Section("图标") {
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
                            Text("创建分类")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("新建分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
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
    let category: VocabularyCategory?
    let onSpeak: () -> Void
    
    @State private var isExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    headerRow
                    metadataRow
                    definitionSection
                    exampleSection
                    reviewSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            speakButton
        }
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
            
            if let cat = category {
                HStack(spacing: 4) {
                    Image(systemName: cat.icon)
                        .font(.caption2)
                    Text(cat.name)
                        .font(.caption2)
                }
                .foregroundColor(Color(hex: cat.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: cat.color).opacity(0.15))
                .cornerRadius(4)
            }
            
            masteryIndicator
        }
    }
    
    @ViewBuilder
    private var metadataRow: some View {
        if !definitionItems.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .foregroundColor(isExpanded ? .blue : .secondary)
                
                Text(isExpanded ? "收起中文释义" : "点击查看中文释义")
                    .font(.caption)
                    .foregroundColor(isExpanded ? .blue : .secondary)
                
                if !isExpanded {
                    Text("共\(definitionItems.count)个意思")
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
                
                Text("暂未找到中文释义")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var definitionSection: some View {
        if isExpanded, !definitionItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(definitionItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                        
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private var exampleSection: some View {
        if let example = vocabulary.contextSnippet {
            VStack(alignment: .leading, spacing: 4) {
                if isExpanded {
                    Text("原文语境")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(example)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(isExpanded ? 3 : 1)
            }
        }
    }
    
    @ViewBuilder
    private var reviewSection: some View {
        if vocabulary.reviewCount > 0 {
            Text("下次复习: \(vocabulary.nextReviewDescription)")
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
        
        let separators = CharacterSet(charactersIn: "；;|/·")
        let normalized = definition.replacingOccurrences(of: "、", with: "；")
        let parts = normalized.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return parts.isEmpty ? [definition] : parts
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
            .navigationTitle("复习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.endReview()
                    } label: {
                        Text("结束")
                    }
                }
            }
        }
    }

    /// 进度头部
    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("进度: \(viewModel.reviewCompletedCount) / \(viewModel.todayReviewWords.count)")
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
                    Text("点击单词查看释义")
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

                        // 释义 - 始终尝试显示
                        Text("释义:")
                            .font(.headline)

                        // 优先使用保存的释义，如果没有则从离线词典获取
                        if let savedDef = word.definition, !savedDef.isEmpty {
                            Text(savedDef)
                                .font(.body)
                        } else if let offlineDef = DictionaryService.shared.getDefinition(for: word.word) {
                            Text(offlineDef)
                                .font(.body)
                                .foregroundColor(.blue)
                        } else {
                            Text("暂无释义")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        // 原文上下文
                        if let context = word.contextSnippet, !context.isEmpty {
                            Text("原文:")
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
                        Text("显示答案")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text("复习完成！")
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
                    Text("你的掌握程度如何？")
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

                    Text("恭喜！今日复习完成")
                        .font(.title2)

                    Button {
                        viewModel.endReview()
                    } label: {
                        Text("返回生词本")
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
                    Text("跳过")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 评分描述
    private func ratingDescription(_ quality: Int) -> String {
        switch quality {
        case 0: return "完全忘记"
        case 1: return "有印象"
        case 2: return "勉强记得"
        case 3: return "正确"
        case 4: return "轻松"
        case 5: return "完美"
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
}
