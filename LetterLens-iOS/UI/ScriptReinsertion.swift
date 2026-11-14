//
//  ScriptReinsertion.swift
//  LetterLens-iOS
//
//  Puts redaction tokens back on this iPhone and remembers which spans were restored.
//  Nothing here is sent.

import Foundation

enum ScriptReinsertion {
    struct Segment: Equatable {
        var text: String
        var isChip: Bool
    }

    /// `[NAME]`, `[REF_1]`, `[ADDRESS_2]`, and the other redactor kinds. Case-insensitive.
    static let tokenPattern = #"\[(NAME|ADDRESS|POSTCODE|PHONE|EMAIL|LINK|NI|SORTCODE|ACCOUNT|CARD|REF)(_\d+)?\]"#

    static func segments(in text: String, map: RedactionMap, reinsert: Bool) -> [Segment] {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern, options: [.caseInsensitive]) else {
            return text.isEmpty ? [] : [Segment(text: text, isChip: false)]
        }

        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        )
        var segments: [Segment] = []
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text), range.lowerBound >= cursor else { continue }
            if cursor < range.lowerBound {
                segments.append(Segment(text: String(text[cursor..<range.lowerBound]), isChip: false))
            }
            let token = String(text[range])
            let shown = reinsert ? (map.original(for: token) ?? token) : token
            if !shown.isEmpty {
                segments.append(Segment(text: shown, isChip: true))
            }
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            segments.append(Segment(text: String(text[cursor...]), isChip: false))
        }
        return segments
    }

    static func plain(in text: String, map: RedactionMap) -> String {
        segments(in: text, map: map, reinsert: true).map(\.text).joined()
    }

    /// VoiceOver for the redacted letter. Tokens are spoken as what was removed.
    static func spokenRedacted(_ text: String) -> String {
        segments(in: text, map: RedactionMap(), reinsert: false).map { segment in
            segment.isChip ? spoken(segment.text) : segment.text
        }.joined()
    }

    static func firstToken(in text: String, kind: String) -> String? {
        let wanted = kind.uppercased()
        return segments(in: text, map: RedactionMap(), reinsert: false).first { segment in
            segment.isChip && tokenKind(segment.text) == wanted
        }?.text
    }

    static func spoken(_ token: String) -> String {
        switch tokenKind(token) {
        case "NAME": "name removed"
        case "ADDRESS": "address removed"
        case "POSTCODE": "postcode removed"
        case "PHONE": "phone number removed"
        case "EMAIL": "email removed"
        case "LINK": "link removed"
        case "NI": "national insurance number removed"
        case "SORTCODE": "sort code removed"
        case "ACCOUNT": "account number removed"
        case "CARD": "card number removed"
        case "REF": "reference removed"
        default: "detail removed"
        }
    }

    static func tokenKind(_ token: String) -> String {
        let inner = token.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let head = inner.split(separator: "_").first.map(String.init) ?? inner
        return head.uppercased()
    }
}
