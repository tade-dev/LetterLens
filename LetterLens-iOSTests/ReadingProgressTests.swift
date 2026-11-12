//
//  ReadingProgressTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite("Reading progress")
struct ReadingProgressTests {
    @Test func rowOneCountsPagesAndTicksOnlyWhenEveryPageIsRead() {
        let progress = ReadingProgress(pagesTotal: 3, path: .device)
        #expect(progress.rowTitle(.textPulled) == "Text pulled from 0 pages")
        #expect(status(progress, .textPulled) == .active)
        #expect(status(progress, .sender) == .pending)

        progress.apply(.pageOCRFinished(index: 0))
        #expect(progress.pagesOCRd == 1)
        #expect(progress.rowTitle(.textPulled) == "Text pulled from 1 page")
        #expect(status(progress, .textPulled) == .active)
        #expect(status(progress, .sender) == .pending)
        #expect(status(progress, .datesAndAmounts) == .pending)
        #expect(status(progress, .warningSigns) == .pending)

        progress.apply(.pageOCRFinished(index: 1))
        #expect(progress.pagesOCRd == 2)
        #expect(status(progress, .textPulled) == .active)

        progress.apply(.pageOCRFinished(index: 2))
        #expect(progress.pagesOCRd == 3)
        #expect(progress.phase == .ocr)
        #expect(status(progress, .textPulled) == .ticked)
        #expect(status(progress, .sender) == .active)
        #expect(status(progress, .datesAndAmounts) == .pending)
    }

    @Test func outOfOrderAndExtraPageEventsDoNotAdvance() {
        let progress = ReadingProgress(pagesTotal: 2, path: .device)
        progress.apply(.pageOCRFinished(index: 1))
        #expect(progress.pagesOCRd == 0)
        #expect(progress.currentPageIndex == 0)

        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.pageOCRFinished(index: 0))
        #expect(progress.pagesOCRd == 1)

