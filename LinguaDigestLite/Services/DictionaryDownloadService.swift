//
//  DictionaryDownloadService.swift
//  LinguaDigestLite
//
//  词典管理服务 - ECDICT 本地词库
//

import Foundation

/// 词典管理服务
class DictionaryDownloadService: ObservableObject {
    static let shared = DictionaryDownloadService()

    private init() {}

    /// ECDICT 是否已就绪
    var isECDICTDownloaded: Bool {
        return DictionaryDatabaseManager.shared.isECDICTAvailable
    }

    /// ECDICT 词条数量
    var ecdictEntryCount: Int {
        return DictionaryDatabaseManager.shared.ecdictEntryCount
    }

    /// 获取词典状态信息
    func getDictionaryStatus() -> DictionaryStatusInfo {
        let dbInfo = DictionaryDatabaseManager.shared.getDatabaseInfo()

        return DictionaryStatusInfo(
            isReady: DictionaryDatabaseManager.shared.isInitialized,
            entryCount: dbInfo.totalEntries,
            ecdictEntryCount: dbInfo.ecdictEntries,
            customEntryCount: dbInfo.customEntries,
            databasePath: dbInfo.path,
            isECDICTAvailable: DictionaryDatabaseManager.shared.isECDICTAvailable
        )
    }
}

/// 词典状态信息
struct DictionaryStatusInfo {
    let isReady: Bool
    let entryCount: Int
    let ecdictEntryCount: Int
    let customEntryCount: Int
    let databasePath: String
    let isECDICTAvailable: Bool
}
