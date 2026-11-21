//
//  HomeAndNextStepsTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite("Home and next steps")
struct HomeAndNextStepsTests {
    @Test func needsActionIsAFutureDeadlineOrScamSignsAndNotDone() throws {
        let now = try london(2026, 11, 14, hour: 9)
        let due = try letter(n: 1, daysAgo: 0, deadline: "2026-12-03", now: now)
        let today = try letter(n: 2, daysAgo: 1, deadline: "2026-11-14", now: now)
        let past = try letter(n: 3, daysAgo: 3, deadline: "2026-11-01", now: now)
        let scam = try letter(n: 4, daysAgo: 0, scam: true, now: now)
        let doneScam = try letter(n: 5, daysAgo: 0, scam: true, done: true, now: now)
        let info = try letter(n: 6, daysAgo: 40, noAction: true, now: now)

        let lists = HomeLetterLists.split([past, info, doneScam, scam, today, due], now: now)

        #expect(lists.needsAction.map(\.id) == [today.id, due.id, scam.id])
        #expect(lists.earlier.map(\.id) == [doneScam.id, past.id, info.id])
        #expect(HomeLetterLists.earlierSubline(past) == "No deadline found")
        #expect(HomeLetterLists.earlierSubline(info) == "For your information")
        #expect(HomeLetterLists.earlierSubline(doneScam) == "Done")
    }

    @Test func aSoonerDeadlineSortsAheadOfALaterOne() throws {
        let now = try london(2026, 11, 14, hour: 9)
        let later = try letter(n: 1, daysAgo: 0, deadline: "2026-12-20", now: now)
        let sooner = try letter(n: 2, daysAgo: 4, deadline: "2026-11-20", now: now)
        let lists = HomeLetterLists.split([later, sooner], now: now)
        #expect(lists.needsAction.map(\.id) == [sooner.id, later.id])
    }

    @Test func relativeDatesAreTodayAWeekdayOrDayMonth() throws {
        let now = try london(2026, 11, 14, hour: 9)
        #expect(HomeDateLabel.relative(now, now: now) == HomeDateText(visual: "Today", spoken: "Today"))

        let monday = try london(2026, 11, 16, hour: 12)
        #expect(HomeDateLabel.relative(monday, now: now) == HomeDateText(visual: "Monday", spoken: "Monday"))

        let thursday = try london(2026, 11, 12, hour: 8)
        #expect(HomeDateLabel.relative(thursday, now: now) == HomeDateText(visual: "Thursday", spoken: "Thursday"))

        let october = try london(2026, 10, 3, hour: 8)
        #expect(HomeDateLabel.relative(october, now: now).visual == "3 Oct")
        #expect(HomeDateLabel.relative(october, now: now).spoken == "3 October 2026")
    }

    @Test func deadlinePillsUseTheShortDateAndASpokenCount() throws {
        let soon = try london(2026, 11, 12, hour: 9)
        let pill = HomeDeadlinePillCopy.make(iso: "2026-12-03", now: soon)
        #expect(pill?.visual == "Due 3 Dec · 21 days")
        #expect(pill?.spoken == "Due 3 December, 21 days left")

        let tomorrow = try london(2026, 12, 2, hour: 18)
        let one = HomeDeadlinePillCopy.make(iso: "2026-12-03", now: tomorrow)
        #expect(one?.visual == "Due 3 Dec · 1 day")
        #expect(one?.spoken == "Due 3 December, 1 day left")

        let today = try london(2026, 12, 3, hour: 10)
        let dueToday = HomeDeadlinePillCopy.make(iso: "2026-12-03", now: today)
        #expect(dueToday?.visual == "Due 3 Dec · today")
        #expect(dueToday?.spoken == "Due 3 December, today")

        let after = try london(2026, 12, 4, hour: 8)
        #expect(HomeDeadlinePillCopy.make(iso: "2026-12-03", now: after) == nil)
        #expect(HomeDeadlinePillCopy.make(iso: "3 December 2026", now: soon) == nil)
    }

