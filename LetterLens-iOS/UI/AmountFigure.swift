//
//  AmountFigure.swift
//  LetterLens-iOS
//
//  Pulls the one currency figure out of an amount quote.
//  The result is a slice of that quote. It is not parsed or rewritten.

import Foundation

enum AmountFigure {
    /// £/$/€ glued to the digits, or GBP/EUR/USD, a space, then the digits.
    /// Thousands commas and a decimal are optional. The characters are the quote's own.
    static func extract(from quote: String) -> Substring? {
        let range = NSRange(quote.startIndex..<quote.endIndex, in: quote)
        let matches = expression.matches(in: quote, range: range)
        guard matches.count == 1, let span = Range(matches[0].range, in: quote) else {
            return nil
        }
        return quote[span]
    }

    private static let expression: NSRegularExpression = {
        let pattern = #"""
        (?:[£$€](?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?|\b(?:GBP|EUR|USD) (?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?)(?![\d,])
        """#
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Amount figure pattern failed to compile: \(error)")
        }
    }()
}

/// What screen 05 shows for `amount_quote`. Nil is the missing card.
/// A quote with no single figure is quote-only, not the missing card.
enum AmountPresentation: Equatable {
    case found(figure: String, quote: String)
    case quoteOnly(quote: String)
    case missing

    init(quote: String?) {
        guard let quote else {
            self = .missing
            return
        }
        if let figure = AmountFigure.extract(from: quote) {
            self = .found(figure: String(figure), quote: quote)
        } else {
            self = .quoteOnly(quote: quote)
        }
    }

    var figure: String? {
        if case .found(let figure, _) = self { return figure }
        return nil
    }

    var quotedText: String? {
        switch self {
        case .found(_, let quote), .quoteOnly(let quote):
            quote
        case .missing:
            nil
        }
    }

    var isQuoteOnly: Bool {
        if case .quoteOnly = self { return true }
        return false
    }
}

enum AmountVisibility {
    /// Bill, reminder, final notice and penalty only. Every other type is listed
    /// so a new case has to choose.
    static func showsRow(for type: LetterType) -> Bool {
        switch type {
        case .bill, .reminder, .finalNotice, .penalty:
            true
        case .changeNotice, .informationRequest, .consentRequest, .refund, .information, .appointment, .other, .notSure:
            false
        }
    }
}
