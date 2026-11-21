//
//  LetterCardScreen.swift
//  LetterLens-iOS
//
//  Screen 05. Plain cards on ground. Glass stays on the buttons and the navigation bar.
//  Plan next steps pushes the local placeholder. Add reminder does not ask permission.
//  Mark done only flips state on this screen.

import SwiftUI

struct LetterCardScreen: View {
    var card: LetterCard
    var path: ReadingPath
    var pageCount: Int
    var onAddReminder: () -> Void = {}
    var onPlanNextSteps: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false
    @State private var isDone = false
    @State private var doneTaps = 0
    @State private var showNextSteps = false
    @ScaledMetric(relativeTo: .subheadline) private var watchDot: CGFloat = 6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                LetterProvenancePill(path: path)
                    .letterCardEntrance(index: 0, appeared: appeared)
                header
                    .letterCardEntrance(index: 1, appeared: appeared)
                if !actionText.isEmpty {
                    actionCard
                        .letterCardEntrance(index: 2, appeared: appeared)
                }
                if AmountVisibility.showsRow(for: card.type) {
                    amountBlock
                        .letterCardEntrance(index: 3, appeared: appeared)
                }
                if let deadline {
                    deadlineCard(deadline)
                        .letterCardEntrance(index: 4, appeared: appeared)
                }
                if !watchOuts.isEmpty {
                    watchCard
                        .letterCardEntrance(index: 5, appeared: appeared)
                }
                footer
                    .letterCardEntrance(index: 6, appeared: appeared)
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LLColor.ground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            pinnedActions
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNextSteps) {
            NextStepsPlaceholderScreen()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: doneTaps)
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var fromLine: String {
        LetterRead(card: card, path: path, pageCount: pageCount).fromLine
    }

    private var actionText: String {
        card.action.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var watchOuts: [String] {
        card.watchOuts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var deadline: LetterDeadline? {
        guard let raw = card.deadline else { return nil }
        return LetterDeadlineFormat.parse(raw)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            LLSectionLabel(text: "What this is")
            Text(verbatim: card.displayTitle)
                .font(LLFont.cardTitle)
                .tracking(-0.5)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: fromLine)
                .clearInkBody14()
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHeading(.h1)
    }

    private var amountBlock: some View {
        let presentation = AmountPresentation(quote: card.amountQuote)
        return LLAmountBlock(
            amount: presentation.figure,
            quote: presentation.quotedText,
            showsFallback: true,
            quoteOnly: presentation.isQuoteOnly
        )
    }

    private var actionCard: some View {
        surface {
            LLSectionLabel(text: "What they want you to do")
            Text(verbatim: actionText)
                .font(LLFont.bodyL)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func deadlineCard(_ deadline: LetterDeadline) -> some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            deadlineHeading(deadline)
            Text(verbatim: deadline.dateText)
                .font(LLFont.title)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let quote = deadlineQuote {
                Rectangle()
                    .fill(LLColor.deadlineRule)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                Text(verbatim: "From the letter: “\(quote)”")
                    .clearInkBody14()
                    .foregroundStyle(LLColor.deadlineQuote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.deadlineTint, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func deadlineHeading(_ deadline: LetterDeadline) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: LLSpace.xs) {
                LLSectionLabel(text: "Deadline", color: LLColor.deadline)
                if let days = deadline.daysLeftText {
                    daysLeft(days)
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
                LLSectionLabel(text: "Deadline", color: LLColor.deadline)
                Spacer(minLength: LLSpace.s)
                if let days = deadline.daysLeftText {
                    daysLeft(days)
                }
            }
        }
    }

    private func daysLeft(_ days: String) -> some View {
        Text(days)
            .font(LLFont.label)
            .foregroundStyle(LLColor.deadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var deadlineQuote: String? {
        guard let quote = card.deadlineQuote?.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty else {
            return nil
        }
        return quote
    }

    private var watchCard: some View {
        surface {
            LLSectionLabel(text: "Watch out")
            VStack(alignment: .leading, spacing: LLSpace.m) {
                ForEach(Array(watchOuts.enumerated()), id: \.offset) { _, item in
                    watchRow(item)
                }
            }
        }
    }

    private func watchRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
            Circle()
                .fill(LLColor.warning)
                .frame(width: watchDot, height: watchDot)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions.height * 0.8
                }
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(LLFont.body)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        Text(LetterCopy.disclaimerShort)
            .font(LLFont.caption)
            .foregroundStyle(LLColor.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var pinnedActions: some View {
        VStack(spacing: LLSpace.m) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: LLSpace.m) {
                    addReminderButton
                    markDoneButton
                }
                VStack(spacing: LLSpace.m) {
                    addReminderButton
                    markDoneButton
                }
            }
            planButton
        }
        .padding(.horizontal, LLSpace.screen)
        .padding(.top, LLSpace.m)
        .padding(.bottom, LLSpace.s)
        .frame(maxWidth: .infinity)
        .background {
            LLColor.ground.ignoresSafeArea(edges: .bottom)
        }
    }

    private var addReminderButton: some View {
        ClearInkGlassButton("Add reminder", kind: .regular) {
            // TODO: Local reminder. Do not request notification permission here.
            onAddReminder()
        }
    }

    private var markDoneButton: some View {
        ClearInkGlassButton(
            "Mark done",
            systemImage: isDone ? "checkmark" : nil,
            kind: .regular
        ) {
            if !isDone {
                doneTaps += 1
            }
            isDone.toggle()
        }
        .accessibilityValue(isDone ? "Done" : "Not done")
    }

    private var planButton: some View {
        ClearInkGlassButton("Plan next steps", systemImage: "cloud", kind: .prominent(LLColor.ink)) {
            onPlanNextSteps()
            showNextSteps = true
        }
    }

    private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            content()
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG

#Preview("05 Amount found, on this iPhone") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.councilBill,
            path: .device,
            pageCount: 2
        )
    }
}

