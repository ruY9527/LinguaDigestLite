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
            clearSelectionRequestID: textTranslationViewModel.clearSelectionRequestID,
            onTranslateSelection: { text, range in
                textTranslationViewModel.requestTranslation(for: text, range: range)
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

/// 文章阅读器 UITextView - 包含标题、头部信息和正文，自带滚动
struct ReaderMetaPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

final class ReaderTextView: UITextView {
    var onTranslateSelectedText: ((String, NSRange) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: L("action.translateSentence"), action: #selector(translateSelectedText(_:))),
            UIMenuItem(title: L("action.clearSelection"), action: #selector(clearTextSelection(_:)))
        ]
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(translateSelectedText(_:)) ||
            action == #selector(clearTextSelection(_:)) {
            return selectedRange.length > 0
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @available(iOS 16.0, *)
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let translateAction = UIAction(
            title: L("action.translateSentence"),
            image: UIImage(systemName: "character.bubble")
        ) { [weak self] _ in
            self?.translateSelectedText(nil)
        }

        let clearSelectionAction = UIAction(
            title: L("action.clearSelection"),
            image: UIImage(systemName: "xmark.circle")
        ) { [weak self] _ in
            self?.clearTextSelection(nil)
        }

        return UIMenu(children: suggestedActions + [translateAction, clearSelectionAction])
    }

    @objc func translateSelectedText(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }

        let sourceText = attributedText?.string ?? text ?? ""
        let selectedText = (sourceText as NSString).substring(with: selectedRange)
        onTranslateSelectedText?(selectedText, selectedRange)
    }

    @objc func clearTextSelection(_ sender: Any?) {
        selectedRange = NSRange(location: 0, length: 0)
        resignFirstResponder()
        UIMenuController.shared.hideMenu()
    }
}

struct ArticleReaderTextView: UIViewRepresentable {
    let content: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let textColor: UIColor
    let backgroundColor: UIColor
    let onWordDoubleTap: (String, CGPoint) -> Void
    let onCloseWordDefinition: () -> Void
    let clearSelectionRequestID: Int
    let onTranslateSelection: (String, NSRange) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = ReaderTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .link
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        textView.attributedText = buildFullText()
        textView.onTranslateSelectedText = onTranslateSelection

        // 添加双击手势识别器（查单词）
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        textView.addGestureRecognizer(doubleTapGesture)

        // 添加单击手势识别器
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        textView.addGestureRecognizer(singleTapGesture)
        
