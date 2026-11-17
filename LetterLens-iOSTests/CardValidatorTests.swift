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

    @Test func aLowercasedDeadlineQuoteIsStoredAsTheOCRSpan() {
        let ocr = "You must pay the processing fee by 18 November 2026 or your refund will be cancelled."
        let card = sample(
            deadline: "2026-11-01",
            deadlineQuote: "you must pay the processing fee by 18 November 2026",
            amountQuote: nil
        )
        let validated = CardValidator.validate(card, ocrText: ocr)
        #expect(validated.deadlineQuote == "You must pay the processing fee by 18 November 2026")
        #expect(validated.deadline == "2026-11-18")
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

    @Test func anEffectiveDateIsNotADeadline() {
        let quotes = [
            "These changes take effect from 1 January 2027.",
            "The new rate takes effect from 1 January 2027.",
            "The new rate is taking effect from 1 January 2027.",
            "The new rate is effective from 1 January 2027.",
            "The new rate is effective on 1 January 2027.",
        ]
        for quote in quotes {
            #expect(DeadlineQuote.isEffectiveDateWithoutAction(quote))
            let validated = CardValidator.validate(
                sample(deadline: "2027-01-01", deadlineQuote: quote, amountQuote: nil),
                ocrText: quote
            )
            #expect(validated.deadline == nil)
            #expect(validated.deadlineQuote == nil)
        }
    }

    @Test func aReplyBeforeTheEffectiveDateIsKept() {
        let quote = "Please reply before the changes take effect on 1 January 2027"
        let validated = CardValidator.validate(
            sample(deadline: "2027-01-01", deadlineQuote: quote, amountQuote: nil),
            ocrText: quote
        )
        #expect(validated.deadline == "2027-01-01")
        #expect(validated.deadlineQuote == quote)
        #expect(!DeadlineQuote.isEffectiveDateWithoutAction(quote))
    }

    @Test func aPayByDateIsKept() {
        let quote = "Pay by 3 March 2027"
        let validated = CardValidator.validate(
            sample(deadline: "2027-03-03", deadlineQuote: quote, amountQuote: nil),
            ocrText: quote
        )
        #expect(validated.deadline == "2027-03-03")
        #expect(validated.deadlineQuote == quote)
    }

    @Test func effectiveDateMatchingIsCaseInsensitive() {
        let quote = "THESE CHANGES TAKE EFFECT FROM 1 JANUARY 2027."
        #expect(DeadlineQuote.isEffectiveDateWithoutAction(quote))
        #expect(DeadlineQuote.isEffectiveDateWithoutAction("EFFECTIVE ON 1 January 2027"))
        let validated = CardValidator.validate(
            sample(deadline: "2027-01-01", deadlineQuote: quote, amountQuote: nil),
            ocrText: quote
        )
        #expect(validated.deadline == nil)
        #expect(validated.deadlineQuote == nil)
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
            type: .reminder,
            senderKind: .council,
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
