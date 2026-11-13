//
//  FirebaseBootstrap.swift
//  LetterLens-iOS
//

import FirebaseAppCheck
import FirebaseCore
import Foundation
import os

#if !DEBUG
import DeviceCheck
#endif

enum LetterLensLog {
    static let firebase = Logger(subsystem: "com.tade.LetterLens-iOS", category: "Firebase")
    static let pipeline = Logger(subsystem: "com.tade.LetterLens-iOS", category: "Pipeline")
}

/// Configures Firebase when `GoogleService-Info.plist` is in the app bundle.
///
/// The plist is gitignored. The Check GoogleService-Info.plist script phase fails
/// the build when the file is absent. This guard remains so a bundle that still
/// lacks the plist logs an error instead of crashing. The synchronized
/// `LetterLens-iOS` folder copies the file into the app once it is present.
enum FirebaseBootstrap {
    #if DEBUG
    private static let appCheckFactory = AppCheckDebugProviderFactory()
    #else
    private static let appCheckFactory = LetterLensAppCheckProviderFactory()
    #endif

    static func configureIfPossible() {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            LetterLensLog.firebase.error(
                """
                GoogleService-Info.plist is missing from the app bundle. Firebase is not \
                configured, so Remote Config and AI Logic stay on bundled defaults. Download \
                the file from the Firebase console and add it to LetterLens-iOS/, then rebuild. \
                Do not commit it.
                """
            )
            return
        }

        // The provider factory must be installed before FirebaseApp.configure().
        AppCheck.setAppCheckProviderFactory(appCheckFactory)
        FirebaseApp.configure()
        AppCheck.appCheck().isTokenAutoRefreshEnabled = true

        #if DEBUG
        logAppCheckDebugTokenInstructions()
        #endif
    }

    #if DEBUG
    /// Tells the developer how to obtain and register a debug token.
    /// The token value is never written here. It comes from the Xcode console
    /// or from `FIRAAppCheckDebugToken` on a local, non-shared scheme.
    private static func logAppCheckDebugTokenInstructions() {
        let pinnedToken = ProcessInfo.processInfo.environment["FIRAAppCheckDebugToken"]
        if let pinnedToken, !pinnedToken.isEmpty {
            LetterLensLog.firebase.notice(
                """
                App Check debug provider is active and FIRAAppCheckDebugToken is set for this \
                process. Register that token in the Firebase console under App Check → Apps → \
                Manage debug tokens. This log does not print the token. Keep it in a local \
                scheme under LetterLens-iOS.xcodeproj/xcuserdata. Do not commit the token or a \
                shared scheme that contains it.
                """
            )
            return
        }

        LetterLensLog.firebase.notice(
            """
            App Check debug provider is active. On the first App Check request, the Xcode \
            console prints a line like: [AppCheckCore][I-GAC004001] App Check debug token: \
            '<token>'. Copy that token and register it in the Firebase console under App \
            Check → Apps → Manage debug tokens. To reuse one token, add the environment \
            variable FIRAAppCheckDebugToken to the Run action of a local, non-shared scheme \
            (LetterLens-iOS.xcodeproj/xcuserdata). Do not commit the token or a shared scheme \
            that contains it.
            """
        )
    }
    #endif
}

#if !DEBUG
/// Release builds use App Attest when the device supports it, and DeviceCheck otherwise.
///
/// `AppAttestProviderFactory` always vends App Attest. Simulator and other devices where
/// `DCAppAttestService.isSupported` is false cannot complete App Attest, so those fall back
/// to `DeviceCheckProvider`.
final class LetterLensAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    nonisolated func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if DCAppAttestService.shared.isSupported {
            return AppAttestProviderFactory().createProvider(with: app)
        }
        // `init?(app:)` is failable, so this cannot be returned as `AppCheckProvider?` directly.
        if let deviceCheck = DeviceCheckProvider(app: app) {
            return deviceCheck
        }
        return nil
    }
}
#endif
