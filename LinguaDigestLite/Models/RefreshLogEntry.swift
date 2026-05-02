import Foundation

struct RefreshLogEntry: Identifiable, Codable {
    var id: UUID
    var feedId: UUID
    var feedTitle: String
    var isSuccess: Bool
    var errorMessage: String?
    var statusCode: Int?
    var addedCount: Int
    var timestamp: Date

    init(
        id: UUID = UUID(),
        feedId: UUID,
        feedTitle: String,
        isSuccess: Bool,
        errorMessage: String? = nil,
        statusCode: Int? = nil,
        addedCount: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.feedId = feedId
        self.feedTitle = feedTitle
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.statusCode = statusCode
        self.addedCount = addedCount
        self.timestamp = timestamp
    }

    /// 简洁的错误描述，适合在列表中展示
    var errorDetail: String {
        if let code = statusCode {
            switch code {
            case 404: return L("httpError.404")
            case 504: return L("httpError.504")
            case 503: return L("httpError.503")
            case 502: return L("httpError.502")
            case 403: return L("httpError.403")
            case 401: return L("httpError.401")
            default:  return String(format: L("httpError.default"), code)
            }
        }
        if let msg = errorMessage {
            if msg.contains("timed out") || msg.contains("超时") {
                return L("error.timeout")
            }
            if msg.contains("Could not connect") || msg.contains("无法连接") {
                return L("error.connectionFailed")
            }
            return msg
        }
        return L("error.unknown")
    }
}