        // 长按可快速选中当前句子，随后通过系统编辑菜单触发翻译。
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPressGesture)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.backgroundColor = backgroundColor
        textView.attributedText = buildFullText()
        if let textView = textView as? ReaderTextView {
            textView.onTranslateSelectedText = onTranslateSelection
        }
        context.coordinator.handleClearSelectionIfNeeded(
            requestID: clearSelectionRequestID,
            textView: textView
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width - 36
        let fittingSize = uiView.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: targetWidth, height: fittingSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onWordDoubleTap: onWordDoubleTap,
            onCloseWordDefinition: onCloseWordDefinition,
            handledClearSelectionRequestID: clearSelectionRequestID
        )
    }

    /// 构建正文文本
    private func buildFullText() -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 正文 - 智能段落分割
        let paragraphs = splitIntoParagraphs(content)
        
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedParagraph.isEmpty { continue }
            
            // 每个段落应用独立的样式
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = fontSize * lineHeight - fontSize
            paragraphStyle.paragraphSpacingBefore = index == 0 ? 0 : fontSize * 0.25
            paragraphStyle.paragraphSpacing = fontSize * 0.9
            
            // 添加段落文本
            let paragraphText = index < paragraphs.count - 1 ? trimmedParagraph + "\n\n" : trimmedParagraph
            let paragraphAttr = NSMutableAttributedString(string: paragraphText)
            paragraphAttr.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize), range: NSRange(location: 0, length: paragraphAttr.length))
            paragraphAttr.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: paragraphAttr.length))
            paragraphAttr.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphAttr.length))
            result.append(paragraphAttr)
        }

        return result
    }
    
    /// 智能分割段落
    private func splitIntoParagraphs(_ text: String) -> [String] {
        // 先按双换行分割
        let doubleNewlineParagraphs = text.components(separatedBy: "\n\n")
        
        // 如果有多个段落，直接返回
        if doubleNewlineParagraphs.count > 1 {
            return doubleNewlineParagraphs
        }
        
        // 否则按单换行分割
        let singleNewlineParagraphs = text.components(separatedBy: "\n")
        
        // 过滤空行并合并短行
        var result: [String] = []
        var currentParagraph = ""
        
        for line in singleNewlineParagraphs {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                // 遇到空行，结束当前段落
                if !currentParagraph.isEmpty {
                    result.append(currentParagraph)
                    currentParagraph = ""
                }
            } else {
                // 如果当前段落不为空，添加空格
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmedLine
                
                // 如果行以句子结束符号结尾，结束段落
                if trimmedLine.hasSuffix(".") || trimmedLine.hasSuffix("!") || trimmedLine.hasSuffix("?") {
                    if currentParagraph.count > 50 {
                        result.append(currentParagraph)
                        currentParagraph = ""
                    }
                }
            }
        }
        
        // 添加最后一个段落
        if !currentParagraph.isEmpty {
            result.append(currentParagraph)
        }
        
        // 如果还是没有足够段落，按句子分割
        if result.count <= 1 {
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            result = sentences.compactMap { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed + "."
            }
        }
        
        return result
    }

    class Coordinator: NSObject {
        let onWordDoubleTap: (String, CGPoint) -> Void
        let onCloseWordDefinition: () -> Void
        private var handledClearSelectionRequestID: Int

        init(
            onWordDoubleTap: @escaping (String, CGPoint) -> Void,
            onCloseWordDefinition: @escaping () -> Void,
            handledClearSelectionRequestID: Int
        ) {
            self.onWordDoubleTap = onWordDoubleTap
            self.onCloseWordDefinition = onCloseWordDefinition
            self.handledClearSelectionRequestID = handledClearSelectionRequestID
        }

        func handleClearSelectionIfNeeded(requestID: Int, textView: UITextView) {
            guard requestID != handledClearSelectionRequestID else { return }

            handledClearSelectionRequestID = requestID
            if let textView = textView as? ReaderTextView {
                textView.clearTextSelection(nil)
            } else {
                textView.selectedRange = NSRange(location: 0, length: 0)
                textView.resignFirstResponder()
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }

            let location = gesture.location(in: textView)

            guard let position = textView.closestPosition(to: location) else { return }
            let characterIndex = textView.offset(from: textView.beginningOfDocument, to: position)

            if characterIndex < textView.attributedText.length {
                let text = textView.attributedText.string as NSString
                let wordRange = wordRangeAt(characterIndex, in: text)
                let word = text.substring(with: wordRange)

                let cleanedWord = word.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespaces))

                if isLookupCandidate(cleanedWord) {
                    let globalPosition = textView.convert(location, to: textView.window)
                    onWordDoubleTap(cleanedWord, globalPosition)
                    highlightWord(textView, range: wordRange)
                }
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            guard let textView = gesture.view as? UITextView else { return }
            
            let location = gesture.location(in: textView)
            
            guard let position = textView.closestPosition(to: location) else { return }
            let characterIndex = textView.offset(from: textView.beginningOfDocument, to: position)
            
            if characterIndex < textView.attributedText.length {
                let text = textView.attributedText.string as NSString
                let sentenceRange = sentenceRangeAt(characterIndex, in: text)
                let sentence = text.substring(with: sentenceRange)
                
                let cleanedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanedSentence.count >= 5 {
                    textView.selectedRange = sentenceRange
                    textView.becomeFirstResponder()
                    if let start = textView.position(from: textView.beginningOfDocument, offset: sentenceRange.location),
                       let end = textView.position(from: start, offset: sentenceRange.length),
                       let textRange = textView.textRange(from: start, to: end) {
                        let rect = textView.firstRect(for: textRange)
                        UIMenuController.shared.showMenu(from: textView, rect: rect)
                    }
                }
            }
        }

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            onCloseWordDefinition()
        }

        private func wordRangeAt(_ index: Int, in text: NSString) -> NSRange {
            var start = index
            var end = index

            while start > 0 {
                let char = text.character(at: start - 1)
                if isWordBoundary(char) { break }
                start -= 1
            }

            while end < text.length {
                let char = text.character(at: end)
                if isWordBoundary(char) { break }
                end += 1
            }

            return NSRange(location: start, length: end - start)
        }
        
        /// 获取句子范围
        private func sentenceRangeAt(_ index: Int, in text: NSString) -> NSRange {
            var start = index
            var end = index
            
            // 向前查找句子开始
            while start > 0 {
                let char = text.character(at: start - 1)
                if isSentenceBoundary(char) { break }
                start -= 1
            }
            
            // 向后查找句子结束
            while end < text.length {
                let char = text.character(at: end)
                if isSentenceBoundary(char) && end > index {
                    end += 1  // 包含结束标点
                    break
                }
                end += 1
            }
            
            return NSRange(location: start, length: end - start)
        }
        
        /// 判断是否是句子边界
        private func isSentenceBoundary(_ char: UniChar) -> Bool {
            return char == 46 ||   // .
                   char == 63 ||   // ?
                   char == 33 ||   // !
                   char == 10 ||   // newline
                   char == 8226 || // • (bullet)
                   char == 13      // CR
        }

        private func isWordBoundary(_ char: UniChar) -> Bool {
            if char == 39 || char == 8217 {
                return false
            }

            return char == 32 || char == 10 || char == 9 ||
                   (char >= 33 && char <= 47) ||
                   (char >= 58 && char <= 64) ||
                   (char >= 91 && char <= 96) ||
                   (char >= 123 && char <= 126)
        }

        private func isLookupCandidate(_ word: String) -> Bool {
            guard !word.isEmpty else { return false }
            return word.rangeOfCharacter(from: .letters) != nil
        }

        private func highlightWord(_ textView: UITextView, range: NSRange) {
            textView.selectedRange = range
        }
    }
}

