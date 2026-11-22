//
//  ScamHelpSheet.swift
//  LetterLens-iOS
//
//  The two buttons at the foot of screen 06 open this. It is fixed copy from
//  ScamHelp, shown as plain text: the numbers and addresses here are not links,
//  because the whole point of the screen is that you go and find the sender
//  yourself. Nothing here is sent.

import SwiftUI

struct ScamHelpSheet: View {
    var content: ScamHelpContent
    var onDone: () -> Void = {}

    @ScaledMetric(relativeTo: .subheadline) private var stepSide: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var stepDigit: CGFloat = 13

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                header
                steps
                Text(content.footnote)
                    .font(LLFont.caption)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ClearInkGlassButton("Done", kind: .prominent(LLColor.ink)) {
                    onDone()
                }
            }
            .padding(.horizontal, LLSpace.l)
            .padding(.top, LLSpace.l)
            .padding(.bottom, LLSpace.l + LLSpace.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            Text(verbatim: content.title)
                .font(LLFont.title)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: content.lead)
                .clearInkBody14()
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            ForEach(Array(content.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: LLSpace.m) {
                    Text("\(index + 1)")
                        .font(.system(size: stepDigit, weight: .bold))
                        .foregroundStyle(LLColor.surface)
                        .frame(width: stepSide, height: stepSide)
                        .background(LLColor.ink, in: Circle())
                        .accessibilityHidden(true)
                    Text(verbatim: step)
                        .font(LLFont.body)
                        .foregroundStyle(LLColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(index + 1). \(step)")
            }
        }
        .padding(LLSpace.blockLoose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
    }
}

#if DEBUG

#Preview("06a How to check") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ScamHelpSheet(content: ScamHelp.check(sender: .hmrc))
    }
}

#Preview("06b Report") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ScamHelpSheet(content: ScamHelp.report(sender: .hmrc))
    }
}

#endif
