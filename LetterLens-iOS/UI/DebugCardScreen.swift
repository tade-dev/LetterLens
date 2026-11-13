//
//  DebugCardScreen.swift
//  LetterLens-iOS
//

import CoreTransferable
import FirebaseAILogic
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Debug stand-in until the real screens exist. It shows every card field and the read badge.
struct DebugCardScreen: View {
    @Environment(AppConfig.self) private var config
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LetterRecord.createdAt, order: .reverse) private var records: [LetterRecord]

    @State private var pipeline = DebugPipelineModel()
    @State private var showScanner = false
    @State private var showImporter = false
    @State private var showPhotos = false
    @State private var showPaste = false
    @State private var pasteText = ""
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        @Bindable var pipeline = pipeline
        NavigationSplitView {
            List {
                if let status = pipeline.status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Section("This iPhone") {
                    Toggle("Never upload", isOn: $pipeline.neverUpload)
                    Toggle("Allow cloud fallback", isOn: $pipeline.allowCloudFallback)
                        .disabled(pipeline.neverUpload)
                    Text("Cloud fallback asks before anything is sent, and only redacted text is sent. Photos stay on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Letters") {
                    ForEach(records) { record in
                        NavigationLink {
                            CardDetailView(record: record)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.card?.displayTitle ?? "Letter")
                                Text(record.source.badgeTitle)
                                    .font(.caption)
                                    .foregroundStyle(record.source == .onDevice ? Color.green : Color.blue)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("LetterLens")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if VNDocumentCameraViewController.isSupported {
                            Button("Scan", systemImage: "doc.viewfinder") { showScanner = true }
                        }
                        Button("Photo", systemImage: "photo") { showPhotos = true }
                        Button("File", systemImage: "folder") { showImporter = true }
                        Button("Paste text", systemImage: "doc.on.clipboard") { showPaste = true }
                    } label: {
                        if pipeline.isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(pipeline.isWorking)
                }
            }
        } detail: {
            ContentUnavailableView(
                "No letter open",
                systemImage: "doc.text",
                description: Text("Scan, import, or paste a letter. The card fields show on the next screen.")
            )
        }
        .sheet(isPresented: $showScanner) {
            DocumentScanner { pages in
                showScanner = false
                Task { await pipeline.readPages(pages, config: config, context: modelContext) }
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaste) {
            NavigationStack {
                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .navigationTitle("Paste letter text")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPaste = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Read") {
                                let text = pasteText
                                showPaste = false
                                Task { await pipeline.read(ocrText: text, config: config, context: modelContext) }
                            }
                        }
                    }
            }
        }
        .sheet(item: $pipeline.consent) { preview in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(preview.removedCount) details removed · 0 photos sent")
                            .font(.headline)
                        Text("Postcodes, phone numbers, emails and account numbers are removed first. A later on-device pass can remove names the rules miss.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(preview.redactedText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Send redacted text?")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Don't send") { pipeline.cancelConsent() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") {
                            Task { await pipeline.confirmConsent(config: config, context: modelContext) }
                        }
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await pipeline.readFile(url, config: config, context: modelContext) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await pipeline.readPages([data], config: config, context: modelContext)
                } else {
                    pipeline.status = "That photo could not be read."
                }
                photoItem = nil
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

struct CardDetailView: View {
    let record: LetterRecord

