//
//  UnsupportedDeviceFlow.swift
//  LetterLens-iOS
//
//  Which sheet to show when this iPhone cannot read a letter on device.
//  `ll.allowCloudFallback` on means screen 07, and we ask on every letter.
//  The switch off, or Never upload, means state 17. No cloud button, nothing is sent.
//  No network call lives here. The view only offers the actions this type returns.

import Foundation

enum UnsupportedDeviceRoute: Equatable, Sendable {
    /// On-device reading can run. No sheet.
    case onDevice
    /// Screen 07. Cloud fallback is on, so we ask before this letter.
    case cloudFallback
    /// State 17. Explain and stop. No cloud button.
    case keepPrivate
}

/// Why state 17 is up. Never upload wins when both switches block the cloud.
enum KeepPrivateCause: Equatable, Sendable {
    case neverUpload
    case cloudFallbackOff
}

enum UnsupportedDevicePrompt: Equatable, Sendable {
    case cloudFallback
    case keepPrivate

    var heroSymbolName: String {
        switch self {
        case .cloudFallback: "cloud"
        case .keepPrivate: "lock.fill"
        }
    }

    /// State 17's tile stays neutral. Green and blue are for where a letter was read.
    var heroIsNeutral: Bool {
        self == .keepPrivate
    }

    var actions: [UnsupportedDeviceAction] {
        switch self {
        case .cloudFallback:
            [.readInCloud, .notNow]
        case .keepPrivate:
            [.keepPrivateAndClose, .openPrivacySettings]
        }
    }
}

enum UnsupportedDeviceAction: Equatable, Hashable, Sendable {
    case readInCloud
    case notNow
    case keepPrivateAndClose
    case openPrivacySettings

    var isCloudRead: Bool { self == .readInCloud }
}

struct UnsupportedDeviceFlow: Equatable, Sendable {
    var onDeviceSupported: Bool
    var neverUpload: Bool
    /// `ll.allowCloudFallback`. On means ask every time (screen 07).
    var allowCloudFallback: Bool

    var route: UnsupportedDeviceRoute {
        if onDeviceSupported {
            return .onDevice
        }
        if neverUpload || !allowCloudFallback {
            return .keepPrivate
        }
        return .cloudFallback
    }

    var prompt: UnsupportedDevicePrompt? {
        switch route {
        case .cloudFallback: .cloudFallback
        case .keepPrivate: .keepPrivate
        case .onDevice: nil
        }
    }

    var keepPrivateCause: KeepPrivateCause? {
        guard route == .keepPrivate else { return nil }
        return neverUpload ? .neverUpload : .cloudFallbackOff
    }

    var actions: [UnsupportedDeviceAction] {
        prompt?.actions ?? []
    }

    /// True only for screen 07. State 17 draws no cloud button.
    var showsCloudButton: Bool {
        actions.contains(.readInCloud)
    }
}

/// What a button on sheet 07 or 17 decided. Drag-down is a decline only when this is empty.
struct SheetChoiceRecord: Equatable, Sendable {
    enum SendChoice: Equatable, Sendable {
        case allowed
        case declined
    }

    struct Resolution: Equatable, Sendable {
        var choice: SendChoice
        /// True when dismiss itself declined, because no button had been pressed.
        var declinedByDismiss: Bool
    }

    private(set) var choice: SendChoice?

    mutating func record(_ choice: SendChoice) {
        self.choice = choice
    }

    mutating func resolveDismiss() -> Resolution {
        if let choice {
            return Resolution(choice: choice, declinedByDismiss: false)
        }
        choice = .declined
        return Resolution(choice: .declined, declinedByDismiss: true)
    }
}