#Preview("05 Amount found, in the cloud") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.councilBill,
            path: .cloud,
            pageCount: 2
        )
    }
}

#Preview("05 Amount missing") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.billWithoutAmount,
            path: .device,
            pageCount: 1
        )
    }
}

#Preview("05 Amount quote only") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.billWithTwoFigures,
            path: .device,
            pageCount: 1
        )
    }
}

#Preview("05 Informational letter, no amount row") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.nhsInformation,
            path: .cloud,
            pageCount: 1
        )
    }
}

#Preview("05 Amount found, largest accessibility type") {
    NavigationStack {
        LetterCardScreen(
            card: LetterCardScreenPreview.councilBill,
            path: .device,
            pageCount: 2
        )
    }
    .dynamicTypeSize(.accessibility5)
}

private enum LetterCardScreenPreview {
    static let councilBill = LetterCard(
        type: .bill,
        senderKind: .council,
        action: "Pay the balance or set up a payment plan before the date in the letter.",
        deadline: "2026-12-03",
        deadlineQuote: "Please pay by 3 December 2026",
        amountQuote: "Please pay £184.50 by 3 December 2026",
        watchOuts: [
            "A missed payment can add costs.",
            "The letter names a recovery process.",
        ],
        scamSigns: [],
        noActionNeeded: false
    )

    static let billWithoutAmount = LetterCard(
        type: .bill,
        senderKind: .council,
        action: "Pay the balance shown in the letter.",
        deadline: "2026-12-03",
        deadlineQuote: "Please pay by 3 December 2026",
        amountQuote: nil,
        watchOuts: [],
        scamSigns: [],
        noActionNeeded: false
    )

    static let billWithTwoFigures = LetterCard(
        type: .penalty,
        senderKind: .council,
        action: "Pay the charge named in the letter.",
        deadline: nil,
        deadlineQuote: nil,
        amountQuote: "£40 plus a £12 late fee",
        watchOuts: [],
        scamSigns: [],
        noActionNeeded: false
    )

    static let nhsInformation = LetterCard(
        type: .information,
        senderKind: .nhs,
        action: "Bring this letter to your appointment.",
        deadline: nil,
        deadlineQuote: nil,
        amountQuote: "Please pay £184.50 by 3 December 2026",
        watchOuts: [
            "The clinic can change the time.",
        ],
        scamSigns: [],
        noActionNeeded: false
    )
}

#endif
