//
//  HTMLEntityDecoder.swift
//  LinguaDigestLite
//
//  Extracted from FeedService.swift
//

import Foundation

/// HTML实体解码器
enum HTMLEntityDecoder {

    /// 解码HTML实体（完整版）
    static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // 1. 先处理十六进制格式 &#xNNNN;
        result = decodeHexEntities(result)

        // 2. 再处理十进制格式 &#NNNN;
        result = decodeDecimalEntities(result)

        // 3. 处理常见命名实体
        let sortedEntities = namedEntities.sorted { $0.key.count > $1.key.count }
        for (entity, replacement) in sortedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        return result
    }

    /// 解码十六进制HTML实体 &#xNNNN;
    static func decodeHexEntities(_ text: String) -> String {
        var result = text

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
    static func decodeDecimalEntities(_ text: String) -> String {
        var result = text

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

    // MARK: - Named Entities

    static let namedEntities: [String: String] = [
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
}
