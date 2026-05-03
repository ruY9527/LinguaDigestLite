//
//  ArticleReaderTextView.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import SwiftUI
import UIKit

/// 文章阅读器 UIViewRepresentable
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
    let onSaveSentence: (String, NSRange, Int) -> Void

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
        let content = self.content
        let onSaveSentence = self.onSaveSentence
        textView.onSaveSentence = { text, range in
            let paragraphIndex = self.paragraphIndexForCharacterOffset(range.location, in: content)
            onSaveSentence(text, range, paragraphIndex)
        }

        // 添加双击手势识别器（查单词）
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        textView.addGestureRecognizer(doubleTapGesture)

        // 添加单击手势识别器
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        textView.addGestureRecognizer(singleTapGesture)

        // 长按可快速选中当前句子
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

        let paragraphs = splitIntoParagraphs(content)

        for (index, paragraph) in paragraphs.enumerated() {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedParagraph.isEmpty { continue }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = fontSize * lineHeight - fontSize
            paragraphStyle.paragraphSpacingBefore = index == 0 ? 0 : fontSize * 0.25
            paragraphStyle.paragraphSpacing = fontSize * 0.9

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
        let doubleNewlineParagraphs = text.components(separatedBy: "\n\n")

        if doubleNewlineParagraphs.count > 1 {
            return doubleNewlineParagraphs
        }

        let singleNewlineParagraphs = text.components(separatedBy: "\n")

        var result: [String] = []
        var currentParagraph = ""

        for line in singleNewlineParagraphs {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    result.append(currentParagraph)
                    currentParagraph = ""
                }
            } else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmedLine

                if trimmedLine.hasSuffix(".") || trimmedLine.hasSuffix("!") || trimmedLine.hasSuffix("?") {
                    if currentParagraph.count > 50 {
                        result.append(currentParagraph)
                        currentParagraph = ""
                    }
                }
            }
        }

        if !currentParagraph.isEmpty {
            result.append(currentParagraph)
        }

        if result.count <= 1 {
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            result = sentences.compactMap { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed + "."
            }
        }

        return result
    }

    /// 根据字符偏移量计算所在段落索引
    private func paragraphIndexForCharacterOffset(_ offset: Int, in text: String) -> Int {
        let paragraphs = splitIntoParagraphs(text)
        var cumulativeOffset = 0
        for (index, paragraph) in paragraphs.enumerated() {
            let paragraphLength = paragraph.count
            if offset < cumulativeOffset + paragraphLength {
                return index
            }
            cumulativeOffset += paragraphLength + (index < paragraphs.count - 1 ? 2 : 0)
        }
        return max(0, paragraphs.count - 1)
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

            while start > 0 {
                let char = text.character(at: start - 1)
                if isSentenceBoundary(char) { break }
                start -= 1
            }

            while end < text.length {
                let char = text.character(at: end)
                if isSentenceBoundary(char) && end > index {
                    end += 1
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
