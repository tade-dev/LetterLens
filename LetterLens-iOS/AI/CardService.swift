//
//  CardService.swift
//  LetterLens-iOS
//

import FirebaseAILogic
import FirebaseCore
import Foundation
import os

/// Reads a letter into a validated card through Firebase AI Logic.
///
/// On-device only uses `generativeModelSession(model: FirebaseAI.SystemLanguageModel.default)`.
/// After cloud consent, the card uses `HybridModel(primary: system, secondary: cloudModel)`
/// and the prompt contains redacted text, because a hybrid fallback can upload that prompt.
/// Photos are never passed in. The image stays in OCR.
///
/// Structured output for hybrid inference is documented for Android and Web, not this iOS
/// session API, so the model is asked for JSON and `CardValidator` checks it.
struct CardService {
    var promptTemplate: String
    var cardModel: String
    var fallbackModel: String
    var router: ModelRouter
    var redactor = Redactor()
    var retryClock: any RetryClock = TaskRetryClock()
    var jitterMilliseconds: () -> Int = { Int.random(in: 0...250) }

    func read(ocrText: String) async throws -> CardReadResult {
        let letter = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !letter.isEmpty else { throw CardPipelineError.emptyOCR }
        guard !promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CardPipelineError.emptyPrompt
        }

        let route = router.route(for: .card)
        if route == .onDeviceOnly {
            guard case .available = router.onDeviceAvailability else {
                throw CardPipelineError.privateReadUnavailable(
                    Self.availabilitySummary(router.onDeviceAvailability)
                )
            }
        }

        // `firebaseAI()` traps when Firebase was not configured. Check first.
        guard FirebaseApp.app() != nil else {
            throw CardPipelineError.firebaseNotConfigured
        }

        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let started = ContinuousClock.now
        var rawResponses: [ModelRawResponse] = []

