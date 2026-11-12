//
//  LetterHarness.swift
//  LetterLens-iOS
//

import Darwin
import Foundation
import SwiftUI

#if DEBUG

/// Unattended scan-to-card run for the 15-letter test. Compiled into Debug builds only.
///
/// The test-kit letters are not in this repo. Point `LL_HARNESS_IN` at a local copy.
enum LetterHarness {
    static let launchArgument = "-LLHarness"
    static let textArgument = "-LLHarnessText"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    @MainActor
    static func run(config: AppConfig) async -> Int32 {
        await config.fetchAndActivate()

        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        let textMode = environment["LL_HARNESS_SOURCE"]?.lowercased() == "txt"
            || arguments.contains(textArgument)
        let neverUpload = flag(environment["LL_NEVER_UPLOAD"])
        let cloudConsent = flag(environment["LL_CLOUD_CONSENT"])

        guard let inputPath = environment["LL_HARNESS_IN"], !inputPath.isEmpty,
              let outputPath = environment["LL_HARNESS_OUT"], !outputPath.isEmpty
        else {
            print("LetterLens harness needs LL_HARNESS_IN and LL_HARNESS_OUT.")
            return 2
        }

        let input = URL(fileURLWithPath: inputPath, isDirectory: true)
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            print("LetterLens harness could not create \(outputPath): \(error.localizedDescription)")
            return 2
        }

        let letters: [(number: Int, url: URL)]
        do {
            letters = try discover(in: input, textMode: textMode)
        } catch {
            print("LetterLens harness could not read \(inputPath): \(error.localizedDescription)")
            return writeSummary(
                to: output,
                input: inputPath,
                output: outputPath,
                textMode: textMode,
                neverUpload: neverUpload,
                cloudConsent: cloudConsent,
                letters: [],
                harnessError: error.localizedDescription
            )
        }

        guard !letters.isEmpty else {
            print("LetterLens harness found no letters in \(inputPath).")
            return writeSummary(
                to: output,
                input: inputPath,
                output: outputPath,
                textMode: textMode,
                neverUpload: neverUpload,
                cloudConsent: cloudConsent,
                letters: [],
                harnessError: "No numbered letters found."
            )
        }

        print("LetterLens harness: \(letters.count) letters, input \(textMode ? "txt" : "png").")
        let service = CardService(
            promptTemplate: config.cardPrompt,
            cardModel: config.cardModel,
            router: ModelRouter(neverUpload: neverUpload, cloudConsent: cloudConsent)
        )

        var rows: [HarnessLetterRow] = []
        for letter in letters {
            let padded = String(format: "%02d", letter.number)
            let kind = letter.url.pathExtension.lowercased()
            do {
                let ocr = try await text(from: letter.url)
                try write(ocr, to: output.appending(path: "\(padded).ocr.txt"))
                try write(ocr, to: output.appending(path: "\(padded).txt"))
                let result = try await service.read(ocrText: ocr)
                let card = try CardJSON.encodeString(result.card)
                try write(card, to: output.appending(path: "\(padded).json"))
                try write(card, to: output.appending(path: "\(padded).validated.json"))
                try writeRaw(result.rawResponses, to: output.appending(path: "\(padded).raw.json"))
                rows.append(
                    HarnessLetterRow(
                        n: letter.number,
                        file: letter.url.lastPathComponent,
                        inputKind: kind,
                        route: result.source.routeLabel,
                        model: result.modelVersion,
                        latencyMS: result.latencyMS,
                        attempts: result.attempts,
                        error: nil
                    )
                )
                print("\(padded) \(result.source.routeLabel) \(result.modelVersion) \(result.latencyMS) ms attempts \(result.attempts)")
            } catch let failure as CardReadFailure {
                try? writeRaw(failure.rawResponses, to: output.appending(path: "\(padded).raw.json"))
                rows.append(
                    HarnessLetterRow(
                        n: letter.number,
                        file: letter.url.lastPathComponent,
                        inputKind: kind,
                        route: failure.routeLabel,
                        model: nil,
                        latencyMS: failure.latencyMS,
                        attempts: failure.attempts,
                        error: failure.message
                    )
                )
                print("\(padded) error after \(failure.attempts) attempts: \(failure.message)")
            } catch {
                rows.append(
                    HarnessLetterRow(
                        n: letter.number,
                        file: letter.url.lastPathComponent,
                        inputKind: kind,
                        route: nil,
                        model: nil,
                        latencyMS: nil,
                        attempts: 0,
                        error: error.localizedDescription
                    )
                )
                print("\(padded) error: \(error.localizedDescription)")
            }
        }

