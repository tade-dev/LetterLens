//
//  Prompts.swift
//  LetterLens-iOS
//

import Foundation

enum CardPrompt {
    /// Low end of the 0–0.2 range requested for the card.
    static let temperature: Float = 0.1
    static let onDeviceTemperature: Double = 0.1

    /// On-device sessions are limited to about 4096 tokens. One page fits in one chunk.
    static let chunkCharacterLimit = 8_000

    static let jsonRetrySuffix = """

    Your previous reply was not valid JSON. Return only one JSON object matching the schema. No markdown and no commentary.
    """

    static func filled(template: String, ocrText: String) -> String {
        if template.contains("{ocr_text}") {
            return template.replacingOccurrences(of: "{ocr_text}", with: ocrText)
        }
        return template + "\n\nLETTER:\n<<<\n\(ocrText)\n>>>"
    }

    static func chunks(of text: String) -> [String] {
        let normalised = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{000c}", with: "\n\n")
        if normalised.count <= chunkCharacterLimit {
            return [normalised]
        }

        let paragraphs = normalised.components(separatedBy: "\n\n")
        var chunks: [String] = []
        var current = ""
        func appendCurrent() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { chunks.append(trimmed) }
            current = ""
        }

        for paragraph in paragraphs {
            let piece = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if piece.isEmpty { continue }
            if piece.count > chunkCharacterLimit {
                appendCurrent()
                var rest = piece
                while rest.count > chunkCharacterLimit {
                    let end = rest.index(rest.startIndex, offsetBy: chunkCharacterLimit)
                    chunks.append(String(rest[..<end]))
                    rest = String(rest[end...])
                }
                current = rest
                continue
            }
            let joinedCount = current.isEmpty ? piece.count : current.count + 2 + piece.count
            if joinedCount > chunkCharacterLimit {
                appendCurrent()
                current = piece
            } else if current.isEmpty {
                current = piece
            } else {
                current += "\n\n" + piece
            }
        }
        appendCurrent()
        return chunks.isEmpty ? [normalised] : chunks
    }
}
