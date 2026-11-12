//
//  CardValidatorTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct CardValidatorTests {
    private let ocr = """
    You must pay the outstanding balance of £42.50 by 1 December 2026.
    Please contact us within 14 days.
    Pay at https://payments.example/now.
    """

    @Test func aQuoteThatIsMissingNullsTheDeadline() {
        let card = sample(
            deadline: "2026-12-01",
            deadlineQuote: "Pay by tomorrow morning.",
            amountQuote: "£42.50"
        )
        let validated = CardValidator.validate(card, ocrText: ocr)
        #expect(validated.deadline == nil)
        #expect(validated.deadlineQuote == nil)
    }

    @Test func theParsedDateReplacesTheModelDate() {
        let card = sample(
            deadline: "2026-11-01",
            deadlineQuote: "You must pay the outstanding balance of £42.50 by 1 December 2026.",
            amountQuote: "outstanding balance of £42.50"
        )
        let validated = CardValidator.validate(card, ocrText: ocr)
        #expect(validated.deadline == "2026-12-01")
        #expect(validated.deadlineQuote == "You must pay the outstanding balance of £42.50 by 1 December 2026.")
    }

    @Test func aRelativeQuoteDoesNotBecomeADate() {
        let card = sample(
            deadline: "2026-11-25",
            deadlineQuote: "Please contact us within 14 days.",
            amountQuote: nil
        )
        let validated = CardValidator.validate(card, ocrText: ocr)
        #expect(validated.deadline == nil)
        #expect(validated.deadlineQuote == nil)
    }

    @Test func anAmountQuoteMustAppear() {
        let card = sample(deadline: nil, deadlineQuote: nil, amountQuote: "£99.00 is due")
        #expect(CardValidator.validate(card, ocrText: ocr).amountQuote == nil)
    }

    @Test func scamSignsWithoutAFoundQuoteAreDropped() {
        var card = sample(deadline: nil, deadlineQuote: nil, amountQuote: nil)
        card.scamSigns = [
            ScamSign(sign: "Payment link", quote: "https://payments.example/now"),
            ScamSign(sign: "Invented link", quote: "https://not-in-the-letter.example"),
            ScamSign(sign: "No reference number", quote: nil),
        ]
        let signs = CardValidator.validate(card, ocrText: ocr).scamSigns
        #expect(signs.map(\.sign) == ["Payment link", "No reference number"])
    }

    @Test func safetyClaimsAreRewritten() {
        var card = sample(deadline: nil, deadlineQuote: nil, amountQuote: nil)
        card.action = "This letter is safe. Pay the balance."
        let validated = CardValidator.validate(card, ocrText: ocr)
        #expect(!validated.action.localizedCaseInsensitiveContains("safe"))
        #expect(validated.action.contains("signs to check"))
        #expect(validated.action.contains("Pay the balance."))
    }

    private func sample(deadline: String?, deadlineQuote: String?, amountQuote: String?) -> LetterCard {
        LetterCard(
            type: "council tax reminder",
            senderKind: "council",
            action: "Pay the balance.",
            deadline: deadline,
            deadlineQuote: deadlineQuote,
            amountQuote: amountQuote,
            watchOuts: [],
            scamSigns: [],
            noActionNeeded: false
        )
    }
}
