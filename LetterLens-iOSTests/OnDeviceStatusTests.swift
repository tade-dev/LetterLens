//
//  OnDeviceStatusTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@Suite("On-device status")
struct OnDeviceStatusTests {
    /// The screens and the pipeline must answer this the same way. They used to
    /// ask separately: RootView read SystemLanguageModel directly with no
    /// Simulator guard, while ModelRouter had one. The UI then skipped the cloud
    /// consent sheet and CardService refused the read, so a letter dead-ended on
    /// "Can't read privately on this iPhone" with no way forward.
    @Test func theScreensAgreeWithThePipeline() {
        let router = ModelRouter(neverUpload: false, cloudConsent: false)
        let screens = OnDeviceReadingStatusReader.current
        #expect((screens == .available) == router.isOnDeviceUsable)
    }

    /// Availability is a property of the device, not of the privacy switches.
    @Test func thePrivacySwitchesDoNotChangeAvailability() {
        let base = ModelRouter(neverUpload: false, cloudConsent: false).isOnDeviceUsable
        #expect(ModelRouter(neverUpload: true, cloudConsent: false).isOnDeviceUsable == base)
        #expect(ModelRouter(neverUpload: false, cloudConsent: true).isOnDeviceUsable == base)
        #expect(ModelRouter(neverUpload: true, cloudConsent: true).isOnDeviceUsable == base)
    }

    /// On the Simulator the system model reports available and then fails, so the
    /// router calls it unavailable. The screens must say the same, which is what
    /// makes the cloud consent sheet appear instead of a dead end.
    @Test func theSimulatorReportsUnavailableToBothSides() {
        #if targetEnvironment(simulator)
        #expect(OnDeviceReadingStatusReader.current == .unavailable)
        let flow = PrivacySettingsModel(neverUpload: false, writesDefaults: false)
            .unsupportedFlow(onDevice: OnDeviceReadingStatusReader.current)
        #expect(flow.route == .cloudFallback)
        #expect(flow.showsCloudButton)
        #endif
    }
}
