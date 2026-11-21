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
