//
//  RootView.swift
//  LetterLens-iOS
//
//  First launch shows Welcome, then pushes Scan. Later launches open Scan.
//  Privacy is the gear on Scan. The unsupported-device sheet follows
//  `UnsupportedDeviceFlow` when a photo or PDF is ready to read.
//  `-LLHarness` is not part of this target; the argument is left unused.

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct RootView: View {
    @AppStorage("ll.hasSeenWelcome") private var hasSeenWelcome = false
    /// Stays true for this session so marking Welcome seen does not swap the root mid-push.
    @State private var continueToScan = false
    @State private var preferences = PrivacySettingsModel()
    @State private var availability: OnDeviceReadingAvailability = .unavailable

    var body: some View {
        NavigationStack {
            if hasSeenWelcome && !continueToScan {
                scan
            } else {
                WelcomeScreen {
                    hasSeenWelcome = true
                    continueToScan = true
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $continueToScan) {
                    scan
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            availability = OnDeviceReadingStatusReader.current
        }
    }

    private var scan: some View {
        ScanEntryScreen(
            flow: preferences.unsupportedFlow(onDevice: availability),
            availability: availability,
            preferences: preferences
        )
    }
}

enum OnDeviceReadingStatusReader {
    static var current: OnDeviceReadingAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable:
            return .unavailable
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }
}
