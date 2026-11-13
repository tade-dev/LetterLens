//
//  UnsupportedDeviceFlow.swift
//  LetterLens-iOS
//
//  Which sheet to show when this iPhone cannot read a letter on device.
//  Screen 07 asks before a cloud read. State 17 stops when Never upload is on.
//  No network call lives here. The view only offers the actions this type returns.

import Foundation

enum UnsupportedDeviceRoute: Equatable, Sendable {
    /// On-device reading can run. No sheet.
    case onDevice
    /// Screen 07. The cloud button is the primary action.
    case cloudFallback
    /// The person already chose "Don't ask again". No sheet, so no cloud button.
    /// A later caller may read in the cloud without asking again.
    case readInCloudWithoutAsking
    /// State 17. Explain and stop. No cloud button.
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
    var askBeforeCloud: Bool

    var route: UnsupportedDeviceRoute {
        if onDeviceSupported {
            return .onDevice
        }
        if neverUpload {
            return .keepPrivate
        }
        if askBeforeCloud {
            return .cloudFallback
        }
        return .readInCloudWithoutAsking
    }

    var prompt: UnsupportedDevicePrompt? {
        switch route {
        case .cloudFallback: .cloudFallback
        case .keepPrivate: .keepPrivate
        case .onDevice, .readInCloudWithoutAsking: nil
        }
    }

    var actions: [UnsupportedDeviceAction] {
        prompt?.actions ?? []
    }

    /// True only for screen 07. State 17 and "don't ask again" do not draw a cloud button.
    var showsCloudButton: Bool {
        actions.contains(.readInCloud)
    }

    /// Whether a cloud read is still allowed for this letter. State 17 is not.
    var allowsCloudRead: Bool {
        switch route {
        case .cloudFallback, .readInCloudWithoutAsking: true
        case .onDevice, .keepPrivate: false
        }
    }
}
