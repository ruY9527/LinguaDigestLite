//
//  ReaderView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI
import UIKit
#if canImport(Translation)
import Translation
#endif

/// 阅读器视图
struct ReaderView: View {
    let article: Article

    @StateObject private var viewModel: ReaderViewModel
    @StateObject private var textTranslationViewModel = TextTranslationViewModel()
    @Environment(\.dismiss) private var dismiss

    init(article: Article) {
        self.article = article
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(article: article))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 主题背景色
                themeBackgroundColor

                // 主内容区域
                mainContent

                // 朗读控制栏
                if viewModel.isSpeaking {
                    speakingControlBar
                }

                // 单词悬浮卡片
                if viewModel.showingWordDefinition {
                    wordFloatingCard
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        viewModel.markAsRead()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // 收藏按钮
                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                            .foregroundColor(viewModel.isFavorite ? .yellow : .gray)
                    }

                    // 朗读按钮
                    Button {
                        if viewModel.isSpeaking {
                            viewModel.stopSpeaking()
                        } else {
                            viewModel.speakArticle()
                        }
                    } label: {
                        Image(systemName: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.3")
                    }

                    // 更多选项
                    Menu {
                        Button {
                            shareArticle()
                        } label: {
                            Label(L("action.share"), systemImage: "square.and.arrow.up")
                        }

                        Button {
                            openInBrowser()
                        } label: {
                            Label(L("action.openInBrowser"), systemImage: "safari")
                        }

                        Button {
                            copyLink()
                        } label: {
                            Label(L("action.copyLink"), systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                viewModel.markAsRead()
            }
            .sheet(isPresented: $viewModel.showingSystemDictionarySheet, onDismiss: {
                viewModel.closeWordDefinition()
            }) {
                if let word = viewModel.selectedWord {
                    SystemDictionarySheetView(viewModel: viewModel, word: word)
                }
            }
            .systemTranslationPresentation(
                isPresented: $textTranslationViewModel.showingNativeTranslation,
                text: textTranslationViewModel.selectedText ?? ""
            )
            .onChange(of: textTranslationViewModel.showingNativeTranslation) { isPresented in
                if !isPresented, textTranslationViewModel.selectedText != nil {
                    textTranslationViewModel.close()
                }
            }
            .sheet(isPresented: $textTranslationViewModel.showingFallbackSheet, onDismiss: {
                textTranslationViewModel.close()
            }) {
                SentenceTranslationSheet(viewModel: textTranslationViewModel)
            }
            .sheet(isPresented: $viewModel.showingSentenceSaveSheet) {
                SentenceSaveSheet(viewModel: viewModel)
            }
        }
    }

    /// 主内容区域
    private var mainContent: some View {
        Group {
            if viewModel.isLoadingContent {
                VStack(spacing: 16) {
                    ProgressView(L("status.loadingContent"))

                    if let summary = article.summary, !summary.isEmpty {
                        Text(FeedService.cleanHTMLContent(summary))
                            .lineLimit(6)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.content.isEmpty {
                // 如果没有内容，显示摘要
                VStack(spacing: 16) {
                    if let summary = article.summary, !summary.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                articleTitleView
                                articleHeader
                                Text(FeedService.cleanHTMLContent(summary))
                                    .font(.body)
                                    .foregroundColor(Color(hex: UserSettings.shared.readingSettings.theme.textColor))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 100)
                            }
                            .padding()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(L("error.loadFailed"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Button(L("action.openInBrowser")) {
                                openInBrowser()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        readingHeroCard
                        if let summary = viewModel.displaySummary {
                            summaryCard(summary)
                        }
                        articleBodyCard
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, viewModel.isSpeaking ? 120 : 40)
                }
            }
        }
    }

    private var readingHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            articleHeader
            articleTitleView

            HStack(spacing: 10) {
                ReaderMetaPill(icon: "clock", text: String(format: L("meta.readTime"), viewModel.estimatedReadingMinutes))
                ReaderMetaPill(icon: "text.justify", text: String(format: L("vocab.countSuffix"), viewModel.content.split(whereSeparator: \.isWhitespace).count))
                if let author = viewModel.article.author, !author.isEmpty {
                    ReaderMetaPill(icon: "person", text: author)
                }
            }

            Text(L("help.doubleTap"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.90),
                    Color(hex: UserSettings.shared.readingSettings.theme.backgroundColor).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("card.summary"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(summary)
                .font(.body)
                .foregroundColor(Color(hex: UserSettings.shared.readingSettings.theme.textColor))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var articleBodyCard: some View {
        ArticleReaderTextView(
            content: viewModel.content,
            fontSize: UserSettings.shared.readingSettings.fontSize,
            lineHeight: UserSettings.shared.readingSettings.lineHeight,
            textColor: UIColor(hex: UserSettings.shared.readingSettings.theme.textColor),
            backgroundColor: UIColor.clear,
            onWordDoubleTap: { word, position in
                handleWordDoubleTap(word, position: position)
            },
            onCloseWordDefinition: {
                viewModel.closeWordDefinition()
            },
            clearSelectionRequestID: textTranslationViewModel.clearSelectionRequestID + viewModel.clearSelectionRequestID,
            onTranslateSelection: { text, range in
                textTranslationViewModel.requestTranslation(for: text, range: range)
            },
            onSaveSentence: { text, range, paragraphIndex in
                viewModel.saveSentence(text, paragraphIndex: paragraphIndex, range: range)
            }
        )
        .padding(20)
        .background(Color(UIColor.systemBackground).opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }

    /// 文章标题视图
    private var articleTitleView: some View {
        Text(viewModel.article.title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(Color(hex: UserSettings.shared.readingSettings.theme.textColor))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 文章头部
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.sourceName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                    Text(viewModel.publishedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.article.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
        }
    }

    /// 主题背景色
    private var themeBackgroundColor: some View {
        let theme = UserSettings.shared.readingSettings.theme

        return Color(hex: theme.backgroundColor)
            .ignoresSafeArea()
    }

    /// 朗读控制栏
    private var speakingControlBar: some View {
        VStack {
            Spacer()

            HStack(spacing: 20) {
                Button {
                    viewModel.stopSpeaking()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }

                VStack {
                    Text(L("status.speaking"))
                        .font(.caption)

                    ProgressView(value: viewModel.currentReadingProgress ?? 0.0)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                }

                Button {
                    viewModel.stopSpeaking()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding()
        }
    }

    /// 单词悬浮卡片
    private var wordFloatingCard: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    if let word = viewModel.selectedWord {
                        VStack(alignment: .leading, spacing: 12) {
                            // 单词标题和操作按钮
                            wordHeader(word)

                            Divider()

                            // 释义内容
                            wordDefinitions(word)

                            Divider()

                            // 分类选择和添加按钮
                            categorySelectionAndAdd(word)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: min(max(geometry.size.width * 0.85, 280), 400))
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .zIndex(100)
        .background(
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeWordDefinition()
                }
        )
    }

    /// 单词头部
    private func wordHeader(_ word: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word)
                    .font(.title2)
                    .fontWeight(.bold)

                if let pos = viewModel.selectedWordPartOfSpeech {
                    Text(DictionaryService.displayNameForPartOfSpeech(pos))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            Spacer()

            Button {
                viewModel.speakWord(word)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Button {
                viewModel.closeWordDefinition()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }

    /// 释义内容
    private func wordDefinitions(_ word: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let analysis = viewModel.wordAnalysis {
                HStack(spacing: 12) {
                    Label(DictionaryService.displayNameForPartOfSpeech(analysis.partOfSpeech), systemImage: "tag")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(analysis.partOfSpeech)))

                    if let lemma = analysis.lemma, lemma.lowercased() != word.lowercased() {
                        Label(String(format: L("lemma.label"), lemma), systemImage: "arrow.turn.down.left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // 按词性分组显示释义
            if !viewModel.selectedWordGroupedDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.selectedWordGroupedDefinitions.enumerated()), id: \.offset) { groupIndex, group in
                        VStack(alignment: .leading, spacing: 6) {
                            if groupIndex > 0 {
                                Divider()
                            }
                            // 词性标签
                            Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                .cornerRadius(4)

                            // 该词性下的所有释义
                            ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, definition in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.blue)
                                        .frame(minWidth: 20, alignment: .trailing)
                                    Text(definition)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else if !viewModel.selectedWordDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("section.definitions"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordDefinitions.enumerated()), id: \.offset) { index, definition in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 20, alignment: .trailing)
                            Text(definition)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else if let definition = viewModel.selectedWordDefinition {
                let items = DictionaryService.shared.splitDefinitions(definition)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("section.definitions"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if items.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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
                            }
                        }
                    } else {
                        Text(definition)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if let context = viewModel.selectedWordContext {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("section.context"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
                HStack {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(L("hint.systemDict"))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    /// 分类选择和添加按钮
    private func categorySelectionAndAdd(_ word: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 英文释义
            if let englishDef = viewModel.selectedWordEnglishDefinition, !englishDef.isEmpty {
                let normalizedDef = englishDef.replacingOccurrences(of: "\\n", with: "\n")
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("section.chineseDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.vertical, showsIndicators: true) {
                        Text(normalizedDef)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            }

            Text(L("section.addToCategory"))
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.selectableCategoriesForWord, id: \.id) { category in
                        Button {
                            viewModel.toggleCategorySelection(for: category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(category.name)
                                    .font(.caption)
                                if viewModel.isCategorySelectedForWord(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.isCategorySelectedForWord(category)
                                    ? Color(hex: category.color)
                                    : Color(hex: category.color).opacity(0.2)
                            )
                            .foregroundColor(
                                viewModel.isCategorySelectedForWord(category)
                                    ? .white
                                    : Color(hex: category.color)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                viewModel.addToVocabulary(
                    word: word,
                    context: viewModel.selectedWordContext,
                    categoryIds: Array(viewModel.selectedCategoryIdsForWord)
                )
                viewModel.closeWordDefinition()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L("action.addToVocab"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }

    /// 处理单词双击
    private func handleWordDoubleTap(_ word: String, position: CGPoint) {
        viewModel.lookupWord(word)
    }

    /// 分享文章
    private func shareArticle() {
        let url = URL(string: article.link)!
        let activityVC = UIActivityViewController(activityItems: [url, article.title], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    /// 在浏览器中打开
    private func openInBrowser() {
        if let url = URL(string: article.link) {
            UIApplication.shared.open(url)
        }
    }

    /// 复制链接
    private func copyLink() {
        UIPasteboard.general.string = article.link
    }
}

// MARK: - View Extensions

private extension View {
    @ViewBuilder
    func systemTranslationPresentation(isPresented: Binding<Bool>, text: String) -> some View {
#if canImport(Translation)
        if #available(iOS 17.4, *) {
            self.translationPresentation(
                isPresented: isPresented,
                text: text,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .bottom
            )
        } else {
            self
        }
#else
        self
#endif
    }
}

// MARK: - Color Extensions

/// Color扩展 - 支持十六进制颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
