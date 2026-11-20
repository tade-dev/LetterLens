//
//  HomeScreen.swift
//  LetterLens-iOS
//
//  Screen 02. The screen after Welcome, and the root after that.
//  Letters come from the on-device SwiftData store. Scan is pushed from here.
//  Mark done is kept for this launch only. See LetterCompletion.

import Foundation
import SwiftData
import SwiftUI

struct HomeScreen: View {
    var preferences: PrivacySettingsModel
    var availability: OnDeviceReadingAvailability
    var completion: LetterCompletion

    @Query(sort: \LetterRecord.createdAt, order: .reverse) private var records: [LetterRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var letterZoom

    @State private var showScan = false
    @State private var scanOpensImport = false
    @State private var showPrivacy = false
    @State private var openedID: UUID?
    @State private var finishedRead: LetterRead?
    @State private var showLetter = false
    @State private var appeared = false
    @State private var doneTaps = 0

    var body: some View {
        List {
            titleRow
            if letters.isEmpty {
                emptyRow
            } else {
                if !lists.needsAction.isEmpty {
                    sectionLabel("Needs action")
                    ForEach(Array(lists.needsAction.enumerated()), id: \.element.id) { index, letter in
                        needsRow(letter, index: index + 1)
                    }
                }
                if !lists.earlier.isEmpty {
                    sectionLabel("Earlier")
                    ForEach(Array(lists.earlier.enumerated()), id: \.element.id) { index, letter in
                        earlierRow(
                            letter,
                            isFirst: index == 0,
                            isLast: index == lists.earlier.count - 1
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .background(LLColor.ground)
        .navigationTitle("Letters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPrivacy = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            scanBar
        }
        .navigationDestination(isPresented: $showScan) {
            ScanEntryScreen(
                flow: preferences.unsupportedFlow(onDevice: availability),
                availability: availability,
                preferences: preferences,
                onCardReady: { card, path, pageCount in
                    guard let card else { return }
                    finishedRead = LetterRead(card: card, path: path, pageCount: pageCount)
                    showLetter = true
                },
                opensImport: scanOpensImport
            )
            .navigationDestination(isPresented: $showLetter) {
                if let finishedRead {
                    if finishedRead.card.opensScamWarning {
                        ScamWarningScreen(card: finishedRead.card, path: finishedRead.path)
                    } else {
                        LetterCardScreen(
                            card: finishedRead.card,
                            path: finishedRead.path,
                            pageCount: finishedRead.pageCount,
                            ocrText: finishedRead.ocrText,
                            preferences: preferences,
                            availability: availability
                        )
                    }
                }
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
        .navigationDestination(item: $openedID) { id in
            openedLetter(id)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: doneTaps)
        .preferredColorScheme(.light)
        .onAppear { appeared = true }
    }

    private var now: Date { .now }

    private var letters: [HomeLetter] {
        records.compactMap { record in
            guard let card = record.card else { return nil }
            return HomeLetter(
                id: record.id,
                createdAt: record.createdAt,
                card: card,
                path: record.source == .cloud ? .cloud : .device,
                isDone: completion.isDone(record.id)
            )
        }
    }

    private var lists: HomeLetterLists.Lists {
        HomeLetterLists.split(letters, now: now)
    }

    private var titleRow: some View {
        Text("Letters")
            .font(LLFont.displayM)
            .tracking(-0.6)
            .foregroundStyle(LLColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .letterCardEntrance(index: 0, appeared: appeared)
            .plainListRow(insets: EdgeInsets(top: LLSpace.s, leading: LLSpace.screen, bottom: LLSpace.s, trailing: LLSpace.screen))
    }

    private var emptyRow: some View {
        ContentUnavailableView {
            Label("No letters yet", systemImage: "envelope")
        } description: {
            Text("Scan a letter and it will show up here.")
        }
        .letterCardEntrance(index: 1, appeared: appeared)
        .plainListRow(insets: EdgeInsets(top: LLSpace.l, leading: LLSpace.screen, bottom: LLSpace.l, trailing: LLSpace.screen))
    }

    private func sectionLabel(_ text: String) -> some View {
        LLSectionLabel(text: text)
            .plainListRow(insets: EdgeInsets(top: LLSpace.m, leading: LLSpace.screen, bottom: LLSpace.s, trailing: LLSpace.screen))
    }

    private func needsRow(_ letter: HomeLetter, index: Int) -> some View {
        Button {
            openedID = letter.id
        } label: {
            needsCard(letter)
        }
        .buttonStyle(.borderless)
        .accessibilityHint(letter.card.opensScamWarning ? "Shows the signs to check" : "Shows this letter")
        .modifier(HomeLetterZoomSource(id: letter.id, namespace: letterZoom, enabled: !reduceMotion))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Mark done") { markDone(letter) }
                .tint(LLColor.device)
        }
        .letterCardEntrance(index: index, appeared: appeared)
        .plainListRow(insets: EdgeInsets(top: 0, leading: LLSpace.screen, bottom: LLSpace.m, trailing: LLSpace.screen))
    }

    private func needsCard(_ letter: HomeLetter) -> some View {
        let date = HomeDateLabel.relative(
            HomeLetterLists.trailingDate(letter, section: .needsAction, now: now),
            now: now
        )
        let action = letter.card.action.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: LLSpace.s) {
            titleAndDate(title: letter.card.displayTitle, date: date)
            if !action.isEmpty {
                Text(verbatim: action)
                    .clearInkBody14()
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            pills(for: letter)
        }
        .padding(LLSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func earlierRow(_ letter: HomeLetter, isFirst: Bool, isLast: Bool) -> some View {
        Button {
            openedID = letter.id
        } label: {
            earlierLabel(letter, isFirst: isFirst, isLast: isLast)
        }
        .buttonStyle(.borderless)
        .accessibilityHint("Shows this letter")
        .modifier(HomeLetterZoomSource(id: letter.id, namespace: letterZoom, enabled: !reduceMotion))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(letter.isDone ? "Mark not done" : "Mark done") { markDone(letter) }
                .tint(LLColor.device)
        }
        .letterCardEntrance(index: lists.needsAction.count + 1, appeared: appeared)
        .plainListRow(
            insets: EdgeInsets(
                top: 0,
                leading: LLSpace.screen,
                bottom: isLast ? LLSpace.m : 0,
                trailing: LLSpace.screen
            )
        )
    }

    private func earlierLabel(_ letter: HomeLetter, isFirst: Bool, isLast: Bool) -> some View {
        let date = HomeDateLabel.relative(letter.createdAt, now: now)
        return VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(LLColor.line)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            earlierText(letter, date: date)
                .padding(LLSpace.card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: isFirst ? LLRadius.card : 0,
                    bottomLeading: isLast ? LLRadius.card : 0,
                    bottomTrailing: isLast ? LLRadius.card : 0,
                    topTrailing: isFirst ? LLRadius.card : 0
                ),
                style: .continuous
            )
            .fill(LLColor.surface)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func earlierText(_ letter: HomeLetter, date: HomeDateText) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: LLSpace.xxs) {
                letterTitle(letter.card.displayTitle)
                earlierSubline(letter)
                dateLabel(date)
            }
        } else {
            HStack(alignment: .center, spacing: LLSpace.m) {
                VStack(alignment: .leading, spacing: LLSpace.xxs) {
                    letterTitle(letter.card.displayTitle)
                    earlierSubline(letter)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                dateLabel(date)
            }
        }
    }

    private func earlierSubline(_ letter: HomeLetter) -> some View {
        Text(HomeLetterLists.earlierSubline(letter))
            .font(.footnote)
            .foregroundStyle(LLColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func titleAndDate(title: String, date: HomeDateText) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: LLSpace.xxs) {
                letterTitle(title)
                dateLabel(date)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
                letterTitle(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                dateLabel(date)
            }
        }
    }

    private func letterTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(LLColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func dateLabel(_ date: HomeDateText) -> some View {
        Text(verbatim: date.visual)
            .clearInkBody14()
            .foregroundStyle(LLColor.inkSecondary)
            .accessibilityLabel(date.spoken)
    }

    private func pills(for letter: HomeLetter) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LLSpace.s) {
                leadingPill(letter)
                provenancePill(letter)
            }
            VStack(alignment: .leading, spacing: LLSpace.s) {
                leadingPill(letter)
                provenancePill(letter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func leadingPill(_ letter: HomeLetter) -> some View {
        if letter.card.opensScamWarning {
            let label = HomeScamPillCopy.label(count: HomeScamPillCopy.count(in: letter.card))
            statusPill(
                text: label,
                spoken: label,
                symbol: nil,
                foreground: LLColor.warning,
                background: LLColor.warningTint
            )
        } else if let iso = letter.card.deadline, let pill = HomeDeadlinePillCopy.make(iso: iso, now: now) {
            statusPill(
                text: pill.visual,
                spoken: pill.spoken,
                symbol: nil,
                foreground: LLColor.deadline,
                background: LLColor.deadlineTint
            )
        }
    }

    private func provenancePill(_ letter: HomeLetter) -> some View {
        statusPill(
            text: HomeProvenanceCopy.visual(for: letter.path),
            spoken: HomeProvenanceCopy.spoken(for: letter.path),
            symbol: HomeProvenanceCopy.symbol(for: letter.path),
            foreground: letter.path == .device ? LLColor.device : LLColor.cloud,
            background: letter.path == .device ? LLColor.deviceTint : LLColor.cloudTint
        )
    }

    private func statusPill(
        text: String,
        spoken: String,
        symbol: String?,
        foreground: Color,
        background: Color
    ) -> some View {
        HStack(spacing: LLSpace.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, LLSpace.sm)
        .padding(.vertical, LLSpace.xs)
        .background(background, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var scanBar: some View {
        VStack(spacing: LLSpace.m) {
            scanControls
            Text("History is stored only on this iPhone")
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

    @ViewBuilder
    private var scanControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: LLSpace.m) {
                scanButton
                ClearInkGlassButton("Import a PDF or photo", systemImage: "square.and.arrow.down", kind: .regular) {
                    openScan(importOptions: true)
                }
            }
        } else {
            HStack(alignment: .center, spacing: LLSpace.m) {
                scanButton
                HomeImportButton { openScan(importOptions: true) }
            }
        }
    }

    private var scanButton: some View {
        ClearInkGlassButton("Scan a letter", systemImage: "camera", kind: .prominent(LLColor.ink)) {
            openScan(importOptions: false)
        }
    }

    @ViewBuilder
    private func openedLetter(_ id: UUID) -> some View {
        if let record = records.first(where: { $0.id == id }), let card = record.card {
            openedCard(record, card: card)
                .modifier(HomeLetterZoom(id: id, namespace: letterZoom, enabled: !reduceMotion))
        }
    }

    @ViewBuilder
    private func openedCard(_ record: LetterRecord, card: LetterCard) -> some View {
        if card.opensScamWarning {
            ScamWarningScreen(card: card, path: readingPath(for: record))
        } else {
            LetterCardScreen(
                card: card,
                path: readingPath(for: record),
                pageCount: 0,
                ocrText: record.ocrText,
                letterID: record.id,
                completion: completion,
                preferences: preferences,
                availability: availability
            )
        }
    }

    private func readingPath(for record: LetterRecord) -> ReadingPath {
        record.source == .cloud ? .cloud : .device
    }

    private func openScan(importOptions: Bool) {
        scanOpensImport = importOptions
        finishedRead = nil
        showLetter = false
        showScan = true
    }

    private func markDone(_ letter: HomeLetter) {
        if !letter.isDone {
            doneTaps += 1
        }
        completion.toggle(letter.id)
    }

    private func deleteAllLetters() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

private struct PlainListRow: ViewModifier {
    var insets: EdgeInsets

    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(insets)
    }
}

private extension View {
    func plainListRow(insets: EdgeInsets) -> some View {
        modifier(PlainListRow(insets: insets))
    }
}

private struct HomeLetterZoom: ViewModifier {
    var id: UUID
    var namespace: Namespace.ID
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct HomeLetterZoomSource: ViewModifier {
    var id: UUID
    var namespace: Namespace.ID
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct HomeImportButton: View {
    var action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            button.buttonStyle(.bordered)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.down")
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Import a PDF or photo")
        .controlSize(.large)
        .tint(LLColor.ink)
    }
}

#if DEBUG

#Preview("02 Home") {
    HomePreview(empty: false)
}

#Preview("02 Home, empty") {
    HomePreview(empty: true)
}

#Preview("02 Home, accessibility XXL") {
    HomePreview(empty: false)
        .dynamicTypeSize(.accessibility5)
}

private struct HomePreview: View {
    var empty: Bool
    @State private var completion = LetterCompletion(doneIDs: [HomeSample.doneID])

    var body: some View {
        NavigationStack {
            HomeScreen(
                preferences: PrivacySettingsModel(writesDefaults: false),
                availability: .available,
                completion: completion
            )
        }
        .modelContainer(empty ? HomeSample.emptyContainer : HomeSample.filledContainer)
    }
}

private enum HomeSample {
    static let councilID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let scamID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let infoID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let plainID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    static let doneID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!

    static let emptyContainer: ModelContainer = makeContainer(fill: false)
    static let filledContainer: ModelContainer = makeContainer(fill: true)

    private static func makeContainer(fill: Bool) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: LetterRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            if fill {
                let context = container.mainContext
                for record in records() {
                    context.insert(record)
                }
                try context.save()
            }
            return container
        } catch {
            fatalError("Could not build the Home preview store: \(error)")
        }
    }

    private static func records() -> [LetterRecord] {
        let calendar = HomeCalendar.london
        let today = calendar.startOfDay(for: .now)
        let due = calendar.date(byAdding: .day, value: 21, to: today) ?? today
        let parts = calendar.dateComponents([.year, .month, .day], from: due)
        let iso = String(
            format: "%04d-%02d-%02d",
            parts.year ?? 2026,
            parts.month ?? 12,
            parts.day ?? 3
        )
        return [
            record(
                id: councilID,
                createdAt: today,
                card: LetterCard(
                    type: .reminder,
                    senderKind: .council,
                    action: "Pay the balance or set up a payment plan.",
                    deadline: iso,
                    deadlineQuote: "Please pay by the date in this letter",
                    amountQuote: "£186.40",
                    watchOuts: [],
                    scamSigns: [],
                    noActionNeeded: false
                ),
                source: .onDevice,
                ocr: "Dear Jane Smith, please pay by the date in this letter. Our reference: AB12CD34EF."
            ),
            record(
                id: scamID,
                createdAt: today,
                card: LetterCard(
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
                ),
                source: .cloud,
                ocr: "Dear Jane Smith, pay a £50 release fee."
            ),
            record(
                id: infoID,
                createdAt: calendar.date(byAdding: .day, value: -40, to: today) ?? today,
                card: LetterCard(
                    type: .information,
                    senderKind: .nhs,
                    action: "Keep this for your records.",
                    deadline: nil,
                    deadlineQuote: nil,
                    amountQuote: nil,
                    watchOuts: [],
                    scamSigns: [],
                    noActionNeeded: true
                ),
                source: .onDevice,
                ocr: "This appointment letter is for your information."
            ),
            record(
                id: plainID,
                createdAt: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                card: LetterCard(
                    type: .information,
                    senderKind: .school,
                    action: "No reply is needed.",
                    deadline: nil,
                    deadlineQuote: nil,
                    amountQuote: nil,
                    watchOuts: [],
                    scamSigns: [],
                    noActionNeeded: false
                ),
                source: .onDevice,
                ocr: "A note from school."
            ),
            record(
                id: doneID,
                createdAt: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                card: LetterCard(
                    type: .bill,
                    senderKind: .utility,
                    action: "The balance was paid.",
                    deadline: iso,
                    deadlineQuote: nil,
                    amountQuote: nil,
                    watchOuts: [],
                    scamSigns: [],
                    noActionNeeded: false
                ),
                source: .onDevice,
                ocr: "Your electricity balance."
            ),
        ]
    }

    private static func record(
        id: UUID,
        createdAt: Date,
        card: LetterCard,
        source: CardReadSource,
        ocr: String
    ) -> LetterRecord {
        let json: String
        do {
            json = try CardJSON.encodeString(card)
        } catch {
            fatalError("Preview card did not encode: \(error)")
        }
        return LetterRecord(
            id: id,
            createdAt: createdAt,
            ocrText: ocr,
            cardJSON: json,
            sourceRaw: source.rawValue,
            modelVersion: "preview",
            latencyMS: 0,
            detailsRemoved: 0,
            schemaVersion: 2
        )
    }
}

#endif
