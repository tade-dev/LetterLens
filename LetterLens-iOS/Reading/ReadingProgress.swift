//
//  ReadingProgress.swift
//  LetterLens-iOS
//
//  Screen 04 state. Swift wires the real pipeline later by calling `apply`.
//  Names line up with the unmerged scan-to-card branch, without importing it:
//  - `ReadingPath.device` is `ModelRoute.onDeviceOnly` / `CardReadSource.onDevice`
//  - `ReadingPath.cloud` is a cloud or hybrid route / `CardReadSource.cloud`
//  - `redactedCount` is `CardReadResult.detailsRemoved`
//  Phases follow OCR (`TextRecognizer`) -> redaction (`Redactor`) -> card
//  (`CardService`) -> validation (`CardValidator`).
//
//  Checklist ticks change only inside `apply`. A timer must not call this.

import Foundation
import Observation

// MARK: - Pipeline-facing values

enum ReadingPath: Equatable, Sendable {
    case device
    case cloud
}

enum ReadingPhase: Equatable, Sendable {
    case ocr
    case redacting
    case carding
    case validated
    case failed
}

enum ReadingEvent: Equatable, Sendable {
    /// `index` is the zero-based page that just finished. Pages are sequential.
    case pageOCRFinished(index: Int)
    /// OCR could not read the letter. Screen 15 is presented by the caller.
    case ocrFailed
    /// Cloud path only. `count` is how many details the redactor removed.
    case redactionFinished(count: Int)
    case cardingStarted
    case cardValidated
    /// A failure after OCR has produced text. Also stops the screen.
    case failed
}

/// Read-only progress surface. `ReadingProgress` is the observable model the screen uses.
@MainActor
protocol ReadingProgressSnapshot: AnyObject {
    var pagesTotal: Int { get }
    var pagesOCRd: Int { get }
    var currentPageIndex: Int { get }
    var path: ReadingPath { get }
    var redactedCount: Int { get }
    var phase: ReadingPhase { get }
}

// MARK: - Motion timings (Pulse)

enum ReadingMotion {
    static let sweepDuration: TimeInterval = 1.6
    static let sweepFade: TimeInterval = 0.2
    static let settleFade: TimeInterval = 0.15
    static let pageCrossfade: TimeInterval = 0.2
    static let reduceMotionCrossfade: TimeInterval = 0.15
    static let tickStaggerMS = 120
    static let activationDelayMS = 80
    /// Three staggers after validation: ticks at 0, 120 and 240, then the hand-off.
    static let handoffDelayMS = 360
    static let tickSpringDuration: TimeInterval = 0.25
    static let slowLetterDelay: TimeInterval = 8
    static let slowLetterFade: TimeInterval = 0.2
    /// Spring used only for the push from scan entry into reading.
    static let pushSpringDuration: TimeInterval = 0.5
    static let pushSpringBounce: Double = 0.2
    static let reduceMotionLine: CGFloat = 0.40
    static let reduceMotionOpacity: Double = 0.60
    static let trailLength: CGFloat = 24
    static let trailOpacity: Double = 0.12
    static let lineWeight: CGFloat = 2

    static var tickStagger: Duration { .milliseconds(tickStaggerMS) }
    static var activationDelay: Duration { .milliseconds(activationDelayMS) }
    static var gapAfterActivation: Duration { .milliseconds(tickStaggerMS - activationDelayMS) }
    static var handoffDelay: Duration { .milliseconds(handoffDelayMS) }
}

// MARK: - Checklist

struct ReadingChecklistItem: Equatable, Identifiable {
    enum Kind: Equatable, Hashable, Sendable {
        case textPulled
        case detailsRemoved
        case sender
        case datesAndAmounts
        case warningSigns
    }

    enum Status: Equatable, Sendable {
        case pending
        case active
        case ticked
        case failed
    }

    var kind: Kind
    var status: Status
    var title: String
    var id: Kind { kind }
}

/// How screen 04 reveals the single "card validated" event.
/// The model marks rows 2–4 ticked together. This frame staggers that one event.
struct ReadingChecklistFrame: Equatable {
    var cardTicksRevealed: Int = 0
    var highlighted: ReadingChecklistItem.Kind?
    var deferredActive: Set<ReadingChecklistItem.Kind> = []

    static let cardOrder: [ReadingChecklistItem.Kind] = [.sender, .datesAndAmounts, .warningSigns]

    func status(for item: ReadingChecklistItem, phase: ReadingPhase) -> ReadingChecklistItem.Status {
        let resolved: ReadingChecklistItem.Status
        switch item.kind {
        case .sender, .datesAndAmounts, .warningSigns:
            if phase == .validated {
                let index = Self.cardOrder.firstIndex(of: item.kind) ?? 0
                if index < cardTicksRevealed {
                    resolved = .ticked
                } else if highlighted == item.kind {
                    resolved = .active
                } else {
                    resolved = .pending
                }
            } else {
                resolved = item.status
            }
        case .textPulled, .detailsRemoved:
            resolved = item.status
        }
        if resolved == .active, deferredActive.contains(item.kind) {
            return .pending
        }
        return resolved
    }
}

// MARK: - Model

@MainActor
@Observable
final class ReadingProgress: ReadingProgressSnapshot {
    let pagesTotal: Int
    private(set) var pagesOCRd: Int = 0
    private(set) var currentPageIndex: Int = 0
    let path: ReadingPath
    private(set) var redactedCount: Int = 0
    private(set) var phase: ReadingPhase = .ocr
    private(set) var didFinishRedaction = false
    /// The validated card. Screen 04 does not render it. RootView pushes 05 or 06
    /// from this value when reading finishes. Nil means the pipeline has not stored one.
    var card: LetterCard?

