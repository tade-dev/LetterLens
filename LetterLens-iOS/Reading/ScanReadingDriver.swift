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
        publish: (LetterRead) -> Void
    ) async -> LetterRead? {
        guard pages.count == progress.pagesTotal, !pages.isEmpty else {
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
                progress.apply(.ocrFailed)
                return nil
            }
        }

        let ocr = pageTexts
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ocr.isEmpty else {
            progress.apply(.failed)
            return nil
        }

        if path == .cloud {
            progress.apply(.redactionFinished(count: redactedDetailCount(ocr)))
        }
        progress.apply(.cardingStarted)
        guard progress.phase == .carding else {
            progress.apply(.failed)
            return nil
        }

        let result: CardReadResult
        do {
            result = try await readCard(ocr)
        } catch is CancellationError {
            return nil
        } catch {
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

enum ScanPageOCR {
    /// On-device OCR for one captured page. The image is not uploaded.
    static func recognize(_ image: UIImage) async throws -> String {
        guard let data = image.pngData() else {
            throw TextRecognizer.Failure.unreadable
        }
        return try await TextRecognizer.recognize(data: data)
    }
}
