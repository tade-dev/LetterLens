//
//  CardValidator.swift
//  LetterLens-iOS
//

import Foundation

/// Drops anything whose quote is not in the OCR text, and replaces the model's
/// deadline with the date parsed from `deadline_quote`.
enum CardValidator {
    static func validate(_ card: LetterCard, ocrText: String) -> LetterCard {
        var card = card
        card.type = SafetyCopy.cleaned(card.type)
        card.action = SafetyCopy.cleaned(card.action)
        card.watchOuts = card.watchOuts.map(SafetyCopy.cleaned).filter { !$0.isEmpty }
        card.senderKind = canonicalSender(card.senderKind)
        applyDeadline(&card, ocrText: ocrText)
        applyAmount(&card, ocrText: ocrText)
        card.scamSigns = card.scamSigns.compactMap { keptSign($0, ocrText: ocrText) }
        return card
    }

    static func merge(_ cards: [LetterCard]) -> LetterCard {
        guard var merged = cards.first else { return .empty }
        if cards.count == 1 { return merged }

        for card in cards.dropFirst() {
            if merged.type.isEmpty { merged.type = card.type }
            if merged.senderKind == "other", card.senderKind != "other" {
                merged.senderKind = card.senderKind
            }
            if merged.action.isEmpty { merged.action = card.action }
            if merged.deadline == nil, card.deadline != nil {
                merged.deadline = card.deadline
                merged.deadlineQuote = card.deadlineQuote
            }
            if merged.amountQuote == nil {
                merged.amountQuote = card.amountQuote
            }
            for watchOut in card.watchOuts where !merged.watchOuts.contains(watchOut) {
                merged.watchOuts.append(watchOut)
            }
            for sign in card.scamSigns
            where !merged.scamSigns.contains(where: { $0.sign == sign.sign && $0.quote == sign.quote }) {
                merged.scamSigns.append(sign)
            }
            if !card.noActionNeeded {
                merged.noActionNeeded = false
            }
        }
        return merged
    }

    private static func applyDeadline(_ card: inout LetterCard, ocrText: String) {
        guard QuoteChecker.contains(card.deadlineQuote, in: ocrText),
              let quote = LetterCard.nullish(card.deadlineQuote)
        else {
            card.deadline = nil
            card.deadlineQuote = nil
            return
        }

        guard let parsed = UKDateParser.firstDate(in: quote) else {
            // "within 14 days" and any other quote with no calendar date.
            card.deadline = nil
            card.deadlineQuote = nil
            return
        }

        card.deadlineQuote = quote
        card.deadline = parsed
    }

    private static func applyAmount(_ card: inout LetterCard, ocrText: String) {
        guard QuoteChecker.contains(card.amountQuote, in: ocrText),
              let quote = LetterCard.nullish(card.amountQuote)
        else {
            card.amountQuote = nil
            return
        }
        card.amountQuote = quote
    }

    /// A sign with no quote is structural ("no reference number") and is kept.
    /// A sign whose quote is not in the OCR text is dropped.
    private static func keptSign(_ sign: ScamSign, ocrText: String) -> ScamSign? {
        var sign = sign
        sign.sign = SafetyCopy.cleaned(sign.sign)
        guard !sign.sign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let quote = LetterCard.nullish(sign.quote)
        if quote == nil {
            sign.quote = nil
            return sign
        }
        guard QuoteChecker.contains(quote, in: ocrText) else { return nil }
        sign.quote = quote
        return sign
    }

    private static func canonicalSender(_ value: String) -> String {
        let normalised = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return LetterCard.senderKinds.contains(normalised) ? normalised : "other"
    }
}
