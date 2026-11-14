//
//  LetterLens_iOSApp.swift
//  LetterLens-iOS
//
//  Created by BSTAR on 12/11/2026.
//

import SwiftUI

@main
struct LetterLens_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            // Clear Ink is light only. Asset colours are Any appearance.
            // `-LLHarness` is unchanged: this target has no harness branch.
            RootView()
                .preferredColorScheme(.light)
        }
    }
}