        let exitCode = writeSummary(
            to: output,
            input: inputPath,
            output: outputPath,
            textMode: textMode,
            neverUpload: neverUpload,
            cloudConsent: cloudConsent,
            letters: rows,
            harnessError: nil
        )
        print("LetterLens harness wrote \(outputPath).")
        return exitCode
    }

    private static func flag(_ value: String?) -> Bool {
        guard let value else { return false }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private static func discover(in directory: URL, textMode: Bool) throws -> [(number: Int, url: URL)] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var grouped: [Int: [URL]] = [:]
        for url in urls {
            guard let number = letterNumber(in: url.lastPathComponent) else { continue }
            grouped[number, default: []].append(url)
        }
        return grouped.keys.sorted().compactMap { number in
            guard let files = grouped[number], let chosen = pick(from: files, textMode: textMode) else {
                return nil
            }
            return (number, chosen)
        }
    }

    private static func letterNumber(in filename: String) -> Int? {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+)"#),
              let match = regex.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)),
              let range = Range(match.range(at: 1), in: stem)
        else { return nil }
        return Int(stem[range])
    }

    private static func pick(from files: [URL], textMode: Bool) -> URL? {
        let order = textMode
            ? ["txt"]
            : ["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "pdf", "txt"]
        let sorted = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for ext in order {
            if let match = sorted.first(where: { $0.pathExtension.lowercased() == ext }) {
                return match
            }
        }
        return nil
    }

    private static func text(from url: URL) async throws -> String {
        if url.pathExtension.lowercased() == "txt" {
            return try String(contentsOf: url, encoding: .utf8)
        }
        let data = try Data(contentsOf: url)
        return try await TextRecognizer.recognize(data: data)
    }

    private static func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeRaw(_ responses: [ModelRawResponse], to url: URL) throws {
        let payload = RawFile(responses: responses.map {
            RawPiece(chunk: $0.chunk, attempt: $0.attempt, text: $0.text, error: $0.error)
        })
        try writeJSON(payload, to: url)
    }

    @discardableResult
    private static func writeSummary(
        to directory: URL,
        input: String,
        output: String,
        textMode: Bool,
        neverUpload: Bool,
        cloudConsent: Bool,
        letters: [HarnessLetterRow],
        harnessError: String?
    ) -> Int32 {
        let failed = letters.filter { $0.error != nil }.count
        let exitCode: Int32
        if harnessError != nil || letters.isEmpty {
            exitCode = 2
        } else if failed > 0 {
            exitCode = 1
        } else {
            exitCode = 0
        }
        let summary = HarnessSummary(
            startedAt: ISO8601DateFormatter().string(from: Date()),
            inputMode: textMode ? "txt" : "png",
            input: input,
            output: output,
            neverUpload: neverUpload,
            cloudConsent: cloudConsent,
            harnessError: harnessError,
            failed: failed,
            exitCode: Int(exitCode),
            letters: letters
        )
        try? writeJSON(summary, to: directory.appending(path: "run.json"))
        return exitCode
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

private struct HarnessSummary: Encodable {
    var startedAt: String
    var inputMode: String
    var input: String
    var output: String
    var neverUpload: Bool
    var cloudConsent: Bool
    var harnessError: String?
    var failed: Int
    var exitCode: Int
    var letters: [HarnessLetterRow]

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case inputMode = "input_mode"
        case input
        case output
        case neverUpload = "never_upload"
        case cloudConsent = "cloud_consent"
        case harnessError = "harness_error"
        case failed
        case exitCode = "exit_code"
        case letters
    }
}

private struct HarnessLetterRow: Encodable {
    var n: Int
    var file: String
    var inputKind: String
    var route: String?
    var model: String?
    var latencyMS: Int?
    var attempts: Int
    var error: String?

    enum CodingKeys: String, CodingKey {
        case n
        case file
        case inputKind = "input_kind"
        case route
        case model
        case latencyMS = "latency_ms"
        case attempts
        case error
    }
}

private struct RawFile: Encodable {
    var responses: [RawPiece]
}

private struct RawPiece: Encodable {
    var chunk: Int
    var attempt: Int
    var text: String
    var error: String?
}

struct LetterHarnessView: View {
    @Environment(AppConfig.self) private var config
    @State private var status = "Running the letter harness…"

    var body: some View {
        Text(status)
            .font(.system(.body, design: .monospaced))
            .padding()
            .task {
                let code = await LetterHarness.run(config: config)
                status = code == 0 ? "Harness finished." : "Harness finished with errors (\(code))."
                fflush(stdout)
                exit(code)
            }
    }
}

#endif
