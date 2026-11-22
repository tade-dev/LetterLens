//
//  WhatGetsSentScreen.swift
//  LetterLens-iOS
//
//  Screen 08. Pushed from Plan next steps. Shows the redacted letter.
//  Send and plan calls the injected planner. The sample planner does not
//  leave the device. A plan is always a cloud call, so Never upload on shows
//  the keep-private sheet and does not plan.

import SwiftData
import SwiftUI

struct WhatGetsSentScreen: View {
    var card: LetterCard
    var ocrText: String
    var path: ReadingPath = .device
    var preferences: PrivacySettingsModel
    /// Previews and tests inject a planner. The app leaves this nil and the real
    /// cloud planner is built from Remote Config when Send and plan is pressed.
    var planner: (any NextStepsPlanner)?
    var availability: OnDeviceReadingAvailability = .available

    @Query(sort: \LetterRecord.createdAt, order: .reverse) private var records: [LetterRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppConfig.self) private var config

    @State private var note = ""
    @State private var isPlanning = false
    @State private var showConsent = false
    @State private var showPrivacy = false
    @State private var afterConsent: ConsentFollowUp?
    @State private var finishedPlan: NextStepsPlan?
    @State private var showPlan = false
    @State private var appeared = false
    @ScaledMetric(relativeTo: .title2) private var statNumber: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                headline
                    .letterCardEntrance(index: 0, appeared: appeared)
                statTiles
                    .letterCardEntrance(index: 1, appeared: appeared)
                redactedCard
                    .letterCardEntrance(index: 2, appeared: appeared)
                noteField
                    .letterCardEntrance(index: 3, appeared: appeared)
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Without this the pill and the hero slid under a bare navigation bar:
        // the back button sat on top of the red card and the pill on the clock.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(LLColor.ground.ignoresSafeArea())
        .navigationTitle("What gets sent")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
        }
        .navigationDestination(isPresented: $showPlan) {
            if let finishedPlan {
                NextStepsScreen(plan: finishedPlan, map: redaction.map, path: path)
            }
        }
        .navigationDestination(isPresented: $showPrivacy) {
            PrivacySettingsScreen(
                preferences: preferences,
                availability: availability,
                storedLetterCount: records.count,
                onDeleteAll: deleteAllLetters
            )
        }
        .sheet(isPresented: $showConsent, onDismiss: finishConsentSheet) {
            consentSheet
        }
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var redaction: RedactionResult {
        Redactor().redact(ocrText)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            Text("Here's exactly what we'll send")
                .font(LLFont.displayS)
                .tracking(-0.4)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Your iPhone removed your personal details. Gemini only sees this.")
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statTiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: LLSpace.m) {
                removedTile
                photosTile
            }
        } else {
            HStack(alignment: .top, spacing: LLSpace.m) {
                removedTile
                photosTile
            }
        }
    }

    private var removedTile: some View {
        statTile(
            number: redaction.removedCount,
            label: redaction.removedCount == 1 ? "detail removed" : "details removed",
            numberColor: LLColor.device,
            labelColor: LLColor.deviceInk,
            fill: LLColor.deviceTint
        )
    }

    private var photosTile: some View {
        statTile(
            number: 0,
            label: "photos sent",
            numberColor: LLColor.ink,
            labelColor: LLColor.inkSecondary,
            fill: LLColor.surface
        )
    }

    private func statTile(
        number: Int,
        label: String,
        numberColor: Color,
        labelColor: Color,
        fill: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: LLSpace.xxs) {
            Text("\(number)")
                .font(.system(size: statNumber, weight: .bold))
                .foregroundStyle(numberColor)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(labelColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var redactedCard: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            if redaction.text.isEmpty {
                Text("No letter text is stored for this one, so nothing would be sent.")
                    .font(LLFont.body)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(RedactionAttributedText.make(text: redaction.text, map: redaction.map, reinsert: false))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(ScriptReinsertion.spokenRedacted(redaction.text))
            }
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            Text("Anything you want help with? (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextField("e.g. I can't afford it this month", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(LLFont.body)
                .foregroundStyle(LLColor.ink)
                .padding(LLSpace.m)
                .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
                .accessibilityLabel("Anything you want help with? (optional)")
        }
    }

    private var actions: some View {
        VStack(spacing: LLSpace.s) {
            ClearInkGlassButton(sendTitle, kind: .prominent(LLColor.ink)) {
                Task { await sendAndPlan() }
            }
            .disabled(isPlanning)
            Button("Cancel") { dismiss() }
                .font(LLFont.button)
                .foregroundStyle(LLColor.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: LLSize.touchMin)
            Text(LetterCopy.disclaimerShort)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, LLSpace.screen)
        .padding(.top, LLSpace.m)
        .padding(.bottom, LLSpace.s)
        .background(LLColor.ground)
    }

    private var sendTitle: LocalizedStringKey {
        isPlanning ? "Planning…" : "Send and plan"
    }

    @ViewBuilder
    private var consentSheet: some View {
        let flow = NextStepsConsent.blockedFlow(neverUpload: preferences.neverUpload)
        if let prompt = flow.prompt {
            UnsupportedDeviceSheet(
                prompt: prompt,
                onReadInCloud: { showConsent = false },
                onNotNow: { showConsent = false },
                onKeepPrivate: { showConsent = false },
                onOpenPrivacySettings: {
                    afterConsent = .privacy
                    showConsent = false
                }
            )
        }
    }

    private func sendAndPlan() async {
        guard !isPlanning else { return }
        let allowed = NextStepsConsent.allowsPlanning(neverUpload: preferences.neverUpload)
        guard allowed else {
            showConsent = true
            return
        }

        isPlanning = true
        defer { isPlanning = false }
        // Pressing Send and plan is the consent, so the router is told the cloud is allowed.
        let active = planner ?? PlanService(
            promptTemplate: config.planPrompt,
            planModel: config.planModel,
            fallbackModel: config.fallbackModel,
            router: ModelRouter(neverUpload: preferences.neverUpload, cloudConsent: true)
        )
        let plan = await active.plan(
            redactedText: redaction.text,
            card: card,
            note: note
        )
        finishedPlan = plan
        showPlan = true
    }

    private func finishConsentSheet() {
        let next = afterConsent
        afterConsent = nil
        if next == .privacy {
            showPrivacy = true
        }
    }

    private func deleteAllLetters() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

private enum ConsentFollowUp {
    case privacy
}

#if DEBUG

#Preview("08 What gets sent") {
    NavigationStack {
        WhatGetsSentScreen(
            card: WhatGetsSentPreview.card,
            ocrText: WhatGetsSentPreview.letter,
            preferences: PrivacySettingsModel(
                neverUpload: false,
                writesDefaults: false
            )
        )
    }
    .modelContainer(for: LetterRecord.self, inMemory: true)
}

#Preview("08 What gets sent, accessibility XXL") {
    NavigationStack {
        WhatGetsSentScreen(
            card: WhatGetsSentPreview.card,
            ocrText: WhatGetsSentPreview.letter,
            preferences: PrivacySettingsModel(
                neverUpload: false,
                writesDefaults: false
            )
        )
    }
    .modelContainer(for: LetterRecord.self, inMemory: true)
    .dynamicTypeSize(.accessibility5)
}

private enum WhatGetsSentPreview {
    static let letter = "Dear Jane Smith, please pay by 3 December 2026. Our reference: AB12CD34EF. Write to 10 Downing Street, London SW1A 2AA."

    static let card = LetterCard(
        type: .reminder,
        senderKind: .council,
        action: "Pay the balance or set up a payment plan.",
        deadline: "2026-12-03",
        deadlineQuote: "Please pay by 3 December 2026",
        amountQuote: nil,
        watchOuts: [],
        scamSigns: [],
        noActionNeeded: false
    )
}

#endif
