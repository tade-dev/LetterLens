//
//  ModelRouter.swift
//  LetterLens-iOS
//

import FirebaseAILogic
import Foundation

/// Where a later inference call is allowed to run.
///
/// Session objects are not created here. `.onDeviceOnly` means the caller must
/// not construct a cloud model or a `HybridModel`.
enum ModelRoute: Equatable {
    /// System model only. Never upload, or the user has not consented to cloud.
    case onDeviceOnly
    /// Card path: on-device model first, cloud model only as the consented fallback.
    case hybridOnDeviceFirst
    /// Cloud model first. Used for the plan, and for the card when the system model is unavailable.
    case cloudPrimary
}

/// Which letter task the router is choosing a route for.
enum InferenceTask: Equatable {
    /// Explain the letter. On-device first once cloud consent allows a fallback.
    case card
    /// Next steps. Cloud primary once consent allows it.
    case plan
}

/// Chooses a route from the never-upload switch, cloud consent, and on-device availability.
///
/// Photos and unredacted personal data never leave the device. This type does not
/// create a Firebase AI session and does not perform a network call.
struct ModelRouter: Equatable {
    var neverUpload: Bool
    /// True only after the user has agreed to send redacted text to the cloud.
    var cloudConsent: Bool

    /// Firebase AI Logic's wrapper around `FoundationModels.SystemLanguageModel`.
    var onDeviceAvailability: FirebaseAI.SystemLanguageModel.Availability {
        FirebaseAI.SystemLanguageModel.default.availability
    }

    /// `.onDeviceOnly` when nothing may be uploaded. Otherwise the card prefers
    /// on-device and the plan stays cloud-primary.
    func route(for task: InferenceTask) -> ModelRoute {
        let onDeviceReady = isOnDeviceReady(onDeviceAvailability)
        if neverUpload || !cloudConsent {
            return .onDeviceOnly
        }

        switch task {
        case .card:
            return onDeviceReady ? .hybridOnDeviceFirst : .cloudPrimary
        case .plan:
            return .cloudPrimary
        }
    }

    /// Cloud and hybrid sessions are allowed only for routes other than `.onDeviceOnly`.
    func allowsCloudOrHybridSession(for task: InferenceTask) -> Bool {
        route(for: task) != .onDeviceOnly
    }

    private func isOnDeviceReady(
        _ availability: FirebaseAI.SystemLanguageModel.Availability
    ) -> Bool {
        switch availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }
}

// TODO: Create sessions only when `allowsCloudOrHybridSession(for:)` is true.
// Do not construct `FirebaseAI.firebaseAI`, `geminiModel`, or `HybridModel` on the
// `.onDeviceOnly` path. On-device-only mode uses `FirebaseAI.SystemLanguageModel`
// alone, with no cloud fallback.
//
// Card, on-device first, per the Firebase AI Logic hybrid iOS docs
// (https://firebase.google.com/docs/ai-logic/hybrid/ios/get-started):
//
//   let ai = FirebaseAI.firebaseAI(backend: .googleAI())
//   let cloudModel = ai.geminiModel(name: cardModelName)
//   let hybridModel = HybridModel(
//       primary: FirebaseAI.SystemLanguageModel.default,
//       secondary: cloudModel
//   )
//   let session = ai.generativeModelSession(model: hybridModel)
//
// `generativeModelSession(model:)` takes a `LanguageModelProvider`. If passing
// `HybridModel` does not typecheck, use the provider form from the same docs:
// `.hybridModel(primary:secondary:)`.
//
// Plan, after consent, is cloud-primary: cloud model as primary and
// `FirebaseAI.SystemLanguageModel.default` as secondary. Still no photos and no
// unredacted personal data.
