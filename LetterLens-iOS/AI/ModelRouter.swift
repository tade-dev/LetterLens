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

    #if targetEnvironment(simulator)
    /// The Simulator reports the system model as available, then inference fails.
    /// Tests set this to false to exercise the device path.
    var runsOnSimulator: Bool = true
    /// `.system` reads Firebase. Tests pass `.ready` or `.unavailable` instead.
    var onDeviceProbe: OnDeviceProbe = .system
    #endif

    /// Firebase AI Logic's wrapper around `FoundationModels.SystemLanguageModel`.
    /// Simulator builds report unavailable so the card does not wait on a 60s timeout.
    var onDeviceAvailability: FirebaseAI.SystemLanguageModel.Availability {
        #if targetEnvironment(simulator)
        if runsOnSimulator {
            return .unavailable(.unknown)
        }
        return probedAvailability
        #else
        FirebaseAI.SystemLanguageModel.default.availability
        #endif
    }

    /// True when a system-model session is allowed to run.
    var isOnDeviceUsable: Bool {
        if case .available = onDeviceAvailability {
            return true
        }
        return false
    }

    /// `.onDeviceOnly` when nothing may be uploaded. Otherwise the card prefers
    /// on-device and the plan stays cloud-primary.
    func route(for task: InferenceTask) -> ModelRoute {
        let onDeviceReady = resolvedOnDeviceReady
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

    private var resolvedOnDeviceReady: Bool {
        #if targetEnvironment(simulator)
        OnDeviceGate.isReady(
            systemReportsAvailable: probedSystemAvailable,
            runsOnSimulator: runsOnSimulator
        )
        #else
        isOnDeviceReady(onDeviceAvailability)
        #endif
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

    #if targetEnvironment(simulator)
    private var probedSystemAvailable: Bool {
        isOnDeviceReady(probedAvailability)
    }

    private var probedAvailability: FirebaseAI.SystemLanguageModel.Availability {
        switch onDeviceProbe {
        case .system:
            FirebaseAI.SystemLanguageModel.default.availability
        case .ready:
            .available
        case .unavailable:
            .unavailable(.unknown)
        }
    }
    #endif
}

/// Whether the system model may run. Tests pass both values of `runsOnSimulator`.
/// Device builds do not call this; their route uses `SystemLanguageModel.availability` directly.
enum OnDeviceGate {
    static func isReady(systemReportsAvailable: Bool, runsOnSimulator: Bool) -> Bool {
        if runsOnSimulator {
            return false
        }
        return systemReportsAvailable
    }
}

#if targetEnvironment(simulator)
/// Stand-in for `SystemLanguageModel.availability` in tests.
enum OnDeviceProbe: Equatable {
    case system
    case ready
    case unavailable
}
#endif

// `CardService` creates the session. The published on-device-only sample still
// obtains it from `FirebaseAI.firebaseAI().generativeModelSession(model:)`.
// That call does not create a `geminiModel` or a `HybridModel`.
// https://firebase.google.com/docs/ai-logic/hybrid/ios/configuration-options
//
//   let ai = FirebaseAI.firebaseAI(backend: .googleAI())
//   let session = ai.generativeModelSession(model: FirebaseAI.SystemLanguageModel.default)
//
// Hybrid, only after cloud consent, and only with redacted text:
//
//   let cloudModel = ai.geminiModel(name: cardModelName)
//   let hybridModel = HybridModel(
//       primary: FirebaseAI.SystemLanguageModel.default,
//       secondary: cloudModel
//   )
//   let session = ai.generativeModelSession(model: hybridModel)
//
// `HybridModel` conforms to `LanguageModel`, which conforms to `LanguageModelProvider`.
// Which model actually ran is `response.rawResponse.modelVersion`.
// On-device is `apple-foundation-models-system-language-model`.
