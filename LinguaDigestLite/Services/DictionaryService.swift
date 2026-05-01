//
//  DictionaryService.swift
//  LinguaDigestLite
//
//  词典服务 - 基于 SQLite 统一词库的查询
//

import Foundation
import UIKit
import NaturalLanguage

/// 词典服务
class DictionaryService {
    static let shared = DictionaryService()

    private init() {
        migrateCustomEntriesIfNeeded()
    }

    // MARK: - ECDICT 状态

    /// ECDICT 完整词典是否可用
    var isECDICTAvailable: Bool {
        return DictionaryDatabaseManager.shared.isECDICTAvailable
    }

    /// ECDICT 词条数量
    var ecdictEntryCount: Int {
        return DictionaryDatabaseManager.shared.ecdictEntryCount
    }

    // MARK: - 不规则词形变化表

    private let irregularWordForms: [String: [String]] = [
        "am": ["be"], "is": ["be"], "are": ["be"], "was": ["be"], "were": ["be"], "been": ["be"], "being": ["be"],
        "has": ["have"], "had": ["have"], "having": ["have"],
        "does": ["do"], "did": ["do"], "done": ["do"], "doing": ["do"],
        "goes": ["go"], "went": ["go"], "gone": ["go"],
        "says": ["say"], "said": ["say"],
        "gets": ["get"], "got": ["get"], "gotten": ["get"], "getting": ["get"],
        "makes": ["make"], "made": ["make"], "making": ["make"],
        "takes": ["take"], "took": ["take"], "taken": ["take"], "taking": ["take"],
        "sees": ["see"], "saw": ["see"], "seen": ["see"], "seeing": ["see"],
        "comes": ["come"], "came": ["come"], "coming": ["come"],
        "thinks": ["think"], "thought": ["think"], "thinking": ["think"],
        "finds": ["find"], "found": ["find"], "finding": ["find"],
        "tells": ["tell"], "told": ["tell"], "telling": ["tell"],
        "feels": ["feel"], "felt": ["feel"], "feeling": ["feel"],
        "leaves": ["leave"], "left": ["leave"], "leaving": ["leave"],
        "keeps": ["keep"], "kept": ["keep"], "keeping": ["keep"],
        "begins": ["begin"], "began": ["begin"], "begun": ["begin"], "beginning": ["begin"],
        "hears": ["hear"], "heard": ["hear"], "hearing": ["hear"],
        "runs": ["run"], "ran": ["run"], "running": ["run"],
        "holds": ["hold"], "held": ["hold"], "holding": ["hold"],
        "brings": ["bring"], "brought": ["bring"], "bringing": ["bring"],
        "writes": ["write"], "wrote": ["write"], "written": ["write"], "writing": ["write"],
        "sits": ["sit"], "sat": ["sit"], "sitting": ["sit"],
        "stands": ["stand"], "stood": ["stand"], "standing": ["stand"],
        "pays": ["pay"], "paid": ["pay"], "paying": ["pay"],
        "meets": ["meet"], "met": ["meet"], "meeting": ["meet"],
        "sets": ["set"], "setting": ["set"],
        "learns": ["learn"], "learned": ["learn"], "learnt": ["learn"], "learning": ["learn"],
        "leads": ["lead"], "led": ["lead"], "leading": ["lead"],
        "understands": ["understand"], "understood": ["understand"], "understanding": ["understand"],
        "speaks": ["speak"], "spoke": ["speak"], "spoken": ["speak"], "speaking": ["speak"],
        "reads": ["read"], "reading": ["read"],
        "spends": ["spend"], "spent": ["spend"], "spending": ["spend"],
        "grows": ["grow"], "grew": ["grow"], "grown": ["grow"], "growing": ["grow"],
        "wins": ["win"], "won": ["win"], "winning": ["win"],
        "buys": ["buy"], "bought": ["buy"], "buying": ["buy"],
        "sends": ["send"], "sent": ["send"], "sending": ["send"],
        "builds": ["build"], "built": ["build"], "building": ["build"],
        "falls": ["fall"], "fell": ["fall"], "fallen": ["fall"], "falling": ["fall"],
        "reaches": ["reach"], "reached": ["reach"], "reaching": ["reach"],
        "raises": ["raise"], "raised": ["raise"], "raising": ["raise"],
        "sells": ["sell"], "sold": ["sell"], "selling": ["sell"],
        "decides": ["decide"], "decided": ["decide"], "deciding": ["decide"],
        "children": ["child"], "men": ["man"], "women": ["woman"], "people": ["person"],
        "teeth": ["tooth"], "feet": ["foot"], "mice": ["mouse"], "geese": ["goose"],
        "better": ["good"], "best": ["good"], "worse": ["bad"], "worst": ["bad"],
        "farther": ["far"], "further": ["far"], "farthest": ["far"], "furthest": ["far"]
    ]

