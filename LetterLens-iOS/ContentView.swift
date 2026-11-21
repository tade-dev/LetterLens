//
//  ContentView.swift
//  LetterLens-iOS
//

import SwiftData
import SwiftUI

/// The real screens are still to come. This shows the debug card so a letter can be read end to end.
struct ContentView: View {
    var body: some View {
        DebugCardScreen()
    }
}

#Preview {
    ContentView()
        .environment(AppConfig())
        .modelContainer(for: LetterRecord.self, inMemory: true)
}
