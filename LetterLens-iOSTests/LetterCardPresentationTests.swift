//
//  LetterCardPresentationTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite("Letter card presentation")
struct LetterCardPresentationTests {
    @Test func aDecemberDeadlineUsesTheUKCalendar() throws {
        let deadline = LetterDeadlineFormat.parse("2026-12-03", now: try london(2026, 11, 30, hour: 9))
        #expect(deadline?.dateText == "Thu 3 December 2026")
        #expect(deadline?.daysLeft == 3)
        #expect(deadline?.daysLeftText == "3 days left")
    }

    @Test func oneDayLeftIsSingularAndTodayIsZero() throws {
        let tomorrow = LetterDeadlineFormat.parse("2026-12-03", now: try london(2026, 12, 2, hour: 18))
        #expect(tomorrow?.daysLeftText == "1 day left")

        let today = LetterDeadlineFormat.parse("2026-12-03", now: try london(2026, 12, 3, hour: 23))
        #expect(today?.daysLeft == 0)
        #expect(today?.daysLeftText == "0 days left")
    }

    @Test func aPastDateKeepsTheDateAndDropsTheDaysLabel() throws {
        let past = LetterDeadlineFormat.parse("2026-12-03", now: try london(2026, 12, 4, hour: 8))
        #expect(past?.dateText == "Thu 3 December 2026")
        #expect(past?.daysLeft == -1)
        #expect(past?.daysLeftText == nil)
    }

    @Test func aDeadlineThatIsNotAnISODateIsHidden() {
        #expect(LetterDeadlineFormat.parse("3 December 2026") == nil)
        #expect(LetterDeadlineFormat.parse("2026-13-01") == nil)
        #expect(LetterDeadlineFormat.parse("2026-12-3") == nil)
        #expect(LetterDeadlineFormat.parse("") == nil)
    }

    @Test func scamSignsAreTheOnlyRouteToTheWarning() {
        var card = LetterCard.empty
        #expect(card.opensScamWarning == false)
        #expect(card.displayTitle == "Not sure · Not sure")

        card.scamSigns = [ScamSign(sign: "   ", quote: "Pay now")]
        #expect(card.opensScamWarning == false)

        card.scamSigns = [ScamSign(sign: "It asks for a fee to release money", quote: nil)]
        #expect(card.opensScamWarning == true)

        card.senderKind = .council
        card.type = .reminder
        #expect(card.displayTitle == "Council tax · Reminder")
        let read = LetterRead(card: card, path: .device, pageCount: 2)
        #expect(read.fromLine == "From Council tax · 2 pages")
        #expect(LetterRead(card: card, path: .cloud, pageCount: 1).fromLine == "From Council tax · 1 page")
    }

    private func london(_ year: Int, _ month: Int, _ day: Int, hour: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        return try #require(
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
        )
    }
}
