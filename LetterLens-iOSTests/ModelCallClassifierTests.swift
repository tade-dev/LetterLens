//
//  ModelCallClassifierTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct ModelCallClassifierTests {
    @Test func sensitiveContentDomainIsAGuardrailBlock() {
        let error = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        #expect(ModelCallClassifier.isOnDeviceGuardrail(error))
    }

    @Test func aNestedSensitiveContentDomainIsAGuardrailBlock() {
        let inner = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        let outer = NSError(domain: "Wrapped", code: 1, userInfo: [NSUnderlyingErrorKey: inner])
        #expect(ModelCallClassifier.isOnDeviceGuardrail(outer))
    }

    @Test func anotherDomainIsNotAGuardrailBlock() {
        let error = NSError(
            domain: "com.example.network",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The model's safety guardrails were triggered."]
        )
        #expect(!ModelCallClassifier.isOnDeviceGuardrail(error))
        #expect(!ModelCallClassifier.isSensitiveContentDomain("com.apple.foundationmodels"))
    }

    @Test func generateContentErrorZeroIsAnOnDeviceBlock() {
        let error = NSError(domain: "FirebaseAILogic.GenerateContentError", code: 0)
        #expect(ModelCallClassifier.isOnDeviceGuardrail(error))
    }

    @Test func generateContentInternalErrorPeelsTheUnderlyingDomain() {
        let underlying = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        let error = NSError(
            domain: "FirebaseAILogic.GenerateContentError",
            code: 0,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        let diagnostic = ModelCallClassifier.diagnostic(error)
        #expect(diagnostic.domain == "com.apple.SensitiveContentAnalysisML")
        #expect(diagnostic.code == 15)
        #expect(ModelCallClassifier.isOnDeviceGuardrail(error))
    }

    @Test func anotherGenerateContentCaseIsNotAnOnDeviceBlock() {
        let error = NSError(domain: "FirebaseAILogic.GenerateContentError", code: 2)
        #expect(!ModelCallClassifier.isOnDeviceGuardrail(error))
    }

    @Test func aTimeoutIsAnOnDeviceBlock() {
        #expect(ModelCallClassifier.isOnDeviceGuardrail(OnDeviceCallTimeout(seconds: 60)))
        #expect(ModelCallClassifier.isOnDeviceGuardrail(URLError(.timedOut)))
    }
}
