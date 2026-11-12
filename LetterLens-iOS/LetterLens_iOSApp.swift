//
//  LetterLens_iOSApp.swift
//  LetterLens-iOS
//
//  Created by BSTAR on 12/11/2026.
//

import SwiftUI
import SwiftData

@main
struct LetterLens_iOSApp: App {
    @State private var appConfig = AppConfig()

    init() {
        FirebaseBootstrap.configureIfPossible()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appConfig)
                .task {
                    await appConfig.fetchAndActivate()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
