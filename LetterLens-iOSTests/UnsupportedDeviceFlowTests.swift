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
    @Test func aSupportedPhoneShowsNoSheetEvenWhenCloudIsBlocked() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: true,
            neverUpload: true,
            allowCloudFallback: false
        )
        #expect(flow.route == .onDevice)
        #expect(flow.prompt == nil)
        #expect(flow.actions == [])
        #expect(flow.showsCloudButton == false)
        #expect(flow.keepPrivateCause == nil)
    }

    @Test func cloudFallbackOnAsksBeforeEveryLetter() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: false,
            neverUpload: false,
            allowCloudFallback: true
        )
        #expect(flow.route == .cloudFallback)
        #expect(flow.prompt == .cloudFallback)
        #expect(flow.actions == [.readInCloud, .notNow])
        #expect(flow.showsCloudButton == true)
        #expect(flow.keepPrivateCause == nil)
        #expect(flow.prompt?.heroSymbolName == "cloud")
        #expect(flow.prompt?.heroIsNeutral == false)
    }

    @Test func cloudFallbackOffStopsWithNoCloudButton() {
        let flow = UnsupportedDeviceFlow(
            onDeviceSupported: false,
            neverUpload: false,
            allowCloudFallback: false
        )
        #expect(flow.route == .keepPrivate)
        #expect(flow.prompt == .keepPrivate)
        #expect(flow.keepPrivateCause == .cloudFallbackOff)
        #expect(flow.actions == [.keepPrivateAndClose, .openPrivacySettings])
        #expect(flow.showsCloudButton == false)
        #expect(flow.prompt?.heroSymbolName == "lock.fill")
        #expect(flow.prompt?.heroIsNeutral == true)
    }

    @Test func neverUploadOnAnUnsupportedPhoneStopsWithNoCloudButton() {
        for allowCloud in [true, false] {
            let flow = UnsupportedDeviceFlow(
                onDeviceSupported: false,
                neverUpload: true,
                allowCloudFallback: allowCloud
            )
            #expect(flow.route == .keepPrivate)
            #expect(flow.prompt == .keepPrivate)
            #expect(flow.keepPrivateCause == .neverUpload)
            #expect(flow.actions == [.keepPrivateAndClose, .openPrivacySettings])
            #expect(flow.actions.contains(.readInCloud) == false)
            #expect(flow.showsCloudButton == false)
        }
    }

    @Test func promptActionsMatchTheRoute() {
        #expect(UnsupportedDevicePrompt.cloudFallback.actions == [.readInCloud, .notNow])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions == [.keepPrivateAndClose, .openPrivacySettings])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions.allSatisfy { !$0.isCloudRead })
        #expect(UnsupportedDevicePrompt.cloudFallback.actions.contains { $0.isCloudRead })
    }

    @Test func modelMapsAvailabilityAndTheStoredSwitchesIntoTheFlow() {
        let stopped = PrivacySettingsModel(neverUpload: true, allowCloudFallback: true, writesDefaults: false)
        #expect(stopped.unsupportedFlow(onDevice: .unavailable).route == .keepPrivate)
        #expect(stopped.unsupportedFlow(onDevice: .unavailable).keepPrivateCause == .neverUpload)
        #expect(stopped.unsupportedFlow(onDevice: .available).route == .onDevice)

        let asking = PrivacySettingsModel(neverUpload: false, allowCloudFallback: true, writesDefaults: false)
        #expect(asking.unsupportedFlow(onDevice: .unavailable).route == .cloudFallback)
        #expect(asking.unsupportedFlow(onDevice: .unavailable).showsCloudButton == true)

        let blocked = PrivacySettingsModel(neverUpload: false, allowCloudFallback: false, writesDefaults: false)
        let blockedFlow = blocked.unsupportedFlow(onDevice: .unavailable)
        #expect(blockedFlow.route == .keepPrivate)
        #expect(blockedFlow.keepPrivateCause == .cloudFallbackOff)
        #expect(blockedFlow.showsCloudButton == false)
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
    }

    @Test func bothSwitchesDefaultToOff() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(PrivacyPreference.readNeverUpload(from: defaults) == false)
        #expect(PrivacyPreference.readAllowCloudFallback(from: defaults) == false)

        let model = PrivacySettingsModel(defaults: defaults)
        #expect(model.neverUpload == false)
        #expect(model.allowCloudFallback == false)
    }

    @Test func settingsWritesNeverUploadAndAllowCloudFallback() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let model = PrivacySettingsModel(defaults: defaults)
        model.setNeverUpload(true)
        model.setAllowCloudFallback(true)

        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
        #expect(defaults.bool(forKey: PrivacyPreference.allowCloudFallback) == true)
        #expect(PrivacyPreference.readAllowCloudFallback(from: defaults) == true)
    }

    @Test func aPreviewModelDoesNotWriteTheStore() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: PrivacyPreference.neverUpload)
        defaults.set(true, forKey: PrivacyPreference.allowCloudFallback)

        let model = PrivacySettingsModel(
            neverUpload: true,
            allowCloudFallback: true,
            defaults: defaults,
            writesDefaults: false
        )
        model.setNeverUpload(false)
        model.setAllowCloudFallback(false)

        #expect(model.neverUpload == false)
        #expect(model.allowCloudFallback == false)
        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
        #expect(defaults.bool(forKey: PrivacyPreference.allowCloudFallback) == true)
    }

    @Test func dismissWithNoChoiceDeclines() {
        var record = SheetChoiceRecord()
        let first = record.resolveDismiss()
        #expect(first.choice == .declined)
        #expect(first.declinedByDismiss == true)
        #expect(record.choice == .declined)

        let second = record.resolveDismiss()
        #expect(second.choice == .declined)
        #expect(second.declinedByDismiss == false)
    }

    @Test func allowThenDismissStaysAllowed() {
        var record = SheetChoiceRecord()
        record.record(.allowed)
        let resolution = record.resolveDismiss()
        #expect(resolution.choice == .allowed)
        #expect(resolution.declinedByDismiss == false)
        #expect(record.choice == .allowed)
    }

    @Test func notNowThenDismissStaysDeclined() {
        var record = SheetChoiceRecord()
        record.record(.declined)
        let resolution = record.resolveDismiss()
        #expect(resolution.choice == .declined)
        #expect(resolution.declinedByDismiss == false)
        #expect(record.choice == .declined)
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
