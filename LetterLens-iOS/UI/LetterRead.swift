//
//  LetterRead.swift
//  LetterLens-iOS
//
//  What screen 04 hands to screens 05 and 06. The card schema is unchanged.
//  A likely scam is a card with at least one scam sign. There is no other flag.

import SwiftUI

struct LetterRead: Equatable {
    var card: LetterCard
    var path: ReadingPath
    var pageCount: Int
    /// The scan's OCR text. Stored on `LetterRecord.ocrText`. Not a new field.
    var ocrText: String

    var fromLine: String {
        let sender = "From \(card.senderKind.title)"
        // Stored letters do not keep a page count. Zero must not pretend there was one page.
        guard pageCount > 0 else { return sender }
        let pages = pageCount == 1 ? "1 page" : "\(pageCount) pages"
        return "\(sender) · \(pages)"
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

extension ReadingPath {
    /// Screens 05 and 06 are handed this path, not `CardReadResult.source`.
    /// Device stays the on-iPhone pill. Cloud stays the cloud pill.
    var letterProvenance: Provenance {
        switch self {
        case .device:
            .device
        case .cloud:
            .cloudRead
        }
    }
}

/// The labelled provenance pill. The system back button stays in the navigation bar.
struct LetterProvenancePill: View {
    var path: ReadingPath

    var body: some View {
        LLProvenanceBadge(kind: path.letterProvenance)
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
