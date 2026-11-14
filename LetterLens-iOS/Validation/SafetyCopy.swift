//
//  SafetyCopy.swift
//  LetterLens-iOS
//

import Foundation

/// Removes wording that calls a letter safe, genuine, or not a scam.
/// The replacement is "signs to check", which is the only scam wording we show.
enum SafetyCopy {
    private static let claims: [NSRegularExpression] = [
        "this letter is safe",
        "the letter is safe",
        "letter is safe",
        "this is safe",
        "it is safe",
        "it's safe",
        "it is genuine",
        "this letter is genuine",
        "the letter is genuine",
        "letter is genuine",
        "this is genuine",
        "is legitimate",
        "not a scam",
        "isn't a scam",
        "is not a scam",
    ].compactMap { phrase in
        let pattern = NSRegularExpression.escapedPattern(for: phrase)
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    static let replacement = "These are signs to check."

    static func cleaned(_ text: String) -> String {
        let sentences = splitSentences(text)
        let rewritten = sentences.map { sentence -> String in
            claims.contains { regex in
                let range = NSRange(sentence.startIndex..., in: sentence)
                return regex.firstMatch(in: sentence, options: [], range: range) != nil
            } ? replacement : sentence
        }
        return rewritten
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitSentences(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "[^.!?]+[.!?]?") else {
            return [text]
        }
        let range = NSRange(text.startIndex..., in: text)
        let parts = regex.matches(in: text, range: range).compactMap { match -> String? in
            guard let slice = Range(match.range, in: text) else { return nil }
            let sentence = text[slice].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
        return parts.isEmpty ? [text] : parts
    }
}
