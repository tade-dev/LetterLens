//
//  LetterDeadlineFormat.swift
//  LetterLens-iOS
//
//  Turns a v2 `deadline` (`YYYY-MM-DD`) into the letter-card date.
//  The schema is not changed. A value that is not that calendar date is hidden.

import Foundation

struct LetterDeadline: Equatable {
    var dateText: String
    var daysLeft: Int

    /// Nil once the date has passed. The card has no overdue sentence.
    var daysLeftText: String? {
        switch daysLeft {
        case ..<0:
            nil
        case 1:
            "1 day left"
        default:
            "\(daysLeft) days left"
        }
    }
}

enum LetterDeadlineFormat {
    static func parse(_ iso: String, now: Date = .now) -> LetterDeadline? {
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
        formatter.dateFormat = "EEE d MMMM yyyy"

        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0
        return LetterDeadline(dateText: formatter.string(from: date), daysLeft: days)
    }
}