    // MARK: - 词典查询

    /// 获取单词的多个中文释义
    func getDefinitions(for word: String) -> [String] {
        let candidates = dictionaryLookupCandidates(for: word)
        var definitions: [String] = []
        var seen = Set<String>()

        for candidate in candidates {
            let entries = DictionaryDatabaseManager.shared.queryAllEntries(word: candidate)
            for entry in entries {
                let split = splitDefinitions(entry.definition ?? "")
                for meaning in split {
                    if seen.insert(meaning).inserted {
                        definitions.append(meaning)
                    }
                }
            }
        }

        return definitions
    }

    /// 获取单词的中文释义（合并为单个字符串）
    func getDefinition(for word: String) -> String? {
        let definitions = getDefinitions(for: word)
        guard !definitions.isEmpty else { return nil }
        return definitions.joined(separator: "；")
    }

    /// 获取单词的英文释义
    func getEnglishDefinition(for word: String) -> String? {
        for candidate in dictionaryLookupCandidates(for: word) {
            let entries = DictionaryDatabaseManager.shared.queryAllEntries(word: candidate)
            if let first = entries.first(where: { $0.englishDefinition != nil && !$0.englishDefinition!.isEmpty }) {
                return first.englishDefinition
            }
        }
        return nil
    }

    /// 获取单词的词性（从词典）
    func getPartOfSpeechFromDictionary(for word: String) -> String? {
        for candidate in dictionaryLookupCandidates(for: word) {
            let entries = DictionaryDatabaseManager.shared.queryAllEntries(word: candidate)
            if let first = entries.first {
                return normalizedPartOfSpeech(first.partOfSpeech)
            }
        }
        return nil
    }

    /// 获取单词的所有词典条目（支持一词多义）
    func dictionaryEntries(for word: String) -> [DictionaryEntry] {
        let candidates = dictionaryLookupCandidates(for: word)
        var allEntries: [DictionaryEntry] = []
        var seen = Set<String>()

        for candidate in candidates {
            let entries = DictionaryDatabaseManager.shared.queryAllEntries(word: candidate)
            for entry in entries {
                let key = "\(entry.partOfSpeech ?? "")|\(entry.definition ?? "")"
                if seen.insert(key).inserted {
                    allEntries.append(entry)
                }
            }
        }

        return allEntries
    }

    /// 按词性分组获取释义
    func getGroupedDefinitions(for word: String) -> [(pos: String, definitions: [String])] {
        let entries = dictionaryEntries(for: word)
        var grouped: [String: [String]] = [:]
        var posOrder: [String] = []

        for entry in entries {
            let pos = entry.partOfSpeech ?? "unknown"
            let defs = splitDefinitions(entry.definition ?? "")
            if grouped[pos] == nil {
                posOrder.append(pos)
                grouped[pos] = []
            }
            for def in defs {
                if !(grouped[pos]?.contains(def) ?? false) {
                    grouped[pos]?.append(def)
                }
            }
        }

        return posOrder.compactMap { pos in
            guard let defs = grouped[pos], !defs.isEmpty else { return nil }
            return (pos: pos, definitions: defs)
        }
    }

    // MARK: - 词形归一化

    private func dictionaryLookupCandidates(for word: String) -> [String] {
        let normalized = normalizeLookupWord(word)
        guard !normalized.isEmpty else { return [] }

        var candidates: [String] = [normalized]
        var seen = Set(candidates)

        func appendCandidate(_ candidate: String?) {
            guard let candidate, !candidate.isEmpty else { return }
            if seen.insert(candidate).inserted {
                candidates.append(candidate)
            }
        }

        appendCandidate(getLemma(for: normalized)?.lowercased())

        if let irregulars = irregularWordForms[normalized] {
            for irregular in irregulars {
                appendCandidate(irregular)
            }
        }

        for derived in deriveBaseForms(from: normalized) {
            appendCandidate(derived)
        }

        return candidates
    }

