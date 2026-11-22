//
//  PlanPrompt.swift
//  LetterLens-iOS
//
//  Fills `plan_prompt` from Remote Config. The letter is already redacted when it
//  gets here; this type never sees the original.

import Foundation

enum PlanPrompt {
    /// Gemini takes a Float, FoundationModels takes a Double.
    static let temperature: Float = 0.2
    static let onDeviceTemperature: Double = 0.2
    static let maxSteps = 4

    static let jsonRetrySuffix = "Reply with JSON only. No prose, no code fence."

    static func filled(
        template: String,
        redactedText: String,
        cardJSON: String,
        note: String
    ) -> String {
        template
            .replacingOccurrences(of: "{redacted_text}", with: redactedText)
            .replacingOccurrences(of: "{card_json}", with: cardJSON)
            .replacingOccurrences(of: "{user_note}", with: note)
    }
}

/// The model's reply. Decoded separately from `LetterCard` because the shapes differ.
struct PlanJSON: Decodable {
    struct Step: Decodable {
        var title: String?
        var detail: String?
    }

    var steps: [Step]?
    var what_to_say: String?
    var where_to_get_help: [String]?
}

enum PlanJSONDecode {
    /// Reuses the card's recovery: one markdown fence and any preamble are stripped locally.
    static func decode(_ text: String) throws -> PlanJSON {
        guard let object = CardJSON.jsonObjectString(from: text),
              let data = object.data(using: .utf8)
        else {
            throw PlanPipelineError.invalidJSON
        }
        return try JSONDecoder().decode(PlanJSON.self, from: data)
    }

    /// Drops empty steps, trims, and holds the plan to the four the prompt asks for.
    static func plan(from json: PlanJSON) -> NextStepsPlan {
        let steps: [NextStepsPlan.Step] = (json.steps ?? []).compactMap { step in
            let title = (step.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = (step.detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !detail.isEmpty else { return nil }
            return NextStepsPlan.Step(title: title, detail: detail)
        }
        let help = (json.where_to_get_help ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return NextStepsPlan(
            steps: Array(steps.prefix(PlanPrompt.maxSteps)),
            script: (json.what_to_say ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            whereToGetHelp: help,
            madeInCloud: true
        )
    }
}

enum PlanPipelineError: LocalizedError {
    case invalidJSON
    case emptyPrompt
    case firebaseNotConfigured
    case notAllowed

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "The plan did not come back in the expected format."
        case .emptyPrompt:
            "No plan prompt is configured."
        case .firebaseNotConfigured:
            "Firebase is not configured, so a plan cannot be made."
        case .notAllowed:
            "A plan needs the cloud, and this letter has not been allowed to leave the phone."
        }
    }
}
