//
//  ReadingScreen.swift
//  LetterLens-iOS
//
//  Screen 04. Device and cloud share one layout. Colour, copy, and the
//  redaction row follow `ReadingProgress.path`. `onCardReady` fires after
//  validation. RootView pushes screen 06 when `progress.card` has a scam sign,
//  and screen 05 for any other stored card. `onReadingFailed` is the route to
//  state 15, which is not built yet.

import SwiftUI
import UIKit

struct ReadingScreen: View {
    let pages: [UIImage]
    var progress: ReadingProgress
    var onCardReady: () -> Void
    var onReadingFailed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: ReadingChecklistFrame
    @State private var showSlowNote = false
    @State private var didHandOff = false
    @State private var didAnnounceLetterRead = false
    @State private var deferToken = 0
    @State private var deferredKind: ReadingChecklistItem.Kind?
    @ScaledMetric(relativeTo: .largeTitle) private var previewHeight: CGFloat = 280

    init(
        pages: [UIImage],
        progress: ReadingProgress,
        onCardReady: @escaping () -> Void = {},
        onReadingFailed: @escaping () -> Void = {}
    ) {
        self.pages = pages
        self.progress = progress
        self.onCardReady = onCardReady
        self.onReadingFailed = onReadingFailed
        let revealed = progress.phase == .validated ? ReadingChecklistFrame.cardOrder.count : 0
        _frame = State(initialValue: ReadingChecklistFrame(cardTicksRevealed: revealed))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                badge
                pagePreview
                titleBlock
                checklist
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LLColor.ground)
        .safeAreaInset(edge: .bottom) {
            Text(LetterCopy.disclaimerShort)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LLSpace.screen)
                .padding(.vertical, LLSpace.m)
                .background(LLColor.ground)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .sensoryFeedback(.error, trigger: progress.phase == .failed)
        .sensoryFeedback(.success, trigger: didHandOff)
        .simultaneousGesture(TapGesture().onEnded {
            guard progress.phase == .validated else { return }
            requestHandoff()
        })
        .onChange(of: progress.pagesOCRd) { previous, count in
            guard count == progress.pagesTotal, previous < count else { return }
            announce(progress.rowTitle(.textPulled))
            deferActive(progress.activeKind)
        }
        .onChange(of: progress.phase) { _, phase in
            switch phase {
            case .redacting:
                announce(progress.rowTitle(.detailsRemoved))
                deferActive(.sender)
            case .validated:
                if frame.cardTicksRevealed == 0 {
                    frame.deferredActive = []
                    frame.highlighted = nil
                    frame.cardTicksRevealed = 1
                }
            case .failed:
                onReadingFailed()
            case .ocr, .carding:
                break
            }
            if phase == .validated || phase == .failed {
                withAnimation(.easeOut(duration: ReadingMotion.slowLetterFade)) {
                    showSlowNote = false
                }
            }
        }
        .task(id: progress.phase) {
            await playValidationIfNeeded()
        }
        .task(id: deferToken) {
            guard deferToken > 0, let kind = deferredKind else { return }
            try? await Task.sleep(for: ReadingMotion.activationDelay)
            guard !Task.isCancelled else { return }
            if deferredKind == kind {
                frame.deferredActive = []
            }
        }
        .task {
            if progress.phase == .failed {
                onReadingFailed()
            }
            try? await Task.sleep(for: .seconds(ReadingMotion.slowLetterDelay))
            guard !Task.isCancelled else { return }
            guard progress.phase != .validated, progress.phase != .failed else { return }
            withAnimation(.easeInOut(duration: ReadingMotion.slowLetterFade)) {
                showSlowNote = true
            }
        }
    }

    private var pathColor: Color {
        progress.path == .device ? LLColor.device : LLColor.cloud
    }

    private var pathTint: Color {
        progress.path == .device ? LLColor.deviceTint : LLColor.cloudTint
    }

    private var badge: some View {
        HStack(spacing: LLSpace.s) {
            badgeIcon
            Text(progress.badgeTitle)
                .font(LLFont.badge)
        }
        .foregroundStyle(pathColor)
        .padding(.horizontal, LLSpace.m)
        .padding(.vertical, LLSpace.s)
        .background(pathTint, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var badgeIcon: some View {
        let icon = Image(systemName: progress.badgeSymbol)
            .font(LLFont.badge)
            .accessibilityHidden(true)
        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.bounce, options: .nonRepeating)
        }
    }

    private var displayedIndex: Int {
        guard !pages.isEmpty else { return 0 }
        return min(progress.displayedPageIndex, pages.count - 1)
    }

    private var pagePreview: some View {
        GeometryReader { geo in
            let image = pages.indices.contains(displayedIndex) ? pages[displayedIndex] : nil
            let rect = aspectFit(image?.size ?? geo.size, in: geo.size)
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: rect.width, height: rect.height)
                        .overlay {
                            ScanLineOverlay(
                                tint: pathColor,
                                visible: progress.showsScanLine,
                                reduceMotion: reduceMotion
                            )
                        }
                        .clipped()
                        .position(x: rect.midX, y: rect.midY)
                        .id(displayedIndex)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(pageAnimation, value: displayedIndex)
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewHeight)
        .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.panel, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: LLRadius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LLRadius.panel, style: .continuous)
                .strokeBorder(LLColor.line, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pageLabel)
    }

    private var pageLabel: String {
        let total = max(pages.count, 1)
        return "Your scanned letter, page \(displayedIndex + 1) of \(total)"
    }

    private var pageAnimation: Animation {
        .easeInOut(duration: reduceMotion ? ReadingMotion.reduceMotionCrossfade : ReadingMotion.pageCrossfade)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: LLSpace.s) {
            Text("Reading your letter…")
                .font(LLFont.displayS)
                .tracking(-0.4)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(progress.subline)
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if showSlowNote {
                Text("Long letters take a little longer.")
                    .font(LLFont.body)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: ReadingMotion.slowLetterFade), value: showSlowNote)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            ForEach(progress.checklist) { item in
                checklistRow(item)
            }
        }
    }

    private func checklistRow(_ item: ReadingChecklistItem) -> some View {
        let status = frame.status(for: item, phase: progress.phase)
        let bold = status == .active || status == .failed
        return HStack(alignment: .center, spacing: LLSpace.m) {
            ReadingStatusMark(status: status, tint: pathColor, reduceMotion: reduceMotion)
            Text(item.title)
                .font(bold ? LLFont.callout.weight(.bold) : LLFont.callout)
                .foregroundStyle(LLColor.ink)
                .contentTransition(.numericText())
                .animation(.spring(duration: ReadingMotion.tickSpringDuration, bounce: 0), value: item.title)
                .animation(.spring(duration: ReadingMotion.tickSpringDuration, bounce: 0), value: bold)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel(for: item, status: status))
    }

    private func spokenLabel(for item: ReadingChecklistItem, status: ReadingChecklistItem.Status) -> String {
        if status == .failed {
            return "\(item.title), failed"
        }
        return item.title
    }

    private func aspectFit(_ image: CGSize, in container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        let origin = CGPoint(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2
        )
        return CGRect(origin: origin, size: size)
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    private func deferActive(_ kind: ReadingChecklistItem.Kind) {
        frame.deferredActive = [kind]
        deferredKind = kind
        deferToken += 1
    }

    private func playValidationIfNeeded() async {
        guard progress.phase == .validated, !didHandOff else { return }
        guard frame.cardTicksRevealed < ReadingChecklistFrame.cardOrder.count else { return }
        if frame.cardTicksRevealed == 0 {
            frame.deferredActive = []
            frame.highlighted = nil
            frame.cardTicksRevealed = 1
        }

        try? await Task.sleep(for: ReadingMotion.activationDelay)
        guard !didHandOff, !Task.isCancelled else { return }
        frame.highlighted = .datesAndAmounts

        try? await Task.sleep(for: ReadingMotion.gapAfterActivation)
        guard !didHandOff, !Task.isCancelled else { return }
        frame.cardTicksRevealed = 2
        frame.highlighted = nil

        try? await Task.sleep(for: ReadingMotion.activationDelay)
        guard !didHandOff, !Task.isCancelled else { return }
        frame.highlighted = .warningSigns

        try? await Task.sleep(for: ReadingMotion.gapAfterActivation)
        guard !didHandOff, !Task.isCancelled else { return }
        frame.cardTicksRevealed = 3
        frame.highlighted = nil
        announceLetterRead()

        try? await Task.sleep(for: ReadingMotion.tickStagger)
        guard !didHandOff, !Task.isCancelled else { return }
        requestHandoff()
    }

    private func announceLetterRead() {
        guard !didAnnounceLetterRead else { return }
        didAnnounceLetterRead = true
        announce("Letter read")
    }

    private func requestHandoff() {
        guard progress.phase == .validated, !didHandOff else { return }
        didHandOff = true
        frame.cardTicksRevealed = ReadingChecklistFrame.cardOrder.count
        frame.highlighted = nil
        frame.deferredActive = []
        announceLetterRead()
        onCardReady()
    }
}

