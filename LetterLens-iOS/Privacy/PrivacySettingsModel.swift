//
//  PrivacySettingsModel.swift
//  LetterLens-iOS
//
//  Settings the Privacy screen and the cloud-fallback sheet share.
//  `ll.neverUpload` is the key `DebugPipelineModel` writes on the scan-to-card branch.
//  This screen does not write `ll.allowCloudFallback`. That flag means cloud fallback
//  is permitted at all. "Ask before using the cloud" is a different choice, so it
//  has its own key. Absent means ask (the mockup default).
//
//  On-device status is an input. The pipeline reads
//  `FirebaseAI.SystemLanguageModel.default.availability` and only switches on
//  `.available` / `.unavailable`. This target does not import Firebase or FoundationModels.

import Foundation
import Observation

enum PrivacyPreference {
    static let neverUpload = "ll.neverUpload"
    /// Owned by the scan-to-card pipeline. Settings must not write it.
    static let allowCloudFallback = "ll.allowCloudFallback"
    static let askBeforeCloud = "ll.askBeforeCloud"

    static let openSourceURL = URL(string: "https://github.com/tade-dev/LetterLens/blob/main/LICENSE")!

    static func readNeverUpload(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: neverUpload)
    }

    static func writeNeverUpload(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: neverUpload)
    }

    static func readAskBeforeCloud(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: askBeforeCloud) != nil else { return true }
        return defaults.bool(forKey: askBeforeCloud)
    }

    static func writeAskBeforeCloud(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: askBeforeCloud)
    }
}

enum StoredLettersCopy {
    static func detail(count: Int) -> String {
        let count = max(0, count)
        switch count {
        case 0:
            String(localized: "No letters stored on this iPhone")
        case 1:
            String(localized: "1 letter, on this iPhone only")
        default:
            String(localized: "\(count) letters, on this iPhone only")
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
    var askBeforeCloud: Bool

    /// `writesDefaults` is false in previews so toggling does not touch the simulator store.
    init(
        neverUpload: Bool = false,
        askBeforeCloud: Bool = true,
        defaults: UserDefaults = .standard,
        writesDefaults: Bool = true
    ) {
        self.defaults = defaults
        self.writesDefaults = writesDefaults
        if writesDefaults {
            self.neverUpload = PrivacyPreference.readNeverUpload(from: defaults)
            self.askBeforeCloud = PrivacyPreference.readAskBeforeCloud(from: defaults)
        } else {
            self.neverUpload = neverUpload
            self.askBeforeCloud = askBeforeCloud
        }
    }

    func setNeverUpload(_ value: Bool) {
        neverUpload = value
        commit()
    }

    func setAskBeforeCloud(_ value: Bool) {
        askBeforeCloud = value
        commit()
    }

    /// Screen 07's "Don't ask again on this phone". Inverse of ask-before.
    func setDontAskAgain(_ value: Bool) {
        setAskBeforeCloud(!value)
    }

    func commit() {
        guard writesDefaults else { return }
        PrivacyPreference.writeNeverUpload(neverUpload, to: defaults)
        PrivacyPreference.writeAskBeforeCloud(askBeforeCloud, to: defaults)
    }

    func unsupportedFlow(onDevice availability: OnDeviceReadingAvailability) -> UnsupportedDeviceFlow {
        UnsupportedDeviceFlow(
            onDeviceSupported: availability == .available,
            neverUpload: neverUpload,
            askBeforeCloud: askBeforeCloud
        )
    }
}
