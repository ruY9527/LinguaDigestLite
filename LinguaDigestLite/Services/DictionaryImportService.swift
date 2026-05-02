//
//  DictionaryImportService.swift
//  LinguaDigestLite
//
//  词典导入服务 - 支持导入自定义词典增强本地词典
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 词典导入模式
enum DictionaryImportMode: String, CaseIterable {
    case enhance
    case overwrite
    case addOnly

    var displayName: String {
        switch self {
        case .enhance: return L("importMode.enhance")
        case .overwrite: return L("importMode.overwriteMode")
        case .addOnly: return L("importMode.addOnlyMode")
        }
    }

    var description: String {
        switch self {
        case .enhance: return L("importMode.merge")
        case .overwrite: return L("importMode.overwrite")
        case .addOnly: return L("importMode.addOnly")
        }
    }
}

/// 词典导入结果
struct DictionaryImportResult {
    var success: Bool
    var totalEntries: Int
    var importedEntries: Int
    var skippedEntries: Int
    var updatedEntries: Int
    var errors: [String]
    var warnings: [String]
    
    var summary: String {
        if success {
            return String(format: L("import.resultDetail"), totalEntries, importedEntries, updatedEntries, skippedEntries)
        } else {
            return String(format: L("import.failedDetail"), errors.first ?? L("common.unknown"))
        }
    }
}

/// 词典文件格式
enum DictionaryFileFormat: String {
    case json = "JSON"
    case csv = "CSV"
    case txt = "TXT"
}

/// 导入的词条格式（简化版，便于用户编写）
struct ImportDictionaryEntry: Codable {
    /// 单词（必填）
    var word: String
    
    /// 音标（可选）
    var phonetic: String?
    
    /// 词性（可选，如 n., v., adj. 等）
    var partOfSpeech: String?
    
    /// 中文释义（必填）
    var definition: String
    
    /// 例句（可选）
    var example: String?
    
    /// 词频等级（可选，1-5）
    var frequency: Int?
    
    /// 词汇等级（可选，如 CET4, CET6, GRE）
    var level: String?
}

/// 词典导入服务
class DictionaryImportService: NSObject, ObservableObject {
    static let shared = DictionaryImportService()
    
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0.0
    @Published var importStatus: String = ""
    
    private let dictionaryService = DictionaryService.shared
    
    /// 支持的文件类型
    let supportedTypes: [UTType] = [
        UTType.json,
        UTType("public.csv") ?? UTType.text,
        UTType.plainText
    ]
    