    private func normalizeLookupWord(_ word: String) -> String {
        var normalized = word.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "")
            .replacingOccurrences(of: "\u{201D}", with: "")

        normalized = normalized.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))

        if normalized.hasSuffix("'s") {
            normalized.removeLast(2)
        } else if normalized.hasSuffix("s'") {
            normalized.removeLast()
        }

        if normalized.hasSuffix("n't") {
            switch normalized {
            case "can't": normalized = "can"
            case "won't": normalized = "will"
            case "shan't": normalized = "shall"
            default: normalized = String(normalized.dropLast(3))
            }
        } else if normalized.hasSuffix("'re") || normalized.hasSuffix("'ve") || normalized.hasSuffix("'ll") {
            normalized.removeLast(3)
        } else if normalized.hasSuffix("'d") || normalized.hasSuffix("'m") {
            normalized.removeLast(2)
        }

        return normalized
    }

    private func deriveBaseForms(from word: String) -> [String] {
        var forms: [String] = []

        if word.count > 4 && word.hasSuffix("ies") {
            forms.append(String(word.dropLast(3)) + "y")
        }
        if word.count > 4 && word.hasSuffix("ves") {
            forms.append(String(word.dropLast(3)) + "f")
            forms.append(String(word.dropLast(3)) + "fe")
        }
        if word.count > 3 && word.hasSuffix("es") {
            forms.append(String(word.dropLast(2)))
        }
        if word.count > 3 && word.hasSuffix("s") {
            forms.append(String(word.dropLast()))
        }
        if word.count > 5 && word.hasSuffix("ing") {
            let stem = String(word.dropLast(3))
            forms.append(stem)
            forms.append(stem + "e")
            if stem.count > 2, let last = stem.last {
                let chars = Array(stem)
                if chars.count >= 2, chars[chars.count - 1] == chars[chars.count - 2] {
                    forms.append(String(stem.dropLast()))
                }
                if last == "y" {
                    forms.append(String(stem.dropLast()) + "ie")
                }
            }
        }
        if word.count > 4 && word.hasSuffix("ied") {
            forms.append(String(word.dropLast(3)) + "y")
        }
        if word.count > 3 && word.hasSuffix("ed") {
            let stem = String(word.dropLast(2))
            forms.append(stem)
            forms.append(stem + "e")
            let chars = Array(stem)
            if chars.count >= 2, chars[chars.count - 1] == chars[chars.count - 2] {
                forms.append(String(stem.dropLast()))
            }
        }
        if word.count > 4 && word.hasSuffix("er") {
            forms.append(String(word.dropLast(2)))
            forms.append(String(word.dropLast(2)) + "e")
        }
        if word.count > 5 && word.hasSuffix("est") {
            forms.append(String(word.dropLast(3)))
            forms.append(String(word.dropLast(3)) + "e")
        }
        if word.count > 4 && word.hasSuffix("ly") {
            forms.append(String(word.dropLast(2)))
        }

        return Array(Set(forms.filter { !$0.isEmpty && $0 != word }))
    }

    func splitDefinitions(_ definition: String) -> [String] {
        let normalized = definition
            .replacingOccurrences(of: "、", with: "；")
            .replacingOccurrences(of: ";", with: "；")
            .replacingOccurrences(of: "|", with: "；")

        return normalized
            .components(separatedBy: "；")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func normalizedPartOfSpeech(_ pos: String?) -> String? {
        guard let pos else { return nil }

        switch pos {
        case "名词": return "noun"
        case "动词": return "verb"
        case "形容词": return "adjective"
        case "副词": return "adverb"
        case "代词": return "pronoun"
        case "介词": return "preposition"
        case "连词": return "conjunction"
        case "限定词": return "determiner"
        case "感叹词": return "interjection"
        // 已标准化的值直接返回
        case "noun", "verb", "adjective", "adverb", "pronoun",
             "preposition", "conjunction", "determiner", "interjection",
             "computer", "medical", "slang", "electronics", "legal",
             "economics", "chemistry", "physics", "math", "biology", "pharmacy":
            return pos
        default:
            if pos.contains("名词") { return "noun" }
            if pos.contains("动词") { return "verb" }
            if pos.contains("形容词") { return "adjective" }
            if pos.contains("副词") { return "adverb" }
            if pos.contains("代词") { return "pronoun" }
            if pos.contains("介词") { return "preposition" }
            if pos.contains("连词") { return "conjunction" }
            if pos.contains("限定词") { return "determiner" }
            if pos.contains("感叹词") { return "interjection" }
            return pos
        }
    }

    // MARK: - 系统词典

    func hasSystemDefinition(for word: String, language: String = "en") -> Bool {
        return UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
    }

    func systemDictionaryViewController(for word: String) -> UIViewController {
        return UIReferenceLibraryViewController(term: word)
    }

    // MARK: - NLP 分析

    func analyzeText(_ text: String) -> TextAnalysis {
        let analyzer = TextAnalyzer(text: text)
        return analyzer.analyze()
    }

    func getPartOfSpeech(for word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = word
        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lexicalClass)
        return tag?.rawValue
    }

    func getLemma(for word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma)
        return tag?.rawValue
    }

    func tagText(_ text: String) -> [TokenTag] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        var tokens: [TokenTag] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { substring, range, _, _ in
            guard let substring = substring else { return }
            let (lexicalTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
            tokens.append(TokenTag(
                text: substring,
                range: NSRange(range, in: text),
                partOfSpeech: lexicalTag?.rawValue,
                lemma: lemmaTag?.rawValue
            ))
        }
        return tokens
    }

    func detectSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }
        return sentences
    }

    func detectWords(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            words.append(String(text[range]))
            return true
        }
        return words
    }
}