        progress.apply(.pageOCRFinished(index: 1))
        progress.apply(.pageOCRFinished(index: 2))
        #expect(progress.pagesOCRd == 2)
        #expect(status(progress, .textPulled) == .ticked)
    }

    @Test func cardRowsTickOnlyOnTheValidatedEvent() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.cardingStarted)
        #expect(progress.phase == .carding)
        #expect(status(progress, .sender) == .active)
        #expect(status(progress, .datesAndAmounts) == .pending)
        #expect(status(progress, .warningSigns) == .pending)

        progress.apply(.cardValidated)
        #expect(progress.phase == .validated)
        #expect(status(progress, .sender) == .ticked)
        #expect(status(progress, .datesAndAmounts) == .ticked)
        #expect(status(progress, .warningSigns) == .ticked)
        #expect(progress.showsScanLine == false)
    }

    @Test func cardRowsStayUntickedUntilValidationEvenIfCardingStarted() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.cardValidated)
        #expect(progress.phase == .ocr)
        #expect(status(progress, .sender) == .pending)

        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.cardValidated)
        #expect(progress.phase == .ocr)
        #expect(status(progress, .sender) == .active)
        #expect(status(progress, .datesAndAmounts) == .pending)
    }

    @Test func devicePathHasNoRedactionRowAndIgnoresRedaction() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        #expect(progress.checklist.map(\.kind) == [.textPulled, .sender, .datesAndAmounts, .warningSigns])
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.redactionFinished(count: 5))
        #expect(progress.redactedCount == 0)
        #expect(progress.didFinishRedaction == false)
        #expect(progress.phase == .ocr)
        #expect(progress.checklist.contains(where: { $0.kind == .detailsRemoved }) == false)
    }

    @Test func cloudPathAddsTheRedactionRowBeforeTheCardCall() {
        let progress = ReadingProgress(pagesTotal: 2, path: .cloud)
        #expect(progress.checklist.map(\.kind) == [
            .textPulled, .detailsRemoved, .sender, .datesAndAmounts, .warningSigns,
        ])
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.pageOCRFinished(index: 1))
        #expect(status(progress, .textPulled) == .ticked)
        #expect(status(progress, .detailsRemoved) == .active)
        #expect(progress.rowTitle(.detailsRemoved) == "Removed 0 details")
        #expect(status(progress, .sender) == .pending)

        progress.apply(.cardingStarted)
        #expect(progress.phase == .ocr)

        progress.apply(.redactionFinished(count: 4))
        #expect(progress.phase == .redacting)
        #expect(progress.redactedCount == 4)
        #expect(status(progress, .detailsRemoved) == .ticked)
        #expect(progress.rowTitle(.detailsRemoved) == "Removed 4 details")
        #expect(status(progress, .sender) == .active)
        #expect(status(progress, .datesAndAmounts) == .pending)

        progress.apply(.cardingStarted)
        #expect(progress.phase == .carding)
        #expect(status(progress, .warningSigns) == .pending)
        #expect(status(progress, .sender) == .active)
    }

    @Test func redactionBeforeOCRFinishesDoesNothing() {
        let progress = ReadingProgress(pagesTotal: 2, path: .cloud)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.redactionFinished(count: 2))
        #expect(progress.redactedCount == 0)
        #expect(progress.phase == .ocr)
        #expect(status(progress, .detailsRemoved) == .pending)
    }

    @Test func oneDetailIsSingular() {
        let progress = ReadingProgress(pagesTotal: 1, path: .cloud)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.redactionFinished(count: 1))
        #expect(progress.rowTitle(.detailsRemoved) == "Removed 1 detail")
    }

    @Test func negativeRedactionCountIsClamped() {
        let progress = ReadingProgress(pagesTotal: 1, path: .cloud)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.redactionFinished(count: -3))
        #expect(progress.redactedCount == 0)
        #expect(status(progress, .detailsRemoved) == .ticked)
    }

    @Test func ocrFailureStopsProgressAndDoesNotTickRowOne() {
        let progress = ReadingProgress(pagesTotal: 2, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.ocrFailed)
        #expect(progress.phase == .failed)
        #expect(progress.pagesOCRd == 1)
        #expect(status(progress, .textPulled) == .failed)
        #expect(status(progress, .sender) == .pending)
        #expect(progress.showsScanLine == false)

        progress.apply(.pageOCRFinished(index: 1))
        progress.apply(.cardingStarted)
        progress.apply(.cardValidated)
        progress.apply(.failed)
        #expect(progress.phase == .failed)
        #expect(progress.pagesOCRd == 1)
        #expect(status(progress, .textPulled) == .failed)
        #expect(status(progress, .sender) == .pending)
        #expect(status(progress, .datesAndAmounts) == .pending)
        #expect(status(progress, .warningSigns) == .pending)
    }

    @Test func failureDuringCardingDoesNotTickTheCardRows() {
        let progress = ReadingProgress(pagesTotal: 1, path: .cloud)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.redactionFinished(count: 2))
        progress.apply(.cardingStarted)
        progress.apply(.failed)
        #expect(progress.phase == .failed)
        #expect(status(progress, .textPulled) == .ticked)
        #expect(status(progress, .detailsRemoved) == .ticked)
        #expect(status(progress, .sender) == .failed)
        #expect(status(progress, .datesAndAmounts) == .pending)
        #expect(status(progress, .warningSigns) == .pending)

        progress.apply(.cardValidated)
        #expect(progress.phase == .failed)
        #expect(status(progress, .sender) == .failed)
    }

    @Test func ocrFailedAfterOCRIsFinishedDoesNotWipeTheTextTick() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.ocrFailed)
        #expect(progress.phase == .ocr)
        #expect(status(progress, .textPulled) == .ticked)
    }

    @Test func eventsAfterValidationAreIgnored() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.cardingStarted)
        progress.apply(.cardValidated)
        progress.apply(.failed)
        progress.apply(.pageOCRFinished(index: 0))
        #expect(progress.phase == .validated)
        #expect(status(progress, .warningSigns) == .ticked)
    }

    @Test func displayedPageFollowsOCRThenReturnsToTheFirstPage() {
        let progress = ReadingProgress(pagesTotal: 3, path: .device)
        #expect(progress.displayedPageIndex == 0)
        progress.apply(.pageOCRFinished(index: 0))
        #expect(progress.currentPageIndex == 1)
        #expect(progress.displayedPageIndex == 1)
        progress.apply(.pageOCRFinished(index: 1))
        #expect(progress.displayedPageIndex == 2)
        progress.apply(.pageOCRFinished(index: 2))
        #expect(progress.displayedPageIndex == 0)
        #expect(progress.showsScanLine == true)
    }

    @Test func cloudSublineNeverSaysNothingLeftThePhone() {
        let cloud = ReadingProgress(pagesTotal: 1, path: .cloud)
        let device = ReadingProgress(pagesTotal: 1, path: .device)
        #expect(device.subline == "Nothing has left your phone.")
        #expect(cloud.subline == "Only the text was sent, with your details removed. Never the photo.")
        #expect(cloud.subline.contains("Nothing has left your phone") == false)
        #expect(cloud.badgeTitle == "In the cloud · details removed")
        #expect(cloud.badgeSymbol == "cloud")
        #expect(device.badgeTitle == "On this iPhone · offline OK")
        #expect(device.badgeSymbol == "lock.fill")
    }

    @Test func scanLineHidesWhenReadingFailsOrValidates() {
        let reading = ReadingProgress(pagesTotal: 1, path: .device)
        #expect(reading.showsScanLine == true)
        reading.apply(.pageOCRFinished(index: 0))
        reading.apply(.cardingStarted)
        #expect(reading.showsScanLine == true)
        reading.apply(.cardValidated)
        #expect(reading.showsScanLine == false)

        let failed = ReadingProgress(pagesTotal: 1, path: .device)
        failed.apply(.ocrFailed)
        #expect(failed.showsScanLine == false)
    }

    @Test func validationFrameRevealsCardRowsOnAStaggerFromOneEvent() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        progress.apply(.cardingStarted)
        progress.apply(.cardValidated)
        let items = progress.checklist
        let sender = items.first { $0.kind == .sender }!
        let dates = items.first { $0.kind == .datesAndAmounts }!
        let warnings = items.first { $0.kind == .warningSigns }!
        #expect(sender.status == .ticked)
        #expect(dates.status == .ticked)

        var frame = ReadingChecklistFrame()
        #expect(frame.status(for: sender, phase: .validated) == .pending)
        frame.cardTicksRevealed = 1
        #expect(frame.status(for: sender, phase: .validated) == .ticked)
        #expect(frame.status(for: dates, phase: .validated) == .pending)
        frame.highlighted = .datesAndAmounts
        #expect(frame.status(for: dates, phase: .validated) == .active)
        #expect(frame.status(for: warnings, phase: .validated) == .pending)
        frame.cardTicksRevealed = 2
        frame.highlighted = nil
        #expect(frame.status(for: dates, phase: .validated) == .ticked)
        frame.highlighted = .warningSigns
        #expect(frame.status(for: warnings, phase: .validated) == .active)
        frame.cardTicksRevealed = 3
        frame.highlighted = nil
        #expect(frame.status(for: warnings, phase: .validated) == .ticked)
    }

    @Test func deferredActiveRowStaysPendingUntilTheFrameReleasesIt() {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        progress.apply(.pageOCRFinished(index: 0))
        let sender = progress.checklist.first { $0.kind == .sender }!
        #expect(sender.status == .active)
        var frame = ReadingChecklistFrame(deferredActive: [.sender])
        #expect(frame.status(for: sender, phase: .ocr) == .pending)
        frame.deferredActive = []
        #expect(frame.status(for: sender, phase: .ocr) == .active)
    }

    @Test func handoffDelayIsThreeStaggersAfterValidation() {
        #expect(ReadingMotion.tickStaggerMS * 3 == ReadingMotion.handoffDelayMS)
        #expect(ReadingMotion.handoffDelayMS == 360)
        #expect(ReadingMotion.activationDelayMS == 80)
        #expect(ReadingMotion.activationDelayMS < ReadingMotion.tickStaggerMS)
        #expect(ReadingMotion.sweepDuration == 1.6)
        #expect(ReadingMotion.sweepFade == 0.2)
        #expect(ReadingMotion.settleFade == 0.15)
    }
}

private func status(
    _ progress: ReadingProgress,
    _ kind: ReadingChecklistItem.Kind
) -> ReadingChecklistItem.Status {
    progress.checklist.first { $0.kind == kind }?.status ?? .pending
}
