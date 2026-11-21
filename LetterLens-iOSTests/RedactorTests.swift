//
//  RedactorTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct RedactorTests {
    private let redactor = Redactor()

    @Test func salutationNameIsTokenisedAndTheDateStays() {
        let result = redactor.redact("Dear Jane Smith, pay by 1 December 2026.")
        #expect(result.text.contains("[NAME_1]"))
        #expect(result.text.contains("1 December 2026"))
        #expect(result.map.original(for: "[NAME_1]") == "Jane Smith")
        #expect(result.text.contains("Dear"))
    }

    @Test func genericSalutationIsLeftAlone() {
        let result = redactor.redact("Dear Sir or Madam, there is nothing to pay.")
        #expect(!result.text.contains("[NAME_"))
        #expect(result.text.contains("Sir or Madam"))
    }

    @Test func postcodeSortCodeAccountEmailPhoneAndReference() {
        let letter = """
        Write to SW1A 1AA. Sort code 20-00-00. Account number 12345678.
        Email ada@example.com or call 020 7946 0958.
        Our reference: AB12CD34EF. NI QQ 12 34 56 C. Amount £42.50 is due on 5th Jan 2027.
        """
        let result = redactor.redact(letter)
        #expect(result.map.original(for: "[POSTCODE_1]") == "SW1A 1AA")
        #expect(result.map.original(for: "[SORTCODE_1]") == "20-00-00")
        #expect(result.map.original(for: "[ACCOUNT_1]") == "12345678")
        #expect(result.map.original(for: "[EMAIL_1]") == "ada@example.com")
        #expect(result.map.original(for: "[PHONE_1]") == "020 7946 0958")
        #expect(result.map.original(for: "[REF_1]") == "AB12CD34EF")
        #expect(result.text.contains("QQ") == false)
        #expect(result.text.contains("£42.50"))
        #expect(result.text.contains("5th Jan 2027"))
    }

    @Test func twoNamesGetSeparateTokensInOrder() {
        let result = redactor.redact("Dear Ada Lovelace,\nHello Grace Hopper.")
        #expect(result.map.original(for: "[NAME_1]") == "Ada Lovelace")
        #expect(result.map.original(for: "[NAME_2]") == "Grace Hopper")
    }

    @Test func reinsertionRestoresTheOriginalAndIgnoresTokenCase() {
        let result = redactor.redact("Dear Jane Smith, email jane@example.com.")
        let restored = result.map.reinsert(into: "Hello [name_1] at [EMAIL_1].")
        #expect(restored == "Hello Jane Smith at jane@example.com.")
    }

    @Test func paymentLinkIsTokenised() {
        let result = redactor.redact("Pay at https://payments.example/final-notice today.")
        #expect(result.text.contains("[LINK_1]"))
        #expect(result.map.original(for: "[LINK_1]") == "https://payments.example/final-notice")
    }

    @Test func fuzzyPassHookSeesTheDeterministicResult() {
        let redactor = Redactor(fuzzyPass: AppendingPass())
        let result = redactor.redact("Dear Ada Lovelace, hello.")
        #expect(result.text.hasSuffix(" [FUZZY]"))
        #expect(result.text.contains("[NAME_1]"))
    }
}

private struct AppendingPass: RedactionFuzzyPass {
    func redactRemaining(_ result: RedactionResult) -> RedactionResult {
        RedactionResult(text: result.text + " [FUZZY]", map: result.map)
    }
}