// MARK: - 文本分析结果

struct TextAnalysis {
    var sentences: [SentenceAnalysis]
    var totalWords: Int
    var uniqueWords: Set<String>
    var unknownWords: Set<String>

    init() {
        self.sentences = []
        self.totalWords = 0
        self.uniqueWords = []
        self.unknownWords = []
    }
}

struct SentenceAnalysis {
    var text: String
    var tokens: [TokenTag]
}

struct TokenTag {
    var text: String
    var range: NSRange
    var partOfSpeech: String?
    var lemma: String?

    var displayName: String {
        if let pos = partOfSpeech {
            return "\(text) (\(pos))"
        }
        return text
    }
}

// MARK: - 文本分析器

class TextAnalyzer {
    private let text: String

    init(text: String) {
        self.text = text
    }

    func analyze() -> TextAnalysis {
        var analysis = TextAnalysis()

        let sentences = DictionaryService.shared.detectSentences(text)
        for sentence in sentences {
            let tokens = DictionaryService.shared.tagText(sentence)
            analysis.sentences.append(SentenceAnalysis(text: sentence, tokens: tokens))
        }

        let words = DictionaryService.shared.detectWords(text)
        analysis.totalWords = words.count

        for word in words {
            if let lemma = DictionaryService.shared.getLemma(for: word) {
                analysis.uniqueWords.insert(lemma.lowercased())
            } else {
                analysis.uniqueWords.insert(word.lowercased())
            }
        }

        return analysis
    }

    func extractUnknownWords(knownWords: Set<String>) -> Set<String> {
        let words = DictionaryService.shared.detectWords(text)
        var unknown = Set<String>()

        for word in words {
            let lowercased = word.lowercased()
            if let lemma = DictionaryService.shared.getLemma(for: word) {
                let lemmaLowercased = lemma.lowercased()
                if !knownWords.contains(lemmaLowercased) {
                    unknown.insert(lemmaLowercased)
                }
            } else if !knownWords.contains(lowercased) {
                unknown.insert(lowercased)
            }
        }

        return unknown
    }
}

// MARK: - 词性颜色映射

