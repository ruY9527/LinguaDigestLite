//
//  FeedService.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// RSS解析服务（简化版，使用XMLParser）
class FeedService {
    static let shared = FeedService()

    private let session: URLSession
    private let timeout: TimeInterval = 30

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - RSS 解析

    /// 解析RSS源（支持条件请求）
    func parseFeed(from feedUrl: String, etag: String? = nil, lastModified: String? = nil) async throws -> FeedFetchResult {
        guard let url = URL(string: feedUrl) else {
            throw FeedError.invalidURL
        }

        let fetchResult = try await fetchData(from: url, etag: etag, lastModified: lastModified)

        if fetchResult.notModified {
            return FeedFetchResult(feed: nil, articles: [], etag: nil, lastModified: nil, notModified: true)
        }

        let parser = RSSParser(data: fetchResult.data, feedUrl: feedUrl)
        let result = parser.parse()

        return FeedFetchResult(
            feed: result.feed,
            articles: result.articles,
            etag: fetchResult.responseEtag,
            lastModified: fetchResult.responseLastModified,
            notModified: false
        )
    }

    /// 获取数据（支持条件请求）
    private func fetchData(from url: URL, etag: String? = nil, lastModified: String? = nil) async throws -> (data: Data, responseEtag: String?, responseLastModified: String?, notModified: Bool) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; LinguaDigestLite/1.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")

        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }

        if httpResponse.statusCode == 304 {
            return (Data(), nil, nil, true)
        }

        guard httpResponse.statusCode == 200 else {
            throw FeedError.httpError(httpResponse.statusCode)
        }

        let responseEtag = httpResponse.value(forHTTPHeaderField: "ETag")
        let responseLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")

        return (data, responseEtag, responseLastModified, false)
    }

    // MARK: - 全文提取

    /// 提取文章全文内容
    func fetchFullArticleContent(from url: String) async throws -> (content: String, htmlContent: String?) {
        guard let articleURL = URL(string: url) else {
            throw FeedError.invalidURL
        }

        let fetchResult = try await fetchData(from: articleURL)
        let data = fetchResult.data
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw FeedError.invalidEncoding
        }

        let extracted = extractArticleContent(from: html, url: url)
        return (extracted.content, html)
    }

    /// 从HTML提取文章正文
    private func extractArticleContent(from html: String, url: String) -> (content: String, htmlContent: String?) {
        let specialized = HTMLContentExtractor.extractMainContent(from: html, url: url)
        let generic = HTMLContentExtractor.extractGenericContent(from: html)
        let metaDescription = extractMetaContent(
            from: html,
            keys: [
                "property=\"og:description\"",
                "name=\"description\"",
                "name=\"twitter:description\""
            ]
        )

        let candidates = [specialized, generic, metaDescription]
            .map { normalizeArticleText($0) }
            .filter { !$0.isEmpty }

        let bestContent = chooseBestContent(from: candidates)
        return (bestContent, nil)
    }

    // MARK: - Content Scoring

    private func chooseBestContent(from candidates: [String]) -> String {
        let best = candidates.max { scoreContentCandidate($0) < scoreContentCandidate($1) }
        return best ?? ""
    }

    private func scoreContentCandidate(_ candidate: String) -> Int {
        let paragraphs = candidate.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let words = candidate.split(whereSeparator: \.isWhitespace).count
        let punctuationCount = candidate.filter { ".!?;:".contains($0) }.count
        let boilerplatePenalty = containsBoilerplate(text: candidate) ? 180 : 0
        let shortPenalty = words < 120 ? 120 : 0
        let denseBonus = min(words, 1800) + paragraphs.count * 45 + punctuationCount

        return denseBonus - boilerplatePenalty - shortPenalty
    }

    private func normalizeArticleText(_ text: String) -> String {
        HTMLContentExtractor.normalizePlainText(HTMLContentExtractor.cleanHTMLContent(text))
    }

    private func extractMetaContent(from html: String, keys: [String]) -> String {
        for key in keys {
            let pattern1 = "<meta[^>]*\(key)[^>]*content=[\"']([^\"']+)[\"'][^>]*>"
            if let regex = try? NSRegularExpression(pattern: pattern1, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
            let pattern2 = "<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*\(key)[^>]*>"
            if let regex = try? NSRegularExpression(pattern: pattern2, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }

        return ""
    }

    private func containsBoilerplate(text: String) -> Bool {
        text
            .components(separatedBy: "\n")
            .contains { HTMLContentExtractor.isBoilerplateLine($0) }
    }

    // MARK: - 静态方法（向后兼容，委托到新类）

    /// 解码HTML实体
    static func decodeHTMLEntities(_ text: String) -> String {
        HTMLEntityDecoder.decodeHTMLEntities(text)
    }

    /// 清理HTML内容
    static func cleanHTMLContent(_ html: String) -> String {
        HTMLContentExtractor.cleanHTMLContent(html)
    }

    /// 清理可读文章文本
    static func sanitizeReadableArticleText(_ text: String?) -> String? {
        HTMLContentExtractor.sanitizeReadableArticleText(text)
    }
}

// MARK: - Feed Fetch Result

/// Result of a feed fetch operation, supporting conditional GET
struct FeedFetchResult {
    let feed: Feed?
    let articles: [Article]
    let etag: String?
    let lastModified: String?
    let notModified: Bool
}

// MARK: - 错误类型

enum FeedError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case parseError(String)
    case invalidEncoding
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .invalidEncoding:
            return "编码错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
