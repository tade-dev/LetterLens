//
//  QuoteChecker.swift
//  LetterLens-iOS
//

import Foundation

/// A quote is in the OCR text when the words match after whitespace is collapsed.
/// Comparison is case-insensitive. Punctuation and the pound sign still have to match.
enum QuoteChecker {
    static func contains(_ quote: String?, in text: String) -> Bool {
        verbatimSpan(of: quote, in: text) != nil
    }

    /// The OCR slice that matches `quote` after whitespace is collapsed and case is ignored.
    /// The returned string is copied from `text`, so a lowercased model quote becomes the
    /// original letters from the scan.
    static func verbatimSpan(of quote: String?, in text: String) -> String? {
        guard let quote = LetterCard.nullish(quote) else { return nil }
        let (needle, _) = indexedNormalisation(quote)
        guard !needle.isEmpty else { return nil }
        let (haystack, indexes) = indexedNormalisation(text)
        guard let range = haystack.range(of: needle, options: [.caseInsensitive]) else { return nil }
        let start = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
        let end = haystack.distance(from: haystack.startIndex, to: range.upperBound)
        guard start < end, end <= indexes.count else { return nil }
        return String(text[indexes[start]...indexes[end - 1]])
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

    /// Same collapsing rules as `normalise`, keeping the original index of each kept character.
    private static func indexedNormalisation(_ text: String) -> (String, [String.Index]) {
        var normalised = ""
        var indexes: [String.Index] = []
        var pendingSpace: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if isWhitespace(character) {
                if !normalised.isEmpty, pendingSpace == nil {
                    pendingSpace = index
                }
            } else {
                if let space = pendingSpace {
                    normalised.append(" ")
                    indexes.append(space)
                    pendingSpace = nil
                }
                normalised.append(character)
                indexes.append(index)
            }
            index = text.index(after: index)
        }
        return (normalised, indexes)
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
