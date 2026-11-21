//
//  LetterRead.swift
//  LetterLens-iOS
//
//  What screen 04 hands to screens 05 and 06. The card schema is unchanged.
//  A likely scam is a card with at least one scam sign. There is no other flag.

import SwiftUI

struct LetterRead: Equatable {
    /// Stable for this scan. Reopening the card uses the same id, so history is written once.
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var card: LetterCard
    var path: ReadingPath
    var pageCount: Int
    /// The scan's OCR text. Stored on `LetterRecord.ocrText`. Not a new field.
    var ocrText: String
    var modelVersion: String = ""
    var latencyMS: Int = 0
    var detailsRemoved: Int = 0
    var schemaVersion: Int = 2

    var fromLine: String {
        let sender = "From \(card.senderKind.title)"
        // Stored letters do not keep a page count. Zero must not pretend there was one page.
        guard pageCount > 0 else { return sender }
        let pages = pageCount == 1 ? "1 page" : "\(pageCount) pages"
        return "\(sender) · \(pages)"
    }

    /// History draft for this hand-off. Nil when there is no OCR text to store.
    func historyDraft() -> LetterHistory.Draft? {
        let text = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard let cardJSON = try? CardJSON.encodeString(card) else { return nil }
        let source: CardReadSource = path == .cloud ? .cloud : .onDevice
        return LetterHistory.Draft(
            id: id,
            createdAt: createdAt,
            ocrText: text,
            cardJSON: cardJSON,
            sourceRaw: source.rawValue,
            modelVersion: modelVersion,
            latencyMS: latencyMS,
            detailsRemoved: detailsRemoved,
            schemaVersion: schemaVersion
        )
    }
}

extension LetterCard {
    /// `scam_signs` is the only scam field on the v2 card.
    var opensScamWarning: Bool {
        scamSigns.contains { sign in
            !sign.sign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// System back button, plus the existing on-device or cloud pill.
/// The pill opts out of the toolbar's shared glass so it stays one capsule.
struct LetterProvenanceToolbar: ViewModifier {
    var path: ReadingPath

    private var provenance: Provenance {
        switch path {
        case .device:
            .device
        case .cloud:
            .cloudRead
        }
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LLProvenanceBadge(kind: provenance)
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension View {
    func letterProvenanceToolbar(path: ReadingPath) -> some View {
        modifier(LetterProvenanceToolbar(path: path))
    }
}
