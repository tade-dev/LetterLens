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
        neverUpload: false,
        allowCloudFallback: false
    )
    var availability: OnDeviceReadingAvailability = .available
    var preferences: PrivacySettingsModel = PrivacySettingsModel(writesDefaults: false)
    var onCardReady: () -> Void = {}
    var onReadingFailed: () -> Void = {}

    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var showPDF = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingScan: [UIImage] = []
    @State private var pendingImages: [UIImage] = []
    @State private var pages: [UIImage] = []
    @State private var readingProgress: ReadingProgress?
    @State private var showReading = false
    @State private var showUnsupported = false
    @State private var presentedPrompt: UnsupportedDevicePrompt?
    @State private var presentedCause: KeepPrivateCause = .cloudFallbackOff
    @State private var showPrivacy = false
    @State private var afterSheet: AfterUnsupportedSheet?
    @State private var captureToken = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 64

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
                .buttonStyle(.glass)
                .accessibilityLabel("Privacy")
            }
        }
        .navigationDestination(isPresented: $showReading) {
            if let readingProgress {
                ReadingScreen(
                    pages: pages,
                    progress: readingProgress,
                    onCardReady: onCardReady,
                    onReadingFailed: onReadingFailed
                )
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
                    keepPrivateCause: presentedCause,
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
    }

    /// Spring into reading. Reduce Motion uses the same short fade as a page change.
    private var pushAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: ReadingMotion.reduceMotionCrossfade)
            : .spring(duration: ReadingMotion.pushSpringDuration, bounce: ReadingMotion.pushSpringBounce)
    }

    private var cameraBlock: some View {
        VStack(alignment: .leading, spacing: LLSpace.m) {
            Button {
                showScanner = true
            } label: {
                Text("Scan with camera")
                    .font(LLFont.button)
                    .foregroundStyle(LLColor.surface)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, LLSpace.l)
                    .padding(.vertical, LLSpace.l)
                    .frame(maxWidth: .infinity)
                    .background(LLColor.ink, in: RoundedRectangle(cornerRadius: LLRadius.panel, style: .continuous))
            }
            .buttonStyle(PressFadeButtonStyle())

            Text("Finds the page edges for you. Add as many pages as the letter has.")
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importBlock: some View {
        // System glass buttons, grouped so neighbouring controls blend.
        // Reduce Transparency drops the material for an opaque surface row.
        Group {
            if reduceTransparency {
                importRows
            } else {
                GlassEffectContainer(spacing: LLSpace.m) {
                    importRows
                }
            }
        }
    }

    private var importRows: some View {
        VStack(spacing: LLSpace.m) {
            importRow("Choose a photo", systemImage: "photo") {
                showPhotos = true
            }
            importRow("Import a PDF", systemImage: "doc") {
                showPDF = true
            }
        }
    }

    @ViewBuilder
    private func importRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        if reduceTransparency {
            Button(action: action) {
                importLabel(title, systemImage: systemImage)
            }
            .buttonStyle(PressFadeButtonStyle())
            .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        } else {
            Button(action: action) {
                importLabel(title, systemImage: systemImage)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.roundedRectangle(radius: LLRadius.card))
        }
    }

    private func importLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: LLSpace.m) {
            Image(systemName: systemImage)
                .font(LLFont.callout)
                .accessibilityHidden(true)
            Text(title)
                .font(LLFont.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(LLColor.ink)
        .padding(.horizontal, LLSpace.card)
        .padding(.vertical, LLSpace.m)
        .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .leading)
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
        presentedCause = flow.keepPrivateCause ?? .cloudFallbackOff
        showUnsupported = true
    }

    private func beginReading(_ images: [UIImage], path: ReadingPath) {
        guard !images.isEmpty else { return }
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

private struct PressFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

#if DEBUG

#Preview("03 Scan entry") {
    NavigationStack {
        ScanEntryScreen()
    }
}

#endif
