//
//  LetterRecord.swift
//  LetterLens-iOS
//

import Foundation
import SwiftData

/// One read letter, stored only on this device. No photo is stored.
@Model
final class LetterRecord {
    var id: UUID
    var createdAt: Date
    var ocrText: String
    var cardJSON: String
    var sourceRaw: String
    var modelVersion: String
    var latencyMS: Int
    var detailsRemoved: Int
    var schemaVersion: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        ocrText: String,
        cardJSON: String,
        sourceRaw: String,
        modelVersion: String,
        latencyMS: Int,
        detailsRemoved: Int,
        schemaVersion: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.ocrText = ocrText
        self.cardJSON = cardJSON
        self.sourceRaw = sourceRaw
        self.modelVersion = modelVersion
        self.latencyMS = latencyMS
        self.detailsRemoved = detailsRemoved
        self.schemaVersion = schemaVersion
    }

    var source: CardReadSource {
        CardReadSource(rawValue: sourceRaw) ?? .onDevice
    }

    var card: LetterCard? {
        guard let data = cardJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LetterCard.self, from: data)
    }
}
