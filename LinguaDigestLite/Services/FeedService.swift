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

    /// 解析RSS源
    /// - Parameter feedUrl: RSS源URL
    /// - Returns: 解析后的文章列表
    func parseFeed(from feedUrl: String) async throws -> (Feed?, [Article]) {
        guard let url = URL(string: feedUrl) else {
            throw FeedError.invalidURL
        }

        let data = try await fetchData(from: url)

        // 使用自定义XML解析器
        let parser = RSSParser(data: data, feedUrl: feedUrl)
        let result = parser.parse()

        return (result.feed, result.articles)
    }

    /// 获取数据
    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; LinguaDigestLite/1.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw FeedError.httpError(httpResponse.statusCode)
        }

        return data
    }

    // MARK: - 全文提取

    /// 提取文章全文内容
    /// - Parameter url: 文章URL
    /// - Returns: 提取后的正文内容和HTML
    func fetchFullArticleContent(from url: String) async throws -> (content: String, htmlContent: String?) {
        guard let articleURL = URL(string: url) else {
            throw FeedError.invalidURL
        }

        let data = try await fetchData(from: articleURL)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw FeedError.invalidEncoding
        }

        // 使用更智能的正文提取
        let extracted = extractArticleContent(from: html, url: url)
        return (extracted.content, html)
    }

    /// 从HTML提取文章正文（改进版）
    private func extractArticleContent(from html: String, url: String) -> (content: String, htmlContent: String?) {
        let specialized = extractMainContent(from: html, url: url)
        let generic = extractGenericContent(from: html)
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
    
    /// 提取主要内容
    private func extractMainContent(from html: String, url: String) -> String {
        // 针对不同网站使用不同策略
        if url.contains("bbc.co.uk") || url.contains("bbc.com") {
            return extractBBCContent(from: html)
        } else if url.contains("guardian.com") {
            return extractGuardianContent(from: html)
        } else if url.contains("npr.org") {
            return extractNPRContent(from: html)
        } else if url.contains("technologyreview.com") {
            return extractMITTRContent(from: html)
        } else {
            // 通用提取方法
            return extractGenericContent(from: html)
        }
    }
    
    /// BBC内容提取
    private func extractBBCContent(from html: String) -> String {
        var content = html
        
        // BBC通常使用特定的article容器
        // 尝试提取 article 标签或特定的内容区域
        
        // 方法1: 提取article标签内容
        if let articleContent = extractTagContent(html: content, tagName: "article") {
            content = articleContent
        }
        
        // 方法2: BBC特定结构 - data-component="text-block"
        if content.contains("data-component=\"text-block\"") {
            let blocks = extractBBCDataBlocks(html: content)
            if !blocks.isEmpty {
                return blocks.joined(separator: "\n\n")
            }
        }
        
        // 方法3: 提取主要段落
        let paragraphs = extractParagraphs(html: content, minLength: 20)
        if !paragraphs.isEmpty {
            return paragraphs.joined(separator: "\n\n")
        }
        
        // 回退到通用方法
        return extractGenericContent(from: content)
    }
    
    /// 提取BBC data-component="text-block"内容
    private func extractBBCDataBlocks(html: String) -> [String] {
        var blocks: [String] = []
        
        // 方法1: 使用更简单的正则匹配 text-block div
        // BBC 的 text-block 结构通常是 <div data-component="text-block">...</div>
        let pattern = "<div[^>]*data-component=\"text-block\"[^>]*>(.*?)</div>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let blockContent = String(html[contentRange])
                    let text = cleanHTMLTags(blockContent)
                    if text.count > 20 {
                        blocks.append(text)
                    }
                }
            }
        }
        
        // 方法2: 如果没有找到足够的块，尝试匹配 BBC 的 paragraph 标签
        if blocks.count < 3 {
            let pPattern = "<p[^>]*>(.*?)</p>"
            if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let paragraphContent = String(html[contentRange])
                        let text = cleanHTMLTags(paragraphContent)
                        if text.count > 20 && !blocks.contains(text) {
                            blocks.append(text)
                        }
                    }
                }
            }
        }
        
        return blocks
    }
    
    /// Guardian内容提取
    private func extractGuardianContent(from html: String) -> String {
        var content = html
        
        // Guardian使用 article-body 或 content-field
        if let articleContent = extractByClass(html: content, className: "article-body") {
            content = articleContent
        } else if let articleContent = extractByClass(html: content, className: "content-field") {
            content = articleContent
        }
        
        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }
    
    /// NPR内容提取
    private func extractNPRContent(from html: String) -> String {
        var content = html
        
        // NPR通常在 story-body 或 transcript-text
        if let articleContent = extractByClass(html: content, className: "story-body") {
            content = articleContent
        } else if let articleContent = extractByClass(html: content, className: "transcript-text") {
            content = articleContent
        }
        
        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }
    
    /// MIT Technology Review内容提取
    private func extractMITTRContent(from html: String) -> String {
        var content = html
        
        if let articleContent = extractByClass(html: content, className: "article-content") {
            content = articleContent
        }
        
        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }
    
    /// 通用内容提取
    private func extractGenericContent(from html: String) -> String {
        var content = html
        
        // 移除不需要的部分
        let removePatterns = [
            "<script[^>]*>.*?</script>",
            "<style[^>]*>.*?</style>",
            "<nav[^>]*>.*?</nav>",
            "<header[^>]*>.*?</header>",
            "<footer[^>]*>.*?</footer>",
            "<aside[^>]*>.*?</aside>",
            "<form[^>]*>.*?</form>",
            "<!--.*?-->"
        ]
        
        for pattern in removePatterns {
            content = content.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // 尝试提取article标签
        if let articleContent = extractTagContent(html: content, tagName: "article") {
            content = articleContent
        }
        
        // 提取段落
        let paragraphs = extractParagraphs(html: content, minLength: 20)
        if !paragraphs.isEmpty {
            return paragraphs.joined(separator: "\n\n")
        }
        
        return ""
    }
    
    /// 提取特定标签内容
    private func extractTagContent(html: String, tagName: String) -> String? {
        let openTag = "<\(tagName)"
        let closeTag = "</\(tagName)>"
        
        guard let openRange = html.range(of: openTag, options: .caseInsensitive),
              let closeRange = html.range(of: closeTag, options: [.caseInsensitive, .backwards]) else {
            return nil
        }
        
        // 找到完整标签的开始
        let tagStart = html[openRange.lowerBound...].firstIndex(of: ">") ?? openRange.upperBound
        let start = html.index(after: tagStart)
        
        guard start < closeRange.lowerBound else { return nil }
        
        return String(html[start..<closeRange.lowerBound])
    }
    
    /// 提取特定class的内容
    private func extractByClass(html: String, className: String) -> String? {
        // 匹配 class="className" 或 class包含className
        let patterns = [
            "class=\"\(className)\"",
            "class='\(className)'",
            "class=\"[^\"]*\(className)[^\"]*\""
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    guard let matchRange = Range(match.range, in: html),
                          let tagStart = html[..<matchRange.lowerBound].lastIndex(of: "<"),
                          let tagClose = html[matchRange.lowerBound...].firstIndex(of: ">"),
                          let tagEnd = findTagEnd(html: html, from: tagStart) else {
                        continue
                    }
                    
                    let contentStart = html.index(after: tagClose)
                    guard contentStart < tagEnd else { continue }
                    return String(html[contentStart..<tagEnd])
                }
            }
        }
        
        return nil
    }
    
    /// 找到标签结束位置
    private func findTagEnd(html: String, from: String.Index) -> String.Index? {
        guard let tagClose = html[from...].firstIndex(of: ">") else { return nil }
        
        let tagDescriptor = html[html.index(after: from)..<tagClose]
        let tagName = tagDescriptor
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "/" })
            .first
            .map(String.init)?
            .lowercased()
        
        guard let tagName, !tagName.isEmpty else { return nil }
        
        let closeTag = "</\(tagName)>"
        if let closeRange = html[tagClose...].range(of: closeTag, options: .caseInsensitive) {
            return closeRange.lowerBound
        }
        
        return nil
    }
    
    /// 提取段落
    private func extractParagraphs(html: String, minLength: Int) -> [String] {
        var paragraphs: [String] = []
        
        // 方法1: 匹配 <p> 标签（改进版，正确处理嵌套标签）
        // 使用更简单但有效的正则，非贪婪匹配
        let pPattern = "<p[^>]*>(.*?)</p>"
        if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let paragraphHTML = String(html[contentRange])
                    let text = cleanHTMLTags(paragraphHTML)
                    
                    // 只保留足够长的段落（可能是正文）
                    if text.count >= minLength && isLikelyArticleParagraph(text) {
                        paragraphs.append(text)
                    }
                }
            }
        }
        
        // 方法2: 如果没有足够的段落，尝试匹配 <div> 标签（排除导航、侧边栏等）
        if paragraphs.count < 3 {
            let divPattern = "<div[^>]*(?:class=\"[^\"]*(?:content|article|body|text|story|post|entry)[^\"]*\"|id=\"[^\"]*(?:content|article|body|text|story|post|entry)[^\"]*\")[^>]*>(.*?)</div>"
            if let regex = try? NSRegularExpression(pattern: divPattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let divHTML = String(html[contentRange])
                        // 从 div 中再提取段落
                        let innerParagraphs = extractParagraphsFromContainer(html: divHTML, minLength: minLength)
                        paragraphs.append(contentsOf: innerParagraphs)
                    }
                }
            }
        }
        
        // 方法3: 如果还是没有足够的段落，尝试提取 article 标签内容
        if paragraphs.count < 3 {
            if let articleContent = extractTagContent(html: html, tagName: "article") {
                let innerParagraphs = extractParagraphsFromContainer(html: articleContent, minLength: minLength)
                paragraphs.append(contentsOf: innerParagraphs)
            }
        }
        
        // 方法4: 如果仍然没有内容，尝试匹配所有包含足够文本的 div
        if paragraphs.count < 2 {
            let allDivPattern = "<div[^>]*>(.*?)</div>"
            if let regex = try? NSRegularExpression(pattern: allDivPattern, options: [.caseInsensitive]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let divHTML = String(html[contentRange])
                        let text = cleanHTMLTags(divHTML)
                        // 只保留足够长的文本块（可能是正文段落）
                        if text.count >= 100 && !isNavigationOrSidebar(text) && isLikelyArticleParagraph(text) {
                            paragraphs.append(text)
                        }
                    }
                }
            }
        }
        
        // 去重并返回
        var uniqueParagraphs: [String] = []
        var seen: Set<String> = []
        for p in paragraphs {
            let normalized = p.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalized) && !normalized.isEmpty {
                seen.insert(normalized)
                uniqueParagraphs.append(p)
            }
        }
        return uniqueParagraphs
    }
    
    /// 从容器中提取段落（辅助方法）
    private func extractParagraphsFromContainer(html: String, minLength: Int) -> [String] {
        var paragraphs: [String] = []
        
        // 匹配 <p> 标签
        let pPattern = "<p[^>]*>(.*?)</p>"
        if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let paragraphHTML = String(html[contentRange])
                    let text = cleanHTMLTags(paragraphHTML)
                    if text.count >= minLength && isLikelyArticleParagraph(text) {
                        paragraphs.append(text)
                    }
                }
            }
        }
        
        return paragraphs
    }
    
    /// 判断是否是导航或侧边栏文本
    private func isNavigationOrSidebar(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let navigationKeywords = ["menu", "nav", "sidebar", "footer", "header", "breadcrumb", "login", "sign up", "subscribe", "follow us", "share", "copyright", "©"]
        
        for keyword in navigationKeywords {
            if lowercased.contains(keyword) && text.count < 200 {
                return true
            }
        }
        
        return false
    }

    private func isLikelyArticleParagraph(_ text: String) -> Bool {
        Self.isLikelyReadableParagraph(text)
    }

    private func looksLikeCodeSnippet(_ text: String) -> Bool {
        Self.looksLikeCodeSnippet(text)
    }

    private static func isLikelyReadableParagraph(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        guard !looksLikeCodeSnippet(trimmed) else { return false }
        guard !isBoilerplateLine(trimmed) else { return false }

        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        let punctuation = trimmed.filter { ".!?;,:".contains($0) }.count
        return words >= 6 && punctuation >= 1
    }

    private static func looksLikeCodeSnippet(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let codeMarkers = [
            "function(",
            "function ",
            "const ",
            "let ",
            "var ",
            "return ",
            "import ",
            "export ",
            "=>",
            "</script",
            "window.",
            "document.",
            "{\"",
            "\"@context\"",
            "font-family",
            "display:flex",
            ".css",
            ".js"
        ]

        if codeMarkers.contains(where: { lowercased.contains($0) }) {
            return true
        }

        let punctuationHeavy = text.filter { "{}[]<>=$".contains($0) }.count
        let wordCount = max(text.split(whereSeparator: \.isWhitespace).count, 1)
        return punctuationHeavy > max(6, wordCount / 2)
    }
    
    /// 清理HTML标签，保留文本和段落结构
    private func cleanHTMLTags(_ html: String) -> String {
        // 处理空内容
        guard !html.isEmpty else { return "" }

        var text = html

        // 第一步：先将块级元素结束标签替换为换行符（保留段落结构）
        let blockEndTags = ["</p>", "</div>", "</section>", "</article>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>"]
        for tag in blockEndTags {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        // 第二步：将换行标签替换为换行符
        let brTags = ["<br>", "<br/>", "<br />", "<br/>"]
        for tag in brTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // 第三步：移除所有剩余的HTML标签
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // 第四步：解码HTML实体
        text = Self.decodeHTMLEntities(text)

        // 第五步：清理多余空白，但保留段落分隔
        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        // 使用字符串方式处理多个换行（避免正则表达式问题）
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    /// 公开的静态方法：清理HTML内容（供 ReaderViewModel 使用）
    static func cleanHTMLContent(_ html: String) -> String {
        // 处理空内容
        guard !html.isEmpty else { return "" }

        var text = html

        // 第一步：先将块级元素结束标签替换为换行符
        let blockEndTags = ["</p>", "</div>", "</section>", "</article>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>"]
        for tag in blockEndTags {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        // 第二步：将换行标签替换为换行符
        let brTags = ["<br>", "<br/>", "<br />", "<br/>"]
        for tag in brTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // 第三步：移除所有剩余的HTML标签
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // 第四步：解码HTML实体
        text = decodeHTMLEntities(text)

        // 第五步：清理多余空白
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        // 使用字符串方式处理多个换行（避免正则表达式问题）
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty &&
                line.count > 1 &&
                !Self.isBoilerplateLine(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Self.normalizePlainText(text)
    }

    static func sanitizeReadableArticleText(_ text: String?) -> String? {
        guard let text else { return nil }

        let cleaned = cleanHTMLContent(text)
        guard !cleaned.isEmpty else { return nil }

        let paragraphs = cleaned
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isLikelyReadableParagraph($0) }

        let normalized = paragraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
    
    // MARK: - 静态HTML实体解码方法（供RSSParser使用）
    
    /// 解码HTML实体（完整版）
    static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        
        // 1. 先处理十六进制格式 &#xNNNN;
        result = decodeHexEntities(result)
        
        // 2. 再处理十进制格式 &#NNNN;
        result = decodeDecimalEntities(result)
        
        // 3. 处理常见命名实体
        let namedEntities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&bull;": "•",
            "&middot;": "·",
            "&para;": "¶",
            "&sect;": "§",
            "&deg;": "°",
            "&plusmn;": "±",
            "&times;": "×",
            "&divide;": "÷",
            "&frac12;": "½",
            "&frac14;": "¼",
            "&frac34;": "¾",
            "&euro;": "€",
            "&pound;": "£",
            "&yen;": "¥",
            "&cent;": "¢",
            "&dollar;": "$",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&sbquo;": "‚",
            "&bdquo;": "„",
            "&circ;": "ˆ",
            "&tilde;": "˜",
            "&acute;": "´",
            "&cedil;": "¸",
            "&uml;": "¨",
            "&laquo;": "«",
            "&raquo;": "»",
            "&iexcl;": "¡",
            "&iquest;": "¿",
            "&brvbar;": "¦",
            "&curren;": "¤",
            "&not;": "¬",
            "&ordf;": "ª",
            "&ordm;": "º",
            "&macr;": "¯",
            "&micro;": "µ",
            "&sup1;": "¹",
            "&sup2;": "²",
            "&sup3;": "³",
            "&agrave;": "à",
            "&aacute;": "á",
            "&acirc;": "â",
            "&atilde;": "ã",
            "&auml;": "ä",
            "&aring;": "å",
            "&aelig;": "æ",
            "&ccedil;": "ç",
            "&egrave;": "è",
            "&eacute;": "é",
            "&ecirc;": "ê",
            "&euml;": "ë",
            "&igrave;": "ì",
            "&iacute;": "í",
            "&icirc;": "î",
            "&iuml;": "ï",
            "&eth;": "ð",
            "&ntilde;": "ñ",
            "&ograve;": "ò",
            "&oacute;": "ó",
            "&ocirc;": "ô",
            "&otilde;": "õ",
            "&ouml;": "ö",
            "&oslash;": "ø",
            "&ugrave;": "ù",
            "&uacute;": "ú",
            "&ucirc;": "û",
            "&uuml;": "ü",
            "&yacute;": "ý",
            "&thorn;": "þ",
            "&yuml;": "ÿ",
            "&Agrave;": "À",
            "&Aacute;": "Á",
            "&Acirc;": "Â",
            "&Atilde;": "Ã",
            "&Auml;": "Ä",
            "&Aring;": "Å",
            "&AElig;": "Æ",
            "&Ccedil;": "Ç",
            "&Egrave;": "È",
            "&Eacute;": "É",
            "&Ecirc;": "Ê",
            "&Euml;": "Ë",
            "&Igrave;": "Ì",
            "&Iacute;": "Í",
            "&Icirc;": "Î",
            "&Iuml;": "Ï",
            "&ETH;": "Ð",
            "&Ntilde;": "Ñ",
            "&Ograve;": "Ò",
            "&Oacute;": "Ó",
            "&Ocirc;": "Ô",
            "&Otilde;": "Õ",
            "&Ouml;": "Ö",
            "&Oslash;": "Ø",
            "&Ugrave;": "Ù",
            "&Uacute;": "Ú",
            "&Ucirc;": "Û",
            "&Uuml;": "Ü",
            "&Yacute;": "Ý",
            "&THORN;": "Þ",
            "&szlig;": "ß",
            "&nbsp": " ",
            "&amp": "&",
            "&lt": "<",
            "&gt": ">",
            "&quot": "\"",
            "&apos": "'"
        ]
        
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        
        return result
    }

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
        Self.normalizePlainText(Self.cleanHTMLContent(text))
    }

    private static func normalizePlainText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let cleanedLines = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                !$0.contains("<") &&
                !$0.contains(">") &&
                !Self.isBoilerplateLine($0)
            }

        return cleanedLines.joined(separator: "\n\n")
    }

    private func extractMetaContent(from html: String, keys: [String]) -> String {
        for key in keys {
            let pattern = "<meta[^>]*\(key)[^>]*content=[\"']([^\"']+)[\"'][^>]*>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }

        return ""
    }

    private static func isBoilerplateLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let keywords = [
            "sign up",
            "subscribe",
            "follow us",
            "all rights reserved",
            "cookie",
            "privacy policy",
            "terms of use",
            "advertisement",
            "newsletter",
            "share this article"
        ]

        return keywords.contains { lowercased.contains($0) }
    }

    private func containsBoilerplate(text: String) -> Bool {
        text
            .components(separatedBy: "\n")
            .contains { Self.isBoilerplateLine($0) }
    }
    
    /// 解码十六进制HTML实体 &#xNNNN;
    private static func decodeHexEntities(_ text: String) -> String {
        var result = text
        
        // 匹配 &#xNNNN; 或 &#XNNNN;
        let pattern = "&#[xX]([0-9a-fA-F]+);"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches.reversed() {
                if let hexRange = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    let hexString = text[hexRange]
                    if let codePoint = UInt32(hexString, radix: 16),
                       let scalar = UnicodeScalar(codePoint) {
                        let character = Character(scalar)
                        result.replaceSubrange(fullRange, with: String(character))
                    }
                }
            }
        }
        
        return result
    }
    
    /// 解码十进制HTML实体 &#NNNN;
    private static func decodeDecimalEntities(_ text: String) -> String {
        var result = text
        
        // 匹配 &#NNNN; (注意：需要有&前缀)
        let pattern = "&([0-9]+);"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches.reversed() {
                if let numRange = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    let numString = text[numRange]
                    if let codePoint = UInt32(numString),
                       let scalar = UnicodeScalar(codePoint) {
                        let character = Character(scalar)
                        result.replaceSubrange(fullRange, with: String(character))
                    }
                }
            }
        }
        
        return result
    }
}

