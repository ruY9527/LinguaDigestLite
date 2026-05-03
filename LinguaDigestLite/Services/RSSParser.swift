//
//  RSSParser.swift
//  LinguaDigestLite
//
//  Extracted from FeedService.swift
//

import Foundation

/// 自定义RSS XML解析器
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
        let decodedText = HTMLEntityDecoder.decodeHTMLEntities(text)

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
                let sanitizedSummary = HTMLContentExtractor.sanitizeReadableArticleText(builder.summary) ?? HTMLContentExtractor.cleanHTMLContent(builder.summary ?? "")
                let sanitizedContent = HTMLContentExtractor.sanitizeReadableArticleText(builder.content)
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
            let cleanTitle = HTMLContentExtractor.cleanHTMLContent(text)
            if feed == nil {
                feed = Feed(title: cleanTitle, link: "", feedUrl: feedUrl, isBuiltIn: false)
            } else {
                if let existingFeed = feed {
                    var mutableFeed = existingFeed
                    mutableFeed.title = cleanTitle
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
            currentArticle?.title = HTMLContentExtractor.cleanHTMLContent(text)

        case "link":
            currentArticle?.link = text

        case "author", "dc:creator":
            currentArticle?.author = text

        case "description", "summary":
            currentArticle?.summary = text

        case "pubdate", "published", "dc:date", "updated":
            if currentArticle?.publishedAt == nil {
                currentArticle?.publishedAt = parseDate(text)
            }

        case "content":
            currentArticle?.content = text

        default:
            break
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        if let date = iso8601Formatter.date(from: trimmed) {
            return date
        }
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: trimmed) {
            return date
        }

        let dateFormats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss",
            "EEE, dd MMM yyyy HH:mm Z",
            "EEE, dd MMM yyyy HH:mm zzz",
            "dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXX",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss",
        ]

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        if let timestamp = Double(trimmed), timestamp > 946684800, timestamp < 4102444800 {
            return Date(timeIntervalSince1970: timestamp)
        }

        return nil
    }
}