    @Test func needsActionUsesTheDeadlineAndEarlierUsesTheStoredDay() throws {
        let now = try london(2026, 11, 14, hour: 9)
        let due = try letter(n: 1, daysAgo: 2, deadline: "2026-12-03", now: now)
        let stored = HomeLetterLists.trailingDate(due, section: .earlier, now: now)
        let deadline = HomeLetterLists.trailingDate(due, section: .needsAction, now: now)
        #expect(HomeDateLabel.relative(stored, now: now).visual == "Thursday")
        #expect(HomeCalendar.format(deadline, pattern: "d MMM") == "3 Dec")
    }

    @Test func tokensAreReinsertedLocallyAndSpokenWithoutBrackets() {
        let map = RedactionMap(entries: [
            RedactionMap.Entry(token: "[NAME_1]", original: "Jane Smith", kind: "NAME"),
            RedactionMap.Entry(token: "[REF_1]", original: "AB12CD34EF", kind: "REF"),
        ])
        let segments = ScriptReinsertion.segments(
            in: "Hello [name_1], reference [REF_1].",
            map: map,
            reinsert: true
        )
        #expect(segments.map(\.text) == ["Hello ", "Jane Smith", ", reference ", "AB12CD34EF", "."])
        #expect(segments.map(\.isChip) == [false, true, false, true, false])
        #expect(ScriptReinsertion.plain(in: "Hello [NAME_1].", map: map) == "Hello Jane Smith.")
        #expect(ScriptReinsertion.spokenRedacted("Dear [NAME_1], ref [REF_1].") == "Dear name removed, ref reference removed.")
        #expect(ScriptReinsertion.firstToken(in: "See [REF_1] and [NAME_1].", kind: "NAME") == "[NAME_1]")
    }

    @Test func samplePlannerKeepsTokensAndDoesNotInventAName() async {
        let card = LetterCard(
            type: .reminder,
            senderKind: .council,
            action: "Pay the balance.",
            deadline: "2026-12-03",
            deadlineQuote: nil,
            amountQuote: nil,
            watchOuts: [],
            scamSigns: [],
            noActionNeeded: false
        )
        let plan = await LocalSampleNextStepsPlanner().plan(
            redactedText: "Dear [NAME_1], reference [REF_1].",
            card: card,
            note: "I can't afford it this month"
        )
        #expect(plan.script.contains("[NAME_1]"))
        #expect(plan.script.contains("[REF_1]"))
        #expect(plan.madeInCloud == false)
        #expect(plan.steps.count == 4)
        #expect(plan.steps.contains { $0.detail == "I can't afford it this month" })

        let unnamed = await LocalSampleNextStepsPlanner().plan(
            redactedText: "Please pay the balance.",
            card: card,
            note: "  "
        )
        #expect(unnamed.script == "Hello. I'd like to talk about the letter I was sent.")
        #expect(!unnamed.script.contains("["))
        #expect(unnamed.madeInCloud == false)
        #expect(unnamed.steps.count == 3)
    }

    @Test func planningIsRefusedOnlyWhenNeverUploadIsOn() {
        // A plan is always a cloud call, so Never upload is the one switch that stops it.
        #expect(NextStepsConsent.allowsPlanning(neverUpload: true) == false)
        let never = NextStepsConsent.blockedFlow(neverUpload: true)
        #expect(never.route == .keepPrivate)
        #expect(never.showsCloudButton == false)
        #expect(never.isKeepPrivateBecauseNeverUpload)

        // Allowing it is not consent. Screen 08 still asks before anything is sent.
        #expect(NextStepsConsent.allowsPlanning(neverUpload: false))
    }

    private func letter(
        n: Int,
        daysAgo: Int,
        deadline: String? = nil,
        scam: Bool = false,
        noAction: Bool = false,
        done: Bool = false,
        now: Date
    ) throws -> HomeLetter {
        let calendar = HomeCalendar.london
        let createdAt = try #require(calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)))
        let id = try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n)))
        return HomeLetter(
            id: id,
            createdAt: createdAt,
            card: LetterCard(
                type: scam ? .refund : .reminder,
                senderKind: .council,
                action: "Do the thing in the letter.",
                deadline: deadline,
                deadlineQuote: nil,
                amountQuote: nil,
                watchOuts: [],
                scamSigns: scam ? [ScamSign(sign: "It asks for a fee", quote: nil)] : [],
                noActionNeeded: noAction
            ),
            path: .device,
            isDone: done
        )
    }

    private func london(_ year: Int, _ month: Int, _ day: Int, hour: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        return try #require(
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
        )
    }
}
