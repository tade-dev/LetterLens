//
//  ConsentState.swift
//  LetterLens-iOS
//

import Foundation

/// The two switches that decide whether redacted text may leave the device.
struct ConsentState: Equatable {
    /// Forces on-device only, including when the system model is unavailable.
    var neverUpload: Bool
    /// True only after the user has agreed to send the redacted text.
    var cloudConsent: Bool

    var router: ModelRouter {
        ModelRouter(neverUpload: neverUpload, cloudConsent: cloudConsent)
    }
}
