//
//  ScanEntryScreen.swift
//  LetterLens-iOS
//
//  Screen 03. VisionKit's document camera is the viewfinder, so this screen has none.
//  Scan, photo, and PDF all open screen 04. Cancelling the camera returns here.

import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ScanEntryScreen: View {
    /// Where an on-device read goes. The unsupported-device sheet replaces this when `flow` asks.
    var path: ReadingPath = .device
    var flow: UnsupportedDeviceFlow = UnsupportedDeviceFlow(
        onDeviceSupported: true,
        neverUpload: false
    )
    var availability: OnDeviceReadingAvailability = .available
    var preferences: PrivacySettingsModel = PrivacySettingsModel(writesDefaults: false)
    /// Nil when reading finishes without a card. The read carries the OCR text.
    var onCardReady: (LetterRead?) -> Void = { _ in }
    var onReadingFailed: () -> Void = {}
    /// Home's import button pushes Scan and opens the photo and PDF choices.
    var opensImport = false
    /// Pages handed over by the share extension. Non-empty means go straight to reading.
    var sharedPages: [UIImage] = []

    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var showPDF = false
    @State private var showImportChoices = false
    @State private var didOfferImport = false
    @State private var didOpenShared = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingScan: [UIImage] = []
    @State private var pendingImages: [UIImage] = []
    @State private var pages: [UIImage] = []
    @State private var readingProgress: ReadingProgress?
    @State private var showReading = false
    @State private var showReadingFailed = false
    @State private var handoff = ScanHandoff()
    @State private var readingStarted = Date()
    @State private var showUnsupported = false
    @State private var presentedPrompt: UnsupportedDevicePrompt?
    @State private var showPrivacy = false
    @State private var afterSheet: AfterUnsupportedSheet?
    @State private var captureToken = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppConfig.self) private var config

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                cameraBlock
                importBlock
                shareLine
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LLColor.ground)
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPrivacy = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Privacy settings")
            }
        }
        .navigationDestination(isPresented: $showReading) {
            if showReadingFailed {
                ReadingFailedScreen(message: handoff.failureMessage ?? ScanReadingFailure.noText)
            } else if let readingProgress {
                readingDestination(progress: readingProgress)
            }
        }
        .navigationDestination(isPresented: $showPrivacy) {
            PrivacySettingsScreen(
                preferences: preferences,
                availability: availability,
                storedLetterCount: 0,
                onDeleteAll: {}
            )
        }
        .sheet(isPresented: $showUnsupported, onDismiss: finishUnsupportedSheet) {
            if let presentedPrompt {
                UnsupportedDeviceSheet(
                    prompt: presentedPrompt,
                    onReadInCloud: {
                        afterSheet = .readInCloud
                        showUnsupported = false
                    },
                    onNotNow: {
                        afterSheet = .stay
                        showUnsupported = false
                    },
                    onKeepPrivate: {
                        afterSheet = .stay
                        showUnsupported = false
                    },
                    onOpenPrivacySettings: {
                        afterSheet = .privacy
                        showUnsupported = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showScanner, onDismiss: openPendingScan) {
            DocumentScanner { scanned in
                pendingScan = CapturedPageLoader.images(fromPNG: scanned)
                showScanner = false
            } onCancel: {
                pendingScan = []
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .confirmationDialog(
            "Import a PDF or photo",
            isPresented: $showImportChoices,
            titleVisibility: .visible
        ) {
            Button("Choose a photo") { showPhotos = true }
            Button("Import a PDF") { showPDF = true }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if !sharedPages.isEmpty, !didOpenShared {
                didOpenShared = true
                openReading(sharedPages)
                return
            }
            guard opensImport, !didOfferImport else { return }
            didOfferImport = true
            showImportChoices = true
        }
        .fileImporter(
            isPresented: $showPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let images = CapturedPageLoader.images(fromPDFAt: url)
            guard !images.isEmpty else { return }
            openReading(images)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                photoItem = nil
                if let data, let image = CapturedPageLoader.image(fromPhotoData: data) {
                    openReading([image])
                }
            }
        }
        .sensoryFeedback(.success, trigger: captureToken)
        .preferredColorScheme(.light)
        .task(id: captureToken) {
            await runReadingIfNeeded()
        }
    }

    private func runReadingIfNeeded() async {
        guard captureToken > 0, let progress = readingProgress else { return }
        let generation = handoff.generation
        let started = readingStarted
        let images = pages
        let path = progress.path
        let schemaVersion = config.cardSchemaVersion
        _ = await ScanReadingDriver.read(
            pages: images,
            path: path,
            progress: progress,
            id: generation,
            createdAt: started,
            schemaVersion: schemaVersion,
            recognize: { image in
                try await ScanPageOCR.recognize(image)
            },
            readCard: { text in
                try await readCard(text, path: path)
            },
            redactedDetailCount: { text in
                Redactor().redact(text).removedCount
            },
            publish: { read in
                guard handoff.generation == generation else { return }
                handoff.read = read
            },
            fail: { message in
                guard handoff.generation == generation else { return }
                handoff.failureMessage = message
            }
        )
    }

    /// Cloud only after this scan's sheet. Otherwise the existing on-device route.
    private func readCard(_ text: String, path: ReadingPath) async throws -> CardReadResult {
        let cloud = path == .cloud && !preferences.neverUpload
        let service = CardService(
            promptTemplate: config.cardPrompt,
            cardModel: config.cardModel,
            fallbackModel: config.fallbackModel,
            router: ModelRouter(neverUpload: !cloud, cloudConsent: cloud)
        )
        return try await service.read(ocrText: text)
    }

    private func readingDestination(progress: ReadingProgress) -> some View {
        let generation = handoff.generation
        return ReadingScreen(
            pages: pages,
            progress: progress,
            onCardReady: {
                guard handoff.generation == generation,
                      let read = handoff.read,
                      read.id == generation
                else { return }
                onCardReady(read)
            },
            onReadingFailed: {
                if handoff.generation == generation, handoff.failureMessage == nil {
                    handoff.failureMessage = ScanReadingFailure.noText
                }
                guard handoff.generation == generation else { return }
                showReadingFailed = true
                onReadingFailed()
            }
        )
    }

    /// Spring into reading. Reduce Motion uses the same short fade as a page change.
    private var pushAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: ReadingMotion.reduceMotionCrossfade)
            : .spring(duration: ReadingMotion.pushSpringDuration, bounce: ReadingMotion.pushSpringBounce)
    }

    private var cameraBlock: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            ClearInkGlassButton("Scan with camera", kind: .prominent(LLColor.ink)) {
                showScanner = true
            }

            Text("Finds the page edges for you. Add as many pages as the letter has.")
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importBlock: some View {
        VStack(spacing: LLSpace.m) {
            importRow("Choose a photo", systemImage: "photo") {
                showPhotos = true
            }
            importRow("Import a PDF", systemImage: "doc") {
                showPDF = true
            }
        }
    }

    private func importRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .buttonSizing(.flexible)
    }

    private var shareLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: LLSpace.s) {
            Image(systemName: "square.and.arrow.up")
                .font(LLFont.body)
                .accessibilityHidden(true)
            Text("You can also share a PDF or photo to LetterLens from Mail, Files or Photos using the share sheet.")
                .font(LLFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(LLColor.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: LLSpace.xs) {
            Text(LetterCopy.photosNeverLeave)
            Text(LetterCopy.disclaimerShort)
        }
        .font(LLFont.caption)
        .foregroundStyle(LLColor.inkSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, LLSpace.screen)
        .padding(.vertical, LLSpace.m)
        .background(LLColor.ground)
    }

    private func openPendingScan() {
        let images = pendingScan
        pendingScan = []
        guard !images.isEmpty else { return }
        openReading(images)
    }

    private func openReading(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        pendingImages = images
        guard let prompt = flow.prompt else {
            beginReading(images, path: path)
            return
        }
        afterSheet = nil
        presentedPrompt = prompt
        showUnsupported = true
    }

    private func beginReading(_ images: [UIImage], path: ReadingPath) {
        guard !images.isEmpty else { return }
        handoff.generation = UUID()
        handoff.read = nil
        handoff.failureMessage = nil
        showReadingFailed = false
        readingStarted = Date()
        pages = images
        pendingImages = []
        readingProgress = ReadingProgress(pagesTotal: images.count, path: path)
        captureToken += 1
        withAnimation(pushAnimation) {
            showReading = true
        }
    }

    /// `onDismiss` also runs after a button. The sheet already recorded that choice.
    private func finishUnsupportedSheet() {
        let next = afterSheet
        afterSheet = nil
        switch next {
        case .readInCloud:
            beginReading(pendingImages, path: .cloud)
        case .privacy:
            pendingImages = []
            showPrivacy = true
        case .stay, nil:
            pendingImages = []
        }
        presentedPrompt = nil
    }
}

private enum AfterUnsupportedSheet {
    case readInCloud
    case privacy
    case stay
}

/// The scan id and the letter ready to store. A class so the reading task and the hand-off share it.
private final class ScanHandoff {
    var generation = UUID()
    var read: LetterRead?
    var failureMessage: String?
}

#if DEBUG

#Preview("03 Scan entry") {
    NavigationStack {
        ScanEntryScreen()
    }
    .environment(AppConfig())
}

#endif
