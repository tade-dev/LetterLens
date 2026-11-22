//
//  LetterCopy.swift
//  LetterLens-iOS
//

import Foundation

/// Shared product copy. The disclaimer is the one string named by the Clear Ink tokens.
enum LetterCopy {
    /// `Localizable.xcstrings` key `disclaimer.short`.
    static let disclaimerShort = String(
        localized: "disclaimer.short",
        defaultValue: "Explains letters. Not legal or financial advice."
    )

    static let photosNeverLeave = "Photos never leave this iPhone."

    /// The scam hero on screen 06, and the summary line Home shows in its place.
    static let stopBeforeYouPay = String(localized: "Stop before you pay or click")
}
