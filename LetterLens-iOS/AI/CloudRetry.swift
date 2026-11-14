//
//  CloudRetry.swift
//  LetterLens-iOS
//

import Foundation

/// Waits between cloud retries. Tests pass a sleeper that records the delay and returns immediately.
protocol RetryClock {
    func sleep(milliseconds: Int) async
}

struct TaskRetryClock: RetryClock {
    func sleep(milliseconds: Int) async {
        guard milliseconds > 0 else { return }
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}

enum CloudBackoff {
    /// Delays before cloud attempts 2, 3, and a further retry the caller does not use.
    static let delaysMilliseconds = [2_000, 5_000, 12_000]
    static let maxAttempts = 3
    /// A Retry-After larger than this is capped so one header cannot stall the run.
    static let maximumRetryAfterMilliseconds = 60_000

    static func milliseconds(
        retryIndex: Int,
        jitterMilliseconds: Int,
        retryAfterSeconds: Double?
    ) -> Int {
        if let retryAfterSeconds, retryAfterSeconds >= 0 {
            let fromHeader = Int((retryAfterSeconds * 1_000).rounded())
            return min(max(fromHeader, 0), maximumRetryAfterMilliseconds)
        }
        let index = min(max(retryIndex, 0), delaysMilliseconds.count - 1)
        return delaysMilliseconds[index] + max(0, jitterMilliseconds)
    }
}

struct CloudRetryDecision: Equatable {
    var nextModel: String
    var backoffMilliseconds: Int
    var shouldRetry: Bool
}

enum CloudRetryPlanner {
    /// Decides the model and the wait after one failed cloud attempt.
    ///
    /// The first HTTP 429 or 503 moves later attempts onto `fallbackModel` when that name is non-empty.
    /// Later 429s and 503s stay on that model. Any other 4xx stops. At most three cloud attempts are made.
    static func decide(
        error: Error,
        attemptsSoFar: Int,
        currentModel: String,
        fallbackModel: String,
        jitterMilliseconds: Int
    ) -> CloudRetryDecision {
        let status = ModelCallClassifier.httpStatus(error)
        let retryable = status == 429 || status == 503
        guard retryable, attemptsSoFar < CloudBackoff.maxAttempts else {
            return CloudRetryDecision(nextModel: currentModel, backoffMilliseconds: 0, shouldRetry: false)
        }

        var nextModel = currentModel
        let trimmed = fallbackModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            nextModel = trimmed
        }

        let backoff = CloudBackoff.milliseconds(
            retryIndex: attemptsSoFar - 1,
            jitterMilliseconds: jitterMilliseconds,
            retryAfterSeconds: ModelCallClassifier.retryAfterSeconds(error)
        )
        return CloudRetryDecision(
            nextModel: nextModel,
            backoffMilliseconds: backoff,
            shouldRetry: true
        )
    }
}

struct CloudAttemptRecord: Equatable {
    var model: String
    var error: String?
    var backoffMilliseconds: Int
    var text: String?
    var modelVersion: String?
}

struct CloudRetryState: Equatable {
    var modelName: String
    var attemptsUsed: Int
}

struct CloudModelOutput: Equatable {
    var text: String
    var modelVersion: String
}

enum CloudRetryRunner {
    struct Outcome {
        var state: CloudRetryState
        var records: [CloudAttemptRecord]
        var output: CloudModelOutput?
        var error: Error?
    }

    static func run(
        state: CloudRetryState,
        fallbackModel: String,
        jitterMilliseconds: @escaping () -> Int,
        sleeper: any RetryClock,
        operation: @escaping (String) async throws -> CloudModelOutput
    ) async -> Outcome {
        var model = state.modelName
        var used = state.attemptsUsed
        var records: [CloudAttemptRecord] = []

        while used < CloudBackoff.maxAttempts {
            do {
                let output = try await operation(model)
                records.append(
                    CloudAttemptRecord(
                        model: model,
                        error: nil,
                        backoffMilliseconds: 0,
                        text: output.text,
                        modelVersion: output.modelVersion
                    )
                )
                used += 1
                return Outcome(
                    state: CloudRetryState(modelName: model, attemptsUsed: used),
                    records: records,
                    output: output,
                    error: nil
                )
            } catch {
                used += 1
                let decision = CloudRetryPlanner.decide(
                    error: error,
                    attemptsSoFar: used,
                    currentModel: model,
                    fallbackModel: fallbackModel,
                    jitterMilliseconds: jitterMilliseconds()
                )
                let backoff = decision.shouldRetry ? decision.backoffMilliseconds : 0
                records.append(
                    CloudAttemptRecord(
                        model: model,
                        error: ModelCallClassifier.summary(error),
                        backoffMilliseconds: backoff,
                        text: nil,
                        modelVersion: nil
                    )
                )
                guard decision.shouldRetry else {
                    return Outcome(
                        state: CloudRetryState(modelName: model, attemptsUsed: used),
                        records: records,
                        output: nil,
                        error: error
                    )
                }
                model = decision.nextModel
                await sleeper.sleep(milliseconds: backoff)
            }
        }

        return Outcome(
            state: CloudRetryState(modelName: model, attemptsUsed: used),
            records: records,
            output: nil,
            error: NSError(domain: ModelCallClassifier.backendErrorDomain, code: -1)
        )
    }
}

