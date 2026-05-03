//
//  HTMLContentExtractor.swift
//  LinguaDigestLite
//
//  Extracted from FeedService.swift
//

import Foundation

/// HTML内容提取器 - 从HTML中提取文章正文
enum HTMLContentExtractor {

    // MARK: - 主入口

    /// 提取主要内容（根据URL选择策略）
    static func extractMainContent(from html: String, url: String) -> String {
        if url.contains("bbc.co.uk") || url.contains("bbc.com") {
            return extractBBCContent(from: html)
        } else if url.contains("guardian.com") {
            return extractGuardianContent(from: html)
        } else if url.contains("npr.org") {
            return extractNPRContent(from: html)
        } else if url.contains("technologyreview.com") {
            return extractMITTRContent(from: html)
        } else {
            return extractGenericContent(from: html)
        }
    }

    // MARK: - BBC

    static func extractBBCContent(from html: String) -> String {
        var content = html

        if let articleContent = extractTagContent(html: content, tagName: "article") {
            content = articleContent
        }

        if content.contains("data-component=\"text-block\"") {
            let blocks = extractBBCDataBlocks(html: content)
            if !blocks.isEmpty {
                return blocks.joined(separator: "\n\n")
            }
        }

        let paragraphs = extractParagraphs(html: content, minLength: 20)
        if !paragraphs.isEmpty {
            return paragraphs.joined(separator: "\n\n")
        }

        return extractGenericContent(from: content)
    }

    static func extractBBCDataBlocks(html: String) -> [String] {
        var blocks: [String] = []

        let pattern = "<div[^>]*data-component=\"text-block\"[^>]*>(.*?)</div>"

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
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

        if blocks.count < 3 {
            let pPattern = "<p[^>]*>(.*?)</p>"
            if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
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

    // MARK: - Guardian

    static func extractGuardianContent(from html: String) -> String {
        var content = html

        if let articleContent = extractByClass(html: content, className: "article-body") {
            content = articleContent
        } else if let articleContent = extractByClass(html: content, className: "content-field") {
            content = articleContent
        }

        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - NPR

    static func extractNPRContent(from html: String) -> String {
        var content = html

        if let articleContent = extractByClass(html: content, className: "story-body") {
            content = articleContent
        } else if let articleContent = extractByClass(html: content, className: "transcript-text") {
            content = articleContent
        }

        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - MIT Technology Review

    static func extractMITTRContent(from html: String) -> String {
        var content = html

        if let articleContent = extractByClass(html: content, className: "article-content") {
            content = articleContent
        }

        let paragraphs = extractParagraphs(html: content, minLength: 20)
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - Generic

    static func extractGenericContent(from html: String) -> String {
        var content = html

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

        if let articleContent = extractTagContent(html: content, tagName: "article") {
            content = articleContent
        }

        let paragraphs = extractParagraphs(html: content, minLength: 20)
        if !paragraphs.isEmpty {
            return paragraphs.joined(separator: "\n\n")
        }

        return ""
    }

    // MARK: - Tag & Class Extraction

    static func extractTagContent(html: String, tagName: String) -> String? {
        let openTag = "<\(tagName)"
        let closeTag = "</\(tagName)>"

        guard let openRange = html.range(of: openTag, options: .caseInsensitive),
              let closeRange = html.range(of: closeTag, options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        let tagStart = html[openRange.lowerBound...].firstIndex(of: ">") ?? openRange.upperBound
        let start = html.index(after: tagStart)

        guard start < closeRange.lowerBound else { return nil }

        return String(html[start..<closeRange.lowerBound])
    }

    static func extractByClass(html: String, className: String) -> String? {
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

    static func findTagEnd(html: String, from: String.Index) -> String.Index? {
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

    // MARK: - Paragraph Extraction

    static func extractParagraphs(html: String, minLength: Int) -> [String] {
        var paragraphs: [String] = []

        let pPattern = "<p[^>]*>(.*?)</p>"
        if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let paragraphHTML = String(html[contentRange])
                    let text = cleanHTMLTags(paragraphHTML)

                    if text.count >= minLength && isLikelyReadableParagraph(text) {
                        paragraphs.append(text)
                    }
                }
            }
        }

        if paragraphs.count < 3 {
            let divPattern = "<div[^>]*(?:class=\"[^\"]*(?:content|article|body|text|story|post|entry)[^\"]*\"|id=\"[^\"]*(?:content|article|body|text|story|post|entry)[^\"]*\")[^>]*>(.*?)</div>"
            if let regex = try? NSRegularExpression(pattern: divPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)

                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let divHTML = String(html[contentRange])
                        let innerParagraphs = extractParagraphsFromContainer(html: divHTML, minLength: minLength)
                        paragraphs.append(contentsOf: innerParagraphs)
                    }
                }
            }
        }

        if paragraphs.count < 3 {
            if let articleContent = extractTagContent(html: html, tagName: "article") {
                let innerParagraphs = extractParagraphsFromContainer(html: articleContent, minLength: minLength)
                paragraphs.append(contentsOf: innerParagraphs)
            }
        }

        if paragraphs.count < 2 {
            let allDivPattern = "<div[^>]*>(.*?)</div>"
            if let regex = try? NSRegularExpression(pattern: allDivPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)

                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let divHTML = String(html[contentRange])
                        let text = cleanHTMLTags(divHTML)
                        if text.count >= 100 && !isNavigationOrSidebar(text) && isLikelyReadableParagraph(text) {
                            paragraphs.append(text)
                        }
                    }
                }
            }
        }

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

