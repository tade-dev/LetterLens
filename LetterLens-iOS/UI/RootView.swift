//
//  RootView.swift
//  LetterLens-iOS
//
//  First launch shows Welcome, then pushes Home. Later launches open Home.
//  Home pushes Scan, Settings, and a stored letter (05 or 06).
//  Scan pushes Reading, then 05 or 06. Plan next steps pushes 08, then 09.
//  `-LLHarness` stays on the app entry.

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

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
