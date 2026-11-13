//
//  PrivacySettingsModel.swift
//  LetterLens-iOS
//
//  Settings the Privacy screen and the cloud-fallback sheet share.
//  `ll.neverUpload` and `ll.allowCloudFallback` are the keys `DebugPipelineModel`
//  writes on the scan-to-card branch. There is no separate ask-before key.
//  Cloud fallback on means we ask before every letter. Off means state 17.
//
//  On-device status is an input. The pipeline reads
//  `FirebaseAI.SystemLanguageModel.default.availability` and only switches on
//  `.available` / `.unavailable`. This target does not import Firebase or FoundationModels.

import Foundation
import Observation

enum PrivacyPreference {
    static let neverUpload = "ll.neverUpload"
    static let allowCloudFallback = "ll.allowCloudFallback"

    static let openSourceURL = URL(string: "https://github.com/tade-dev/LetterLens/blob/main/LICENSE")!

    static func readNeverUpload(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: neverUpload)
    }

    static func writeNeverUpload(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: neverUpload)
    }

    static func readAllowCloudFallback(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: allowCloudFallback)
    }

    static func writeAllowCloudFallback(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: allowCloudFallback)
    }
}

enum StoredLettersCopy {
    static func detail(count: Int) -> String {
        let count = max(0, count)
        switch count {
        case 0:
            return String(localized: "No letters stored on this iPhone")
        case 1:
            return String(localized: "1 letter, on this iPhone only")
        default:
            return String(localized: "\(count) letters, on this iPhone only")
        }
    }
}

/// What the Privacy status row may say. Map this from the pipeline's availability.
enum OnDeviceReadingAvailability: Equatable, Sendable {
    case available
    case unavailable
}

struct OnDeviceStatusStyle: Equatable, Sendable {
    enum Tint: Equatable, Sendable {
        /// Device green. Only when on-device reading is actually ready.
        case device
        /// `fillQuiet` tile. Nothing has been read, and the model is not ready.
        case neutral
    }

    var symbolName: String
    var tint: Tint
}

extension OnDeviceReadingAvailability {
    var statusStyle: OnDeviceStatusStyle {
        switch self {
        case .available:
            OnDeviceStatusStyle(symbolName: "checkmark.shield.fill", tint: .device)
        case .unavailable:
            OnDeviceStatusStyle(symbolName: "lock.fill", tint: .neutral)
        }
    }
}

@MainActor
@Observable
final class PrivacySettingsModel {
    private let defaults: UserDefaults
    private let writesDefaults: Bool

    var neverUpload: Bool
    var allowCloudFallback: Bool

    /// `writesDefaults` is false in previews so toggling does not touch the simulator store.
    init(
        neverUpload: Bool = false,
        allowCloudFallback: Bool = false,
        defaults: UserDefaults = .standard,
        writesDefaults: Bool = true
    ) {
        self.defaults = defaults
        self.writesDefaults = writesDefaults
        if writesDefaults {
            self.neverUpload = PrivacyPreference.readNeverUpload(from: defaults)
            self.allowCloudFallback = PrivacyPreference.readAllowCloudFallback(from: defaults)
        } else {
            self.neverUpload = neverUpload
            self.allowCloudFallback = allowCloudFallback
        }
    }

    func setNeverUpload(_ value: Bool) {
        neverUpload = value
        commit()
    }

    func setAllowCloudFallback(_ value: Bool) {
        allowCloudFallback = value
        commit()
    }

    func commit() {
        guard writesDefaults else { return }
        PrivacyPreference.writeNeverUpload(neverUpload, to: defaults)
        PrivacyPreference.writeAllowCloudFallback(allowCloudFallback, to: defaults)
    }

    func unsupportedFlow(onDevice availability: OnDeviceReadingAvailability) -> UnsupportedDeviceFlow {
        UnsupportedDeviceFlow(
            onDeviceSupported: availability == .available,
            neverUpload: neverUpload,
            allowCloudFallback: allowCloudFallback
        )
    }
}
