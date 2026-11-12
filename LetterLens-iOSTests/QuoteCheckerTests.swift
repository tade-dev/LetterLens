//
//  QuoteCheckerTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct QuoteCheckerTests {
    private let letter = """
    You must pay the outstanding balance of £42.50 by 1 December 2026.
    Call us if you cannot pay.
    """

    @Test func exactQuoteMatches() {
        #expect(QuoteChecker.contains(
            "You must pay the outstanding balance of £42.50 by 1 December 2026.",
            in: letter
        ))
    }

    @Test func caseAndLineBreaksAreIgnored() {
        let quote = "you must pay the outstanding balance of £42.50 by 1 december 2026."
        let wrapped = "You must pay the outstanding\nbalance of £42.50 by 1 December 2026."
        #expect(QuoteChecker.contains(quote, in: letter))
        #expect(QuoteChecker.contains(wrapped, in: letter))
    }

    @Test func repeatedSpacesCollapse() {
        #expect(QuoteChecker.contains(
            "You  must   pay the outstanding balance of £42.50 by 1 December 2026.",
            in: letter
        ))
    }

    @Test func aMissingWordDoesNotMatch() {
        #expect(!QuoteChecker.contains(
            "You must pay the full balance of £42.50 by 1 December 2026.",
            in: letter
        ))
    }

    @Test func punctuationAndThePoundSignMustMatch() {
        #expect(!QuoteChecker.contains(
            "You must pay the outstanding balance of 42.50 by 1 December 2026.",
            in: letter
        ))
        #expect(!QuoteChecker.contains(
            "You must pay the outstanding balance of £42.50 by 1 December 2026!",
            in: letter
        ))
    }

    @Test func emptyAndNullQuotesDoNotMatch() {
        #expect(!QuoteChecker.contains(nil, in: letter))
        #expect(!QuoteChecker.contains("  ", in: letter))
        #expect(!QuoteChecker.contains("null", in: letter))
    }
}