private struct ReadingStatusMark: View {
    var status: ReadingChecklistItem.Status
    var tint: Color
    var reduceMotion: Bool
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 22

    private var symbolName: String {
        switch status {
        case .ticked:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle"
        case .active, .pending:
            "circle"
        }
    }

    private var symbolColor: Color {
        status == .failed ? LLColor.ink : tint
    }

    var body: some View {
        ZStack {
            statusSymbol
                .opacity(status == .ticked || status == .failed ? 1 : 0)
            if status == .pending {
                Circle()
                    .stroke(LLColor.controlBorder, lineWidth: ReadingMotion.lineWeight)
            }
            if status == .active {
                ReadingActiveRing(tint: tint, reduceMotion: reduceMotion)
            }
        }
        .frame(width: side, height: side)
        .animation(
            reduceMotion
                ? .easeOut(duration: ReadingMotion.reduceMotionCrossfade)
                : .spring(duration: ReadingMotion.tickSpringDuration, bounce: 0),
            value: status
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusSymbol: some View {
        let symbol = Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(symbolColor)
        if reduceMotion {
            symbol.contentTransition(.opacity)
        } else {
            symbol
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: status)
        }
    }
}

private struct ReadingActiveRing: View {
    var tint: Color
    var reduceMotion: Bool
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: reduceMotion ? 1 : 0.25)
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: ReadingMotion.lineWeight, lineCap: .round)
            )
            .rotationEffect(.degrees(reduceMotion ? -90 : (spinning ? 270 : -90)))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    spinning = true
                }
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG

