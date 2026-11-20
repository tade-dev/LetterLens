//
//  DeadlineQuote.swift
//  LetterLens-iOS
//

import Foundation

/// Decides whether a deadline quote is only an effective date.
enum DeadlineQuote {
    /// Phrases that name when a change takes effect, not when the reader must act.
    private static let effectPhrases = [
        "take effect",
        "takes effect",
        "taking effect",
        "effective from",
        "effective on",
    ]

    /// Cues that the same quote also asks the reader to do something.
    private static let actionCues = [
        "no later than",
        "let us know",
        "tell us",
        "opt out",
        "pay",
        "reply",
        "respond",
        "contact",
        "call",
        "cancel",
        "switch",
        "apply",
        "appeal",
        "send",
        "return",
        "before",
        "by",
    ]

    /// True when the quote is an effective date and does not also ask the reader to act.
    static func isEffectiveDateWithoutAction(_ quote: String) -> Bool {
        guard effectPhrases.contains(where: { quote.range(of: $0, options: [.caseInsensitive]) != nil }) else {
            return false
        }
        return !containsActionCue(in: quote)
    }

    /// True when `quote` contains an action cue as a whole word or phrase.
    /// "by" matches "Pay by 3 March" and does not match "nearby" or "byte".
    static func containsActionCue(in quote: String) -> Bool {
        actionCues.contains { matchesTerm($0, in: quote) }
    }

    /// Word-boundary match. Multi-word cues such as "no later than" stay one phrase.
    private static func matchesTerm(_ term: String, in text: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
