//
//  PrivacySettingsScreen.swift
//  LetterLens-iOS
//
//  Screen 10. A grouped form so the navigation bar and toggles stay system controls.
//  Push it to get the system back button. Delete all confirms, then calls `onDeleteAll`.
//  It does not touch SwiftData.
//
//  Toggles write `ll.neverUpload` and `ll.askBeforeCloud` through the model.
//  Ask before is disabled while Never upload is on. Its stored value is kept.

import SwiftUI

struct PrivacySettingsScreen: View {
    @Bindable var preferences: PrivacySettingsModel
    var availability: OnDeviceReadingAvailability
    var storedLetterCount: Int
    var onDeleteAll: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingDelete = false
    @State private var deleteCount = 0
    @State private var appeared = false
    @ScaledMetric(relativeTo: .body) private var statusSide: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var statusSymbol: CGFloat = 20

    var body: some View {
        Form {
            Section {
                statusRow
                    .letterLensRow()
                    .listRowSeparator(.hidden)
            }
            Section {
                neverUploadRow.letterLensRow()
                askBeforeRow.letterLensRow()
                storedRow.letterLensRow()
            }
            Section {
                howItWorks
                    .letterLensRow()
                    .listRowSeparator(.hidden)
            }
        }
        .listRowSeparatorTint(LLColor.line)
        .listSectionSpacing(LLSpace.blockLoose)
        .scrollContentBackground(.hidden)
        .background(LLColor.ground)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.automatic, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .confirmationDialog(
            "Delete all letters?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                deleteCount += 1
                onDeleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every letter stored on this iPhone. Nothing is sent.")
        }
        .sensoryFeedback(.selection, trigger: preferences.neverUpload)
        .sensoryFeedback(.selection, trigger: preferences.askBeforeCloud)
        .sensoryFeedback(.warning, trigger: deleteCount)
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var statusForeground: Color {
        availability.statusStyle.tint == .device ? LLColor.device : LLColor.ink
    }

    private var statusTile: Color {
        availability.statusStyle.tint == .device ? LLColor.deviceTint : LLColor.fillQuiet
    }

    private var statusRow: some View {
        HStack(alignment: .center, spacing: LLSpace.block) {
            ClearInkIconTile(
                systemName: availability.statusStyle.symbolName,
                foreground: statusForeground,
                tile: statusTile,
                side: statusSide,
                symbolSize: statusSymbol,
                cornerRadius: LLRadius.iconButton,
                bounceTrigger: appeared
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(LLFont.body.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusSubtitle)
                    .font(.footnote)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: LocalizedStringKey {
        switch availability {
        case .available:
            "On-device reading is ready"
        case .unavailable:
            "On-device reading isn't available"
        }
    }

    private var statusSubtitle: LocalizedStringKey {
        switch availability {
        case .available:
            "Apple Intelligence · works offline"
        case .unavailable:
            "Apple Intelligence isn't on this iPhone"
        }
    }

    private var neverUploadRow: some View {
        Toggle(isOn: Binding(
            get: { preferences.neverUpload },
            set: { preferences.setNeverUpload($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Never upload")
                    .font(LLFont.body.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                Text("Everything stays on this phone. “Plan next steps” is turned off.")
                    .font(.footnote)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(LLColor.ink)
    }

    private var askBeforeRow: some View {
        Toggle(isOn: Binding(
            get: { preferences.askBeforeCloud },
            set: { preferences.setAskBeforeCloud($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ask before using the cloud")
                    .font(LLFont.body.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                Text("Every time, with a preview of what's sent.")
                    .font(.footnote)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(LLColor.ink)
        .disabled(preferences.neverUpload)
    }

    private var storedRow: some View {
        HStack(alignment: .center, spacing: LLSpace.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Letters stored")
                    .font(LLFont.body.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                Text(StoredLettersCopy.detail(count: storedLetterCount))
                    .font(.footnote)
                    .foregroundStyle(LLColor.inkSecondary)
                    .contentTransition(.numericText())
                    .animation(countAnimation, value: storedLetterCount)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                confirmingDelete = true
            } label: {
                Text("Delete all")
                    .font(ClearInkMockFont.body14Semibold)
                    .foregroundStyle(LLColor.warning)
                    .padding(.horizontal, LLSpace.block)
                    .frame(minHeight: LLSize.touchMin)
                    .background(
                        LLColor.warningTint,
                        in: RoundedRectangle(cornerRadius: LLRadius.iconButton, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(storedLetterCount <= 0)
            .accessibilityLabel("Delete all letters")
        }
    }

    private var countAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .snappy
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            LLSectionLabel(text: "How LetterLens works")
            Text("Your iPhone reads the letter with Apple's on-device model. If that isn't available, or you ask for a plan, Google Gemini is used through Firebase, only after you agree and with your details removed.")
                .font(ClearInkMockFont.body14)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Text(LetterCopy.disclaimerShort)
            Link(destination: PrivacyPreference.openSourceURL) {
                Text("Open source · MIT")
                    .underline()
            }
            .accessibilityHint("Opens the MIT licence on GitHub.")
        }
        .font(LLFont.caption)
        .foregroundStyle(LLColor.inkSecondary)
        .tint(LLColor.ink)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, LLSpace.screen)
        .padding(.vertical, LLSpace.m)
        .background(LLColor.ground)
    }
}

private extension View {
    func letterLensRow() -> some View {
        listRowBackground(LLColor.surface)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
    }
}

#if DEBUG

#Preview("10 Privacy") {
    PrivacyPreview(neverUpload: false)
}

#Preview("10 Privacy, Never upload on") {
    PrivacyPreview(neverUpload: true)
}

#Preview("10 Privacy, on-device unavailable") {
    PrivacyPreview(neverUpload: false, availability: .unavailable)
}

#Preview("10 Privacy, accessibility XXL") {
    PrivacyPreview(neverUpload: false)
        .dynamicTypeSize(.accessibility5)
}

private struct PrivacyPreview: View {
    @State private var preferences: PrivacySettingsModel
    var availability: OnDeviceReadingAvailability
    var count: Int

    init(
        neverUpload: Bool,
        askBeforeCloud: Bool = true,
        availability: OnDeviceReadingAvailability = .available,
        count: Int = 5
    ) {
        _preferences = State(
            initialValue: PrivacySettingsModel(
                neverUpload: neverUpload,
                askBeforeCloud: askBeforeCloud,
                writesDefaults: false
            )
        )
        self.availability = availability
        self.count = count
    }

    var body: some View {
        NavigationStack {
            PrivacySettingsScreen(
                preferences: preferences,
                availability: availability,
                storedLetterCount: count,
                onDeleteAll: {}
            )
        }
        .preferredColorScheme(.light)
    }
}

#endif