extension DictionaryService {
    static func colorForPartOfSpeech(_ pos: String?) -> String {
        guard let pos = pos else { return "#78909C" }
        switch pos {
        case "noun": return "#E57373"
        case "verb": return "#81C784"
        case "adjective": return "#64B5F6"
        case "adverb": return "#FFD54F"
        case "pronoun": return "#BA68C8"
        case "preposition": return "#A1887F"
        case "conjunction": return "#90A4AE"
        case "determiner": return "#4DB6AC"
        case "interjection": return "#FF8A65"
        // ECDICT 专业领域标签
        case "computer": return "#26C6DA"
        case "medical": return "#EF5350"
        case "slang": return "#AB47BC"
        case "electronics": return "#42A5F5"
        case "legal": return "#7E57C2"
        case "economics": return "#FFA726"
        case "chemistry": return "#66BB6A"
        case "physics": return "#5C6BC0"
        case "math": return "#29B6F6"
        case "biology": return "#9CCC65"
        case "pharmacy": return "#EC407A"
        default: return "#78909C"
        }
    }

    static func displayNameForPartOfSpeech(_ pos: String?) -> String {
        guard let pos = pos else { return "释义" }
        switch pos {
        case "noun": return "名词"
        case "verb": return "动词"
        case "adjective": return "形容词"
        case "adverb": return "副词"
        case "pronoun": return "代词"
        case "preposition": return "介词"
        case "conjunction": return "连词"
        case "determiner": return "限定词"
        case "interjection": return "感叹词"
        // ECDICT 专业领域标签
        case "computer": return "计算机"
        case "medical": return "医学"
        case "slang": return "网络"
        case "electronics": return "电子"
        case "legal": return "法律"
        case "economics": return "经济"
        case "chemistry": return "化学"
        case "physics": return "物理"
        case "math": return "数学"
        case "biology": return "生物"
        case "pharmacy": return "医药"
        default: return pos
        }
    }
}

// MARK: - 自定义词典支持（基于 SQLite）

extension DictionaryService {

    /// 添加自定义词条
    func addCustomEntry(_ entry: DictionaryEntry) -> Bool {
        return DictionaryDatabaseManager.shared.addCustomEntry(
            word: entry.word,
            phonetic: entry.phoneticUS,
            pos: entry.partOfSpeech,
            definition: entry.definition ?? "",
            example: entry.example
        )
    }

    /// 更新已有词条
    func updateEntry(word: String, phonetic: String?, partOfSpeech: String?, definition: String, example: String?) -> Bool {
        return DictionaryDatabaseManager.shared.updateCustomEntry(
            word: word,
            phonetic: phonetic,
            pos: partOfSpeech,
            definition: definition,
            example: example
        )
    }

    /// 获取自定义词条数量
    func getCustomEntryCount() -> Int {
        return DictionaryDatabaseManager.shared.getCustomEntryCount()
    }

    /// 清除所有自定义词条
    func clearCustomEntries() {
        DictionaryDatabaseManager.shared.clearCustomEntries()
    }

    /// 获取所有自定义词条
    func getAllCustomEntries() -> [DictionaryEntry] {
        return DictionaryDatabaseManager.shared.queryAll(source: "custom")
    }

    /// 获取词条的完整释义（合并多个释义）
    func getFullDefinition(for word: String) -> String {
        let definitions = getDefinitions(for: word)
        return definitions.isEmpty ? "" : definitions.joined(separator: "；")
    }

    /// 获取词条详情（包含所有信息）
    func getEntryDetail(for word: String) -> DictionaryEntry? {
        return DictionaryDatabaseManager.shared.queryEntry(word: word)
    }

    /// 从 UserDefaults 迁移旧的自定义词条到 SQLite
    private func migrateCustomEntriesIfNeeded() {
        let migrationKey = "custom_entries_migrated_to_sqlite"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // 检查是否有旧的 UserDefaults 数据
        if let data = UserDefaults.standard.data(forKey: "customDictionary"),
           let entries = try? JSONDecoder().decode([String: DictionaryEntry].self, from: data) {
            for (_, entry) in entries {
                DictionaryDatabaseManager.shared.addCustomEntry(
                    word: entry.word,
                    phonetic: entry.phoneticUS,
                    pos: entry.partOfSpeech,
                    definition: entry.definition ?? "",
                    example: entry.example
                )
            }
            if !entries.isEmpty {
                print("迁移了 \(entries.count) 条自定义词条到 SQLite")
            }
        }

        // 清除旧数据
        UserDefaults.standard.removeObject(forKey: "customDictionary")
        UserDefaults.standard.removeObject(forKey: "customSimpleDictionary")
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