private struct SystemDictionarySheetView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let word: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                quickLookupSummary
                Divider()
                EmbeddedSystemDictionaryView(word: word)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(viewModel.selectableCategoriesForWord, id: \.id) { category in
                            Button {
                                viewModel.toggleCategorySelection(for: category)
                            } label: {
                                HStack {
                                    Text(category.name)
                                    if viewModel.isCategorySelectedForWord(category) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }

                    Button {
                        viewModel.addToVocabulary(
                            word: word,
                            context: viewModel.selectedWordContext,
                            categoryIds: Array(viewModel.selectedCategoryIdsForWord)
                        )
                    } label: {
                        Image(systemName: "plus.circle")
                    }

                    Button {
                        viewModel.speakWord(word)
                    } label: {
                        Image(systemName: "speaker.wave.3")
                    }
                }
            }
        }
    }

    private var quickLookupSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let pos = viewModel.selectedWordPartOfSpeech {
                        Text(DictionaryService.displayNameForPartOfSpeech(pos))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(6)
                    }

                    if !viewModel.selectedCategoriesForWord.isEmpty {
                        Text(String(format: L("category.addLabel"), viewModel.selectedCategoriesForWord.map(\.name).joined(separator: "、")))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if !viewModel.selectedWordGroupedDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("section.quickDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordGroupedDefinitions.prefix(3).enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                .cornerRadius(3)

                            ForEach(Array(group.definitions.prefix(2).enumerated()), id: \.offset) { index, definition in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.blue)
                                    Text(definition)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            } else if !viewModel.selectedWordDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("section.quickDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordDefinitions.prefix(4).enumerated()), id: \.offset) { index, definition in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                            Text(definition)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(L("hint.systemDictSwitched"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let context = viewModel.selectedWordContext {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("section.context"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color(UIColor.systemBackground))
    }
}

private struct EmbeddedSystemDictionaryView: UIViewControllerRepresentable {
    let word: String

    func makeUIViewController(context: Context) -> DictionaryContainerViewController {
        let controller = DictionaryContainerViewController()
        controller.updateWord(word)
        return controller
    }

    func updateUIViewController(_ uiViewController: DictionaryContainerViewController, context: Context) {
        uiViewController.updateWord(word)
    }
}

private final class DictionaryContainerViewController: UIViewController {
    private var currentWord: String?
    private var dictionaryController: UIReferenceLibraryViewController?

    func updateWord(_ word: String) {
        guard currentWord != word else { return }
        currentWord = word
        embedDictionaryController(for: word)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    private func embedDictionaryController(for word: String) {
        if let dictionaryController {
            dictionaryController.willMove(toParent: nil)
            dictionaryController.view.removeFromSuperview()
            dictionaryController.removeFromParent()
        }

        let controller = UIReferenceLibraryViewController(term: word)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        controller.didMove(toParent: self)
        dictionaryController = controller
    }
}

// MARK: - 句子翻译弹窗

private struct SentenceTranslationSheet: View {
    @ObservedObject var viewModel: TextTranslationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 原文显示
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("sheet.originalText"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(viewModel.selectedText ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal)

                Divider()

                // 翻译服务选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("sheet.translationServices"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.availableServices, id: \.self) { serviceType in
                                Button {
                                    viewModel.translateWithService(serviceType)
                                } label: {
                                    HStack {
                                        Image(systemName: iconForService(serviceType))
                                            .font(.title2)
                                            .foregroundColor(colorForService(serviceType))

                                        Text(serviceType.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 提示信息
                Text(L("hint.translationRedirect"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle(L("nav.sentenceTranslation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                        viewModel.close()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func iconForService(_ serviceType: TranslationServiceType) -> String {
        switch serviceType {
        case .system:
            return "character.bubble"
        case .google:
            return "globe"
        case .baidu:
            return "translate"
        case .deepL:
            return "doc.text"
        }
    }

    private func colorForService(_ serviceType: TranslationServiceType) -> Color {
        switch serviceType {
        case .system:
            return .blue
        case .google:
            return .green
        case .baidu:
            return .orange
        case .deepL:
            return .purple
        }
    }
}

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
