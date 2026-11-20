//
//  LetterHistoryTests.swift
//  LetterLens-iOSTests
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import LetterLens_iOS

@MainActor
@Suite("Scanned letter history")
struct LetterHistoryTests {
    @Test func aFinishedScanIsStoredOnceAndKeepsTheOCRText() throws {
        let harness = try HistoryHarness()
        let read = sampleRead(ocrText: "  Pay by 3 March 2027  ")

        #expect(try LetterHistory.write(read, into: harness.context) == .inserted)
        #expect(try LetterHistory.write(read, into: harness.context) == .alreadyStored)

        let stored = try harness.context.fetch(FetchDescriptor<LetterRecord>())
        #expect(stored.count == 1)
        let record = try #require(stored.first)
        #expect(record.id == read.id)
        #expect(record.ocrText == "Pay by 3 March 2027")
        #expect(record.card?.senderKind == .council)
        #expect(record.card?.action == "Pay the balance.")
        #expect(record.source == .onDevice)
        #expect(record.modelVersion == CardReadSource.onDeviceModelVersion)
        #expect(record.latencyMS == 15)
        #expect(record.detailsRemoved == 0)
        #expect(record.schemaVersion == 2)
        #expect(record.createdAt == read.createdAt)
    }

    @Test func anEmptyOCRTextIsNotStored() throws {
        let harness = try HistoryHarness()
        let read = sampleRead(ocrText: " \n\t ")
        #expect(try LetterHistory.write(read, into: harness.context) == .refusedEmptyOCR)
        #expect(try harness.context.fetch(FetchDescriptor<LetterRecord>()).isEmpty)
    }

    @Test func aSecondScanWithTheSameTextIsASeparateLetter() throws {
        let harness = try HistoryHarness()
        let first = sampleRead(ocrText: "Pay by 3 March 2027")
        var second = first
        second.id = UUID()
        #expect(try LetterHistory.write(first, into: harness.context) == .inserted)
        #expect(try LetterHistory.write(second, into: harness.context) == .inserted)
        #expect(try harness.context.fetch(FetchDescriptor<LetterRecord>()).count == 2)
    }

    @Test func theDraftUsesTheExistingOCRFieldAndCloudSource() throws {
        var read = sampleRead(ocrText: "Dear Jane Smith")
        read.path = .cloud
        read.detailsRemoved = 2
        let draft = try #require(read.historyDraft())
        #expect(draft.ocrText == "Dear Jane Smith")
        #expect(draft.sourceRaw == CardReadSource.cloud.rawValue)
        #expect(draft.detailsRemoved == 2)
        #expect(draft.schemaVersion == 2)
        let card = try JSONDecoder().decode(LetterCard.self, from: Data(draft.cardJSON.utf8))
        #expect(card.senderKind == .council)
        #expect(card.type == .reminder)
    }

    @Test func deviceReadingHandsOffTheOCRText() async {
        let progress = ReadingProgress(pagesTotal: 2, path: .device)
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        var page = 0
        var published: LetterRead?
        let read = await ScanReadingDriver.read(
            pages: [UIImage(), UIImage()],
            path: .device,
            progress: progress,
            id: id,
            createdAt: createdAt,
            schemaVersion: 2,
            recognize: { _ in
                page += 1
                return page == 1 ? "Page one" : " Page two "
            },
            readCard: { text in
                cardResult(ocrText: text, source: .onDevice, detailsRemoved: 0)
            },
            redactedDetailCount: { _ in
                Issue.record("Device reading must not redact before the card")
                return 0
            },
            publish: { published = $0 }
        )

        #expect(progress.phase == .validated)
        #expect(progress.card?.type == .reminder)
        #expect(read?.id == id)
        #expect(read?.ocrText == "Page one\n\nPage two")
        #expect(read?.pageCount == 2)
        #expect(read?.path == .device)
        #expect(read?.schemaVersion == 2)
        #expect(published?.ocrText == read?.ocrText)
        #expect(published?.id == id)
    }

