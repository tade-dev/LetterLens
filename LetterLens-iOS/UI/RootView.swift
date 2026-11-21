//
//  RootView.swift
//  LetterLens-iOS
//
//  First launch shows Welcome, then pushes Scan. Later launches open Scan.
//  Privacy is the gear on Scan. The unsupported-device sheet follows
//  `UnsupportedDeviceFlow` when a photo or PDF is ready to read.
//  When reading finishes with a card, a scam sign pushes screen 06.
//  Any other card pushes screen 05. `-LLHarness` stays on the app entry.

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
    @State private var finishedRead: LetterRead?
    @State private var showLetter = false

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
            preferences: preferences,
            onCardReady: { card, path, pageCount in
                guard let card else { return }
                finishedRead = LetterRead(card: card, path: path, pageCount: pageCount)
                showLetter = true
            }
        )
        .navigationDestination(isPresented: $showLetter) {
            if let finishedRead {
                if finishedRead.card.opensScamWarning {
                    ScamWarningScreen(card: finishedRead.card, path: finishedRead.path)
                } else {
                    LetterCardScreen(
                        card: finishedRead.card,
                        path: finishedRead.path,
                        pageCount: finishedRead.pageCount
                    )
                }
            }
        }
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
