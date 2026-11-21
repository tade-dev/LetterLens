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

    @Test func hyphenatedAndSlashedReferencesAreTokenised() {
        let samples = ["WT-8841-QX", "AB/12345/C", "1234-ABCD"]
        for sample in samples {
            let result = redactor.redact("Code \(sample) today.")
            #expect(!result.text.contains(sample))
            #expect(result.text.contains("[REF_1]"))
            #expect(result.map.original(for: "[REF_1]") == sample)
        }
        let labelled = redactor.redact("See REF 1234-ABCD today.")
        #expect(labelled.map.original(for: "[REF_1]") == "1234-ABCD")
        #expect(!labelled.text.contains("1234-ABCD"))
    }

    @Test func datesAmountsPostcodesAndPlainWordsAreNotReferences() {
        let result = redactor.redact("Thank-you for £42.50 on 9 January 2027 at SW1A 1AA.")
        #expect(result.text.contains("Thank-you"))
        #expect(result.text.contains("£42.50"))
        #expect(result.text.contains("9 January 2027"))
        #expect(result.map.original(for: "[POSTCODE_1]") == "SW1A 1AA")
        #expect(!result.text.contains("[REF_"))
    }

    @Test func aSeparatorBetweenRedactedSpansIsKeptAndRoundTrips() {
        let newline = "ada@example.com\nSW1A 1AA"
        let spaced = "WT-8841-QX SW1A 1AA"
        let broken = redactor.redact(newline)
        let beside = redactor.redact(spaced)
        #expect(broken.text.contains("[EMAIL_1]\n[POSTCODE_1]"))
        #expect(beside.text.contains("[REF_1] [POSTCODE_1]"))
        #expect(!broken.text.contains("]["))
        #expect(!beside.text.contains("]["))
        #expect(broken.map.reinsert(into: broken.text) == newline)
        #expect(beside.map.reinsert(into: beside.text) == spaced)
    }
}

private struct AppendingPass: RedactionFuzzyPass {
    func redactRemaining(_ result: RedactionResult) -> RedactionResult {
        RedactionResult(text: result.text + " [FUZZY]", map: result.map)
    }
}