#Preview("04 Reading, device mid-OCR") {
    ReadingPreviewHost(script: .deviceMidOCR)
}

#Preview("04 Reading, cloud carding") {
    ReadingPreviewHost(script: .cloudCarding)
}

#Preview("04 Reading, accessibility XXL") {
    ReadingPreviewHost(script: .cloudCarding)
        .dynamicTypeSize(.accessibility4)
}

/// Plays real events so the checklist can move in the preview canvas.
#Preview("04 Reading, device event playback") {
    ReadingEventPlaybackPreview()
}

private struct ReadingPreviewHost: View {
    @State private var progress: ReadingProgress
    private let pages: [UIImage]

    init(script: ReadingPreviewScript) {
        let progress = script.makeProgress()
        _progress = State(initialValue: progress)
        pages = ReadingPreviewArtwork.pages(script.pagesTotal)
    }

    var body: some View {
        NavigationStack {
            ReadingScreen(pages: pages, progress: progress)
        }
    }
}

private struct ReadingEventPlaybackPreview: View {
    @State private var progress = ReadingProgress(pagesTotal: 2, path: .device)

    var body: some View {
        NavigationStack {
            ReadingScreen(
                pages: ReadingPreviewArtwork.pages(2),
                progress: progress
            )
        }
        .task {
            await ReadingEventSimulator.play(
                [
                    .pageOCRFinished(index: 0),
                    .pageOCRFinished(index: 1),
                    .cardingStarted,
                    .cardValidated,
                ],
                on: progress
            )
        }
    }
}

enum ReadingPreviewArtwork {
    static func pages(_ count: Int) -> [UIImage] {
        (0..<count).map { page(number: $0 + 1, total: count) }
    }

    private static func page(number: Int, total: Int) -> UIImage {
        let size = CGSize(width: 400, height: 560)
        let renderer = UIGraphicsImageRenderer(size: size)
        let ink = UIColor(named: "ink") ?? UIColor.darkText
        let surface = UIColor(named: "surface") ?? UIColor.white
        let line = UIColor(named: "line") ?? UIColor.lightGray
        return renderer.image { context in
            surface.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ink.setFill()
            let title = "\(number)" as NSString
            let font = UIFont.boldSystemFont(ofSize: 28)
            title.draw(at: CGPoint(x: 28, y: 28), withAttributes: [
                .font: font,
                .foregroundColor: ink,
            ])
            line.setFill()
            for row in 0..<8 {
                let y = 88 + CGFloat(row) * 28
                let width = row % 3 == 2 ? 180 : 320
                context.fill(CGRect(x: 28, y: y, width: CGFloat(width), height: 8))
            }
            _ = total
        }
    }
}

#endif
