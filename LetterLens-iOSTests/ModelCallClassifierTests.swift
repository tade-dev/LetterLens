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
}
