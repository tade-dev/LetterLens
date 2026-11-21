//
//  UKDateParserTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct UKDateParserTests {
    @Test func longMonth() {
        #expect(UKDateParser.firstDate(in: "by 1 December 2026") == "2026-12-01")
    }

    @Test func numericDateIsDayThenMonth() {
        #expect(UKDateParser.firstDate(in: "by 01/12/2026") == "2026-12-01")
        #expect(UKDateParser.firstDate(in: "on 03-04-2026") == "2026-04-03")
    }

    @Test func ordinalsAndAbbreviations() {
        #expect(UKDateParser.firstDate(in: "on or before 5th Jan 2027") == "2027-01-05")
        #expect(UKDateParser.firstDate(in: "Payment must reach us on or before 8th January 2027.") == "2027-01-08")
        #expect(UKDateParser.firstDate(in: "by 15 January 2027") == "2027-01-15")
        #expect(UKDateParser.firstDate(in: "by 18 November 2026") == "2026-11-18")
    }

    @Test func relativePhrasesHaveNoCalendarDate() {
        #expect(UKDateParser.firstDate(in: "Please contact us within 14 days") == nil)
        #expect(UKDateParser.firstDate(in: "within 24 hours of the date on this letter") == nil)
        #expect(UKDateParser.firstDate(in: "We have not set a calendar date by which you must pay.") == nil)
    }

    @Test func invalidDatesAreDropped() {
        #expect(UKDateParser.firstDate(in: "by 31/02/2026") == nil)
        #expect(UKDateParser.firstDate(in: "by 00/12/2026") == nil)
    }

    @Test func theFirstCalendarDateWins() {
        let text = "Letter date 3 November 2026. Pay by 1 December 2026."
        #expect(UKDateParser.firstDate(in: text) == "2026-11-03")
    }
}