// MARK: - 自定义RSS XML解析器

class RSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let feedUrl: String

    private var currentElement: String = ""
    private var currentText: String = ""

    private var feed: Feed?
    private var articles: [Article] = []
    private var currentArticle: ArticleBuilder?

    private var parsingState: ParsingState = .start

    enum ParsingState {
        case start
        case feed
        case feedImage
        case item
        case itemEnclosure
        case itemContent
        case itemMedia
    }

    struct ArticleBuilder {
        var title: String?
        var link: String?
        var author: String?
        var summary: String?
        var content: String?
        var imageUrl: String?
        var publishedAt: Date?
    }

    init(data: Data, feedUrl: String) {
        self.data = data
        self.feedUrl = feedUrl
    }

    func parse() -> (feed: Feed?, articles: [Article]) {
        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            return (feed, articles)
        }
        return (nil, [])
    }

    // MARK: - XMLParserDelegate

    func parserDidStartDocument(_ parser: XMLParser) {
        parsingState = .start
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""

        switch currentElement {
        case "rss", "rdf:channel":
            parsingState = .feed

        case "channel":
            if parsingState == .start {
                parsingState = .feed
            }

        case "image":
            if parsingState == .feed {
                parsingState = .feedImage
            }

        case "item", "entry":
            parsingState = .item
            currentArticle = ArticleBuilder()

        case "enclosure":
            if parsingState == .item {
                if let url = attributeDict["url"], let type = attributeDict["type"], type.hasPrefix("image") {
                    currentArticle?.imageUrl = url
                }
            }

        case "content:encoded":
            parsingState = .itemContent

        case "media:content":
            if parsingState == .item, let url = attributeDict["url"] {
                currentArticle?.imageUrl = url
            }
            parsingState = .itemMedia

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 对文本进行HTML实体解码
        let decodedText = FeedService.decodeHTMLEntities(text)

        switch parsingState {
        case .feed:
            handleFeedElement(elementName.lowercased(), text: decodedText)

        case .feedImage:
            if elementName.lowercased() == "url" {
                if let existingFeed = feed {
                    var mutableFeed = existingFeed
                    mutableFeed.imageUrl = decodedText
                    feed = mutableFeed
                }
            }

        case .item:
            handleItemElement(elementName.lowercased(), text: decodedText)

        case .itemContent:
            if elementName.lowercased() == "content:encoded" || elementName.lowercased() == "content" {
                currentArticle?.content = decodedText
            }
            parsingState = .item

        case .itemMedia:
            parsingState = .item

        default:
            break
        }

        currentElement = ""
        currentText = ""

        // 状态恢复
        if elementName.lowercased() == "item" || elementName.lowercased() == "entry" {
            if let builder = currentArticle, let title = builder.title, let link = builder.link {
                let sanitizedSummary = FeedService.sanitizeReadableArticleText(builder.summary) ?? FeedService.cleanHTMLContent(builder.summary ?? "")
                let sanitizedContent = FeedService.sanitizeReadableArticleText(builder.content)
                let articleContent = sanitizedContent ?? sanitizedSummary

                let article = Article(
                    feedId: feed?.id,
                    title: title,
                    link: link,
                    author: builder.author,
                    summary: sanitizedSummary.isEmpty ? nil : sanitizedSummary,
                    content: articleContent,
                    imageUrl: builder.imageUrl,
                    publishedAt: builder.publishedAt
                )
                articles.append(article)
            }
            currentArticle = nil
            parsingState = .feed
        }

        if elementName.lowercased() == "channel" || elementName.lowercased() == "feed" {
            parsingState = .start
        }
    }

    private func handleFeedElement(_ element: String, text: String) {
        switch element {
        case "title":
            if feed == nil {
                feed = Feed(title: text, link: "", feedUrl: feedUrl, isBuiltIn: false)
            } else {
                if let existingFeed = feed {
                    var mutableFeed = existingFeed
                    mutableFeed.title = text
                    feed = mutableFeed
                }
            }

        case "link":
            if let existingFeed = feed {
                var mutableFeed = existingFeed
                mutableFeed.link = text
                feed = mutableFeed
            }

        case "description":
            if let existingFeed = feed {
                var mutableFeed = existingFeed
                mutableFeed.description = text
                feed = mutableFeed
            }

        default:
            break
        }
    }

    private func handleItemElement(_ element: String, text: String) {
        switch element {
        case "title":
            currentArticle?.title = text

        case "link":
            currentArticle?.link = text

        case "author", "dc:creator":
            currentArticle?.author = text

        case "description", "summary":
            currentArticle?.summary = text

        case "pubdate", "published", "dc:date":
            currentArticle?.publishedAt = parseDate(text)

        case "content":
            currentArticle?.content = text

        default:
            break
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        // 先尝试ISO8601格式
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // 再尝试其他格式
        let dateFormats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
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