        do {
            return try await complete(
                letter: letter,
                route: route,
                ai: ai,
                started: started,
                rawResponses: &rawResponses
            )
        } catch let failure as CardReadFailure {
            throw failure
        } catch {
            // One on-device retry already happened inside `send`. A second guardrail block
            // may use the redacted cloud model only when the same consent gate as hybrid is open.
            let cloudAllowed = router.cloudConsent && !router.neverUpload && route != .cloudPrimary
            if cloudAllowed, ModelCallClassifier.isOnDeviceGuardrail(error) {
                LetterLensLog.pipeline.notice(
                    "On-device guardrail persisted after one retry. Sending redacted text to the cloud model."
                )
                do {
                    return try await complete(
                        letter: letter,
                        route: .cloudPrimary,
                        ai: ai,
                        started: started,
                        rawResponses: &rawResponses
                    )
                } catch let failure as CardReadFailure {
                    throw failure
                } catch {
                    throw recordedFailure(error, route: .cloudPrimary, rawResponses: rawResponses, started: started)
                }
            }
            throw recordedFailure(error, route: route, rawResponses: rawResponses, started: started)
        }
    }

    private func complete(
        letter: String,
        route: ModelRoute,
        ai: FirebaseAI,
        started: ContinuousClock.Instant,
        rawResponses: inout [ModelRawResponse]
    ) async throws -> CardReadResult {
        let sendsOffDevice = route != .onDeviceOnly
        let redaction = sendsOffDevice ? redactor.redact(letter) : nil
        let textForModel = redaction?.text ?? letter
        var versions: [String] = []
        var cards: [LetterCard] = []
        var cloudState = CloudRetryState(modelName: cardModel, attemptsUsed: 0)

        for (index, chunk) in CardPrompt.chunks(of: textForModel).enumerated() {
            var session: GenerativeModelSession?
            let chunkNumber = index + 1
            let prompt = CardPrompt.filled(template: promptTemplate, ocrText: chunk)
            let first = try await send(
                prompt: prompt,
                route: route,
                ai: ai,
                chunk: chunkNumber,
                session: &session,
                cloudState: &cloudState,
                rawResponses: &rawResponses
            )
            versions.append(first.modelVersion)

            if let card = try? CardJSON.decodeModelText(first.text) {
                let restored = reinserted(card, map: redaction?.map)
                cards.append(CardValidator.validate(restored, ocrText: letter))
                continue
            }

            // Cloud attempts each start a new session, so the repair call repeats the letter.
            // On-device keeps the same session and only sends the correction.
            let retryPrompt = route == .cloudPrimary
                ? prompt + "\n\n" + CardPrompt.jsonRetrySuffix
                : CardPrompt.jsonRetrySuffix
            let second = try await send(
                prompt: retryPrompt,
                route: route,
                ai: ai,
                chunk: chunkNumber,
                session: &session,
                cloudState: &cloudState,
                rawResponses: &rawResponses
            )
            versions.append(second.modelVersion)
            guard let card = try? CardJSON.decodeModelText(second.text) else {
                throw CardReadFailure(
                    message: CardPipelineError.invalidJSON.localizedDescription,
                    rawResponses: rawResponses,
                    latencyMS: Self.milliseconds(started.duration(to: ContinuousClock.now)),
                    routeLabel: route.harnessLabel,
                    attempts: rawResponses.count
                )
            }
            let restored = reinserted(card, map: redaction?.map)
            cards.append(CardValidator.validate(restored, ocrText: letter))
        }

        guard !cards.isEmpty else {
            throw CardReadFailure(
                message: CardPipelineError.invalidJSON.localizedDescription,
                rawResponses: rawResponses,
                latencyMS: Self.milliseconds(started.duration(to: ContinuousClock.now)),
                routeLabel: route.harnessLabel,
                attempts: rawResponses.count
            )
        }

        let card = CardValidator.validate(CardValidator.merge(cards), ocrText: letter)
        let source = Self.source(versions: versions, route: route)
        let modelVersion = Self.reportedModel(versions: versions, source: source, route: route)
        let latency = Self.milliseconds(started.duration(to: ContinuousClock.now))
        // Copy out of the inout buffer before the log. Logger interpolations are autoclosures.
        let attemptCount = rawResponses.count
        let detailsRemoved = redaction?.removedCount ?? 0
        LetterLensLog.pipeline.notice(
            "Card read \(source.routeLabel, privacy: .public) model \(modelVersion, privacy: .public) in \(latency, privacy: .public) ms. Attempts: \(attemptCount, privacy: .public). Details removed: \(detailsRemoved, privacy: .public)."
        )

        return CardReadResult(
            card: card,
            source: source,
            modelVersion: modelVersion,
            latencyMS: latency,
            route: route,
            attempts: rawResponses.count,
            rawResponses: rawResponses,
            ocrText: letter,
            redactedText: redaction?.text,
            detailsRemoved: redaction?.removedCount ?? 0
        )
    }

    /// Runs one prompt. A guardrail or sensitive-content error is retried once on a new
    /// session of the same route. Cloud 429 and 503 wait, then try `fallbackModel` when
    /// that name is set, at most three times.
    private func send(
        prompt: String,
        route: ModelRoute,
        ai: FirebaseAI,
        chunk: Int,
        session: inout GenerativeModelSession?,
        cloudState: inout CloudRetryState,
        rawResponses: inout [ModelRawResponse]
    ) async throws -> (text: String, modelVersion: String) {
        if route == .cloudPrimary {
            return try await sendCloud(
                prompt: prompt,
                ai: ai,
                chunk: chunk,
                cloudState: &cloudState,
                rawResponses: &rawResponses
            )
        }

        if session == nil {
            session = makeSession(route: route, ai: ai)
        }

        do {
            let response = try await respond(session: session!, prompt: prompt, route: route)
            let attempt = rawResponses.count + 1
            rawResponses.append(
                ModelRawResponse(
                    chunk: chunk,
                    attempt: attempt,
                    text: response.text,
                    model: response.modelVersion
                )
            )
            return response
        } catch {
            recordFailure(error, chunk: chunk, model: CardReadSource.onDeviceModelVersion, backoffMS: 0, rawResponses: &rawResponses)
            guard ModelCallClassifier.isOnDeviceGuardrail(error) else {
                throw error
            }
            session = makeSession(route: route, ai: ai)
            do {
                let response = try await respond(session: session!, prompt: prompt, route: route)
                let attempt = rawResponses.count + 1
                rawResponses.append(
                    ModelRawResponse(
                        chunk: chunk,
                        attempt: attempt,
                        text: response.text,
                        model: response.modelVersion
                    )
                )
                return response
            } catch {
                recordFailure(error, chunk: chunk, model: CardReadSource.onDeviceModelVersion, backoffMS: 0, rawResponses: &rawResponses)
                throw error
            }
        }
    }

    /// Cloud calls share one three-attempt budget for the letter. The prompt is already redacted.
    private func sendCloud(
        prompt: String,
        ai: FirebaseAI,
        chunk: Int,
        cloudState: inout CloudRetryState,
        rawResponses: inout [ModelRawResponse]
    ) async throws -> (text: String, modelVersion: String) {
        let outcome = await CloudRetryRunner.run(
            state: cloudState,
            fallbackModel: fallbackModel,
            jitterMilliseconds: jitterMilliseconds,
            sleeper: retryClock
        ) { modelName in
            let session = self.makeCloudSession(ai: ai, modelName: modelName)
            let reply = try await self.readResponse(session: session, prompt: prompt)
            return CloudModelOutput(text: reply.text, modelVersion: reply.modelVersion)
        }
        cloudState = outcome.state
        appendCloudRecords(outcome.records, chunk: chunk, rawResponses: &rawResponses)
        if let output = outcome.output {
            let reported = output.modelVersion
            let modelVersion = reported.isEmpty || reported == CardReadSource.unknownModelVersion
                ? cloudState.modelName
                : reported
            return (output.text, modelVersion)
        }
        throw outcome.error ?? CardPipelineError.modelFailed("The cloud model did not return a card.")
    }

    private func appendCloudRecords(
        _ records: [CloudAttemptRecord],
        chunk: Int,
        rawResponses: inout [ModelRawResponse]
    ) {
        let start = rawResponses.count
        for (offset, record) in records.enumerated() {
            let attempt = start + offset + 1
            let model = record.model
            let backoff = record.backoffMilliseconds
            let errorText = record.error
            if let errorText {
                LetterLensLog.pipeline.error(
                    "Cloud model call failed \(errorText, privacy: .public) backoff \(backoff, privacy: .public) ms attempt \(attempt, privacy: .public)"
                )
            }
            rawResponses.append(
                ModelRawResponse(
                    chunk: chunk,
                    attempt: attempt,
                    text: record.text ?? "",
                    error: errorText,
                    backoffMS: errorText == nil ? nil : backoff,
                    model: model
                )
            )
        }
    }

    private func recordedFailure(
        _ error: Error,
        route: ModelRoute,
        rawResponses: [ModelRawResponse],
        started: ContinuousClock.Instant
    ) -> CardReadFailure {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return CardReadFailure(
            message: message,
            rawResponses: rawResponses,
            latencyMS: Self.milliseconds(started.duration(to: ContinuousClock.now)),
            routeLabel: route.harnessLabel,
            attempts: rawResponses.count
        )
    }

    /// On-device only does not construct a cloud model. Hybrid and cloud do.
    private func makeSession(route: ModelRoute, ai: FirebaseAI) -> GenerativeModelSession {
        let system = FirebaseAI.SystemLanguageModel.default
        switch route {
        case .onDeviceOnly:
            return ai.generativeModelSession(model: system)
        case .hybridOnDeviceFirst:
            let cloud = ai.geminiModel(name: cardModel)
            let hybrid = HybridModel(primary: system, secondary: cloud)
            return ai.generativeModelSession(model: hybrid)
        case .cloudPrimary:
            return makeCloudSession(ai: ai, modelName: cardModel)
        }
    }

    private func makeCloudSession(ai: FirebaseAI, modelName: String) -> GenerativeModelSession {
        let cloud = ai.geminiModel(name: modelName)
        return ai.generativeModelSession(model: cloud)
    }

    private func recordFailure(
        _ error: Error,
        chunk: Int,
        model: String,
        backoffMS: Int,
        rawResponses: inout [ModelRawResponse]
    ) {
        let diagnostic = ModelCallClassifier.diagnostic(error)
        let domain = diagnostic.domain
        let code = diagnostic.code
        let attempt = rawResponses.count + 1
        let recordedModel = model
        let recordedBackoff = backoffMS
        LetterLensLog.pipeline.error(
            "Model call failed domain \(domain, privacy: .public) code \(code, privacy: .public) attempt \(attempt, privacy: .public)"
        )
        rawResponses.append(
            ModelRawResponse(
                chunk: chunk,
                attempt: attempt,
                text: "",
                error: "\(domain) error \(code)",
                backoffMS: recordedBackoff,
                model: recordedModel
            )
        )
    }

    /// On-device calls are cut off well under the ~190s hangs seen in the 15-letter run.
    static let onDeviceTimeoutSeconds = 60

    private struct ModelReply: Sendable {
        var text: String
        var modelVersion: String
    }

    private func respond(
        session: GenerativeModelSession,
        prompt: String,
        route: ModelRoute
    ) async throws -> (text: String, modelVersion: String) {
        if route == .cloudPrimary {
            let reply = try await readResponse(session: session, prompt: prompt)
            return (reply.text, reply.modelVersion)
        }
        let responseTask = Task { @MainActor () -> ModelReply in
            try await self.readResponse(session: session, prompt: prompt)
        }
        let timeoutTask = Task { @MainActor () -> ModelReply in
            try await Task.sleep(for: .seconds(Self.onDeviceTimeoutSeconds))
            throw OnDeviceCallTimeout(seconds: Self.onDeviceTimeoutSeconds)
        }
        let reply = try await withThrowingTaskGroup(of: ModelReply.self) { group in
            group.addTask { try await responseTask.value }
            group.addTask { try await timeoutTask.value }
            defer {
                group.cancelAll()
                responseTask.cancel()
                timeoutTask.cancel()
            }
            guard let value = try await group.next() else {
                throw OnDeviceCallTimeout(seconds: Self.onDeviceTimeoutSeconds)
            }
            return value
        }
        return (reply.text, reply.modelVersion)
    }

    private func readResponse(
        session: GenerativeModelSession,
        prompt: String
    ) async throws -> ModelReply {
        let response = try await session.respond(to: prompt, options: generationOptions)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CardPipelineError.emptyModelResponse }
        return ModelReply(text: text, modelVersion: response.rawResponse.modelVersion)
    }

    /// Both sides are set so whichever model the session actually runs stays at 0.1.
    private var generationOptions: ResponseGenerationOptions {
        .hybrid(
            gemini: GenerationConfig(temperature: CardPrompt.temperature),
            foundationModels: FirebaseAI.GenerationOptions(temperature: CardPrompt.onDeviceTemperature)
        )
    }

    private func reinserted(_ card: LetterCard, map: RedactionMap?) -> LetterCard {
        guard let map, map.removedCount > 0 else { return card }
        var card = card
        card.action = map.reinsert(into: card.action)
        if let deadline = card.deadline {
            card.deadline = map.reinsert(into: deadline)
        }
        if let deadlineQuote = card.deadlineQuote {
            card.deadlineQuote = map.reinsert(into: deadlineQuote)
        }
        if let amountQuote = card.amountQuote {
            card.amountQuote = map.reinsert(into: amountQuote)
        }
        card.watchOuts = card.watchOuts.map { map.reinsert(into: $0) }
        card.scamSigns = card.scamSigns.map { sign in
            var sign = sign
            sign.sign = map.reinsert(into: sign.sign)
            if let quote = sign.quote {
                sign.quote = map.reinsert(into: quote)
            }
            return sign
        }
        return card
    }

    private static func source(versions: [String], route: ModelRoute) -> CardReadSource {
        let resolved = versions.map { CardReadSource.resolve(modelVersion: $0, route: route) }
        if resolved.contains(.cloud) { return .cloud }
        return resolved.last ?? CardReadSource.resolve(modelVersion: "", route: route)
    }

    private static func reportedModel(versions: [String], source: CardReadSource, route: ModelRoute) -> String {
        let matching = versions.last {
            CardReadSource.resolve(modelVersion: $0, route: route) == source
        }
        return matching ?? versions.last ?? CardReadSource.unknownModelVersion
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let parts = duration.components
        let fromSeconds = parts.seconds * 1000
        let fromAttoseconds = parts.attoseconds / 1_000_000_000_000_000
        return Int(max(Int64(0), fromSeconds + fromAttoseconds))
    }

    private static func availabilitySummary(
        _ availability: FirebaseAI.SystemLanguageModel.Availability
    ) -> String {
        switch availability {
        case .available:
            return "available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This iPhone cannot run Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is turned off."
            case .modelNotReady:
                return "The on-device model is still downloading."
            case .unknown:
                return "The on-device model is unavailable."
            @unknown default:
                return "The on-device model is unavailable."
            }
        }
    }
}

/// A failed read that still carries the raw model text for the harness.
struct CardReadFailure: LocalizedError {
    var message: String
    var rawResponses: [ModelRawResponse]
    var latencyMS: Int
    /// Route of the call that failed. `on-device` or `cloud`.
    var routeLabel: String?
    var attempts: Int

    var errorDescription: String? { message }
}

extension ModelRoute {
    /// Harness label for the route that was actually called.
    var harnessLabel: String {
        switch self {
        case .onDeviceOnly, .hybridOnDeviceFirst:
            "on-device"
        case .cloudPrimary:
            "cloud"
        }
    }
}
