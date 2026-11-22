//
//  NextStepsScreen.swift
//  LetterLens-iOS
//
//  Screen 09. Shown after a plan comes back. The script's tokens are filled
//  in here, on this iPhone. Copy uses the filled-in words.
//  The pill matches screens 05 and 06. "Planned in the cloud" is only for a real cloud plan.

import SwiftUI
import UIKit

struct NextStepsScreen: View {
    var plan: NextStepsPlan
    var map: RedactionMap
    var path: ReadingPath = .device

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var appeared = false
    @State private var copied = false
    @State private var copyCount = 0
    @ScaledMetric(relativeTo: .title3) private var stepSide: CGFloat = 28
    @ScaledMetric(relativeTo: .title3) private var stepDigit: CGFloat = 15

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                provenance
                    .letterCardEntrance(index: 0, appeared: appeared)
                headline
                    .letterCardEntrance(index: 1, appeared: appeared)
                if !plan.steps.isEmpty {
                    stepsCard
                }
                scriptCard
                    .letterCardEntrance(index: plan.steps.count + 1, appeared: appeared)
                if !plan.whereToGetHelp.isEmpty {
                    helpCard
                        .letterCardEntrance(index: plan.steps.count + 2, appeared: appeared)
                }
                restoredRow
                    .letterCardEntrance(index: plan.steps.count + 3, appeared: appeared)
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LLColor.ground.ignoresSafeArea())
        .navigationTitle("Next steps")
        .navigationBarTitleDisplayMode(.inline)
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
        .sensoryFeedback(.impact(weight: .light), trigger: copyCount)
        .task(id: copyCount) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copied = false
        }
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    /// Cloud only when this plan was actually made in the cloud. The local sample follows the letter's read path.
    private var provenanceKind: Provenance {
        plan.madeInCloud ? .cloudPlanned : path.letterProvenance
    }

    private var provenance: some View {
        LLProvenanceBadge(kind: provenanceKind)
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scriptPlain: String {
        plain(plan.script)
    }

    /// The plan comes back from the cloud still holding redaction tokens.
    /// `[ACCOUNT_1]` means nothing to someone reading a step, so the detail
    /// goes back in here, on this iPhone, as a chip.
    private func filledIn(_ text: String) -> AttributedString {
        RedactionAttributedText.inline(text: text, map: map, reinsert: true)
    }

    private func plain(_ text: String) -> String {
        ScriptReinsertion.plain(in: text, map: map)
    }

    private var headline: some View {
        Text("Your next steps")
            .font(LLFont.displayS)
            .tracking(-0.4)
            .foregroundStyle(LLColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                stepRow(number: index + 1, step: step)
                    .letterCardEntrance(index: index + 1, appeared: appeared)
            }
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
    }

    private func stepRow(number: Int, step: NextStepsPlan.Step) -> some View {
        HStack(alignment: .top, spacing: LLSpace.m) {
            Text("\(number)")
                .font(.system(size: stepDigit, weight: .bold))
                .foregroundStyle(LLColor.surface)
                .frame(width: stepSide, height: stepSide)
                .background(LLColor.ink, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: LLSpace.xxs) {
                Text(filledIn(step.title))
                    .font(LLFont.body.weight(.semibold))
                    .foregroundStyle(LLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(filledIn(step.detail))
                    .clearInkBody14()
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number). \(plain(step.title)). \(plain(step.detail))")
    }

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            HStack(alignment: .center, spacing: LLSpace.s) {
                LLSectionLabel(text: "What to say")
                Spacer(minLength: LLSpace.s)
                copyButton
            }
            Text(RedactionAttributedText.make(text: plan.script, map: map, reinsert: true))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
    }

    /// Free, official or charity sources from the plan. Screen 09 calls for these.
    /// Shown as plain text: these are not links, and nothing here is advice.
    private var helpCard: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            LLSectionLabel(text: "Where to get help")
            ForEach(Array(plan.whereToGetHelp.enumerated()), id: \.offset) { _, source in
                HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
                    Image(systemName: "info.circle")
                        .font(LLFont.body)
                        .foregroundStyle(LLColor.inkSecondary)
                        .accessibilityHidden(true)
                    Text(filledIn(source))
                        .font(LLFont.body)
                        .foregroundStyle(LLColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var copyButton: some View {
        if reduceTransparency {
            copyControl.buttonStyle(.bordered)
        } else {
            copyControl.buttonStyle(.glass)
        }
    }

    private var copyControl: some View {
        Button(action: copyScript) {
            Text(copied ? "Copied" : "Copy")
        }
        .controlSize(.large)
        .tint(LLColor.ink)
        .accessibilityHint("Copies the script")
    }

    private var restoredRow: some View {
        Label("Your details were added back on this iPhone", systemImage: "lock.fill")
            .font(LLFont.caption)
            .foregroundStyle(LLColor.device)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    private func copyScript() {
        UIPasteboard.general.string = scriptPlain
        copied = true
        copyCount += 1
        UIAccessibility.post(notification: .announcement, argument: "Copied")
    }
}

#if DEBUG

#Preview("09 Next steps") {
    NavigationStack {
        NextStepsScreen(plan: NextStepsPreview.plan, map: NextStepsPreview.map)
    }
}

#Preview("09 Next steps, accessibility XXL") {
    NavigationStack {
        NextStepsScreen(plan: NextStepsPreview.plan, map: NextStepsPreview.map)
    }
    .dynamicTypeSize(.accessibility5)
}

private enum NextStepsPreview {
    static let map = RedactionMap(entries: [
        RedactionMap.Entry(token: "[NAME_1]", original: "Jane Smith", kind: "NAME"),
        RedactionMap.Entry(token: "[REF_1]", original: "AB12CD34EF", kind: "REF"),
    ])

    static let plan = NextStepsPlan(
        steps: [
            NextStepsPlan.Step(
                title: "Do what the letter asks",
                detail: "Pay the balance or set up a payment plan."
            ),
            NextStepsPlan.Step(
                title: "Keep the date in the letter",
                detail: "Use only a date the letter itself states. LetterLens does not invent one."
            ),
            NextStepsPlan.Step(
                title: "Contact the sender yourself",
                detail: "Look up a phone number or website you trust."
            ),
        ],
        script: "Hello, this is [NAME_1]. My reference is [REF_1]. I'd like to talk about the letter I was sent."
    )
}

#endif
