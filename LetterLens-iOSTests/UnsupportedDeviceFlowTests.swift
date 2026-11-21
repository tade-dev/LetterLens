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
        let flow = UnsupportedDeviceFlow(onDeviceSupported: true, neverUpload: true)
        #expect(flow.route == .onDevice)
        #expect(flow.prompt == nil)
        #expect(flow.actions == [])
        #expect(flow.showsCloudButton == false)
        #expect(flow.isKeepPrivateBecauseNeverUpload == false)
    }

    @Test func neverUploadOffAlwaysAsksBeforeACloudRead() {
        let flow = UnsupportedDeviceFlow(onDeviceSupported: false, neverUpload: false)
        #expect(flow.route == .cloudFallback)
        #expect(flow.prompt == .cloudFallback)
        #expect(flow.actions == [.readInCloud, .notNow])
        #expect(flow.showsCloudButton == true)
        #expect(flow.isKeepPrivateBecauseNeverUpload == false)
        #expect(flow.prompt?.heroSymbolName == "cloud")
        #expect(flow.prompt?.heroIsNeutral == false)
        #expect(flow.actions.contains(.keepPrivateAndClose) == false)
    }

    @Test func neverUploadOnAnUnsupportedPhoneIsTheOnlyKeepPrivateCause() {
        let flow = UnsupportedDeviceFlow(onDeviceSupported: false, neverUpload: true)
        #expect(flow.route == .keepPrivate)
        #expect(flow.prompt == .keepPrivate)
        #expect(flow.isKeepPrivateBecauseNeverUpload == true)
        #expect(flow.actions == [.keepPrivateAndClose, .openPrivacySettings])
        #expect(flow.actions.contains(.readInCloud) == false)
        #expect(flow.showsCloudButton == false)
        #expect(flow.prompt?.heroSymbolName == "lock.fill")
        #expect(flow.prompt?.heroIsNeutral == true)
    }

    @Test func promptActionsMatchTheRoute() {
        #expect(UnsupportedDevicePrompt.cloudFallback.actions == [.readInCloud, .notNow])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions == [.keepPrivateAndClose, .openPrivacySettings])
        #expect(UnsupportedDevicePrompt.keepPrivate.actions.allSatisfy { !$0.isCloudRead })
        #expect(UnsupportedDevicePrompt.cloudFallback.actions.contains { $0.isCloudRead })
    }

    @Test func modelMapsAvailabilityAndNeverUploadIntoTheFlow() {
        let stopped = PrivacySettingsModel(neverUpload: true, writesDefaults: false)
        #expect(stopped.unsupportedFlow(onDevice: .unavailable).route == .keepPrivate)
        #expect(stopped.unsupportedFlow(onDevice: .unavailable).isKeepPrivateBecauseNeverUpload == true)
        #expect(stopped.unsupportedFlow(onDevice: .available).route == .onDevice)

        let asking = PrivacySettingsModel(neverUpload: false, writesDefaults: false)
        let askingFlow = asking.unsupportedFlow(onDevice: .unavailable)
        #expect(askingFlow.route == .cloudFallback)
        #expect(askingFlow.showsCloudButton == true)
        #expect(askingFlow.isKeepPrivateBecauseNeverUpload == false)
    }

    @Test func neverUploadFootnoteChangesWithTheSwitch() {
        #expect(NeverUploadCopy.footnote(isOn: true) == "Everything stays on this phone. “Plan next steps” is turned off.")
        #expect(NeverUploadCopy.footnote(isOn: false) == "Letters are read on this phone. If that isn't possible, or you ask for a plan, we'll show you what gets sent and ask first.")
    }

    @Test func readyStatusUsesDeviceGreenAndUnavailableStaysNeutral() {
        #expect(OnDeviceReadingAvailability.available.statusStyle.symbolName == "checkmark.shield.fill")
        #expect(OnDeviceReadingAvailability.available.statusStyle.tint == .device)
        #expect(OnDeviceReadingAvailability.unavailable.statusStyle.symbolName == "lock.fill")
        #expect(OnDeviceReadingAvailability.unavailable.statusStyle.tint == .neutral)
    }

    @Test func preferenceKeyIsNeverUploadOnly() {
        #expect(PrivacyPreference.neverUpload == "ll.neverUpload")
    }

    @Test func neverUploadDefaultsToOff() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(PrivacyPreference.readNeverUpload(from: defaults) == false)
        let model = PrivacySettingsModel(defaults: defaults)
        #expect(model.neverUpload == false)
        #expect(model.unsupportedFlow(onDevice: .unavailable).route == .cloudFallback)
    }

    @Test func settingsWritesNeverUploadAndIgnoresAStoredCloudFallbackKey() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "ll.allowCloudFallback")

        let model = PrivacySettingsModel(defaults: defaults)
        #expect(model.unsupportedFlow(onDevice: .unavailable).route == .cloudFallback)
        model.setNeverUpload(true)
        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
        #expect(model.unsupportedFlow(onDevice: .unavailable).isKeepPrivateBecauseNeverUpload == true)
        #expect(defaults.bool(forKey: "ll.allowCloudFallback") == true)
    }

    @Test func aPreviewModelDoesNotWriteTheStore() throws {
        let (defaults, name) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: PrivacyPreference.neverUpload)

        let model = PrivacySettingsModel(neverUpload: true, defaults: defaults, writesDefaults: false)
        model.setNeverUpload(false)

        #expect(model.neverUpload == false)
        #expect(defaults.bool(forKey: PrivacyPreference.neverUpload) == true)
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
