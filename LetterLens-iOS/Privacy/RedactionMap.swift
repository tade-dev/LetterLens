//
//  RedactionMap.swift
//  LetterLens-iOS
//

import Foundation

/// Local token → original text. Stays on the device so a cloud reply can be refilled.
struct RedactionMap: Equatable {
    struct Entry: Equatable {
        var token: String
        var original: String
        var kind: String
    }

    var entries: [Entry] = []

    var removedCount: Int { entries.count }

    func original(for token: String) -> String? {
        entries.first { $0.token.caseInsensitiveCompare(token) == .orderedSame }?.original
    }

    /// Puts the original text back. Token match is case-insensitive.
    /// Longer tokens are replaced first so `[NAME_10]` is not eaten by `[NAME_1]`.
    /// A slightly damaged token is restored too: `[amount_1)`, `S[AMOUNT_1]`, or `S[AMOUNT)`
    /// when that kind appears only once. The stray letter is part of the match, so
    /// `S[AMOUNT_1]` becomes the original text and not `S` plus the original.
    func reinsert(into text: String) -> String {
        var result = text
        let ordered = entries.sorted { $0.token.count > $1.token.count }
        let shapes = ordered.compactMap { entry -> (entry: Entry, shape: TokenShape)? in
            guard let shape = TokenShape.parse(entry.token) else { return nil }
            return (entry, shape)
        }
        // Damaged forms first, so a letter stuck to the bracket is consumed with the token.
        // Doing the exact form first would leave that letter behind.
        for item in shapes.sorted(by: { $0.shape.number > $1.shape.number }) {
            let pattern = Self.numberedPattern(kind: item.shape.kind, number: item.shape.number)
            result = Self.replacePattern(pattern, with: item.entry.original, in: result)
        }
        for entry in ordered {
            result = Self.replaceLiteral(entry.token, with: entry.original, in: result)
        }

        let grouped = Dictionary(grouping: shapes, by: { $0.shape.kind.uppercased() })
        for (kind, group) in grouped where group.count == 1 {
            guard let entry = group.first?.entry else { continue }
            let pattern = Self.kindOnlyPattern(kind: kind)
            result = Self.replacePattern(pattern, with: entry.original, in: result)
        }
        return result
    }

    /// A bracketed token, or a broken piece of one, is still visible.
    static func containsTokenFragment(_ text: String) -> Bool {
        let patterns = [
            #"(?i)(?<![A-Za-z0-9])[A-Za-z]?[\[\(][A-Za-z][A-Za-z0-9]*(?:_\d+)?[\]\)]?"#,
            #"(?i)(?<![A-Za-z0-9])[A-Za-z][A-Za-z0-9]*_\d+[\]\)]"#,
        ]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        }
    }

    private static func replaceLiteral(_ token: String, with original: String, in text: String) -> String {
        let pattern = NSRegularExpression.escapedPattern(for: token)
        return replacePattern(pattern, with: original, in: text, options: [.caseInsensitive])
    }

    private static func numberedPattern(kind: String, number: Int) -> String {
        let kindPattern = NSRegularExpression.escapedPattern(for: kind)
        return "(?i)(?<![A-Za-z0-9])[A-Za-z]?[\\[\\(]\(kindPattern)_\(number)(?!\\d)[\\]\\)]?"
    }

    private static func kindOnlyPattern(kind: String) -> String {
        let kindPattern = NSRegularExpression.escapedPattern(for: kind)
        return "(?i)(?<![A-Za-z0-9])[A-Za-z]?[\\[\\(]\(kindPattern)(?!_\\d)[\\]\\)]?"
    }

    private static func replacePattern(
        _ pattern: String,
        with original: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }
        var rebuilt = ""
        var cursor = 0
        for match in matches where match.range.location >= cursor {
            let range = match.range
            if range.location > cursor {
                rebuilt += nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))
            }
            // Copy the stored original. A replacement template can rewrite `$` and `\`.
            rebuilt += original
            cursor = range.location + range.length
        }
        if cursor < nsText.length {
            rebuilt += nsText.substring(from: cursor)
        }
        return rebuilt
    }
}

private struct TokenShape: Equatable {
    var kind: String
    var number: Int

    static func parse(_ token: String) -> TokenShape? {
        guard let regex = try? NSRegularExpression(pattern: #"^\[([A-Za-z][A-Za-z0-9]*)_(\d+)\]$"#),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)),
              match.numberOfRanges == 3,
              let kindRange = Range(match.range(at: 1), in: token),
              let numberRange = Range(match.range(at: 2), in: token),
              let number = Int(token[numberRange])
        else { return nil }
        return TokenShape(kind: String(token[kindRange]), number: number)
    }
}

/// Restores redaction tokens on the device, then drops a field that still shows one.
enum CardFieldRestore {
    static func text(_ value: String?, map: RedactionMap?) -> String? {
        guard let value else { return nil }
        let restored = map?.reinsert(into: value) ?? value
        if RedactionMap.containsTokenFragment(restored) {
            return nil
        }
        return restored
    }

    static func apply(_ card: LetterCard, map: RedactionMap?) -> LetterCard {
        var card = card
        card.action = text(card.action, map: map) ?? ""
        card.deadline = text(card.deadline, map: map)
        card.deadlineQuote = text(card.deadlineQuote, map: map)
        card.amountQuote = text(card.amountQuote, map: map)
        card.watchOuts = card.watchOuts.compactMap { text($0, map: map) }.filter { !$0.isEmpty }
        card.scamSigns = card.scamSigns.compactMap { sign in
            guard let signText = text(sign.sign, map: map), !signText.isEmpty else { return nil }
            var sign = sign
            sign.sign = signText
            sign.quote = text(sign.quote, map: map)
            return sign
        }
        return card
    }
}

struct RedactionResult: Equatable {
    var text: String
    var map: RedactionMap

    var removedCount: Int { map.removedCount }
}
