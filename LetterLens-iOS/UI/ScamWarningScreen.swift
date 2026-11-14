//
//  ScamWarningScreen.swift
//  LetterLens-iOS
//
//  Screen 06. Shown when the v2 card has at least one scam sign.
//  The hero copy is fixed. Signs use `scam_signs` (`sign`, and `quote` when present).
//  The check and report buttons stay on this iPhone. They do not send the letter.

import SwiftUI

struct ScamWarningScreen: View {
    var card: LetterCard
    var path: ReadingPath
    var onCheckWithSender: () -> Void = {}
    var onReport: () -> Void = {}

    @State private var appeared = false
    @State private var warningShown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                hero
                    .letterCardEntrance(index: 0, appeared: appeared)
                claim
                    .letterCardEntrance(index: 1, appeared: appeared)
                if !signs.isEmpty {
                    signsCard
                        .letterCardEntrance(index: 2, appeared: appeared)
                }
                bottom
                    .letterCardEntrance(index: 3, appeared: appeared)
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LLColor.ground.ignoresSafeArea())
        .letterProvenanceToolbar(path: path)
        .sensoryFeedback(.warning, trigger: warningShown)
        .preferredColorScheme(.light)
        .onAppear {
            appeared = true
            warningShown = true
        }
    }

    private var signs: [ScamSign] {
        card.scamSigns.filter { sign in
            !sign.sign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var signsLabel: String {
        signs.count == 1 ? "1 sign to check" : "\(signs.count) signs to check"
    }

    private var checkTitle: LocalizedStringKey {
        LocalizedStringKey(stringLiteral: "How to check with \(card.senderKind.title)")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(LLFont.badge)
                    .accessibilityHidden(true)
                Text("Stop before you pay or click")
                    .font(LLFont.badge)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            Text("This letter has signs of a scam")
                .font(LLFont.title)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("We can't be sure. Check with the sender using contact details you find yourself.")
                .clearInkBody14()
                .foregroundStyle(LLColor.warningOn)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LLSpace.blockLoose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.warning, in: RoundedRectangle(cornerRadius: LLRadius.warningCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHeading(.h1)
        .accessibilitySortPriority(1)
    }

    private var claim: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            LLSectionLabel(text: "What it claims to be")
            Text(verbatim: card.displayTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var signsCard: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            LLSectionLabel(text: signsLabel, color: LLColor.warning)
            VStack(alignment: .leading, spacing: LLSpace.m) {
                ForEach(Array(signs.enumerated()), id: \.offset) { _, sign in
                    signRow(sign)
                }
            }
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func signRow(_ sign: ScamSign) -> some View {
        VStack(alignment: .leading, spacing: LLSpace.xxs) {
            Text(verbatim: sign.sign)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let quote = sign.quote?.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty {
                Text(verbatim: "“\(quote)”")
                    .font(.footnote)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottom: some View {
        VStack(spacing: LLSpace.m) {
            ClearInkGlassButton(checkTitle, kind: .prominent(LLColor.ink)) {
                onCheckWithSender()
            }
            ClearInkGlassButton("Report a suspicious letter", kind: .regular) {
                onReport()
            }
            Text("We never say a letter is safe. Only the sender can confirm.")
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG

#Preview("06 Scam warning, on this iPhone") {
    NavigationStack {
        ScamWarningScreen(card: ScamWarningPreview.hmrcRefund, path: .device)
    }
}

#Preview("06 Scam warning, cloud") {
    NavigationStack {
        ScamWarningScreen(card: ScamWarningPreview.bankFee, path: .cloud)
    }
}

private enum ScamWarningPreview {
    static let hmrcRefund = LetterCard(
        type: .refund,
        senderKind: .hmrc,
        action: "Pay a fee so the refund can be released.",
        deadline: nil,
        deadlineQuote: nil,
        amountQuote: nil,
        watchOuts: [],
        scamSigns: [
            ScamSign(sign: "It asks for a fee to release money", quote: "Pay a £50 release fee"),
            ScamSign(sign: "No reference number", quote: nil),
        ],
        noActionNeeded: false
    )

    static let bankFee = LetterCard(
        type: .bill,
        senderKind: .bank,
        action: "Call the number in the letter today.",
        deadline: nil,
        deadlineQuote: nil,
        amountQuote: nil,
        watchOuts: [],
        scamSigns: [
            ScamSign(sign: "The payment link is not an official domain", quote: "https://bank-secure.example/pay"),
        ],
        noActionNeeded: false
    )
}

#endif
