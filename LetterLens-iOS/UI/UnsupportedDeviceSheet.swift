//
//  UnsupportedDeviceSheet.swift
//  LetterLens-iOS
//
//  Screen 07 and state 17. Present with `.sheet` and detents. The system draws the
//  glass sheet and the grabber; this view does not paint a sheet background.
//  Buttons come only from `prompt.actions`, so state 17 has no cloud button.
//
//  "Don't ask again" is the inverse of `PrivacySettingsModel.askBeforeCloud`.
//  Wire it with `model.setDontAskAgain`. Leave the sheet up if that value changes
//  while it is open. Swiping the sheet away is "Not now" for screen 07, and
//  "Keep it private and close" for state 17. This view does not send anything.

import SwiftUI

struct UnsupportedDeviceSheet: View {
    var prompt: UnsupportedDevicePrompt
    @Binding var dontAskAgain: Bool
    var onReadInCloud: () -> Void = {}
    var onNotNow: () -> Void = {}
    var onKeepPrivate: () -> Void = {}
    var onOpenPrivacySettings: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var actionGlass
    @State private var appeared = false
    @State private var detent: PresentationDetent = .large
    @State private var cloudTaps = 0
    @State private var notNowTaps = 0
    @State private var keepTaps = 0
    @State private var settingsTaps = 0
    @ScaledMetric(relativeTo: .title2) private var heroSide: CGFloat = 52
    @ScaledMetric(relativeTo: .title2) private var heroSymbol: CGFloat = 26
    @ScaledMetric(relativeTo: .subheadline) private var checkSize: CGFloat = 16

    init(
        prompt: UnsupportedDevicePrompt,
        dontAskAgain: Binding<Bool> = .constant(false),
        onReadInCloud: @escaping () -> Void = {},
        onNotNow: @escaping () -> Void = {},
        onKeepPrivate: @escaping () -> Void = {},
        onOpenPrivacySettings: @escaping () -> Void = {}
    ) {
        self.prompt = prompt
        self._dontAskAgain = dontAskAgain
        self.onReadInCloud = onReadInCloud
        self.onNotNow = onNotNow
        self.onKeepPrivate = onKeepPrivate
        self.onOpenPrivacySettings = onOpenPrivacySettings
        _detent = State(initialValue: prompt == .keepPrivate ? .medium : .large)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.blockLoose) {
                hero
                    .clearInkEntrance(index: 0, appeared: appeared)
                titleBlock
                    .clearInkEntrance(index: 1, appeared: appeared)
                if prompt == .cloudFallback {
                    protections
                    dontAskAgainToggle
                        .clearInkEntrance(index: 4, appeared: appeared)
                }
                actions
                    .clearInkEntrance(index: 5, appeared: appeared)
            }
            .padding(.horizontal, LLSpace.screen)
            .padding(.top, LLSpace.s)
            .padding(.bottom, LLSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .sensoryFeedback(.impact, trigger: cloudTaps)
        .sensoryFeedback(.selection, trigger: notNowTaps)
        .sensoryFeedback(.impact, trigger: keepTaps)
        .sensoryFeedback(.selection, trigger: settingsTaps)
        .sensoryFeedback(.selection, trigger: dontAskAgain)
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var heroForeground: Color {
        prompt.heroIsNeutral ? LLColor.ink : LLColor.cloud
    }

    private var heroTile: Color {
        prompt.heroIsNeutral ? LLColor.fillQuiet : LLColor.cloudTint
    }

    private var hero: some View {
        ClearInkIconTile(
            systemName: prompt.heroSymbolName,
            foreground: heroForeground,
            tile: heroTile,
            side: heroSide,
            symbolSize: heroSymbol,
            cornerRadius: LLRadius.tile,
            bounceTrigger: appeared
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            Text(title)
                .font(LLFont.title)
                .tracking(-0.4)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: LocalizedStringKey {
        switch prompt {
        case .cloudFallback:
            "This iPhone can't read letters privately"
        case .keepPrivate:
            "This iPhone can't read letters on its own"
        }
    }

    private var message: LocalizedStringKey {
        switch prompt {
        case .cloudFallback:
            "On-device reading needs Apple Intelligence. We can read it in the cloud with Google's Gemini instead."
        case .keepPrivate:
            "On-device reading needs Apple Intelligence. Never upload is on, so nothing will be sent."
        }
    }

    private var protections: some View {
        VStack(alignment: .leading, spacing: LLSpace.sm) {
            protectionRow("Postcodes, phone numbers, emails and account numbers are removed first", index: 0)
            protectionRow("Only the text is sent, never the photo", index: 1)
            protectionRow("The card will say “Read in the cloud”", index: 2)
        }
        .padding(.horizontal, LLSpace.card)
        .padding(.vertical, LLSpace.block)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.ground, in: RoundedRectangle(cornerRadius: LLRadius.button, style: .continuous))
    }

    private func protectionRow(_ text: LocalizedStringKey, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LLSpace.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: checkSize, weight: .bold))
                .foregroundStyle(LLColor.device)
                .modifier(ClearInkCheckBounce(trigger: appeared))
                .accessibilityHidden(true)
            Text(text)
                .font(ClearInkMockFont.body14)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clearInkEntrance(index: index + 2, appeared: appeared)
    }