    /// 词典格式说明文档
    static var formatGuide: String {
        """
        # 词典导入格式说明
        
        LinguaDigestLite 支持三种词典格式：JSON、CSV、TXT
        
        ## JSON 格式（推荐）
        
        ```json
        [
          {
            "word": "hello",
            "phonetic": "həˈləʊ",
            "partOfSpeech": "int.",
            "definition": "你好；喂",
            "example": "Hello, how are you?",
            "frequency": 5,
            "level": "CET4"
          },
          {
            "word": "world",
            "phonetic": "wɜːld",
            "partOfSpeech": "n.",
            "definition": "世界；地球",
            "example": "The world is beautiful.",
            "frequency": 4
          }
        ]
        ```
        
        ## CSV 格式
        
        ```
        word,phonetic,partOfSpeech,definition,example,frequency,level
        hello,həˈləʊ,int.,你好；喂,Hello, how are you?,5,CET4
        world,wɜːld,n.,世界；地球,The world is beautiful.,4,CET4
        ```
        
        ## TXT 格式（简单格式）
        
        每行一个词条，格式：单词|音标|词性|释义|例句
        
        ```
        hello|həˈləʊ|int.|你好；喂|Hello, how are you?
        world|wɜːld|n.|世界；地球|The world is beautiful.
        ```
        
        ## 字段说明
        
        | 字段 | 必填 | 说明 |
        |------|------|------|
        | word | ✅ | 单词本身 |
        | phonetic | ❌ | 音标（美式） |
        | partOfSpeech | ❌ | 词性（n./v./adj./adv./prep./conj./int.） |
        | definition | ✅ | 中文释义，多个释义可用分号分隔 |
        | example | ❌ | 例句 |
        | frequency | ❌ | 词频等级（1-5，5为最高频） |
        | level | ❌ | 词汇等级（CET4/CET6/GRE/TOEFL/IELTS） |
        
        ## 导入模式
        
        - **增强**：添加新词，已有词条会合并释义
        - **覆盖**：完全替换已有词条
        - **仅新增**：只添加不存在的词条
        
        ## 示例文件
        
        可在 App 设置页面下载示例词典文件。
        """
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - 文件导入
    
    /// 导入词典文件
    func importDictionary(
        from url: URL,
        mode: DictionaryImportMode,
        completion: @escaping (DictionaryImportResult) -> Void
    ) {
        DispatchQueue.main.async {
            self.isImporting = true
            self.importProgress = 0.0
            self.importStatus = "正在读取文件..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.processImport(url: url, mode: mode)
            
            DispatchQueue.main.async {
                self.isImporting = false
                self.importProgress = 1.0
                self.importStatus = result.summary
                completion(result)
            }
        }
    }
    
    /// 处理导入
    private func processImport(url: URL, mode: DictionaryImportMode) -> DictionaryImportResult {
        // 获取文件扩展名
        let extensionName = url.pathExtension.lowercased()
        let format = DictionaryFileFormat(rawValue: extensionName.uppercased()) ?? .txt
        
        // 读取文件内容
        guard let content = readFileContent(url: url) else {
            return DictionaryImportResult(
                success: false,
                totalEntries: 0,
                importedEntries: 0,
                skippedEntries: 0,
                updatedEntries: 0,
                errors: ["无法读取文件内容"],
                warnings: []
            )
        }
        
        // 解析词条
        var entries: [ImportDictionaryEntry] = []
        var parseErrors: [String] = []
        
        switch format {
        case .json:
            entries = parseJSON(content: content, errors: &parseErrors)
        case .csv:
            entries = parseCSV(content: content, errors: &parseErrors)
        case .txt:
            entries = parseTXT(content: content, errors: &parseErrors)
        }
        
        if entries.isEmpty {
            return DictionaryImportResult(
                success: false,
                totalEntries: 0,
                importedEntries: 0,
                skippedEntries: 0,
                updatedEntries: 0,
                errors: parseErrors.isEmpty ? ["文件中没有有效词条"] : parseErrors,
                warnings: []
            )
        }
        
        // 导入词条到数据库
        return importEntries(entries: entries, mode: mode)
    }
    
    /// 读取文件内容
    private func readFileContent(url: URL) -> String? {
        // 需要访问安全范围内的文件
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    // MARK: - 格式解析
    
    /// 解析 JSON 格式
    private func parseJSON(content: String, errors: inout [String]) -> [ImportDictionaryEntry] {
        guard let data = content.data(using: .utf8) else {
            errors.append("无法转换 JSON 数据")
            return []
        }
        
        do {
            // 尝试解析数组格式
            let entries = try JSONDecoder().decode([ImportDictionaryEntry].self, from: data)
            return entries.filter { !$0.word.isEmpty && !$0.definition.isEmpty }
        } catch {
            // 尝试解析单个对象格式（包装成数组）
            do {
                let singleEntry = try JSONDecoder().decode(ImportDictionaryEntry.self, from: data)
                if !singleEntry.word.isEmpty && !singleEntry.definition.isEmpty {
                    return [singleEntry]
                }
            } catch {
                errors.append("JSON 解析失败：\(error.localizedDescription)")
            }
            return []
        }
    }
    
    /// 解析 CSV 格式
    private func parseCSV(content: String, errors: inout [String]) -> [ImportDictionaryEntry] {
        var entries: [ImportDictionaryEntry] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        
        guard lines.count > 0 else {
            errors.append("CSV 文件为空")
            return []
        }
        
        // 解析标题行
        let headerLine = lines[0].split(separator: ",")
        var headerMap: [String: Int] = [:]
        
        for (index, header) in headerLine.enumerated() {
            let cleanHeader = String(header).trimmingCharacters(in: .whitespaces).lowercased()
            headerMap[cleanHeader] = index
        }
        
        // 检查必要字段
        let requiredFields = ["word", "definition"]
        for field in requiredFields {
            if headerMap[field] == nil {
                errors.append("CSV 缺少必要字段：\(field)")
                return []
            }
        }
        
        // 解析数据行
        for (lineIndex, line) in lines.dropFirst().enumerated() {
            let values = parseCSVLine(String(line))
            
            guard let wordIndex = headerMap["word"],
                  let defIndex = headerMap["definition"],
                  values.count > max(wordIndex, defIndex) else {
                continue
            }
            
            let word = values[wordIndex].trimmingCharacters(in: .whitespaces)
            let definition = values[defIndex].trimmingCharacters(in: .whitespaces)
            
            if word.isEmpty || definition.isEmpty {
                continue
            }
            
            var entry = ImportDictionaryEntry(word: word, definition: definition)
            
            // 解析可选字段
            if let phoneticIndex = headerMap["phonetic"], values.count > phoneticIndex {
                entry.phonetic = values[phoneticIndex].trimmingCharacters(in: .whitespaces)
            }
            
            if let posIndex = headerMap["partofspeech"], values.count > posIndex {
                entry.partOfSpeech = values[posIndex].trimmingCharacters(in: .whitespaces)
            }
            // 支持 pos 别名
            if entry.partOfSpeech == nil, let posIndex = headerMap["pos"], values.count > posIndex {
                entry.partOfSpeech = values[posIndex].trimmingCharacters(in: .whitespaces)
            }
            
            if let exampleIndex = headerMap["example"], values.count > exampleIndex {
                entry.example = values[exampleIndex].trimmingCharacters(in: .whitespaces)
            }
            
            if let freqIndex = headerMap["frequency"], values.count > freqIndex {
                let freqStr = values[freqIndex].trimmingCharacters(in: .whitespaces)
                entry.frequency = Int(freqStr)
            }
            
            if let levelIndex = headerMap["level"], values.count > levelIndex {
                entry.level = values[levelIndex].trimmingCharacters(in: .whitespaces)
            }
            
            entries.append(entry)
        }
        
        return entries
    }
    
    /// 解析 CSV 行（处理引号内的逗号）
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        
        values.append(currentValue)
        return values
    }
    
    /// 解析 TXT 格式（简单管道分隔）
    private func parseTXT(content: String, errors: inout [String]) -> [ImportDictionaryEntry] {
        var entries: [ImportDictionaryEntry] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            let parts = String(line).split(separator: "|")
            
            guard parts.count >= 2 else {
                continue
            }
            
            let word = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let definition = String(parts[parts.count >= 4 ? 3 : 1]).trimmingCharacters(in: .whitespaces)
            
            if word.isEmpty || definition.isEmpty {
                continue
            }
            
            var entry = ImportDictionaryEntry(word: word, definition: definition)
            
            // 解析其他字段
            if parts.count >= 2 {
                entry.phonetic = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
            
            if parts.count >= 3 {
                entry.partOfSpeech = String(parts[2]).trimmingCharacters(in: .whitespaces)
            }
            
            if parts.count >= 5 {
                entry.example = String(parts[4]).trimmingCharacters(in: .whitespaces)
            }
            
            entries.append(entry)
        }
        
        return entries
    }
    
    // MARK: - 数据库导入
    
    /// 导入词条到数据库
    private func importEntries(entries: [ImportDictionaryEntry], mode: DictionaryImportMode) -> DictionaryImportResult {
        var imported = 0
        var skipped = 0
        var updated = 0
        var warnings: [String] = []
        var errors: [String] = []
        
        let total = entries.count
        
        for (index, entry) in entries.enumerated() {
            // 更新进度
            DispatchQueue.main.async {
                self.importProgress = Double(index + 1) / Double(total)
                self.importStatus = "正在导入词条 \(index + 1)/\(total)... \(entry.word)"
            }
            
            let cleanWord = entry.word.lowercased().trimmingCharacters(in: .whitespaces)
            
            // 检查是否已存在
            let existingDef = dictionaryService.getDefinition(for: cleanWord)
            
            if existingDef != nil {
                switch mode {
                case .enhance:
                    // 合并释义
                    let mergedDef = mergeDefinitions(existing: existingDef!, new: entry.definition)
                    if updateEntry(word: cleanWord, definition: mergedDef, entry: entry) {
                        updated += 1
                    } else {
                        skipped += 1
                    }
                    
                case .overwrite:
                    // 完全替换
                    if updateEntry(word: cleanWord, definition: entry.definition, entry: entry) {
                        updated += 1
                    } else {
                        skipped += 1
                    }
                    
                case .addOnly:
                    // 跳过已存在的
                    skipped += 1
                }
            } else {
                // 新词条，直接添加
                if addEntry(entry: entry) {
                    imported += 1
                } else {
                    warnings.append("无法添加词条：\(entry.word)")
                }
            }
        }
        
        return DictionaryImportResult(
            success: errors.isEmpty,
            totalEntries: total,
            importedEntries: imported,
            skippedEntries: skipped,
            updatedEntries: updated,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// 合并释义
    private func mergeDefinitions(existing: String, new: String) -> String {
        // 使用分号分隔多个释义
        let existingDefs = existing.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
        let newDefs = new.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        var allDefs = existingDefs
        
        for def in newDefs {
            if !allDefs.contains(def) {
                allDefs.append(def)
            }
        }
        
        return allDefs.joined(separator: "; ")
    }
    
    /// 添加新词条到内置词典
    private func addEntry(entry: ImportDictionaryEntry) -> Bool {
        let word = entry.word.lowercased()
        
        // 创建词条并添加到内置词典
        let dictEntry = DictionaryEntry(
            word: word,
            phoneticUS: entry.phonetic,
            phoneticUK: nil,
            partOfSpeech: entry.partOfSpeech,
            definition: entry.definition,
            definitionSimple: entry.definition,
            example: entry.example,
            frequency: entry.frequency ?? 3,
            level: entry.level
        )
        
        // 使用 DictionaryService 的扩展方法添加
        return dictionaryService.addCustomEntry(dictEntry)
    }
    
    /// 更新已有词条
    private func updateEntry(word: String, definition: String, entry: ImportDictionaryEntry) -> Bool {
        return dictionaryService.updateEntry(
            word: word,
            phonetic: entry.phonetic,
            partOfSpeech: entry.partOfSpeech,
            definition: definition,
            example: entry.example
        )
    }
    
    // MARK: - 示例文件生成
    
    /// 生成示例词典文件
    func generateSampleDictionary(format: DictionaryFileFormat) -> URL? {
        let sampleEntries: [ImportDictionaryEntry] = [
            ImportDictionaryEntry(
                word: "example",
                phonetic: "ɪɡˈzæmpəl",
                partOfSpeech: "n.",
                definition: "例子；榜样",
                example: "This is an example of how to use the word.",
                frequency: 5,
                level: "CET4"
            ),
            ImportDictionaryEntry(
                word: "dictionary",
                phonetic: "ˈdɪkʃənərɪ",
                partOfSpeech: "n.",
                definition: "词典；字典",
                example: "I looked up the word in the dictionary.",
                frequency: 4,
                level: "CET4"
            ),
            ImportDictionaryEntry(
                word: "import",
                phonetic: "ɪmˈpɔːt",
                partOfSpeech: "v.",
                definition: "导入；输入",
                example: "You can import custom dictionaries.",
                frequency: 3,
                level: "CET6"
            ),
            ImportDictionaryEntry(
                word: "enhance",
                phonetic: "ɪnˈhæns",
                partOfSpeech: "v.",
                definition: "增强；提高",
                example: "This feature enhances the learning experience.",
                frequency: 3,
                level: "CET6"
            ),
            ImportDictionaryEntry(
                word: "vocabulary",
                phonetic: "vəˈkæbjʊlərɪ",
                partOfSpeech: "n.",
                definition: "词汇；词汇量",
                example: "Learning new vocabulary is important.",
                frequency: 5,
                level: "CET4"
            )
        ]
        
        let fileName = "sample_dictionary.\(format.rawValue.lowercased())"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        var content: String
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(sampleEntries),
               let jsonString = String(data: data, encoding: .utf8) {
                content = jsonString
            } else {
                return nil
            }
            
        case .csv:
            let header = "word,phonetic,partOfSpeech,definition,example,frequency,level"
            let rows = sampleEntries.map { entry in
                "\"\(entry.word)\",\"\(entry.phonetic ?? "")\",\"\(entry.partOfSpeech ?? "")\",\"\(entry.definition)\"," +
                "\"\(entry.example ?? "")\",\"\(entry.frequency ?? 0)\",\"\(entry.level ?? "")\""
            }
            content = header + "\n" + rows.joined(separator: "\n")
            
        case .txt:
            content = sampleEntries.map { entry in
                "\(entry.word)|\(entry.phonetic ?? "")|\(entry.partOfSpeech ?? "")|\(entry.definition)|\(entry.example ?? "")"
            }.joined(separator: "\n")
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("生成示例文件失败: \(error)")
            return nil
        }
    }
    
    /// 获取当前自定义词条数量
    func getCustomEntryCount() -> Int {
        return dictionaryService.getCustomEntryCount()
    }
    
    /// 清除所有自定义词条
    func clearCustomEntries() {
        dictionaryService.clearCustomEntries()
    }
    
    /// 导出当前自定义词典
    func exportCustomDictionary(format: DictionaryFileFormat) -> URL? {
        let customEntries = dictionaryService.getAllCustomEntries()
        
        if customEntries.isEmpty {
            return nil
        }
        
        let fileName = "exported_dictionary.\(format.rawValue.lowercased())"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        var content: String
        
        switch format {
        case .json:
            let importEntries = customEntries.map { entry in
                ImportDictionaryEntry(
                    word: entry.word,
                    phonetic: entry.phoneticUS,
                    partOfSpeech: entry.partOfSpeech,
                    definition: entry.definition ?? "",
                    example: entry.example,
                    frequency: entry.frequency,
                    level: entry.level
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(importEntries),
               let jsonString = String(data: data, encoding: .utf8) {
                content = jsonString
            } else {
                return nil
            }
            
        case .csv:
            let header = "word,phonetic,partOfSpeech,definition,example,frequency,level"
            let rows = customEntries.map { entry in
                "\"\(entry.word)\",\"\(entry.phoneticUS ?? "")\",\"\(entry.partOfSpeech ?? "")\",\"\(entry.definition ?? "")\",\"\(entry.example ?? "")\",\"\(entry.frequency ?? 0)\",\"\(entry.level ?? "")\""
            }
            content = header + "\n" + rows.joined(separator: "\n")
            
        case .txt:
            content = customEntries.map { entry in
                "\(entry.word)|\(entry.phoneticUS ?? "")|\(entry.partOfSpeech ?? "")|\(entry.definition ?? "")|\(entry.example ?? "")"
            }.joined(separator: "\n")
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("导出词典失败: \(error)")
            return nil
        }
    }
}