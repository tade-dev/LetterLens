//
//  HomeLetterLists.swift
//  LetterLens-iOS
//
//  Which stored letters belong under Needs action, and how Home dates them.
//  Needs action: not marked done, and either a deadline still ahead (today counts)
//  or at least one scam sign. Everything else is Earlier.

import Foundation

struct HomeLetter: Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var card: LetterCard
    var path: ReadingPath
    var isDone: Bool
}

enum HomeLetterSection: Equatable {
    case needsAction
    case earlier
}

enum HomeCalendar {
    static var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }

    /// The same ISO date `LetterDeadlineFormat` accepts. Nil for anything else.
    static func date(fromISO iso: String) -> Date? {
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

        let calendar = london
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = london.timeZone
        formatter.calendar = london
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

enum HomeDeadline {
    /// Today or later. A past date, or a value the card would hide, is nil.
    static func upcoming(_ iso: String?, now: Date = .now) -> LetterDeadline? {
        guard let iso, let deadline = LetterDeadlineFormat.parse(iso, now: now), deadline.daysLeft >= 0 else {
            return nil
        }
        return deadline
    }
}

struct HomeDateText: Equatable {
    var visual: String
    var spoken: String
}

enum HomeDateLabel {
    /// Today, a weekday within six days either side, otherwise `d MMM`.
    static func relative(_ date: Date, now: Date = .now) -> HomeDateText {
        let calendar = HomeCalendar.london
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let delta = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch delta {
        case 0:
            return HomeDateText(visual: "Today", spoken: "Today")
        case 1..<7, -6..<0:
            let weekday = HomeCalendar.format(date, pattern: "EEEE")
            return HomeDateText(visual: weekday, spoken: weekday)
        default:
            return HomeDateText(
                visual: HomeCalendar.format(date, pattern: "d MMM"),
                spoken: HomeCalendar.format(date, pattern: "d MMMM yyyy")
            )
        }
    }
}

struct HomeDeadlinePill: Equatable {
    var visual: String
    var spoken: String
}

enum HomeDeadlinePillCopy {
    static func make(iso: String, now: Date = .now) -> HomeDeadlinePill? {
        guard let deadline = HomeDeadline.upcoming(iso, now: now),
              let date = HomeCalendar.date(fromISO: iso)
        else { return nil }

        let short = HomeCalendar.format(date, pattern: "d MMM")
        let long = HomeCalendar.format(date, pattern: "d MMMM")
        switch deadline.daysLeft {
        case 0:
            return HomeDeadlinePill(visual: "Due \(short) · today", spoken: "Due \(long), today")
        case 1:
            return HomeDeadlinePill(visual: "Due \(short) · 1 day", spoken: "Due \(long), 1 day left")
        default:
            return HomeDeadlinePill(
                visual: "Due \(short) · \(deadline.daysLeft) days",
                spoken: "Due \(long), \(deadline.daysLeft) days left"
            )
        }
    }
}

enum HomeScamPillCopy {
    static func count(in card: LetterCard) -> Int {
        card.scamSigns.filter { sign in
            !sign.sign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    static func label(count: Int) -> String {
        count == 1 ? "1 sign to check" : "\(count) signs to check"
    }
}

enum HomeProvenanceCopy {
    static func visual(for path: ReadingPath) -> String {
        switch path {
        case .device: "On device"
        case .cloud: "Read in the cloud"
        }
    }

    static func spoken(for path: ReadingPath) -> String {
        switch path {
        case .device: "Read on this iPhone"
        case .cloud: "Read in the cloud"
        }
    }

    static func symbol(for path: ReadingPath) -> String {
        path == .device ? "lock.fill" : "cloud"
    }
}

enum HomeLetterLists {
    struct Lists: Equatable {
        var needsAction: [HomeLetter]
        var earlier: [HomeLetter]
    }

    static func split(_ letters: [HomeLetter], now: Date = .now) -> Lists {
        let needs = letters
            .filter { needsAction($0, now: now) }
            .sorted { compareNeeds($0, $1, now: now) }
        let earlier = letters
            .filter { !needsAction($0, now: now) }
            .sorted { compareEarlier($0, $1) }
        return Lists(needsAction: needs, earlier: earlier)
    }

    static func needsAction(_ letter: HomeLetter, now: Date = .now) -> Bool {
        guard !letter.isDone else { return false }
        if letter.card.opensScamWarning { return true }
        return HomeDeadline.upcoming(letter.card.deadline, now: now) != nil
    }

    /// Earlier has three lines. Done wins, then the letter's own no-action flag.
    static func earlierSubline(_ letter: HomeLetter) -> String {
        if letter.isDone { return "Done" }
        if letter.card.noActionNeeded { return "For your information" }
        return "No deadline found"
    }

    /// Needs action uses a deadline that is still ahead. Otherwise the day it was stored.
    static func trailingDate(_ letter: HomeLetter, section: HomeLetterSection, now: Date = .now) -> Date {
        if section == .needsAction,
           let iso = letter.card.deadline,
           HomeDeadline.upcoming(iso, now: now) != nil,
           let date = HomeCalendar.date(fromISO: iso) {
            return date
        }
        return letter.createdAt
    }

    private static func compareNeeds(_ lhs: HomeLetter, _ rhs: HomeLetter, now: Date) -> Bool {
        let left = sortKey(lhs, now: now)
        let right = sortKey(rhs, now: now)
        if left.group != right.group { return left.group < right.group }
        if left.group == 0, left.days != right.days { return left.days < right.days }
        return compareEarlier(lhs, rhs)
    }

    private static func compareEarlier(_ lhs: HomeLetter, _ rhs: HomeLetter) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Group 0 has a deadline still ahead, soonest first. Scam-only letters follow.
    private static func sortKey(_ letter: HomeLetter, now: Date) -> (group: Int, days: Int) {
        if let deadline = HomeDeadline.upcoming(letter.card.deadline, now: now) {
            return (0, deadline.daysLeft)
        }
        return (1, 0)
    }
}
