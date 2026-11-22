//
//  PlanService.swift
//  LetterLens-iOS
//
//  Next steps, screen 09. Always cloud, always after the consent sheet.
//
//  Only the redacted letter is in the prompt. The card is re-encoded from the
//  redacted text's tokens, so an original detail that was put back for display
//  does not travel with it. Details are re-inserted on this iPhone, in the screen.

import FirebaseAILogic
import FirebaseCore
import Foundation
import os

struct PlanService: NextStepsPlanner {
    var promptTemplate: String
    var planModel: String
    var fallbackModel: String
    var router: ModelRouter
    var retryClock: any RetryClock = TaskRetryClock()
    var jitterMilliseconds: () -> Int = { Int.random(in: 0...250) }

    func plan(redactedText: String, card: LetterCard, note: String) async -> NextStepsPlan {
        do {
            return try await send(redactedText: redactedText, card: card, note: note)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            LetterLensLog.pipeline.error("Plan failed: \(message, privacy: .public)")
            // The screen still shows something useful, and the badge stays off the cloud.
            return await LocalSampleNextStepsPlanner()
                .plan(redactedText: redactedText, card: card, note: note)
        }
    }

    private func send(redactedText: String, card: LetterCard, note: String) async throws -> NextStepsPlan {
        guard !promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanPipelineError.emptyPrompt
        }
        guard router.route(for: .plan) == .cloudPrimary else {
            throw PlanPipelineError.notAllowed
        }
        guard FirebaseApp.app() != nil else {
            throw PlanPipelineError.firebaseNotConfigured
        }

        let cardJSON = (try? CardJSON.encodeString(card)) ?? "{}"
        let prompt = PlanPrompt.filled(
            template: promptTemplate,
            redactedText: redactedText,
            cardJSON: cardJSON,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let started = ContinuousClock.now
        var state = CloudRetryState(modelName: planModel, attemptsUsed: 0)

        let first = try await respond(prompt: prompt, ai: ai, state: &state)
        if let json = try? PlanJSONDecode.decode(first) {
            return finish(json, started: started, model: state.modelName)
        }

        // Same repair the card uses: repeat the prompt with a JSON-only nudge.
        let second = try await respond(
            prompt: prompt + "\n\n" + PlanPrompt.jsonRetrySuffix,
            ai: ai,
            state: &state
        )
        let json = try PlanJSONDecode.decode(second)
        return finish(json, started: started, model: state.modelName)
    }

    private func finish(
        _ json: PlanJSON,
        started: ContinuousClock.Instant,
        model: String
    ) -> NextStepsPlan {
        let plan = PlanJSONDecode.plan(from: json)
        let ms = Self.milliseconds(started.duration(to: ContinuousClock.now))
        let steps = plan.steps.count
        LetterLensLog.pipeline.notice(
            "Plan made in the cloud, model \(model, privacy: .public), \(ms, privacy: .public) ms, \(steps, privacy: .public) steps."
        )
        return plan
    }

    /// Shares the card's cloud retry: 429 and 503 wait and then move to `fallbackModel`.
    private func respond(
        prompt: String,
        ai: FirebaseAI,
        state: inout CloudRetryState
    ) async throws -> String {
        let outcome = await CloudRetryRunner.run(
            state: state,
            fallbackModel: fallbackModel,
            jitterMilliseconds: jitterMilliseconds,
            sleeper: retryClock
        ) { modelName in
            let session = ai.generativeModelSession(model: ai.geminiModel(name: modelName))
            let response = try await session.respond(
                to: prompt,
                options: .hybrid(
                    gemini: GenerationConfig(temperature: PlanPrompt.temperature),
                    foundationModels: FirebaseAI.GenerationOptions(temperature: PlanPrompt.onDeviceTemperature)
                )
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw PlanPipelineError.invalidJSON }
            return CloudModelOutput(text: text, modelVersion: response.rawResponse.modelVersion)
        }
        state = outcome.state
        if let output = outcome.output {
            return output.text
        }
        throw outcome.error ?? PlanPipelineError.invalidJSON
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let parts = duration.components
        return Int(max(Int64(0), parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000))
    }
}
