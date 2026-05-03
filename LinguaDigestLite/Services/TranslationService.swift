//
//  TranslationService.swift
//  LinguaDigestLite
//
//  系统翻译服务 - 支持句子翻译
//

import Foundation
import UIKit

/// 翻译服务类型
enum TranslationServiceType: String, CaseIterable {
    case system
    case google
    case baidu
    case deepL

    var displayName: String {
        switch self {
        case .system: return L("translation.system")
        case .google: return L("translation.google")
        case .baidu: return L("translation.baidu")
        case .deepL: return L("translation.deepl")
        }
    }
}

/// 系统翻译服务
class TranslationService: NSObject {
    static let shared = TranslationService()
    
    /// 翻译错误类型
    enum TranslationError: LocalizedError {
        case translationUnavailable
        case textTooShort
        case networkError
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .translationUnavailable:
                return L("error.translationUnavailable")
            case .textTooShort:
                return L("error.textTooShort")
            case .networkError:
                return L("error.translationNetwork")
            case .unknownError:
                return L("error.translationFailed")
            }
        }
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - 系统翻译
    
    /// 使用系统翻译（iOS 15+）
    /// 调用系统翻译应用进行翻译
    func translateWithSystemApp(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= 2 else { return }
        
        // 使用系统翻译 URL scheme
        let encodedText = trimmedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedText
        
        // 方案1: 使用系统翻译应用
        if let url = URL(string: "x-translate://?text=\(encodedText)&source=en&target=zh") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // 方案2: 使用 Google 翻译作为备选
        openGoogleTranslate(text: trimmedText)
    }
    
    /// 打开 Google 翻译
    func openGoogleTranslate(text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        
        // Google 翻译网页版
        let googleTranslateURL = "https://translate.google.com/?sl=en&tl=zh-CN&text=\(encodedText)"
        
        if let url = URL(string: googleTranslateURL) {
            UIApplication.shared.open(url)
        }
    }
    
    /// 打开百度翻译（备选）
    func openBaiduTranslate(text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        
        let baiduTranslateURL = "https://fanyi.baidu.com/#en/zh/\(encodedText)"
        
        if let url = URL(string: baiduTranslateURL) {
            UIApplication.shared.open(url)
        }
    }
    
    /// 打开 DeepL 翻译（备选）
    func openDeepLTranslate(text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        
        let deepLURL = "https://www.deepl.com/translator#en/zh/\(encodedText)"
        
        if let url = URL(string: deepLURL) {
            UIApplication.shared.open(url)
        }
    }
    
    /// 根据类型翻译
    func translate(text: String, serviceType: TranslationServiceType) {
        switch serviceType {
        case .system:
            translateWithSystemApp(text: text)
        case .google:
            openGoogleTranslate(text: text)
        case .baidu:
            openBaiduTranslate(text: text)
        case .deepL:
            openDeepLTranslate(text: text)
        }
    }
    
    // MARK: - 内置简易翻译（用于快速预览）
    
    /// 内置简易翻译（仅用于句子快速预览，非完整翻译）
    /// 使用词典中的单词释义组合生成大致意思
    func quickTranslateSentence(_ sentence: String) -> String? {
        let dictionaryService = DictionaryService.shared
        
        // 分词
        let words = sentence.split(separator: " ").map { String($0) }
        var translations: [String] = []
        
        for word in words {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let definition = dictionaryService.getDefinition(for: cleanWord) {
                translations.append(definition)
            }
        }
        
        if translations.isEmpty {
            return nil
        }
        
        // 返回主要单词释义的组合（仅用于预览）
        return translations.prefix(5).joined(separator: "、")
    }
    
    // MARK: - 检测翻译可用性
    
    /// 检查系统翻译是否可用
    func isSystemTranslationAvailable() -> Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }

    /// iOS 17.4+ 支持 app 内系统翻译弹窗。
    var supportsNativeTranslationPresentation: Bool {
        if #available(iOS 17.4, *) {
            return true
        }
        return false
    }
    
    /// 获取可用的翻译服务列表
    func availableTranslationServiceTypes() -> [TranslationServiceType] {
        var services: [TranslationServiceType] = []
        
        // 系统翻译（优先）
        if isSystemTranslationAvailable() {
            services.append(.system)
        }
        
        // 第三方翻译服务
        services.append(contentsOf: [.google, .baidu, .deepL])
        
        return services
    }
}
