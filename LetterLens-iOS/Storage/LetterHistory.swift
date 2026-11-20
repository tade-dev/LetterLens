//
//  LetterHistory.swift
//  LetterLens-iOS
//
//  Writes one LetterRecord when a scan's card is shown.
//  Uses the existing fields only. OCR text goes in `ocrText`.
//  The same id is not inserted again.

import Foundation
import SwiftData

enum LetterHistory {
    struct Draft: Equatable, Sendable {
        var id: UUID
        var createdAt: Date
        var ocrText: String
        var cardJSON: String
        var sourceRaw: String
        var modelVersion: String
        var latencyMS: Int
        var detailsRemoved: Int
        var schemaVersion: Int
    }

    enum Result: Equatable {
        case inserted
        case alreadyStored
        case refusedEmptyOCR
    }

    /// Inserts the scan when this id is not already stored and OCR text is present.
    @MainActor
    static func write(_ draft: Draft, into context: ModelContext) throws -> Result {
        let text = draft.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .refusedEmptyOCR }

        let id = draft.id
        let existing = try context.fetch(
            FetchDescriptor<LetterRecord>(predicate: #Predicate { $0.id == id })
        )
        guard existing.isEmpty else { return .alreadyStored }

        let record = LetterRecord(
            id: draft.id,
            createdAt: draft.createdAt,
            ocrText: text,
            cardJSON: draft.cardJSON,
            sourceRaw: draft.sourceRaw,
            modelVersion: draft.modelVersion,
            latencyMS: draft.latencyMS,
            detailsRemoved: draft.detailsRemoved,
            schemaVersion: draft.schemaVersion
        )
        context.insert(record)
        try context.save()
        return .inserted
    }

    @MainActor
    static func write(_ read: LetterRead, into context: ModelContext) throws -> Result {
        guard let draft = read.historyDraft() else { return .refusedEmptyOCR }
        return try write(draft, into: context)
    }
}
