//
//  TextRecognizer.swift
//  LetterLens-iOS
//

import CoreFoundation
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

/// On-device OCR. The image is not returned and is not uploaded.
enum TextRecognizer {
    enum Failure: LocalizedError {
        case unreadable
        case noText

        var errorDescription: String? {
            switch self {
            case .unreadable:
                "That file could not be read as a letter."
            case .noText:
                "No text was found on the page."
            }
        }
    }

    static func recognize(data: Data) async throws -> String {
        if data.starts(with: Data("%PDF".utf8)) {
            return try await recognizePDF(data)
        }
        guard let image = cgImage(from: data) else { throw Failure.unreadable }
        return try await recognize(cgImage: image, imageData: data)
    }

    static func recognize(cgImage: CGImage) async throws -> String {
        guard let encoded = pngData(from: cgImage) else { throw Failure.unreadable }
        return try await recognize(cgImage: cgImage, imageData: encoded)
    }

    private static func recognizePDF(_ data: Data) async throws -> String {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw Failure.unreadable
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let image = render(page) else { continue }
            let text = try await recognize(cgImage: image)
            if !text.isEmpty { pages.append(text) }
        }
        let joined = pages.joined(separator: "\n\n")
        guard !joined.isEmpty else { throw Failure.noText }
        return joined
    }

    private static func recognize(cgImage: CGImage, imageData: Data) async throws -> String {
        if let documentText = try? await recognizeDocument(imageData), !documentText.isEmpty {
            return documentText
        }
        let lines = try recognizeLines(cgImage)
        guard !lines.isEmpty else { throw Failure.noText }
        return lines
    }

    /// iOS 26 document request. Paragraphs and tables come back in reading order.
    /// `perform(on:)` and `document` follow the Vision sample for RecognizeDocumentsRequest.
    private static func recognizeDocument(_ data: Data) async throws -> String {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [
            Locale.Language(identifier: "en-GB"),
            Locale.Language(identifier: "en-US"),
        ]
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: data)
        guard let document = observations.first?.document else { return "" }
        return plainText(from: document)
    }

    private static func plainText(from document: DocumentObservation.Container) -> String {
        var lines: [String] = []
        for paragraph in document.paragraphs {
            let transcript = paragraph.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty { lines.append(transcript) }
        }
        let paragraphText = lines.joined(separator: "\n")
        for table in document.tables {
            for row in table.rows {
                let cells = row.map {
                    $0.content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
                guard !cells.isEmpty else { continue }
                let rowText = cells.joined(separator: "\t")
                if paragraphText.contains(rowText) { continue }
                lines.append(rowText)
            }
        }
        let structured = lines.joined(separator: "\n")
        let flat = document.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !structured.isEmpty {
            return structured.count >= flat.count ? structured : flat
        }
        return flat
    }

    /// Line OCR, top to bottom. Vision's origin is the bottom left.
    private static func recognizeLines(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-GB", "en-US"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = (request.results ?? []).sorted { lhs, rhs in
            let deltaY = lhs.boundingBox.midY - rhs.boundingBox.midY
            if abs(deltaY) > 0.012 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return context.makeImage()
    }
}
