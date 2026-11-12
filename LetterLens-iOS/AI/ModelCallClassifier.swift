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

    /// Domain and code of the innermost error, after peeling Firebase internal wrappers.
    static func diagnostic(_ error: Error) -> (domain: String, code: Int) {
        let peeled = deepest(error, depth: 0) as NSError
        return (peeled.domain, peeled.code)
    }

    private static func isOnDeviceGuardrail(_ error: Error, depth: Int) -> Bool {
        if depth > 5 { return false }
        if error is OnDeviceCallTimeout { return true }
        if let urlError = error as? URLError, urlError.code == .timedOut { return true }
        if isGenerateContentInternal(error) { return true }
        if isTypedGuardrail(error) { return true }
        let bridged = error as NSError
        if bridged.domain == NSURLErrorDomain && bridged.code == NSURLErrorTimedOut { return true }
        if isSensitiveContentDomain(bridged.domain) { return true }
        if isGenerateContentInternalDomain(bridged.domain), bridged.code == 0 { return true }
        if let underlying = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
            return isOnDeviceGuardrail(underlying, depth: depth + 1)
        }
        return false
    }

    /// `GenerateContentError.internalError` is case 0. The harness logged it as
    /// `FirebaseAILogic.GenerateContentError error 0` after the on-device call sat for ~190s.
    private static func isGenerateContentInternal(_ error: Error) -> Bool {
        guard let contentError = error as? GenerateContentError else { return false }
        if case .internalError = contentError { return true }
        return false
    }

    private static func isGenerateContentInternalDomain(_ domain: String) -> Bool {
        domain == "FirebaseAILogic.GenerateContentError" || domain.hasSuffix(".GenerateContentError")
    }

    private static func deepest(_ error: Error, depth: Int) -> Error {
        if depth > 5 { return error }
        if let contentError = error as? GenerateContentError, case .internalError(let underlying) = contentError {
            return deepest(underlying, depth: depth + 1)
        }
        if let generation = error as? GenerativeModelSession.GenerationError,
           case .internalError(_, let underlying) = generation {
            return deepest(underlying, depth: depth + 1)
        }
        let bridged = error as NSError
        if let underlying = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
            return deepest(underlying, depth: depth + 1)
        }
        return error
    }

    /// `LanguageModelSession.GenerationError.guardrailViolation` is the on-device case whose
    /// description is "The model's safety guardrails were triggered." Firebase wraps some
    /// failures in `GenerativeModelSession.GenerationError.internalError` and keeps the
    /// original error as `underlyingError`.
    private static func isTypedGuardrail(_ error: Error) -> Bool {
        if let generation = error as? GenerativeModelSession.GenerationError {
            switch generation {
            case .internalError:
                return true
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

/// Thrown when an on-device model call is still running after `CardService.onDeviceTimeoutSeconds`.
struct OnDeviceCallTimeout: Error {
    var seconds: Int
}
