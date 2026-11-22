//
//  ScanReadingDriver.swift
//  LetterLens-iOS
//
//  Drives screen 04 from a scan's pages to the letter-card hand-off.
//  OCR stays on the device. The card read is the existing CardService,
//  passed in by the caller. This type does not open a network session.

import UIKit

@MainActor
enum ScanReadingDriver {
    /// Runs OCR, then the card read, and publishes the hand-off before validation.
    /// Nil means reading failed and the caller should not store a letter.
    static func read(
        pages: [UIImage],
        path: ReadingPath,
        progress: ReadingProgress,
        id: UUID,
        createdAt: Date,
        schemaVersion: Int,
        recognize: (UIImage) async throws -> String,
        readCard: (String) async throws -> CardReadResult,
        redactedDetailCount: (String) -> Int,
        publish: (LetterRead) -> Void,
        fail: (String) -> Void = { _ in }
    ) async -> LetterRead? {
        guard pages.count == progress.pagesTotal, !pages.isEmpty else {
            fail(ScanReadingFailure.unreadable)
            progress.apply(.failed)
            return nil
        }

        var pageTexts: [String] = []
        for (index, page) in pages.enumerated() {
            if Task.isCancelled { return nil }
            do {
                let text = try await recognize(page)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                pageTexts.append(text)
                progress.apply(.pageOCRFinished(index: index))
            } catch is CancellationError {
                return nil
            } catch TextRecognizer.Failure.noText {
                pageTexts.append("")
                progress.apply(.pageOCRFinished(index: index))
            } catch {
                fail(ScanReadingFailure.message(for: error))
                progress.apply(.ocrFailed)
                return nil
            }
        }

        let ocr = pageTexts
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ocr.isEmpty else {
            fail(ScanReadingFailure.noText)
            progress.apply(.failed)
            return nil
        }

        if path == .cloud {
            progress.apply(.redactionFinished(count: redactedDetailCount(ocr)))
        }
        progress.apply(.cardingStarted)
        guard progress.phase == .carding else {
            fail(ScanReadingFailure.unreadable)
            progress.apply(.failed)
            return nil
        }

        let result: CardReadResult
        do {
            result = try await readCard(ocr)
        } catch is CancellationError {
            return nil
        } catch {
            fail(ScanReadingFailure.message(for: error))
            progress.apply(.failed)
            return nil
        }

        if Task.isCancelled { return nil }
        let storedText = result.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        let read = LetterRead(
            id: id,
            createdAt: createdAt,
            card: result.card,
            path: result.source == .cloud ? .cloud : .device,
            pageCount: pages.count,
            ocrText: storedText.isEmpty ? ocr : storedText,
            modelVersion: result.modelVersion,
            latencyMS: result.latencyMS,
            detailsRemoved: result.detailsRemoved,
            schemaVersion: schemaVersion
        )
        publish(read)
        guard !Task.isCancelled else { return nil }
        progress.validate(result.card)
        return progress.phase == .validated ? read : nil
    }
}

/// Existing OCR and pipeline sentences. State 15 shows one of these.
enum ScanReadingFailure {
    static var noText: String {
        TextRecognizer.Failure.noText.errorDescription ?? "No text was found on the page."
    }

    static var unreadable: String {
        TextRecognizer.Failure.unreadable.errorDescription ?? "That file could not be read as a letter."
    }

    /// Shown to the reader, so it never carries SDK text. A letter that cannot be
    /// read produced "The operation couldn't be completed.
    /// (FirebaseAILogic.GenerateContentError error 0.)" on screen.
    static let generic = String(
        localized: "This letter could not be read. Try again in a moment."
    )

    static let offline = String(
        localized: "No connection, so the letter stayed on this iPhone. Try again when you are online."
    )

    static let busy = String(
        localized: "The reading service is busy. Try again in a moment."
    )

    static func message(for error: Error) -> String {
        if let described = (error as? LocalizedError)?.errorDescription,
           !described.isEmpty,
           !readsLikeDeveloperText(described) {
            return described
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return offline
            default:
                return generic
            }
        }
        if let status = ModelCallClassifier.httpStatus(error),
           ModelCallClassifier.transientCloudStatuses.contains(status) {
            return busy
        }
        let fallback = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty || readsLikeDeveloperText(fallback) {
            return generic
        }
        return fallback
    }

    /// Framework strings name a type, a domain or a numeric code. None of that
    /// means anything to someone holding a letter.
    static func readsLikeDeveloperText(_ text: String) -> Bool {
        let markers = [
            "couldn't be completed",
            "couldn’t be completed",
            "Error Domain=",
            "NSURLErrorDomain",
            "FirebaseAILogic",
            "GenerateContentError",
            "NSError",
        ]
        if markers.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        // "… error 0.)" and friends.
        return text.range(of: #"(?i)\berror -?\d+\b"#, options: .regularExpression) != nil
    }
}

enum ScanPageOCR {
    /// On-device OCR for one captured page. The image is not uploaded.
    static func recognize(_ image: UIImage) async throws -> String {
        guard let data = image.pngData() else {
            throw TextRecognizer.Failure.unreadable
        }
        return try await TextRecognizer.recognize(data: data)
    }
}
