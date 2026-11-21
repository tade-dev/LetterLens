//
//  CardReadSourceTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct CardReadSourceTests {
    @Test func anOnDeviceModelVersionBadgesOnDevice() {
        let source = CardReadSource.resolve(
            modelVersion: CardReadSource.onDeviceModelVersion,
            route: .hybridOnDeviceFirst
        )
        #expect(source == .onDevice)
        #expect(source.badgeTitle == "Read on this iPhone")
    }

    @Test func aGeminiModelVersionBadgesCloudOnTheHybridRoute() {
        let source = CardReadSource.resolve(
            modelVersion: "gemini-3.8-flash",
            route: .hybridOnDeviceFirst
        )
        #expect(source == .cloud)
        #expect(source.badgeTitle == "Read in the cloud")
    }

    @Test func aHybridFailureIsNotLabelledAsTheOnDeviceModel() {
        let label = AttemptModelLabel.forFailedAttempt(route: .hybridOnDeviceFirst)
        #expect(label == "hybrid(on-device-first)")
        #expect(label != CardReadSource.onDeviceModelVersion)
        #expect(AttemptModelLabel.forFailedAttempt(route: .onDeviceOnly) == CardReadSource.onDeviceModelVersion)
    }
}
