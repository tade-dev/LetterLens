//
//  NextStepsPlan.swift
//  LetterLens-iOS
//
//  Screen 09's plan. It is not part of the card schema and it is not stored.
//
//  `CloudNextStepsPlanner` sends the redacted letter to `plan_model`, after the
//  consent sheet. `LocalSampleNextStepsPlanner` is the offline stand-in, used when
//  Firebase is not configured and in previews. Only the cloud planner sets
//  `madeInCloud`, so the badge never claims a cloud plan that did not happen.

import Foundation

struct NextStepsPlan: Equatable {
    struct Step: Equatable {
        var title: String
        var detail: String
    }

    var steps: [Step]
    /// May still contain redaction tokens. The screen puts the originals back locally.
    var script: String
    /// Free, official or charity sources. `PROMPTS.md` asks the model for these.
    var whereToGetHelp: [String] = []
    /// True only after a planner that actually called the cloud. The local sample stays false.
    var madeInCloud: Bool = false
}

protocol NextStepsPlanner {
    /// `redactedText` is the only letter body a later cloud planner may upload.
    /// `card` is the on-device display card. Details may already have been put back
    /// into it, so a cloud planner must not upload the card as it stands.
    func plan(redactedText: String, card: LetterCard, note: String) async -> NextStepsPlan
}

enum NextStepsConsent {
    /// A plan is always a cloud call, so Never upload is the only switch that blocks it.
    /// Allowing it here is not consent: screen 08 still asks before anything is sent.
    static func allowsPlanning(neverUpload: Bool) -> Bool {
        !neverUpload
    }

    /// The keep-private sheet. On-device reading is irrelevant: a plan is not a local model call.
    static func blockedFlow(neverUpload: Bool) -> UnsupportedDeviceFlow {
        UnsupportedDeviceFlow(
            onDeviceSupported: false,
            neverUpload: neverUpload
        )
    }
}

/// A stand-in plan built from the redacted text and the card. No network.
struct LocalSampleNextStepsPlanner: NextStepsPlanner {
    func plan(redactedText: String, card: LetterCard, note: String) async -> NextStepsPlan {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var steps: [NextStepsPlan.Step] = []

        let action = card.action.trimmingCharacters(in: .whitespacesAndNewlines)
        steps.append(
            NextStepsPlan.Step(
                title: "Do what the letter asks",
                detail: action.isEmpty
                    ? "Check who it says it is from, and what it asks you to do."
                    : action
            )
        )

        if let iso = card.deadline, LetterDeadlineFormat.parse(iso) != nil {
            steps.append(
                NextStepsPlan.Step(
                    title: "Keep the date in the letter",
                    detail: "Use only a date the letter itself states. LetterLens does not invent one."
                )
            )
        }

        steps.append(
            NextStepsPlan.Step(
                title: "Contact the sender yourself",
                detail: "Look up a phone number or website you trust. Do not rely on a link in the letter if you are unsure."
            )
        )

        if !trimmedNote.isEmpty {
            steps.append(
                NextStepsPlan.Step(
                    title: "Say what you need",
                    detail: trimmedNote
                )
            )
        }

        if steps.count > 4 {
            steps = Array(steps.prefix(4))
        }

        return NextStepsPlan(steps: steps, script: script(for: redactedText))
    }

    private func script(for redactedText: String) -> String {
        let name = ScriptReinsertion.firstToken(in: redactedText, kind: "NAME")
        let reference = ScriptReinsertion.firstToken(in: redactedText, kind: "REF")
        var parts: [String] = []
        if let name {
            parts.append("Hello, this is \(name).")
        } else {
            parts.append("Hello.")
        }
        if let reference {
            parts.append("My reference is \(reference).")
        }
        parts.append("I'd like to talk about the letter I was sent.")
        return parts.joined(separator: " ")
    }
}
