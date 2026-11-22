//
//  RootView.swift
//  LetterLens-iOS
//
//  First launch shows Welcome, then pushes Home. Later launches open Home.
//  Home pushes Scan, Settings, and a stored letter (05 or 06).
//  Scan pushes Reading, then 05 or 06. Plan next steps pushes 08, then 09.
//  `-LLHarness` stays on the app entry.

import SwiftUI

struct RootView: View {
    @AppStorage("ll.hasSeenWelcome") private var hasSeenWelcome = false
    /// Stays true for this session so marking Welcome seen does not swap the root mid-push.
    @State private var continueToHome = false
    @State private var preferences = PrivacySettingsModel()
    @State private var availability: OnDeviceReadingAvailability = .unavailable
    @State private var completion = LetterCompletion()

    var body: some View {
        NavigationStack {
            if hasSeenWelcome && !continueToHome {
                home
            } else {
                WelcomeScreen {
                    hasSeenWelcome = true
                    continueToHome = true
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $continueToHome) {
                    home
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            availability = OnDeviceReadingStatusReader.current
        }
    }

    private var home: some View {
        HomeScreen(
            preferences: preferences,
            availability: availability,
            completion: completion
        )
    }
}

/// What the screens are told about on-device reading.
///
/// This asks `ModelRouter`, which is what the pipeline will actually use, rather
/// than reading `SystemLanguageModel` a second time. Asking separately meant the
/// two could disagree: on the Simulator the model reports itself available and
/// then fails, so the UI skipped the cloud consent sheet while `CardService`
/// refused the read. The reader got a dead end instead of the offer.
///
/// `neverUpload` and `cloudConsent` do not affect availability, so the values
/// passed here are irrelevant to the answer.
enum OnDeviceReadingStatusReader {
    static var current: OnDeviceReadingAvailability {
        ModelRouter(neverUpload: false, cloudConsent: false).isOnDeviceUsable ? .available : .unavailable
    }
}
