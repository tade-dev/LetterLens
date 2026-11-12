//
//  ModelCallClassifier.swift
//  LetterLens-iOS
//

import FirebaseAILogic
import Foundation
import FoundationModels

/// Decides whether an on-device model failure is a guardrail or sensitive-content block.
///
/// Those blocks were intermittent on the 15-letter run: the same letter succeeded on a
/// second on-device call. Typed errors are checked first. The domain string is only the
/// fallback, for `com.apple.SensitiveContentAnalysisML`.
enum ModelCallClassifier {
    /// Apple's sensitive-content analysis framework. Error 15 showed up as
    /// `com.apple.SensitiveContentAnalysisML error 15`.
    static let sensitiveContentDomain = "com.apple.SensitiveContentAnalysisML"

    static func isOnDeviceGuardrail(_ error: Error) -> Bool {
        isOnDeviceGuardrail(error, depth: 0)
    }

    private static func isOnDeviceGuardrail(_ error: Error, depth: Int) -> Bool {
        if depth > 5 { return false }
        if isTypedGuardrail(error, depth: depth) { return true }
        let bridged = error as NSError
        if isSensitiveContentDomain(bridged.domain) { return true }
        if let underlying = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
            return isOnDeviceGuardrail(underlying, depth: depth + 1)
        }
        return false
    }

    /// `LanguageModelSession.GenerationError.guardrailViolation` is the on-device case whose
    /// description is "The model's safety guardrails were triggered." Firebase wraps some
    /// failures in `GenerativeModelSession.GenerationError.internalError` and keeps the
    /// original error as `underlyingError`.
    private static func isTypedGuardrail(_ error: Error, depth: Int) -> Bool {
        if let generation = error as? GenerativeModelSession.GenerationError {
            switch generation {
            case .internalError(_, let underlying):
                return isOnDeviceGuardrail(underlying, depth: depth + 1)
            case .assetsUnavailable, .decodingFailure, .concurrentRequests, .unsupportedPromptContent:
                return false
            @unknown default:
                return false
            }
        }

        if let generation = error as? FoundationModels.LanguageModelSession.GenerationError {
            switch generation {
            case .guardrailViolation:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Domain-string fallback. A matching description with some other domain is not a block.
    static func isSensitiveContentDomain(_ domain: String) -> Bool {
        if domain.caseInsensitiveCompare(sensitiveContentDomain) == .orderedSame {
            return true
        }
        return domain.localizedCaseInsensitiveContains("SensitiveContentAnalysis")
    }
}