    var body: some View {
        Form {
            if let card = record.card {
                Section {
                    Label(record.source.badgeTitle, systemImage: record.source == .onDevice ? "lock.fill" : "cloud.fill")
                        .foregroundStyle(record.source == .onDevice ? Color.green : Color.blue)
                    LabeledContent("Model", value: record.modelVersion)
                    LabeledContent("Latency", value: "\(record.latencyMS) ms")
                    LabeledContent("Details removed", value: "\(record.detailsRemoved)")
                }
                Section("Card") {
                    labeled("Title", card.displayTitle)
                    labeled("Type", card.type.rawValue)
                    labeled("Sender", card.senderKind.rawValue)
                    labeled("Action", card.action)
                    labeled("Deadline", card.deadline ?? "None found")
                    labeled("Deadline quote", card.deadlineQuote ?? "None")
                    labeled("Amount quote", card.amountQuote ?? "None")
                    labeled("No action needed", card.noActionNeeded ? "Yes" : "No")
                }
                if !card.watchOuts.isEmpty {
                    Section("Watch-outs") {
                        ForEach(Array(card.watchOuts.enumerated()), id: \.offset) { _, watchOut in
                            Text(watchOut)
                        }
                    }
                }
                Section("Signs to check") {
                    if card.scamSigns.isEmpty {
                        Text("None found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(card.scamSigns.enumerated()), id: \.offset) { _, sign in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sign.sign)
                                if let quote = sign.quote {
                                    Text(quote)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("This saved card could not be read.")
            }
            Section("OCR text") {
                Text(record.ocrText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(record.card?.displayTitle ?? "Letter")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value.isEmpty ? "—" : value)
                .multilineTextAlignment(.trailing)
        }
    }
}

@Observable
final class DebugPipelineModel {
    var neverUpload: Bool {
        didSet { UserDefaults.standard.set(neverUpload, forKey: Self.neverUploadKey) }
    }

    var allowCloudFallback: Bool {
        didSet { UserDefaults.standard.set(allowCloudFallback, forKey: Self.allowCloudKey) }
    }

    var isWorking = false
    var status: String?
    var consent: ConsentPreview?

    private var pendingLetter: String?
    private static let neverUploadKey = "ll.neverUpload"
    private static let allowCloudKey = "ll.allowCloudFallback"

    init() {
        neverUpload = UserDefaults.standard.bool(forKey: Self.neverUploadKey)
        allowCloudFallback = UserDefaults.standard.bool(forKey: Self.allowCloudKey)
    }

    func readPages(_ pages: [Data], config: AppConfig, context: ModelContext) async {
        do {
            var texts: [String] = []
            for page in pages {
                texts.append(try await TextRecognizer.recognize(data: page))
            }
            await read(ocrText: texts.joined(separator: "\n\n"), config: config, context: context)
        } catch {
            status = error.localizedDescription
        }
    }

    func readFile(_ url: URL, config: AppConfig, context: ModelContext) async {
        do {
            let data = try ImportHandler.load(url: url)
            let text = try await TextRecognizer.recognize(data: data)
            await read(ocrText: text, config: config, context: context)
        } catch {
            status = error.localizedDescription
        }
    }

    func read(ocrText: String, config: AppConfig, context: ModelContext) async {
        let letter = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !letter.isEmpty else {
            status = "No text was found on the page."
            return
        }

        let onDevice = ModelRouter(neverUpload: true, cloudConsent: false).onDeviceAvailability
        let onDeviceReady: Bool
        if case .available = onDevice {
            onDeviceReady = true
        } else {
            onDeviceReady = false
        }

        if neverUpload || !allowCloudFallback {
            guard onDeviceReady else {
                status = "Can't read privately on this iPhone."
                return
            }
            await run(letter, cloudConsent: false, config: config, context: context)
            return
        }

        let redaction = Redactor().redact(letter)
        pendingLetter = letter
        consent = ConsentPreview(redactedText: redaction.text, removedCount: redaction.removedCount)
    }

    func confirmConsent(config: AppConfig, context: ModelContext) async {
        guard let letter = pendingLetter else { return }
        pendingLetter = nil
        consent = nil
        await run(letter, cloudConsent: true, config: config, context: context)
    }

    func cancelConsent() {
        pendingLetter = nil
        consent = nil
        status = "Nothing was sent."
    }

    private func run(
        _ letter: String,
        cloudConsent: Bool,
        config: AppConfig,
        context: ModelContext
    ) async {
        isWorking = true
        status = nil
        defer { isWorking = false }

        let service = CardService(
            promptTemplate: config.cardPrompt,
            cardModel: config.cardModel,
            fallbackModel: config.fallbackModel,
            router: ModelRouter(neverUpload: neverUpload, cloudConsent: cloudConsent)
        )
        do {
            let result = try await service.read(ocrText: letter)
            let record = LetterRecord(
                ocrText: result.ocrText,
                cardJSON: try CardJSON.encodeString(result.card),
                sourceRaw: result.source.rawValue,
                modelVersion: result.modelVersion,
                latencyMS: result.latencyMS,
                detailsRemoved: result.detailsRemoved,
                schemaVersion: config.cardSchemaVersion
            )
            context.insert(record)
            try context.save()
        } catch {
            status = error.localizedDescription
        }
    }
}

struct ConsentPreview: Identifiable {
    let id = UUID()
    var redactedText: String
    var removedCount: Int
}

#Preview {
    DebugCardScreen()
        .environment(AppConfig())
        .modelContainer(for: LetterRecord.self, inMemory: true)
}
