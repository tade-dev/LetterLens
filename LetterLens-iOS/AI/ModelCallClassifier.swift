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

    static func summary(_ error: Error) -> String {
        let diagnostic = diagnostic(error)
        return "\(diagnostic.domain) error \(diagnostic.code)"
    }

    /// HTTP status from `BackendError`, including when it is nested under another error.
    /// `com.google.firebase.firebaseai.BackendError error 429` is HTTP 429.
    static func httpStatus(_ error: Error) -> Int? {
        httpStatus(error, depth: 0)
    }

    /// Seconds from a `Retry-After` value on the error, when the SDK or the bridge exposes one.
    static func retryAfterSeconds(_ error: Error) -> Double? {
        retryAfterSeconds(error, depth: 0)
    }

    static func isCloudRetryable(_ error: Error) -> Bool {
        guard let status = httpStatus(error) else { return false }
        return status == 429 || status == 503
    }

    private static func httpStatus(_ error: Error, depth: Int) -> Int? {
        if depth > 5 { return nil }
        if let contentError = error as? GenerateContentError, case .internalError(let underlying) = contentError {
            return httpStatus(underlying, depth: depth + 1)
        }
        let bridged = error as NSError
        if isBackendErrorDomain(bridged.domain), bridged.code > 0 {
            return bridged.code
        }
        if let underlying = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
            return httpStatus(underlying, depth: depth + 1)
        }
        return nil
    }

    private static func retryAfterSeconds(_ error: Error, depth: Int) -> Double? {
        if depth > 5 { return nil }
        let bridged = error as NSError
        if let seconds = retryAfterSeconds(in: bridged.userInfo) {
            return seconds
        }
        if let contentError = error as? GenerateContentError, case .internalError(let underlying) = contentError {
            return retryAfterSeconds(underlying, depth: depth + 1)
        }
        if let underlying = bridged.userInfo[NSUnderlyingErrorKey] as? Error {
            return retryAfterSeconds(underlying, depth: depth + 1)
        }
        return nil
    }

    private static func retryAfterSeconds(in userInfo: [String: Any]) -> Double? {
        for (key, value) in userInfo where key.caseInsensitiveCompare("Retry-After") == .orderedSame {
            switch value {
            case let seconds as Int:
                return Double(seconds)
            case let seconds as Double:
                return seconds
            case let seconds as NSNumber:
                return seconds.doubleValue
            case let seconds as String:
                return Double(seconds.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                return nil
            }
        }
        return nil
    }

    static let backendErrorDomain = "com.google.firebase.firebaseai.BackendError"

    private static func isBackendErrorDomain(_ domain: String) -> Bool {
        domain == backendErrorDomain || domain.hasSuffix(".BackendError")
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
