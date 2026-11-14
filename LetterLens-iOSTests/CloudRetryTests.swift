//
//  CloudRetryTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

private final class RecordingClock: RetryClock {
    var delays: [Int] = []

    func sleep(milliseconds: Int) async {
        delays.append(milliseconds)
    }
}

@MainActor
@Suite struct CloudRetryTests {
    @Test func backoffScheduleAddsJitterAndHonoursRetryAfter() {
        #expect(CloudBackoff.milliseconds(retryIndex: 0, jitterMilliseconds: 0, retryAfterSeconds: nil) == 2_000)
        #expect(CloudBackoff.milliseconds(retryIndex: 1, jitterMilliseconds: 0, retryAfterSeconds: nil) == 5_000)
        #expect(CloudBackoff.milliseconds(retryIndex: 2, jitterMilliseconds: 0, retryAfterSeconds: nil) == 12_000)
        #expect(CloudBackoff.milliseconds(retryIndex: 0, jitterMilliseconds: 150, retryAfterSeconds: nil) == 2_150)
        #expect(CloudBackoff.milliseconds(retryIndex: 0, jitterMilliseconds: 150, retryAfterSeconds: 4) == 4_000)
    }

    @Test func first429SwitchesToTheFallbackModel() async {
        let clock = RecordingClock()
        var calls: [String] = []
        let outcome = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "gemini-3.5-flash-lite",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            if calls.count == 1 {
                throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 429)
            }
            return CloudModelOutput(text: "ok", modelVersion: model)
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.5-flash-lite"])
        #expect(clock.delays == [2_000])
        #expect(outcome.records[0].backoffMilliseconds == 2_000)
        #expect(outcome.records[0].model == "gemini-3.8-flash")
        #expect(outcome.output?.modelVersion == "gemini-3.5-flash-lite")
    }

    @Test func later429sStayOnTheFallbackModel() async {
        let clock = RecordingClock()
        var calls: [String] = []
        _ = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "gemini-3.5-flash-lite",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            if calls.count < 3 {
                throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 429)
            }
            return CloudModelOutput(text: "ok", modelVersion: model)
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.5-flash-lite"])
        #expect(clock.delays == [2_000, 5_000])
    }

    @Test func anEmptyFallbackStaysOnTheCardModel() async {
        let clock = RecordingClock()
        var calls: [String] = []
        _ = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "  ",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            if calls.count == 1 {
                throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 429)
            }
            return CloudModelOutput(text: "ok", modelVersion: model)
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.8-flash"])
    }

    @Test func first503SwitchesToTheFallbackModel() async {
        let clock = RecordingClock()
        var calls: [String] = []
        let outcome = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "gemini-3.5-flash-lite",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            if calls.count == 1 {
                throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 503)
            }
            return CloudModelOutput(text: "ok", modelVersion: model)
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.5-flash-lite"])
        #expect(clock.delays == [2_000])
        #expect(outcome.records[0].backoffMilliseconds == 2_000)
        #expect(outcome.records[0].model == "gemini-3.8-flash")
        #expect(outcome.output?.modelVersion == "gemini-3.5-flash-lite")
    }

    @Test func a503WithAnEmptyFallbackStaysOnTheCardModel() async {
        let clock = RecordingClock()
        var calls: [String] = []
        _ = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "  ",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            if calls.count == 1 {
                throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 503)
            }
            return CloudModelOutput(text: "ok", modelVersion: model)
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.8-flash"])
        #expect(clock.delays == [2_000])
    }

    @Test func mixed429And503StopAfterThreeAttempts() async {
        let clock = RecordingClock()
        var calls: [String] = []
        let statuses = [429, 503, 429]
        let outcome = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "gemini-3.5-flash-lite",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: statuses[calls.count - 1])
        }
        #expect(calls == ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.5-flash-lite"])
        #expect(clock.delays == [2_000, 5_000])
        #expect(outcome.output == nil)
        #expect(outcome.records.count == 3)
        #expect(outcome.state.attemptsUsed == 3)
    }

    @Test func aClientErrorStopsWithoutSleeping() async {
        let clock = RecordingClock()
        var calls: [String] = []
        let outcome = await CloudRetryRunner.run(
            state: CloudRetryState(modelName: "gemini-3.8-flash", attemptsUsed: 0),
            fallbackModel: "gemini-3.5-flash-lite",
            jitterMilliseconds: { 0 },
            sleeper: clock
        ) { model in
            calls.append(model)
            throw NSError(domain: ModelCallClassifier.backendErrorDomain, code: 400)
        }
        #expect(calls == ["gemini-3.8-flash"])
        #expect(clock.delays.isEmpty)
        #expect(outcome.output == nil)
        #expect(outcome.records[0].backoffMilliseconds == 0)
    }
}
