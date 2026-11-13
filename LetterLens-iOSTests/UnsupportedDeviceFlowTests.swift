//
//  UnsupportedDeviceFlowTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite("Privacy and cloud fallback")
struct UnsupportedDeviceFlowTests {
    @Test func aSupportedPhoneShowsNoSheetEvenWhenNeverUploadIsOn() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: true,
            neverUpload: true,
            askBeforeCloud: false
        )
        #expect(flow.route == .onDevice)
        #expect(flow.prompt == nil)
        #expect(flow.actions == [])
        #expect(flow.showsCloudButton == false)
        #expect(flow.allowsCloudRead == false)
    }

    @Test func anUnsupportedPhoneAsksBeforeACloudRead() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: false,
            neverUpload: false,
            askBeforeCloud: true
        )
        #expect(flow.route == .cloudFallback)
        #expect(flow.prompt == .cloudFallback)
        #expect(flow.actions == [.readInCloud, .notNow])
        #expect(flow.showsCloudButton == true)
        #expect(flow.allowsCloudRead == true)
        #expect(flow.prompt?.heroSymbolName == "cloud")
        #expect(flow.prompt?.heroIsNeutral == false)
    }

    @Test func dontAskAgainSkipsTheSheetAndStillAllowsACloudRead() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: false,
            neverUpload: false,
            askBeforeCloud: false
        )
        #expect(flow.route == .readInCloudWithoutAsking)
        #expect(flow.prompt == nil)
        #expect(flow.actions == [])
        #expect(flow.showsCloudButton == false)
        #expect(flow.allowsCloudRead == true)
    }

    @Test func neverUploadOnAnUnsupportedPhoneStopsWithNoCloudButton() {
        for askBefore in [true, false] {
            let flow = UnsupportedDeviceFlow(
                onDeviceSupported: false,
                neverUpload: true,
                askBeforeCloud: askBefore
            )
            #expect(flow.route == .keepPrivate)
            #expect(flow.prompt == .keepPrivate)
            #expect(flow.actions == [.keepPrivateAndClose, .openPrivacySettings])
            #expect(flow.actions.contains(.readInCloud) == false)
            #expect(flow.showsCloudButton == false)
            #expect(flow.allowsCloudRead == false)
            #expect(flow.prompt?.heroSymbolName == "lock.fill")
            #expect(flow.prompt?.heroIsNeutral == true)
        }
    }

    @Test func promptActionsMatchTheRoute() {
        #expect(UnsupportedDevicePrompt.cloudFallback.actions == [.readInCloud, .notNow])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions == [.keepPrivateAndClose, .openPrivacySettings])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions.allSatisfy { !$0.isCloudRead })
        #expect(UnsupportedDevicePrompt.cloudFallback.actions.contains { $0.isCloudRead })
    }

    @Test func modelMapsAvailabilityAndTheStoredSwitchesIntoTheFlow() {
        let stopped = PrivacySettingsModel(neverUpload: true, askBeforeCloud: true, writesDefaults: false)
        #expect(stopped.unsupportedFlow(onDevice: .unavailable).route == .keepPrivate)
        #expect(stopped.unsupportedFlow(onDevice: .available).route == .onDevice)

        let asking = PrivacySettingsModel(neverUpload: false, askBeforeCloud: true, writesDefaults: false)
        #expect(asking.unsupportedFlow(onDevice: .unavailable).route == .cloudFallback)
        #expect(asking.unsupportedFlow(onDevice: .unavailable).showsCloudButton == true)

        let remembered = PrivacySettingsModel(neverUpload: false, askBeforeCloud: false, writesDefaults: false)
        let rememberedFlow = remembered.unsupportedFlow(onDevice: .unavailable)
        #expect(rememberedFlow.route == .readInCloudWithoutAsking)
        #expect(rememberedFlow.showsCloudButton == false)
        #expect(rememberedFlow.allowsCloudRead == true)
    }

    @Test func readyStatusUsesDeviceGreenAndUnavailableStaysNeutral() {
        #expect(OnDeviceReadingAvailability.available.statusStyle.symbolName == "checkmark.shield.fill")
        #expect(OnDeviceReadingAvailability.available.statusStyle.tint == .device)
        #expect(OnDeviceReadingAvailability.unavailable.statusStyle.symbolName == "lock.fill")
        #expect(OnDeviceReadingAvailability.unavailable.statusStyle.tint == .neutral)
    }

    @Test func preferenceKeysMatchTheScanToCardPipeline() {
        #expect(PrivacyPreference.neverUpload == "ll.neverUpload")
        #expect(PrivacyPreference.allowCloudFallback == "ll.allowCloudFallback")
        #expect(PrivacyPreference.askBeforeCloud == "ll.askBeforeCloud")
    }

    @Test func askBeforeDefaultsToTrueAndNeverUploadDefaultsToFalse() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(PrivacyPreference.readNeverUpload(from: defaults) == false)
        #expect(PrivacyPreference.readAskBeforeCloud(from: defaults) == true)

        let model = PrivacySettingsModel(defaults: defaults)
        #expect(model.neverUpload == false)
        #expect(model.askBeforeCloud == true)
    }

    @Test func settingsWritesNeverUploadAndAskBeforeAndLeavesThePipelineCloudFlagAlone() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let model = PrivacySettingsModel(defaults: defaults)
        model.setNeverUpload(true)
        model.setDontAskAgain(true)

        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
        #expect(defaults.bool(forKey: PrivacyPreference.askBeforeCloud) == false)
        #expect(model.askBeforeCloud == false)
        #expect(defaults.object(forKey: PrivacyPreference.allowCloudFallback) == nil)

        model.setAskBeforeCloud(true)
        #expect(PrivacyPreference.readAskBeforeCloud(from: defaults) == true)
        #expect(defaults.object(forKey: PrivacyPreference.allowCloudFallback) == nil)
    }

    @Test func aPreviewModelDoesNotWriteTheStore() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: PrivacyPreference.neverUpload)
        defaults.set(true, forKey: PrivacyPreference.askBeforeCloud)

        let model = PrivacySettingsModel(
            neverUpload: true,
            askBeforeCloud: true,
            defaults: defaults,
            writesDefaults: false
        )
        model.setNeverUpload(false)
        model.setDontAskAgain(true)

        #expect(model.neverUpload == false)
        #expect(model.askBeforeCloud == false)
        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
        #expect(defaults.bool(forKey: PrivacyPreference.askBeforeCloud) == true)
    }

    @Test func storedLetterLinesPluralise() {
        #expect(StoredLettersCopy.detail(count: 0) == "No letters stored on this iPhone")
        #expect(StoredLettersCopy.detail(count: 1) == "1 letter, on this iPhone only")
        #expect(StoredLettersCopy.detail(count: 5) == "5 letters, on this iPhone only")
        #expect(StoredLettersCopy.detail(count: -3) == "No letters stored on this iPhone")
    }
}

private func freshDefaults() throws -> (UserDefaults, String) {
    let name = "LetterLensPrivacy.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
}