    init(pagesTotal: Int, path: ReadingPath) {
        precondition(pagesTotal > 0, "A letter has at least one page.")
        self.pagesTotal = pagesTotal
        self.path = path
    }

    /// Stores the card, then validates when the checklist is still in the carding phase.
    func validate(_ card: LetterCard) {
        self.card = card
        apply(.cardValidated)
    }

    func apply(_ event: ReadingEvent) {
        guard phase != .failed, phase != .validated else { return }
        switch event {
        case .pageOCRFinished(let index):
            guard phase == .ocr, index == pagesOCRd, index < pagesTotal else { return }
            pagesOCRd = index + 1
            if pagesOCRd < pagesTotal {
                currentPageIndex = pagesOCRd
            }
        case .ocrFailed:
            guard phase == .ocr, pagesOCRd < pagesTotal else { return }
            phase = .failed
        case .redactionFinished(let count):
            guard path == .cloud, phase == .ocr, pagesOCRd == pagesTotal, !didFinishRedaction else { return }
            redactedCount = max(0, count)
            didFinishRedaction = true
            phase = .redacting
        case .cardingStarted:
            guard pagesOCRd == pagesTotal else { return }
            switch path {
            case .device:
                guard phase == .ocr else { return }
            case .cloud:
                guard phase == .redacting, didFinishRedaction else { return }
            }
            phase = .carding
        case .cardValidated:
            guard phase == .carding else { return }
            phase = .validated
        case .failed:
            phase = .failed
        }
    }

    var subline: String {
        switch path {
        case .device:
            "Nothing has left your phone."
        case .cloud:
            "Only the text was sent, with your details removed. Never the photo."
        }
    }

    var badgeTitle: String {
        switch path {
        case .device:
            "On this iPhone · offline OK"
        case .cloud:
            "In the cloud · details removed"
        }
    }

    /// Same marks as `LLProvenanceBadge`: a lock on device, `cloud` in the cloud.
    var badgeSymbol: String {
        switch path {
        case .device:
            "lock.fill"
        case .cloud:
            "cloud"
        }
    }

    var showsScanLine: Bool {
        switch phase {
        case .ocr, .redacting, .carding:
            true
        case .validated, .failed:
            false
        }
    }

    /// During OCR, the page being read. Once every page is read, page 1.
    var displayedPageIndex: Int {
        guard pagesTotal > 0 else { return 0 }
        if pagesOCRd >= pagesTotal { return 0 }
        return min(max(currentPageIndex, 0), pagesTotal - 1)
    }

    var checklist: [ReadingChecklistItem] {
        kinds.map { kind in
            ReadingChecklistItem(kind: kind, status: status(for: kind), title: rowTitle(kind))
        }
    }

    func rowTitle(_ kind: ReadingChecklistItem.Kind) -> String {
        switch kind {
        case .textPulled:
            "Text pulled from \(pagesOCRd) \(pagesOCRd == 1 ? "page" : "pages")"
        case .detailsRemoved:
            "Removed \(redactedCount) \(redactedCount == 1 ? "detail" : "details")"
        case .sender:
            "Working out who sent it"
        case .datesAndAmounts:
            "Finding dates and amounts"
        case .warningSigns:
            "Checking for warning signs"
        }
    }

    var activeKind: ReadingChecklistItem.Kind {
        if pagesOCRd < pagesTotal { return .textPulled }
        if path == .cloud, !didFinishRedaction { return .detailsRemoved }
        return .sender
    }

    private var kinds: [ReadingChecklistItem.Kind] {
        var rows: [ReadingChecklistItem.Kind] = [.textPulled]
        if path == .cloud {
            rows.append(.detailsRemoved)
        }
        rows.append(contentsOf: ReadingChecklistFrame.cardOrder)
        return rows
    }

    private func status(for kind: ReadingChecklistItem.Kind) -> ReadingChecklistItem.Status {
        if phase == .failed {
            if isTicked(kind) { return .ticked }
            if kind == activeKind { return .failed }
            return .pending
        }
        if isTicked(kind) { return .ticked }
        if kind == activeKind { return .active }
        return .pending
    }

    private func isTicked(_ kind: ReadingChecklistItem.Kind) -> Bool {
        switch kind {
        case .textPulled:
            pagesOCRd >= pagesTotal
        case .detailsRemoved:
            path == .cloud && didFinishRedaction
        case .sender, .datesAndAmounts, .warningSigns:
            phase == .validated
        }
    }
}

#if DEBUG

/// Preview-only player. It sleeps between events. Each change still goes through `apply`.
@MainActor
enum ReadingEventSimulator {
    static func play(
        _ events: [ReadingEvent],
        on progress: ReadingProgress,
        pause: Duration = .milliseconds(900)
    ) async {
        for event in events {
            if Task.isCancelled { return }
            progress.apply(event)
            try? await Task.sleep(for: pause)
        }
    }
}

enum ReadingPreviewScript {
    case deviceMidOCR
    case cloudCarding

    var pagesTotal: Int {
        switch self {
        case .deviceMidOCR: 3
        case .cloudCarding: 2
        }
    }

    var path: ReadingPath {
        switch self {
        case .deviceMidOCR: .device
        case .cloudCarding: .cloud
        }
    }

    var events: [ReadingEvent] {
        switch self {
        case .deviceMidOCR:
            [.pageOCRFinished(index: 0)]
        case .cloudCarding:
            [
                .pageOCRFinished(index: 0),
                .pageOCRFinished(index: 1),
                .redactionFinished(count: 4),
                .cardingStarted,
            ]
        }
    }

    @MainActor
    func makeProgress() -> ReadingProgress {
        let progress = ReadingProgress(pagesTotal: pagesTotal, path: path)
        for event in events {
            progress.apply(event)
        }
        return progress
    }
}

#endif
