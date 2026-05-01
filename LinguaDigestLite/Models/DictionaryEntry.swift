//
//  DictionaryEntry.swift
//  LinguaDigestLite
//
//  ECDICT 词典词条模型
//

import Foundation

/// 词典词条模型（基于 ECDICT 数据结构）
struct DictionaryEntry: Codable {
    /// 单词
    let word: String
    
    /// 音标（美式）
    let phoneticUS: String?
    
    /// 音标（英式）
    let phoneticUK: String?
    
    /// 词性
    let partOfSpeech: String?
    
    /// 中文释义
    let definition: String?
    
    /// 中文释义（简化版）
    let definitionSimple: String?

    /// 英文释义
    let englishDefinition: String?
    
    /// 例句
    let example: String?
    
    /// 词频等级
    let frequency: Int?
    
    /// 等级（如 CET4, CET6, GRE 等）
    let level: String?
    
    /// 是否是牛津3000核心词汇
    let isOxford3000: Bool?
    
    /// 是否是牛津5000核心词汇
    let isOxford5000: Bool?
    
    enum CodingKeys: String, CodingKey {
        case word = "word"
        case phoneticUS = "phonetic_us"
        case phoneticUK = "phonetic_uk"
        case partOfSpeech = "pos"
        case definition = "definition"
        case definitionSimple = "definition_simple"
        case englishDefinition = "english_definition"
        case example = "example"
        case frequency = "frequency"
        case level = "level"
        case isOxford3000 = "oxford3000"
        case isOxford5000 = "oxford5000"
    }
    
    /// 从简化格式创建词条
    init(word: String, phoneticUS: String? = nil, phoneticUK: String? = nil,
         partOfSpeech: String? = nil, definition: String,
         definitionSimple: String? = nil, englishDefinition: String? = nil,
         example: String? = nil,
         frequency: Int? = nil, level: String? = nil) {
        self.word = word
        self.phoneticUS = phoneticUS
        self.phoneticUK = phoneticUK
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.definitionSimple = definitionSimple ?? definition
        self.englishDefinition = englishDefinition
        self.example = example
        self.frequency = frequency
        self.level = level
        self.isOxford3000 = nil
        self.isOxford5000 = nil
    }
}

/// 词典状态
enum DictionaryState {
    /// 未下载
    case notDownloaded
    /// 下载中
    case downloading(progress: Double)
    /// 已下载
    case downloaded(entryCount: Int)
    /// 错误
    case error(message: String)
}