//
//  DictionaryDatabaseManager.swift
//  LinguaDigestLite
//
//  词典数据库管理服务 - 基于 ECDICT 开源词库
//

import Foundation
import SQLite3

/// 词典数据库管理服务
class DictionaryDatabaseManager {
    static let shared = DictionaryDatabaseManager()

    /// ECDICT 数据库是否已就绪
    private(set) var isInitialized: Bool = false

    /// 词条总数
    private(set) var entryCount: Int = 0

    /// ECDICT 数据库路径
    private let ecdictDbPath: String

    /// ECDICT 数据库连接
    private var ecdictDb: OpaquePointer?

    /// 自定义词条数据库路径
    private let customDbPath: String

    /// 自定义词条数据库连接
    private var customDb: OpaquePointer?

    /// 初始化状态键
    private let initializedKey = "ecdict_initialized"

    // MARK: - 初始化

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        ecdictDbPath = documentsPath.path + "/ecdict.db"
        customDbPath = documentsPath.path + "/custom_dictionary.db"

        // 复制 ECDICT 从 bundle 到 Documents（首次启动）
        copyECDICTFromBundleIfNeeded()

        // 打开数据库
        openECDICTDatabase()
        openCustomDatabase()

        isInitialized = ecdictDb != nil
        if isInitialized {
            updateEntryCount()
        }
    }

    // MARK: - 数据库操作

    /// 从 bundle 复制 ECDICT 到 Documents
    private func copyECDICTFromBundleIfNeeded() {
        guard let bundlePath = Bundle.main.path(forResource: "ecdict", ofType: "db") else {
            print("Bundle 中未找到 ecdict.db，请将 ECDICT 数据库文件添加到项目中")
            return
        }

        // 如果 Documents 中不存在，直接复制
        guard FileManager.default.fileExists(atPath: ecdictDbPath) else {
            do {
                try FileManager.default.copyItem(atPath: bundlePath, toPath: ecdictDbPath)
                print("ECDICT 数据库已从 bundle 复制到 Documents")
            } catch {
                print("复制 ECDICT 数据库失败: \(error)")
            }
            return
        }

        // Documents 中已存在，校验是否有效（包含 stardict 表且有数据）
        var checkDb: OpaquePointer?
        if sqlite3_open(ecdictDbPath, &checkDb) == SQLITE_OK {
            var stmt: OpaquePointer?
            let valid = sqlite3_prepare_v2(checkDb, "SELECT COUNT(*) FROM stardict", -1, &stmt, nil) == SQLITE_OK
                && sqlite3_step(stmt) == SQLITE_ROW
                && sqlite3_column_int(stmt, 0) > 0
            sqlite3_finalize(stmt)
            sqlite3_close(checkDb)

            if valid {
                print("ECDICT 数据库已存在于 Documents 且有效")
                return
            }
        } else if let db = checkDb {
            sqlite3_close(db)
        }

        // Documents 中的文件无效，删除后重新复制
        print("Documents 中的 ECDICT 数据库无效，重新复制")
        try? FileManager.default.removeItem(atPath: ecdictDbPath)
        do {
            try FileManager.default.copyItem(atPath: bundlePath, toPath: ecdictDbPath)
            print("ECDICT 数据库已重新复制到 Documents")
        } catch {
            print("重新复制 ECDICT 数据库失败: \(error)")
        }
    }

    /// 打开 ECDICT 数据库
    private func openECDICTDatabase() {
        guard FileManager.default.fileExists(atPath: ecdictDbPath) else {
            print("ECDICT 数据库文件不存在: \(ecdictDbPath)")
            return
        }

        if sqlite3_open(ecdictDbPath, &ecdictDb) == SQLITE_OK {
            print("ECDICT 数据库已打开，词条数: \(ecdictEntryCount)")
        } else {
            print("无法打开 ECDICT 数据库")
            if let db = ecdictDb {
                sqlite3_close(db)
                ecdictDb = nil
            }
        }
    }

    /// 打开自定义词条数据库
    private func openCustomDatabase() {
        if sqlite3_open(customDbPath, &customDb) == SQLITE_OK {
            sqlite3_exec(customDb, "PRAGMA foreign_keys = ON", nil, nil, nil)
            createCustomTablesIfNeeded()
        } else {
            print("无法打开自定义词条数据库")
        }
    }

    /// 创建自定义词条表
    private func createCustomTablesIfNeeded() {
        guard let database = customDb else { return }

        let createSQL = """
        CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            phonetic TEXT,
            frequency INTEGER DEFAULT 3,
            level TEXT,
            source TEXT DEFAULT 'custom',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            pos TEXT,
            definition TEXT NOT NULL,
            example TEXT,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_words_word ON words(word);
        CREATE INDEX IF NOT EXISTS idx_definitions_word_id ON definitions(word_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_words_word_source ON words(word, source);
        """

        if sqlite3_exec(database, createSQL, nil, nil, nil) != SQLITE_OK {
            print("创建自定义词条表失败: \(String(cString: sqlite3_errmsg(database)))")
        }
    }

    // MARK: - ECDICT 状态

    /// ECDICT 是否可用
    var isECDICTAvailable: Bool {
        return ecdictDb != nil
    }

    /// ECDICT 词条数量
    var ecdictEntryCount: Int {
        guard let database = ecdictDb else { return 0 }
        var statement: OpaquePointer?
        let query = "SELECT COUNT(*) FROM stardict"
        if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(statement, 0))
                sqlite3_finalize(statement)
                return count
            }
            sqlite3_finalize(statement)
        }
        return 0
    }

    /// 更新词条总数
    private func updateEntryCount() {
        entryCount = ecdictEntryCount
    }

    // MARK: - ECDICT 查询

    /// 从 ECDICT 查询单词（支持一词多义，按词性分组）
    private func queryECDICT(word: String) -> [DictionaryEntry] {
        guard let database = ecdictDb else { return [] }

        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWord.isEmpty else { return [] }

        var results: [DictionaryEntry] = []

        let querySQL = "SELECT word, phonetic, translation, pos, collins, oxford, tag, bnc, frq FROM stardict WHERE word = ?"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, querySQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (normalizedWord as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let word = String(cString: sqlite3_column_text(stmt, 0))
                let phonetic = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                let translation = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let pos = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let collins = Int(sqlite3_column_int(stmt, 4))
                let oxford = Int(sqlite3_column_int(stmt, 5))
                let tag = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

                guard let translationText = translation, !translationText.isEmpty else { continue }

                // translation 字段以 \n 分隔多个释义（存储为字面两个字符 '\' + 'n'，需先替换为真实换行）
                let normalizedTranslation = translationText.replacingOccurrences(of: "\\n", with: "\n")
                let definitions = normalizedTranslation.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for def in definitions {
                    // 从释义文本中提取词性前缀（如 "n. 苹果" → pos="noun", def="苹果"）
                    let (extractedPos, cleanDef) = extractPOSFromDefinition(def)
                    let finalPos = pos ?? extractedPos

                    results.append(DictionaryEntry(
                        word: word,
                        phoneticUS: phonetic,
                        phoneticUK: nil,
                        partOfSpeech: finalPos,
                        definition: cleanDef,
                        definitionSimple: cleanDef,
                        example: nil,
                        frequency: collins > 0 ? collins : nil,
                        level: tag
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }

        return results
    }

    /// 从释义文本中提取词性前缀，返回 (词性, 清理后的释义)
    private func extractPOSFromDefinition(_ def: String) -> (pos: String?, cleanDef: String) {
        let trimmed = def.trimmingCharacters(in: .whitespacesAndNewlines)

        // 处理 [计]、[医]、[网络]、[电] 等标签前缀
        if trimmed.hasPrefix("[") {
            if let closeBracket = trimmed.firstIndex(of: "]") {
                let tag = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                let rest = trimmed[trimmed.index(after: closeBracket)...].trimmingCharacters(in: .whitespacesAndNewlines)
                let pos: String
                switch tag {
                case "计": pos = "computer"
                case "医": pos = "medical"
                case "网络": pos = "slang"
                case "电": pos = "electronics"
                case "法律": pos = "legal"
                case "经": pos = "economics"
                case "化": pos = "chemistry"
                case "物": pos = "physics"
                case "数": pos = "math"
                case "生": pos = "biology"
                case "药": pos = "pharmacy"
                default: pos = tag
                }
                return (pos, rest.isEmpty ? trimmed : rest)
            }
        }

        // 处理 n.、vi.、vt.、a.、adv.、prep.、conj.、pron.、det.、int. 等词性前缀
        let posPatterns: [(prefix: String, pos: String)] = [
            ("adv.", "adverb"), ("adj.", "adjective"), ("prep.", "preposition"),
            ("conj.", "conjunction"), ("pron.", "pronoun"), ("det.", "determiner"),
            ("int.", "interjection"), ("vt.", "verb"), ("vi.", "verb"),
            ("v.", "verb"), ("n.", "noun"), ("a.", "adjective"),
        ]

        for pattern in posPatterns {
            if trimmed.hasPrefix(pattern.prefix) {
                let rest = trimmed.dropFirst(pattern.prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                return (pattern.pos, rest)
            }
        }

        return (nil, trimmed)
    }

    // MARK: - 统一查询接口

    /// 查询单词的所有释义（ECDICT + 自定义词条）
    func queryAllEntries(word: String) -> [DictionaryEntry] {
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [DictionaryEntry] = []

        // 查询 ECDICT
        results = queryECDICT(word: normalizedWord)

        // 查询自定义词条
        if let database = customDb {
            let querySQL = """
            SELECT w.word, w.phonetic, w.frequency, w.level, d.pos, d.definition, d.example
            FROM words w
            INNER JOIN definitions d ON d.word_id = w.id
            WHERE w.word = ?
            ORDER BY d.id ASC
            """

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(database, querySQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (normalizedWord as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let word = String(cString: sqlite3_column_text(stmt, 0))
                    let phonetic = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                    let frequency = Int(sqlite3_column_int(stmt, 2))
                    let level = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                    let pos = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let definition = String(cString: sqlite3_column_text(stmt, 5))
                    let example = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

                    results.append(DictionaryEntry(
                        word: word, phoneticUS: phonetic, phoneticUK: nil,
                        partOfSpeech: pos, definition: definition,
                        definitionSimple: definition, example: example,
                        frequency: frequency, level: level
                    ))
                }
                sqlite3_finalize(stmt)
            }
        }

        return results
    }

    /// 查询单词（兼容旧接口）
    func query(word: String) -> [(pos: String?, definition: String)] {
        let entries = queryAllEntries(word: word)
        return entries.map { (pos: $0.partOfSpeech, definition: $0.definition ?? "") }
    }

    /// 查询单词的单个释义
    func querySingle(word: String) -> (pos: String?, definition: String)? {
        let entries = queryAllEntries(word: word)
        guard let first = entries.first else { return nil }
        return (pos: first.partOfSpeech, definition: first.definition ?? "")
    }

    /// 查询词条详情
    func queryEntry(word: String) -> DictionaryEntry? {
        return queryAllEntries(word: word).first
    }

    /// 检查单词是否存在
    func hasWord(word: String) -> Bool {
        let normalizedWord = word.lowercased()

        // 检查 ECDICT
        if let database = ecdictDb {
            var statement: OpaquePointer?
            let querySQL = "SELECT 1 FROM stardict WHERE word = ? LIMIT 1"
            if sqlite3_prepare_v2(database, querySQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (normalizedWord as NSString).utf8String, -1, nil)
                let result = sqlite3_step(statement)
                sqlite3_finalize(statement)
                if result == SQLITE_ROW { return true }
            }
        }

        // 检查自定义词条
        if let database = customDb {
            var statement: OpaquePointer?
            let querySQL = "SELECT 1 FROM words WHERE word = ? LIMIT 1"
            if sqlite3_prepare_v2(database, querySQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (normalizedWord as NSString).utf8String, -1, nil)
                let result = sqlite3_step(statement)
                sqlite3_finalize(statement)
                return result == SQLITE_ROW
            }
        }

        return false
    }

    // MARK: - 自定义词条操作

    /// 添加自定义词条
    @discardableResult
    func addCustomEntry(word: String, phonetic: String?, pos: String?, definition: String, example: String?) -> Bool {
        guard let database = customDb else { return false }

        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWord.isEmpty else { return false }

        sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)

        // 插入 word
        var stmt: OpaquePointer?
        let insertSQL = "INSERT OR IGNORE INTO words (word, phonetic, source) VALUES (?, ?, 'custom')"
        if sqlite3_prepare_v2(database, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (normalizedWord as NSString).utf8String, -1, nil)
            if let phonetic = phonetic {
                sqlite3_bind_text(stmt, 2, (phonetic as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_text(stmt, 2, nil, -1, nil)
            }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }

        // 获取 word_id
        let selectSQL = "SELECT id FROM words WHERE word = ? AND source = 'custom' LIMIT 1"
        var wordId: Int64 = 0
        if sqlite3_prepare_v2(database, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (normalizedWord as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                wordId = sqlite3_column_int64(stmt, 0)
            }
            sqlite3_finalize(stmt)
        }

        // 插入 definition
        if wordId > 0 {
            let defSQL = "INSERT INTO definitions (word_id, pos, definition, example) VALUES (?, ?, ?, ?)"
            if sqlite3_prepare_v2(database, defSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, wordId)
                if let pos = pos {
                    sqlite3_bind_text(stmt, 2, (pos as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_text(stmt, 2, nil, -1, nil)
                }
                sqlite3_bind_text(stmt, 3, (definition as NSString).utf8String, -1, nil)
                if let example = example {
                    sqlite3_bind_text(stmt, 4, (example as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_text(stmt, 4, nil, -1, nil)
                }
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }

        sqlite3_exec(database, "COMMIT", nil, nil, nil)
        return wordId > 0
    }

    /// 更新自定义词条
    @discardableResult
    func updateCustomEntry(word: String, phonetic: String?, pos: String?, definition: String, example: String?) -> Bool {
        guard let database = customDb else { return false }

        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)

        var stmt: OpaquePointer?
        let findSQL = "SELECT id FROM words WHERE word = ? AND source = 'custom' LIMIT 1"
        var wordId: Int64 = 0

        if sqlite3_prepare_v2(database, findSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (normalizedWord as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                wordId = sqlite3_column_int64(stmt, 0)
            }
            sqlite3_finalize(stmt)
        }

        if wordId > 0 {
            sqlite3_exec(database, "DELETE FROM definitions WHERE word_id = \(wordId)", nil, nil, nil)
            if let phonetic = phonetic {
                let updateSQL = "UPDATE words SET phonetic = ? WHERE id = \(wordId)"
                if sqlite3_prepare_v2(database, updateSQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (phonetic as NSString).utf8String, -1, nil)
                    sqlite3_step(stmt)
                    sqlite3_finalize(stmt)
                }
            }
            let defSQL = "INSERT INTO definitions (word_id, pos, definition, example) VALUES (?, ?, ?, ?)"
            if sqlite3_prepare_v2(database, defSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, wordId)
                if let pos = pos {
                    sqlite3_bind_text(stmt, 2, (pos as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_text(stmt, 2, nil, -1, nil)
                }
                sqlite3_bind_text(stmt, 3, (definition as NSString).utf8String, -1, nil)
                if let example = example {
                    sqlite3_bind_text(stmt, 4, (example as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_text(stmt, 4, nil, -1, nil)
                }
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        } else {
            sqlite3_exec(database, "COMMIT", nil, nil, nil)
            return addCustomEntry(word: word, phonetic: phonetic, pos: pos, definition: definition, example: example)
        }

        sqlite3_exec(database, "COMMIT", nil, nil, nil)
        return true
    }

    /// 获取自定义词条数量
    func getCustomEntryCount() -> Int {
        guard let database = customDb else { return 0 }

        var statement: OpaquePointer?
        let query = "SELECT COUNT(*) FROM words"

        if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(statement, 0))
                sqlite3_finalize(statement)
                return count
            }
            sqlite3_finalize(statement)
        }

        return 0
    }

    /// 清除自定义词条
    func clearCustomEntries() {
        guard let database = customDb else { return }

        sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)
        sqlite3_exec(database, "DELETE FROM definitions", nil, nil, nil)
        sqlite3_exec(database, "DELETE FROM words", nil, nil, nil)
        sqlite3_exec(database, "COMMIT", nil, nil, nil)
    }

    /// 查询所有自定义词条
    func queryAllCustomEntries() -> [DictionaryEntry] {
        guard let database = customDb else { return [] }

        var results: [DictionaryEntry] = []

        let querySQL = """
        SELECT w.word, w.phonetic, w.frequency, w.level, d.pos, d.definition, d.example
        FROM words w
        INNER JOIN definitions d ON d.word_id = w.id
        ORDER BY w.word, d.id ASC
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(database, querySQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let word = String(cString: sqlite3_column_text(stmt, 0))
                let phonetic = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                let frequency = Int(sqlite3_column_int(stmt, 2))
                let level = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let pos = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let definition = String(cString: sqlite3_column_text(stmt, 5))
                let example = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

                results.append(DictionaryEntry(
                    word: word, phoneticUS: phonetic, phoneticUK: nil,
                    partOfSpeech: pos, definition: definition,
                    definitionSimple: definition, example: example,
                    frequency: frequency, level: level
                ))
            }
            sqlite3_finalize(stmt)
        }

        return results
    }

    /// 批量导入自定义词条
    func importCustomEntries(_ entries: [DictionaryEntry]) {
        guard let database = customDb else { return }

        sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)

        for entry in entries {
            addCustomEntry(
                word: entry.word, phonetic: entry.phoneticUS,
                pos: entry.partOfSpeech, definition: entry.definition ?? "",
                example: entry.example
            )
        }

        sqlite3_exec(database, "COMMIT", nil, nil, nil)
    }

    // MARK: - 兼容旧接口

    /// 批量导入词条（兼容旧接口，实际导入到自定义数据库）
    func importEntries(_ entries: [DictionaryEntry], source: String = "custom") {
        importCustomEntries(entries)
    }

    /// 查询所有指定 source 的词条
    func queryAll(source: String) -> [DictionaryEntry] {
        if source == "custom" {
            return queryAllCustomEntries()
        }
        return []
    }

    /// 重新初始化数据库
    func reinitializeDatabase() {
        closeDatabases()
        try? FileManager.default.removeItem(atPath: customDbPath)
        openCustomDatabase()
    }

    // MARK: - 关闭

    /// 关闭所有数据库
    func closeDatabases() {
        if let db = ecdictDb {
            sqlite3_close(db)
            ecdictDb = nil
        }
        if let db = customDb {
            sqlite3_close(db)
            customDb = nil
        }
    }

    /// 获取数据库信息
    func getDatabaseInfo() -> (path: String, totalEntries: Int, ecdictEntries: Int, customEntries: Int) {
        let ecdictCount = ecdictEntryCount
        let customCount = getCustomEntryCount()
        return (ecdictDbPath, ecdictCount + customCount, ecdictCount, customCount)
    }
}
