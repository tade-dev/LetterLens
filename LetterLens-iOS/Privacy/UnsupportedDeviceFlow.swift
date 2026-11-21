//
//  UnsupportedDeviceFlow.swift
//  LetterLens-iOS
//
//  Which sheet to show when this iPhone cannot read a letter on device.
//  Never upload off means screen 07, and we ask before every cloud read.
//  Never upload on means state 17. No cloud button, nothing is sent.
//  No network call lives here. The view only offers the actions this type returns.

import Foundation

enum UnsupportedDeviceRoute: Equatable, Sendable {
    /// On-device reading can run. No sheet.
    case onDevice
    /// Screen 07. Never upload is off, so we ask before this letter is read in the cloud.
    case cloudFallback
    /// State 17. Never upload is on. Explain and stop. No cloud button.
    case keepPrivate
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

    var route: UnsupportedDeviceRoute {
        if onDeviceSupported {
            return .onDevice
        }
        if neverUpload {
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

    /// State 17 has one cause: Never upload is on, and this iPhone cannot read on its own.
    var isKeepPrivateBecauseNeverUpload: Bool {
        route == .keepPrivate && neverUpload
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
