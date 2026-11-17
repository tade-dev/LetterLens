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
        let lowered = quote.lowercased()
        guard effectPhrases.contains(where: { lowered.contains($0) }) else { return false }
        return !actionCues.contains(where: { lowered.contains($0) })
    }
}