    static func extractParagraphsFromContainer(html: String, minLength: Int) -> [String] {
        var paragraphs: [String] = []

        let pPattern = "<p[^>]*>(.*?)</p>"
        if let regex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let paragraphHTML = String(html[contentRange])
                    let text = cleanHTMLTags(paragraphHTML)
                    if text.count >= minLength && isLikelyReadableParagraph(text) {
                        paragraphs.append(text)
                    }
                }
            }
        }

        return paragraphs
    }

    // MARK: - Text Analysis

    static func isNavigationOrSidebar(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let navigationKeywords = ["menu", "nav", "sidebar", "footer", "header", "breadcrumb", "login", "sign up", "subscribe", "follow us", "share", "copyright", "©"]

        for keyword in navigationKeywords {
            if lowercased.contains(keyword) && text.count < 200 {
                return true
            }
        }

        return false
    }

    static func isLikelyReadableParagraph(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        guard !looksLikeCodeSnippet(trimmed) else { return false }
        guard !isBoilerplateLine(trimmed) else { return false }

        let words = trimmed.split(whereSeparator: \.isWhitespace).count
        let punctuation = trimmed.filter { ".!?;,:".contains($0) }.count
        return words >= 6 && punctuation >= 1
    }

    static func looksLikeCodeSnippet(_ text: String) -> Bool {
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

    static func isBoilerplateLine(_ line: String) -> Bool {
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

    // MARK: - HTML Cleaning

    /// 清理HTML标签，保留文本和段落结构
    static func cleanHTMLTags(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        var text = html

        let blockEndTags = ["</p>", "</div>", "</section>", "</article>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>"]
        for tag in blockEndTags {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.caseInsensitive, .regularExpression])

        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        text = HTMLEntityDecoder.decodeHTMLEntities(text)

        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    /// 清理HTML内容（供 ReaderViewModel 使用）
    static func cleanHTMLContent(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        var text = html

        let blockEndTags = ["</p>", "</div>", "</section>", "</article>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>"]
        for tag in blockEndTags {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.caseInsensitive, .regularExpression])

        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        text = HTMLEntityDecoder.decodeHTMLEntities(text)

        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty &&
                line.count > 1 &&
                !isBoilerplateLine(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizePlainText(text)
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

    static func normalizePlainText(_ text: String) -> String {
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
                !isBoilerplateLine($0)
            }

        return cleanedLines.joined(separator: "\n\n")
    }
}
