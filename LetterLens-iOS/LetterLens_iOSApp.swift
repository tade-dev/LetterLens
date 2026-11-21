//
//  LetterLens_iOSApp.swift
//  LetterLens-iOS
//
//  Created by BSTAR on 12/11/2026.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct LetterLens_iOSApp: App {
    @State private var appConfig = AppConfig()

    init() {
        FirebaseBootstrap.configureIfPossible()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LetterRecord.self])
        let support = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let storeURL = support.appending(path: "LetterLens.store")
        // A new store file so this model does not collide with the old template Item store.
        let modelConfiguration = ModelConfiguration(
            "LetterLens",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if LetterHarness.isEnabled {
                    LetterHarnessView()
                } else {
                    ContentView()
                }
                #else
                ContentView()
                #endif
            }
            .environment(appConfig)
            .task {
                #if DEBUG
                if LetterHarness.isEnabled { return }
                #endif
                await appConfig.fetchAndActivate()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
