//
//  CardRead.swift
//  LetterLens-iOS
//

import Foundation

/// Where the card was actually read. Drives the badge on the debug screen.
enum CardReadSource: String, Equatable {
    case onDevice
    case cloud

    var badgeTitle: String {
        switch self {
        case .onDevice:
            "Read on this iPhone"
        case .cloud:
            "Read in the cloud"
        }
    }

    /// Harness `run.json` value.
    var routeLabel: String {
        switch self {
        case .onDevice:
            "on-device"
        case .cloud:
            "cloud"
        }
    }

    /// `rawResponse.modelVersion` when the system model served the request.
    /// https://firebase.google.com/docs/ai-logic/hybrid/ios/configuration-options
    static let onDeviceModelVersion = "apple-foundation-models-system-language-model"
    static let unknownModelVersion = "unknown-model-version"

    static func resolve(modelVersion: String, route: ModelRoute) -> CardReadSource {
        if modelVersion == onDeviceModelVersion {
            return .onDevice
        }
        if modelVersion.isEmpty || modelVersion == unknownModelVersion {
            // An on-device-only session cannot have used the cloud. A hybrid session can.
            return route == .onDeviceOnly ? .onDevice : .cloud
        }
        return .cloud
    }
}

struct ModelRawResponse: Equatable {
    var chunk: Int
    var attempt: Int
    var text: String
    /// Set when this attempt failed before the model returned text. Guardrail retries are recorded here.
    var error: String? = nil
}

struct CardReadResult: Equatable {
    var card: LetterCard
    var source: CardReadSource
    var modelVersion: String
    var latencyMS: Int
    var route: ModelRoute
    /// Model calls for this letter, including a guardrail retry and a cloud fallback.
    var attempts: Int
    var rawResponses: [ModelRawResponse]
    var ocrText: String
    var redactedText: String?
    var detailsRemoved: Int
}

enum CardPipelineError: LocalizedError {
    case emptyPrompt
    case emptyOCR
    case firebaseNotConfigured
    case privateReadUnavailable(String)
    case emptyModelResponse
    case invalidJSON
    case modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            "The card prompt is empty. Remote Config defaults did not load."
        case .emptyOCR:
            "No text was found on the page."
        case .firebaseNotConfigured:
            "Firebase isn't configured. Add GoogleService-Info.plist to LetterLens-iOS and rebuild."
        case .privateReadUnavailable(let reason):
            "Can't read privately on this iPhone. \(reason)"
        case .emptyModelResponse:
            "The model returned an empty reply."
        case .invalidJSON:
            "The model did not return valid JSON."
        case .modelFailed(let message):
            message
        }
    }
}
