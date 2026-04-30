//
//  ReaderView.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import SwiftUI
import UIKit

/// 阅读器视图
struct ReaderView: View {
    let article: Article

    @StateObject private var viewModel: ReaderViewModel
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
                    Button("关闭") {
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
                            Label("分享", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            openInBrowser()
                        } label: {
                            Label("在浏览器中打开", systemImage: "safari")
                        }

                        Button {
                            copyLink()
                        } label: {
                            Label("复制链接", systemImage: "link")
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
            .sheet(isPresented: $viewModel.showingSentenceTranslation) {
                SentenceTranslationSheet(viewModel: viewModel)
            }
            .alert("选择翻译服务", isPresented: $viewModel.showingTranslationMenu) {
                ForEach(viewModel.availableTranslationServices, id: \.self) { serviceType in
                    Button(serviceType.rawValue) {
                        viewModel.translateWithService(type: serviceType)
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    /// 主内容区域
    private var mainContent: some View {
        Group {
            if viewModel.isLoadingContent {
                VStack(spacing: 16) {
                    ProgressView("加载全文...")

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
                            Text("无法加载文章内容")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Button("在浏览器中打开") {
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
                ReaderMetaPill(icon: "clock", text: "约\(viewModel.estimatedReadingMinutes)分钟")
                ReaderMetaPill(icon: "text.justify", text: "\(viewModel.content.split(whereSeparator: \.isWhitespace).count)词")
                if let author = viewModel.article.author, !author.isEmpty {
                    ReaderMetaPill(icon: "person", text: author)
                }
            }

            Text("双击正文中的单词即可查词并加入生词本。")
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
            Text("摘要")
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
            onSentenceSelect: { sentence, range in
                viewModel.selectSentenceForTranslation(sentence, range: range)
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
                    Text("正在朗读...")
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
                        Label("原形: \(lemma)", systemImage: "arrow.turn.down.left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // 按词性分组显示释义
            if !viewModel.selectedWordGroupedDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.selectedWordGroupedDefinitions.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 4) {
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
                                (Text("\(index + 1). ").font(.caption.weight(.semibold)).foregroundColor(.blue)
                                 + Text(definition).font(.subheadline).foregroundColor(.primary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } else if !viewModel.selectedWordDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("释义")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordDefinitions.enumerated()), id: \.offset) { index, definition in
                        (Text("\(index + 1). ").font(.caption.weight(.semibold)).foregroundColor(.blue)
                         + Text(definition).font(.subheadline).foregroundColor(.primary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let definition = viewModel.selectedWordDefinition {
                VStack(alignment: .leading, spacing: 4) {
                    Text("释义")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(definition)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            if let context = viewModel.selectedWordContext {
                VStack(alignment: .leading, spacing: 4) {
                    Text("原文上下文")
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
                    Text("iOS系统词典有详细释义")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    /// 分类选择和添加按钮
    private func categorySelectionAndAdd(_ word: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("添加到分类")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button {
                            viewModel.selectedCategoryForWord = category
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(category.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedCategoryForWord?.id == category.id
                                    ? Color(hex: category.color)
                                    : Color(hex: category.color).opacity(0.2)
                            )
                            .foregroundColor(
                                viewModel.selectedCategoryForWord?.id == category.id
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
                    categoryId: viewModel.selectedCategoryForWord?.id
                )
                viewModel.closeWordDefinition()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("加入生词本")
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

struct ArticleReaderTextView: UIViewRepresentable {
    let content: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let textColor: UIColor
    let backgroundColor: UIColor
    let onWordDoubleTap: (String, CGPoint) -> Void
    let onCloseWordDefinition: () -> Void
    let onSentenceSelect: ((String, NSRange) -> Void)?  // 句子选择回调

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .link
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        textView.attributedText = buildFullText()

        // 添加双击手势识别器（查单词）
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        textView.addGestureRecognizer(doubleTapGesture)

        // 添加单击手势识别器
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        textView.addGestureRecognizer(singleTapGesture)
        
        // 添加长按手势识别器（句子翻译）
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPressGesture)
        
        // 添加翻译菜单项
        context.coordinator.setupTranslationMenu(textView)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.backgroundColor = backgroundColor
        textView.attributedText = buildFullText()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width - 36
        let fittingSize = uiView.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: targetWidth, height: fittingSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onWordDoubleTap: onWordDoubleTap, onCloseWordDefinition: onCloseWordDefinition, onSentenceSelect: onSentenceSelect)
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
        let onSentenceSelect: ((String, NSRange) -> Void)?
        
        private weak var textView: UITextView?

        init(onWordDoubleTap: @escaping (String, CGPoint) -> Void, onCloseWordDefinition: @escaping () -> Void, onSentenceSelect: ((String, NSRange) -> Void)? = nil) {
            self.onWordDoubleTap = onWordDoubleTap
            self.onCloseWordDefinition = onCloseWordDefinition
            self.onSentenceSelect = onSentenceSelect
        }
        
        /// 设置翻译菜单
        func setupTranslationMenu(_ textView: UITextView) {
            self.textView = textView
            
            // 创建自定义菜单项
            let translateMenuItem = UIMenuItem(title: "翻译句子", action: #selector(Coordinator.translateSelectedText))
            UIMenuController.shared.menuItems = [translateMenuItem]
            UIMenuController.shared.update()
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
                
                if cleanedSentence.count >= 5, let callback = onSentenceSelect {
                    callback(cleanedSentence, sentenceRange)
                    // 高亮选中的句子
                    textView.selectedRange = sentenceRange
                }
            }
        }
        
        /// 翻译选中的文本（菜单项动作）
        @objc func translateSelectedText() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                let text = textView.attributedText.string as NSString
                let selectedText = text.substring(with: selectedRange)
                
                if let callback = onSentenceSelect {
                    callback(selectedText, selectedRange)
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
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(viewModel.categories, id: \.id) { category in
                            Button(category.name) {
                                viewModel.selectedCategoryForWord = category
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }

                    Button {
                        viewModel.addToVocabulary(
                            word: word,
                            context: viewModel.selectedWordContext,
                            categoryId: viewModel.selectedCategoryForWord?.id
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

                    if let category = viewModel.selectedCategoryForWord {
                        Text("加入分类: \(category.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if !viewModel.selectedWordGroupedDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("快速释义")
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
                                }
                            }
                        }
                    }
                }
            } else if !viewModel.selectedWordDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("快速释义")
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text("下方已切换到系统完整英汉词典。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let context = viewModel.selectedWordContext {
                VStack(alignment: .leading, spacing: 4) {
                    Text("原文上下文")
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
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 原文显示
                VStack(alignment: .leading, spacing: 12) {
                    Text("原文")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(viewModel.selectedSentence ?? "")
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
                    Text("选择翻译服务")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.availableTranslationServices, id: \.self) { serviceType in
                                Button {
                                    viewModel.translateWithService(type: serviceType)
                                } label: {
                                    HStack {
                                        Image(systemName: iconForService(serviceType))
                                            .font(.title2)
                                            .foregroundColor(colorForService(serviceType))

                                        Text(serviceType.rawValue)
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
                Text("点击翻译服务将跳转到对应应用进行翻译")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("句子翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                        viewModel.closeSentenceTranslation()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let sentence = viewModel.selectedSentence {
                            viewModel.speakSentence(sentence)
                        }
                    } label: {
                        Image(systemName: "speaker.wave.3.fill")
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
