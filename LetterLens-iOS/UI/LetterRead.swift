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

    var fromLine: String {
        let pages = pageCount == 1 ? "1 page" : "\(pageCount) pages"
        return "From \(card.senderKind.title) · \(pages)"
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
