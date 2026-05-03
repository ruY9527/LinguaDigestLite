//
//  ReaderTextView.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import UIKit

/// 文章阅读器 UITextView 子类
final class ReaderTextView: UITextView {
    var onTranslateSelectedText: ((String, NSRange) -> Void)?
    var onSaveSentence: ((String, NSRange) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: L("action.translateSentence"), action: #selector(translateSelectedText(_:))),
            UIMenuItem(title: L("action.save"), action: #selector(saveSelectedSentence(_:))),
            UIMenuItem(title: L("action.clearSelection"), action: #selector(clearTextSelection(_:)))
        ]
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(translateSelectedText(_:)) ||
            action == #selector(saveSelectedSentence(_:)) ||
            action == #selector(clearTextSelection(_:)) {
            return selectedRange.length > 0
        }
        // 隐藏系统"查询/定义/翻译"菜单项
        let selName = NSStringFromSelector(action).lowercased()
        if selName.contains("lookup") || selName.contains("define") || selName.contains("_share") || selName.contains("_translate") {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @available(iOS 16.0, *)
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        // 过滤掉系统"查询/翻译"菜单项（UIAction 和 UIMenu 子菜单）
        func shouldKeep(_ element: UIMenuElement) -> Bool {
            let blocked = ["look up", "lookup", "查询", "define", "translate", "翻译"]
            if let uiAction = element as? UIAction {
                let title = uiAction.title.lowercased()
                return !blocked.contains { title.contains($0) }
            }
            if let menu = element as? UIMenu {
                let title = menu.title.lowercased()
                if blocked.contains(where: { title.contains($0) }) {
                    return false
                }
                let filteredChildren = menu.children.filter { shouldKeep($0) }
                return !filteredChildren.isEmpty
            }
            return true
        }

        // 过滤掉系统"拷贝"，用自定义替代（拷贝后自动取消选中）
        let filteredActions = suggestedActions.filter { shouldKeep($0) }.compactMap { element -> UIMenuElement? in
            if let action = element as? UIAction {
                let title = action.title.lowercased()
                if title.contains("copy") || title.contains("拷贝") || title.contains("复制") { return nil }
            }
            return element
        }

        let copyAction = UIAction(
            title: L("common.copy"),
            image: UIImage(systemName: "doc.on.doc")
        ) { [weak self] _ in
            self?.copyAndClearSelection()
        }

        let translateAction = UIAction(
            title: L("action.translateSentence"),
            image: UIImage(systemName: "character.bubble")
        ) { [weak self] _ in
            self?.translateSelectedText(nil)
        }

        let saveSentenceAction = UIAction(
            title: L("action.save"),
            image: UIImage(systemName: "bookmark.fill")
        ) { [weak self] _ in
            self?.saveSelectedSentence(nil)
        }

        let clearSelectionAction = UIAction(
            title: L("action.clearSelection"),
            image: UIImage(systemName: "xmark.circle")
        ) { [weak self] _ in
            self?.clearTextSelection(nil)
        }

        return UIMenu(children: filteredActions + [copyAction, translateAction, saveSentenceAction, clearSelectionAction])
    }

    @objc func translateSelectedText(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }

        let sourceText = attributedText?.string ?? text ?? ""
        let selectedText = (sourceText as NSString).substring(with: selectedRange)
        onTranslateSelectedText?(selectedText, selectedRange)
    }

    @objc func saveSelectedSentence(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }
        let sourceText = attributedText?.string ?? text ?? ""
        let selectedText = (sourceText as NSString).substring(with: selectedRange)
        onSaveSentence?(selectedText, selectedRange)
    }

    @objc func clearTextSelection(_ sender: Any?) {
        selectedRange = NSRange(location: 0, length: 0)
        resignFirstResponder()
        UIMenuController.shared.hideMenu()
    }

    func copyAndClearSelection() {
        guard selectedRange.length > 0 else { return }
        let sourceText = attributedText?.string ?? text ?? ""
        let selectedText = (sourceText as NSString).substring(with: selectedRange)
        UIPasteboard.general.string = selectedText
        // 延迟到下一个 run loop 执行，避免系统在 action 结束后恢复选区
        DispatchQueue.main.async { [weak self] in
            self?.selectedRange = NSRange(location: 0, length: 0)
        }
    }
}
