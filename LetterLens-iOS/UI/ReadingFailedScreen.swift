//
//  ReadingFailedScreen.swift
//  LetterLens-iOS
//
//  State 15. ReadingScreen calls `onReadingFailed` when OCR or the card read fails.
//  No visual spec for this state was in the repo. This is the system
//  ContentUnavailableView, with the pipeline's existing error sentence.
//  TODO: Replace this layout when Prism's spec for state 15 arrives.

import SwiftUI

struct ReadingFailedScreen: View {
    var message: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LLColor.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }
}

#if DEBUG

#Preview("15 Reading failed") {
    NavigationStack {
        ReadingFailedScreen(message: ScanReadingFailure.noText)
    }
}

#endif
