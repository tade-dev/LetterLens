//
//  UKDateParser.swift
//  LetterLens-iOS
//

import Foundation

/// Reads the first calendar date out of a quote. UK order: day, then month, then year.
/// A relative phrase such as "within 14 days" has no calendar date, so the result is nil.
enum UKDateParser {
    private static let months: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sept": 9, "sep": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12,
    ]

    /// Longer month names are listed first so "sept" does not win over "september".
    private static let monthNames = [
        "january", "february", "march", "april", "june", "july", "august",
        "september", "october", "november", "december", "sept",
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
    ].joined(separator: "|")

    private static let textual = try? NSRegularExpression(
        pattern: "(?i)\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(\(monthNames))\\s+(\\d{4})\\b"
    )

    private static let numeric = try? NSRegularExpression(
        pattern: "\\b(\\d{1,2})[/\\-.](\\d{1,2})[/\\-.](\\d{4})\\b"
    )

    /// The first valid calendar date in `text`, as `YYYY-MM-DD`.
    static func firstDate(in text: String) -> String? {
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        var found: [(location: Int, iso: String)] = []

        if let textual {
            for match in textual.matches(in: text, range: full) {
                guard match.numberOfRanges == 4,
                      let day = integer(match, group: 1, in: nsText),
                      let month = months[nsText.substring(with: match.range(at: 2)).lowercased()],
                      let year = integer(match, group: 3, in: nsText),
                      let iso = isoDate(day: day, month: month, year: year)
                else { continue }
                found.append((match.range.location, iso))
            }
        }

        if let numeric {
            for match in numeric.matches(in: text, range: full) {
                guard match.numberOfRanges == 4,
                      let day = integer(match, group: 1, in: nsText),
                      let month = integer(match, group: 2, in: nsText),
                      let year = integer(match, group: 3, in: nsText),
                      let iso = isoDate(day: day, month: month, year: year)
                else { continue }
                found.append((match.range.location, iso))
            }
        }

        return found.min { $0.location < $1.location }?.iso
    }

    private static func integer(_ match: NSTextCheckingResult, group: Int, in text: NSString) -> Int? {
        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return Int(text.substring(with: range))
    }

    /// Day / month / year. 03/04/2026 is 3 April 2026, not 4 March.
    private static func isoDate(day: Int, month: Int, year: Int) -> String? {
        guard (1900...2200).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.day = day
        components.month = month
        components.year = year
        guard let date = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.day, .month, .year], from: date)
        guard back.day == day, back.month == month, back.year == year else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
