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
    func reinsert(into text: String) -> String {
        var result = text
        let ordered = entries.sorted { $0.token.count > $1.token.count }
        for entry in ordered {
            let pattern = NSRegularExpression.escapedPattern(for: entry.token)
            let template = NSRegularExpression.escapedTemplate(for: entry.original)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: template
            )
        }
        return result
    }
}

struct RedactionResult: Equatable {
    var text: String
    var map: RedactionMap

    var removedCount: Int { map.removedCount }
}
