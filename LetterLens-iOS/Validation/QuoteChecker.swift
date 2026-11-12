//
//  QuoteChecker.swift
//  LetterLens-iOS
//

import Foundation

/// A quote is in the OCR text when the words match after whitespace is collapsed.
/// Comparison is case-insensitive. Punctuation and the pound sign still have to match.
enum QuoteChecker {
    static func contains(_ quote: String?, in text: String) -> Bool {
        guard let quote = LetterCard.nullish(quote) else { return false }
        let needle = normalise(quote)
        guard !needle.isEmpty else { return false }
        return normalise(text).range(of: needle, options: [.caseInsensitive]) != nil
    }

    /// Turns line breaks and repeated spaces into a single space. Nothing else is removed.
    static func normalise(_ text: String) -> String {
        let scalars = text.unicodeScalars.map { scalar -> Character in
            CharacterSet.whitespacesAndNewlines.contains(scalar) ? " " : Character(scalar)
        }
        return String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
