import Foundation
import SQLite3

/// Lightweight SQLite3 wrapper using the C API
class SQLiteHelper {
    private var db: OpaquePointer?
    private let path: String

    init(path: String) throws {
        self.path = path
        let result = sqlite3_open(path, &db)
        guard result == SQLITE_OK else {
            let errMsg: String
            if let db, let cStr = sqlite3_errmsg(db) {
                errMsg = String(cString: cStr)
            } else {
                errMsg = "Unknown error"
            }
            sqlite3_close(db)
            db = nil
            throw SQLiteError.openFailed(errMsg)
        }
        // Enable WAL mode for better concurrent read performance
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Execute

    @discardableResult
    func execute(_ sql: String) throws -> Bool {
        guard let db else { throw SQLiteError.databaseNotOpen }
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let message: String
            if let errMsg {
                message = String(cString: errMsg)
            } else {
                message = "Unknown error"
            }
            sqlite3_free(errMsg)
            throw SQLiteError.executionFailed(message)
        }
        return true
    }

    @discardableResult
    func execute(_ sql: String, params: [Any]) throws -> Bool {
        guard let db else { throw SQLiteError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError)
        }

        try bindParams(params, to: stmt)

        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteError.executionFailed(lastError)
        }
        return true
    }

    // MARK: - Query

    func query(_ sql: String) throws -> [[String: Any]] {
        guard let db else { throw SQLiteError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError)
        }

        return try readRows(stmt)
    }

    func query(_ sql: String, params: [Any]) throws -> [[String: Any]] {
        guard let db else { throw SQLiteError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError)
        }

        try bindParams(params, to: stmt)
        return try readRows(stmt)
    }

    // MARK: - Convenience

    var lastInsertRowId: Int64 {
        guard let db else { return 0 }
        return sqlite3_last_insert_rowid(db)
    }

    var changes: Int {
        guard let db else { return 0 }
        return Int(sqlite3_changes(db))
    }

    // MARK: - Private

    private var lastError: String {
        guard let db, let cStr = sqlite3_errmsg(db) else { return "Database not open" }
        return String(cString: cStr)
    }

    private func bindParams(_ params: [Any], to stmt: OpaquePointer?) throws {
        for (index, param) in params.enumerated() {
            let i = Int32(index + 1)
            let result: Int32
            switch param {
            case let val as String:
                result = sqlite3_bind_text(stmt, i, val, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let val as Int:
                result = sqlite3_bind_int64(stmt, i, Int64(val))
            case let val as Int64:
                result = sqlite3_bind_int64(stmt, i, val)
            case let val as Double:
                result = sqlite3_bind_double(stmt, i, val)
            case let val as Bool:
                result = sqlite3_bind_int(stmt, i, val ? 1 : 0)
            case is NSNull:
                result = sqlite3_bind_null(stmt, i)
            case let val as Data:
                result = val.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(stmt, i, ptr.baseAddress, Int32(val.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            default:
                result = sqlite3_bind_text(stmt, i, "\(param)", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            guard result == SQLITE_OK else {
                throw SQLiteError.bindingFailed("Failed to bind param at index \(index): \(lastError)")
            }
        }
    }

    private func readRows(_ stmt: OpaquePointer?) throws -> [[String: Any]] {
        var rows: [[String: Any]] = []
        let columnCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(stmt, i))
                let type = sqlite3_column_type(stmt, i)
                switch type {
                case SQLITE_INTEGER:
                    row[columnName] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    if let cString = sqlite3_column_text(stmt, i) {
                        row[columnName] = String(cString: cString)
                    }
                case SQLITE_BLOB:
                    if let blob = sqlite3_column_blob(stmt, i) {
                        let size = sqlite3_column_bytes(stmt, i)
                        row[columnName] = Data(bytes: blob, count: Int(size))
                    }
                case SQLITE_NULL:
                    row[columnName] = NSNull()
                default:
                    break
                }
            }
            rows.append(row)
        }
        return rows
    }
}

// MARK: - Error Types

enum SQLiteError: LocalizedError {
    case openFailed(String)
    case databaseNotOpen
    case prepareFailed(String)
    case executionFailed(String)
    case bindingFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open database: \(msg)"
        case .databaseNotOpen: return "Database is not open"
        case .prepareFailed(let msg): return "Failed to prepare statement: \(msg)"
        case .executionFailed(let msg): return "Failed to execute statement: \(msg)"
        case .bindingFailed(let msg): return "Failed to bind parameters: \(msg)"
        }
    }
}