    private var dontAskAgainToggle: some View {
        Toggle(isOn: $dontAskAgain) {
            Text("Don't ask again on this phone")
                .font(LLFont.body.weight(.medium))
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(LLColor.ink)
        .frame(minHeight: LLSize.touchMin)
    }

    private var actions: some View {
        Group {
            if reduceTransparency {
                actionStack
            } else {
                GlassEffectContainer(spacing: LLSpace.sm) {
                    actionStack
                }
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth, value: prompt)
    }

    private var actionStack: some View {
        VStack(spacing: LLSpace.sm) {
            ForEach(Array(prompt.actions.enumerated()), id: \.element) { index, action in
                identifiedButton(action, index: index)
            }
        }
    }

    @ViewBuilder
    private func identifiedButton(_ action: UnsupportedDeviceAction, index: Int) -> some View {
        if reduceTransparency {
            actionButton(action)
        } else {
            actionButton(action)
                .glassEffectID(index == 0 ? "unsupported-primary" : "unsupported-secondary", in: actionGlass)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: UnsupportedDeviceAction) -> some View {
        switch action {
        case .readInCloud:
            ClearInkGlassButton("Read it in the cloud", kind: .prominent(LLColor.cloud)) {
                cloudTaps += 1
                onReadInCloud()
            }
        case .notNow:
            ClearInkGlassButton("Not now, keep it on my phone", kind: .regular) {
                notNowTaps += 1
                onNotNow()
            }
        case .keepPrivateAndClose:
            ClearInkGlassButton("Keep it private and close", kind: .prominent(LLColor.ink)) {
                keepTaps += 1
                onKeepPrivate()
            }
        case .openPrivacySettings:
            ClearInkGlassButton("Open Privacy settings", kind: .regular) {
                settingsTaps += 1
                onOpenPrivacySettings()
            }
        }
    }
}

/// Checkmarks bounce once. Reduce Motion leaves the symbol still.
private struct ClearInkCheckBounce: ViewModifier {
    var trigger: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: trigger)
        }
    }
}

#if DEBUG

#Preview("07 Cloud fallback") {
    UnsupportedDevicePreview(prompt: .cloudFallback, dontAskAgain: false)
}

#Preview("07 Cloud fallback, don't ask again") {
    UnsupportedDevicePreview(prompt: .cloudFallback, dontAskAgain: true)
}

#Preview("07 Cloud fallback, Reduce Transparency") {
    UnsupportedDevicePreview(prompt: .cloudFallback, dontAskAgain: false, reduceTransparency: true)
}

#Preview("07 Cloud fallback, accessibility XXL") {
    UnsupportedDevicePreview(prompt: .cloudFallback, dontAskAgain: false, dynamicType: .accessibility5)
}

#Preview("07 Cloud fallback, Reduce Motion") {
    UnsupportedDevicePreview(prompt: .cloudFallback, dontAskAgain: false, reduceMotion: true)
}

#Preview("17 Keep it private") {
    UnsupportedDevicePreview(prompt: .keepPrivate, dontAskAgain: false)
}

#Preview("17 Keep it private, accessibility XXL") {
    UnsupportedDevicePreview(prompt: .keepPrivate, dontAskAgain: false, dynamicType: .accessibility5)
}

private struct UnsupportedDevicePreview: View {
    var prompt: UnsupportedDevicePrompt
    @State var dontAskAgain: Bool
    var reduceTransparency = false
    var reduceMotion = false
    var dynamicType: DynamicTypeSize? = nil
    @State private var showSheet = true

    var body: some View {
        LLColor.ground
            .ignoresSafeArea()
            .sheet(isPresented: $showSheet) {
                UnsupportedDeviceSheet(prompt: prompt, dontAskAgain: $dontAskAgain)
                    .environment(\.accessibilityReduceTransparency, reduceTransparency)
                    .environment(\.accessibilityReduceMotion, reduceMotion)
                    .dynamicTypeSize(dynamicType ?? .large)
            }
            .preferredColorScheme(.light)
    }
}

#endif
