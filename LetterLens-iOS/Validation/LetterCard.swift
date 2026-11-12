//
//  LetterCard.swift
//  LetterLens-iOS
//

import Foundation

/// The card schema from the shared prompt. Field names match it exactly.
struct LetterCard: Equatable {
    var type: String
    var senderKind: String
    var action: String
    var deadline: String?
    var deadlineQuote: String?
    var amountQuote: String?
    var watchOuts: [String]
    var scamSigns: [ScamSign]
    var noActionNeeded: Bool

    static let senderKinds: Set<String> = [
        "council", "hmrc", "bank", "benefits", "school", "utility", "landlord", "nhs", "other",
    ]

    static let empty = LetterCard(
        type: "",
        senderKind: "other",
        action: "",
        deadline: nil,
        deadlineQuote: nil,
        amountQuote: nil,
        watchOuts: [],
        scamSigns: [],
        noActionNeeded: false
    )

    /// Blank, the word "null", and the word "none" are the same as JSON null.
    static func nullish(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        switch trimmed.lowercased() {
        case "null", "none":
            return nil
        default:
            return trimmed
        }
    }
}

struct ScamSign: Equatable {
    var sign: String
    var quote: String?
}

extension LetterCard: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case senderKind = "sender_kind"
        case action
        case deadline
        case deadlineQuote = "deadline_quote"
        case amountQuote = "amount_quote"
        case watchOuts = "watch_outs"
        case scamSigns = "scam_signs"
        case noActionNeeded = "no_action_needed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        senderKind = try container.decodeIfPresent(String.self, forKey: .senderKind) ?? "other"
        action = try container.decodeIfPresent(String.self, forKey: .action) ?? ""
        deadline = Self.nullish(try container.decodeIfPresent(String.self, forKey: .deadline))
        deadlineQuote = Self.nullish(try container.decodeIfPresent(String.self, forKey: .deadlineQuote))
        amountQuote = Self.nullish(try container.decodeIfPresent(String.self, forKey: .amountQuote))
        watchOuts = try container.decodeIfPresent([String].self, forKey: .watchOuts) ?? []
        scamSigns = try container.decodeIfPresent([ScamSign].self, forKey: .scamSigns) ?? []
        noActionNeeded = try container.decodeIfPresent(Bool.self, forKey: .noActionNeeded) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(senderKind, forKey: .senderKind)
        try container.encode(action, forKey: .action)
        try encodeNullish(deadline, forKey: .deadline, in: &container)
        try encodeNullish(deadlineQuote, forKey: .deadlineQuote, in: &container)
        try encodeNullish(amountQuote, forKey: .amountQuote, in: &container)
        try container.encode(watchOuts, forKey: .watchOuts)
        try container.encode(scamSigns, forKey: .scamSigns)
        try container.encode(noActionNeeded, forKey: .noActionNeeded)
    }

    private func encodeNullish(
        _ value: String?,
        forKey key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

extension ScamSign: Codable {
    enum CodingKeys: String, CodingKey {
        case sign
        case quote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sign = try container.decodeIfPresent(String.self, forKey: .sign) ?? ""
        quote = LetterCard.nullish(try container.decodeIfPresent(String.self, forKey: .quote))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sign, forKey: .sign)
        if let quote {
            try container.encode(quote, forKey: .quote)
        } else {
            try container.encodeNil(forKey: .quote)
        }
    }
}

enum CardJSON {
    static func encode(_ card: LetterCard) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(card)
    }

    static func encodeString(_ card: LetterCard) throws -> String {
        let data = try encode(card)
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes one JSON object. Markdown fences and a short preamble are stripped locally.
    /// That recovery is not the model retry.
    static func decodeModelText(_ text: String) throws -> LetterCard {
        guard let object = jsonObjectString(from: text),
              let data = object.data(using: .utf8)
        else {
            throw CardJSONError.notAnObject
        }
        return try JSONDecoder().decode(LetterCard.self, from: data)
    }

    static func jsonObjectString(from text: String) -> String? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let newline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: newline)...])
            }
            if let closing = trimmed.range(of: "```", options: .backwards) {
                trimmed = String(trimmed[..<closing.lowerBound])
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let start = trimmed.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaping = false
        var index = start
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if inString {
                if escaping {
                    escaping = false
                } else if character == "\\" {
                    escaping = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(trimmed[start...index])
                }
            }
            index = trimmed.index(after: index)
        }
        return nil
    }
}

enum CardJSONError: Error {
    case notAnObject
}
