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
    /// Where the letter will be read. Defaults to on-device until Swift passes the route.
    var path: ReadingPath = .device
    var onCardReady: () -> Void = {}
    var onReadingFailed: () -> Void = {}

    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var showPDF = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingScan: [UIImage] = []
    @State private var pages: [UIImage] = []
    @State private var readingProgress: ReadingProgress?
    @State private var showReading = false
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 64

    var body: some View {
        NavigationStack {
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
            .toolbar(.hidden, for: .navigationBar)
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
        }
        .preferredColorScheme(.light)
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
            HStack(spacing: LLSpace.m) {
                Image(systemName: systemImage)
                    .font(LLFont.callout)
                    .foregroundStyle(LLColor.ink)
                    .accessibilityHidden(true)
                Text(title)
                    .font(LLFont.callout)
                    .foregroundStyle(LLColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LLSpace.card)
            .padding(.vertical, LLSpace.m)
            .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .leading)
            .background(LLColor.surface, in: RoundedRectangle(cornerRadius: LLRadius.card, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
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
        pages = images
        readingProgress = ReadingProgress(pagesTotal: images.count, path: path)
        showReading = true
    }
}

private struct PressFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

#if DEBUG

#Preview("03 Scan entry") {
    ScanEntryScreen()
}

#endif
