//
//  ShareViewController.swift
//  LetterLensShare
//
//  Takes a photo or PDF from the share sheet and leaves it in the App Group
//  inbox for the app to read. Nothing is read, redacted or uploaded here.
//
//  The app is asked to open through `NSExtensionContext.open`. That request is
//  allowed to fail: the inbox is the contract, and the app drains it whenever it
//  next comes to the front.

import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await receive() }
    }

    private func receive() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var saved = 0

        for item in items {
            for provider in item.attachments ?? [] {
                if await save(provider) {
                    saved += 1
                }
            }
        }

        finish(saved: saved)
    }

    private func save(_ provider: NSItemProvider) async -> Bool {
        // PDF first: a PDF also conforms to public.data, and the page count matters.
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
           let data = await data(from: provider, type: .pdf) {
            return (try? SharedInbox.write(data, kind: .pdf)) != nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = await data(from: provider, type: .image) {
            return (try? SharedInbox.write(data, kind: .image)) != nil
        }
        return false
    }

    private func data(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func finish(saved: Int) {
        if saved > 0, let url = URL(string: "letterlens://shared") {
            extensionContext?.open(url)
        }
        extensionContext?.completeRequest(returningItems: [])
    }
}
