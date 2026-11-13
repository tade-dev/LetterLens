//
//  WelcomeScreen.swift
//  LetterLens-iOS
//
//  Screen 01. First launch. The promise rows stay on surface.
//  Get started is a glass prominent control; the disclaimer stays on ground.

import SwiftUI

struct WelcomeScreen: View {
    var onGetStarted: () -> Void = {}

    @State private var appeared = false
    @State private var getStartedCount = 0
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = WelcomeLayout.iconTile
    @ScaledMetric(relativeTo: .body) private var iconSymbol: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WelcomeLayout.sectionGap) {
                LetterLensLogo()
                    .clearInkEntrance(index: 0, appeared: appeared)
                headline
                    .clearInkEntrance(index: 1, appeared: appeared)
                promises
            }
            .padding(.horizontal, LLSpace.l)
            .padding(.top, LLSpace.blockLoose)
            .padding(.bottom, LLSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LLColor.ground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .sensoryFeedback(.impact, trigger: getStartedCount)
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            Text("Confusing letter? Get the short version.")
                .font(LLFont.displayL)
                .tracking(WelcomeLayout.titleTracking)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Snap a letter from HMRC, the council, your bank or school. LetterLens tells you what it is and what to do.")
                .font(.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var promises: some View {
        VStack(spacing: LLSpace.m) {
            ForEach(Array(WelcomePromise.all.enumerated()), id: \.element.id) { index, promise in
                promiseRow(promise)
                    .clearInkEntrance(index: index + 2, appeared: appeared)
            }
        }
    }

    private func promiseRow(_ promise: WelcomePromise) -> some View {
        HStack(alignment: .top, spacing: LLSpace.block) {
            ClearInkIconTile(
                systemName: promise.symbol,
                foreground: promise.foreground,
                tile: promise.tile,
                side: iconSide,
                symbolSize: iconSymbol,
                cornerRadius: WelcomeLayout.iconRadius,
                bounceTrigger: appeared
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(promise.title)
                    .font(LLFont.callout.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(promise.detail)
                    .font(ClearInkMockFont.body14)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, minHeight: LLSize.touchMin, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.button, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: LLSpace.m) {
            ClearInkGlassButton("Get started", kind: .prominent(LLColor.ink)) {
                getStartedCount += 1
                onGetStarted()
            }
            .clearInkEntrance(index: 5, appeared: appeared)

            Text(LetterCopy.disclaimerShort)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, LLSpace.l)
        .padding(.top, LLSpace.m)
        .padding(.bottom, LLSpace.s)
        .background(LLColor.ground)
    }
}

private enum WelcomeLayout {
    /// The welcome HTML uses 28 between the logo, the headline, and the promises.
    static let sectionGap: CGFloat = 28
    /// Nearest token radius is the 12pt icon button.
    static let iconRadius: CGFloat = 10
    static let iconTile: CGFloat = 36
    /// The type gallery tracks displayL at -0.6. This screen's HTML uses -0.8.
    static let titleTracking: CGFloat = -0.8
}

private struct WelcomePromise: Identifiable {
    var title: String
    var detail: String
    var symbol: String
    var tile: Color
    var foreground: Color
    var id: String { title }

    static let all: [WelcomePromise] = [
        WelcomePromise(
            title: "Read on your iPhone",
            detail: "Your name, address and account numbers stay on this phone.",
            symbol: "lock.fill",
            tile: LLColor.deviceTint,
            foreground: LLColor.device
        ),
        WelcomePromise(
            title: "Cloud only when you say so",
            detail: "We ask first, and remove your details before anything is sent.",
            symbol: "cloud",
            tile: LLColor.cloudTint,
            foreground: LLColor.cloud
        ),
        WelcomePromise(
            title: "No made-up deadlines",
            detail: "Every date is shown with the exact words it came from.",
            symbol: "clock",
            tile: LLColor.deadlineTint,
            foreground: LLColor.deadline
        ),
    ]
}

#if DEBUG

#Preview("01 Welcome") {
    WelcomeScreen()
}

#Preview("01 Welcome, Reduce Transparency") {
    WelcomeScreen()
        .environment(\.accessibilityReduceTransparency, true)
}

#Preview("01 Welcome, Reduce Motion") {
    WelcomeScreen()
        .environment(\.accessibilityReduceMotion, true)
}

#Preview("01 Welcome, accessibility XXL") {
    WelcomeScreen()
        .dynamicTypeSize(.accessibility5)
}

#endif
