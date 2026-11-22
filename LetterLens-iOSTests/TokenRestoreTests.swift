//
//  TokenRestoreTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct TokenRestoreTests {
    private var amountMap: RedactionMap {
        RedactionMap(entries: [
            RedactionMap.Entry(token: "[AMOUNT_1]", original: "£42.50", kind: "AMOUNT"),
        ])
    }

    @Test func aCleanTokenIsRestored() {
        let restored = CardFieldRestore.text("The balance of [AMOUNT_1] is due.", map: amountMap)
        #expect(restored == "The balance of £42.50 is due.")
    }

    @Test func aMangledTokenIsRestored() {
        #expect(CardFieldRestore.text("S[AMOUNT)", map: amountMap) == "£42.50")
        #expect(CardFieldRestore.text("[amount_1)", map: amountMap) == "£42.50")
        #expect(CardFieldRestore.text("S[AMOUNT_1]", map: amountMap) == "£42.50")
    }

    @Test func aLeftoverFragmentIsNulled() {
        #expect(CardFieldRestore.text("See S[ACCOUNT) today.", map: amountMap) == nil)
        #expect(CardFieldRestore.text("Reference [NAME_2].", map: amountMap) == nil)
    }

    /// The guard used to fire on an opening bracket followed by letters, with the
    /// closing bracket optional. "[ADDRESS LINE 1]" matched on "[ADDRESS" alone, so a
    /// correct deadline whose quote contained the phrase was thrown away. Letters 1, 3
    /// and 15 of the test kit lost a deadline the model had read correctly.
    @Test func bracketedTextInTheLetterIsNotTreatedAsAToken() {
        let sentence = "Pay by 17 November 2026 or bailiffs will be sent to [ADDRESS LINE 1] on the same day."
        #expect(CardFieldRestore.text(sentence, map: amountMap) == sentence)

        let instalment = "Your first remaining instalment of E[INSTALMENT AMOUNT] is due on 1 December 2026."
        #expect(CardFieldRestore.text(instalment, map: amountMap) == instalment)
    }

    /// Tightening the guard must not let a real token through.
    @Test func aClosedOrNumberedTokenIsStillCaught() {
        for leftover in ["[NAME_2]", "See S[ACCOUNT) today.", "Ref [REF_10]", "ends with [POSTCODE]"] {
            #expect(CardFieldRestore.text(leftover, map: amountMap) == nil, "\(leftover) must be dropped")
        }
    }

    @Test func textWithNoTokenIsUnchanged() {
        let plain = "Pay £10 by Friday."
        #expect(CardFieldRestore.text(plain, map: amountMap) == plain)
        #expect(CardFieldRestore.text(plain, map: nil) == plain)
    }

    @Test func aRestoredQuoteMustStillBeVerbatim() {
        let ocr = "The balance of £42.50 is due."
        let card = LetterCard(
            type: .bill,
            senderKind: .council,
            action: "Pay the balance.",
            deadline: nil,
            deadlineQuote: nil,
            amountQuote: "The balance of S[AMOUNT) is due.",
            watchOuts: ["Keep [AMOUNT_1] aside.", "This line has no token."],
            scamSigns: [ScamSign(sign: "Odd wording", quote: "S[ACCOUNT)")],
            noActionNeeded: false
        )
        let restored = CardFieldRestore.apply(card, map: amountMap)
        let validated = CardValidator.validate(restored, ocrText: ocr)
        #expect(validated.amountQuote == "The balance of £42.50 is due.")
        #expect(validated.watchOuts == ["Keep £42.50 aside.", "This line has no token."])
        #expect(validated.scamSigns.map(\.sign) == ["Odd wording"])
        #expect(validated.scamSigns.map(\.quote) == [nil])
        #expect(validated.action == "Pay the balance.")
    }
}
