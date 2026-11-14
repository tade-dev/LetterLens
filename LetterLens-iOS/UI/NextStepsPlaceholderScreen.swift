//
//  NextStepsPlaceholderScreen.swift
//  LetterLens-iOS
//
//  Stand-in for screens 08 and 09. It stays on this iPhone and sends nothing.

import SwiftUI

struct NextStepsPlaceholderScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            Text("Next steps")
                .font(LLFont.displayS)
                .tracking(-0.4)
                .foregroundStyle(LLColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(LLSpace.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LLColor.ground)
        .navigationTitle("Next steps")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text(LetterCopy.disclaimerShort)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LLSpace.screen)
                .padding(.vertical, LLSpace.m)
                .background(LLColor.ground)
        }
    }
}