    @Test func cloudReadingCountsRedactionBeforeTheCardAndKeepsOCR() async {
        let progress = ReadingProgress(pagesTotal: 1, path: .cloud)
        var order: [String] = []
        let read = await ScanReadingDriver.read(
            pages: [UIImage()],
            path: .cloud,
            progress: progress,
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            schemaVersion: 2,
            recognize: { _ in "Dear Jane, account 12345678" },
            readCard: { text in
                order.append("card")
                return cardResult(ocrText: text, source: .cloud, detailsRemoved: 1)
            },
            redactedDetailCount: { _ in
                order.append("redact")
                return 1
            },
            publish: { _ in order.append("publish") }
        )

        #expect(order == ["redact", "card", "publish"])
        #expect(progress.redactedCount == 1)
        #expect(progress.phase == .validated)
        #expect(read?.path == .cloud)
        #expect(read?.ocrText == "Dear Jane, account 12345678")
        #expect(read?.detailsRemoved == 1)
    }

    @Test func unreadableOCRDoesNotHandOffALetter() async {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        var published = false
        let read = await ScanReadingDriver.read(
            pages: [UIImage()],
            path: .device,
            progress: progress,
            id: UUID(),
            createdAt: Date(),
            schemaVersion: 2,
            recognize: { _ in throw TextRecognizer.Failure.unreadable },
            readCard: { _ in
                Issue.record("A failed scan must not read a card")
                return cardResult(ocrText: "unused", source: .onDevice, detailsRemoved: 0)
            },
            redactedDetailCount: { _ in 0 },
            publish: { _ in published = true }
        )
        #expect(read == nil)
        #expect(published == false)
        #expect(progress.phase == .failed)
        #expect(progress.card == nil)
    }

    @Test func aBlankPageDoesNotStoreALetter() async {
        let progress = ReadingProgress(pagesTotal: 1, path: .device)
        let read = await ScanReadingDriver.read(
            pages: [UIImage()],
            path: .device,
            progress: progress,
            id: UUID(),
            createdAt: Date(),
            schemaVersion: 2,
            recognize: { _ in "  \n" },
            readCard: { _ in
                Issue.record("Blank OCR must not read a card")
                return cardResult(ocrText: "unused", source: .onDevice, detailsRemoved: 0)
            },
            redactedDetailCount: { _ in 0 },
            publish: { _ in }
        )
        #expect(read == nil)
        #expect(progress.phase == .failed)
    }

    private func sampleRead(ocrText: String) -> LetterRead {
        LetterRead(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            card: LetterCard(
                type: .reminder,
                senderKind: .council,
                action: "Pay the balance.",
                deadline: "2027-03-03",
                deadlineQuote: "Pay by 3 March 2027",
                amountQuote: nil,
                watchOuts: [],
                scamSigns: [],
                noActionNeeded: false
            ),
            path: .device,
            pageCount: 1,
            ocrText: ocrText,
            modelVersion: CardReadSource.onDeviceModelVersion,
            latencyMS: 15,
            detailsRemoved: 0,
            schemaVersion: 2
        )
    }

    private func cardResult(
        ocrText: String,
        source: CardReadSource,
        detailsRemoved: Int
    ) -> CardReadResult {
        var card = LetterCard.empty
        card.type = .reminder
        card.senderKind = .council
        card.action = "Pay the balance."
        return CardReadResult(
            card: card,
            source: source,
            modelVersion: source == .onDevice
                ? CardReadSource.onDeviceModelVersion
                : "gemini-3.8-flash",
            latencyMS: 20,
            route: source == .cloud ? .cloudPrimary : .onDeviceOnly,
            attempts: 1,
            rawResponses: [],
            ocrText: ocrText.trimmingCharacters(in: .whitespacesAndNewlines),
            redactedText: source == .cloud ? "Dear [NAME_1]" : nil,
            detailsRemoved: detailsRemoved
        )
    }
}

@MainActor
private struct HistoryHarness {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: LetterRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
