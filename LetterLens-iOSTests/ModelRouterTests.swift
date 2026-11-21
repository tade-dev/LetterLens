//
//  ModelRouterTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct OnDeviceGateTests {
    @Test func aSimulatorIsNotReadyWhenTheSystemReportsAvailable() {
        #expect(!OnDeviceGate.isReady(systemReportsAvailable: true, runsOnSimulator: true))
    }

    @Test func aDeviceUsesTheSystemReport() {
        #expect(OnDeviceGate.isReady(systemReportsAvailable: true, runsOnSimulator: false))
        #expect(!OnDeviceGate.isReady(systemReportsAvailable: false, runsOnSimulator: false))
    }
}

#if targetEnvironment(simulator)
@MainActor
@Suite struct SimulatorRouteTests {
    @Test func consentOnTheSimulatorUsesTheCloudPath() {
        let router = ModelRouter(
            neverUpload: false,
            cloudConsent: true,
            runsOnSimulator: true,
            onDeviceProbe: .ready
        )
        #expect(router.route(for: .card) == .cloudPrimary)
        #expect(!router.isOnDeviceUsable)
    }

    @Test func noConsentOnTheSimulatorStaysUnavailable() {
        let router = ModelRouter(
            neverUpload: false,
            cloudConsent: false,
            runsOnSimulator: true,
            onDeviceProbe: .ready
        )
        #expect(router.route(for: .card) == .onDeviceOnly)
        #expect(!router.isOnDeviceUsable)
    }

    @Test func turningTheSimulatorFlagOffRestoresTheDeviceRoute() {
        let ready = ModelRouter(
            neverUpload: false,
            cloudConsent: true,
            runsOnSimulator: false,
            onDeviceProbe: .ready
        )
        let unavailable = ModelRouter(
            neverUpload: false,
            cloudConsent: true,
            runsOnSimulator: false,
            onDeviceProbe: .unavailable
        )
        #expect(ready.route(for: .card) == .hybridOnDeviceFirst)
        #expect(ready.isOnDeviceUsable)
        #expect(unavailable.route(for: .card) == .cloudPrimary)
        #expect(!unavailable.isOnDeviceUsable)
    }
}
#endif
