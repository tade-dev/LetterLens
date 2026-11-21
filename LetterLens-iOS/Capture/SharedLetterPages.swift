//
//  SharedLetterPages.swift
//  LetterLens-iOS
//
//  Turns what the share extension left in the App Group inbox into pages.
//  The extension only copies bytes; the PDF rendering and every privacy
//  decision still happen here, in the app.

import Foundation
import UIKit

enum SharedLetterPages {
    /// Reads every pending file and removes it. A file that cannot be decoded is
    /// still removed, so one bad share cannot wedge the inbox on every launch.
    static func drain() -> [UIImage] {
        let urls = SharedInbox.pending()
        guard !urls.isEmpty else { return [] }
        defer { SharedInbox.clear(urls) }

        var pages: [UIImage] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            if url.pathExtension.lowercased() == "pdf" {
                pages.append(contentsOf: CapturedPageLoader.images(fromPDF: data))
            } else if let image = CapturedPageLoader.image(fromPhotoData: data) {
                pages.append(image)
            }
        }
        return pages
    }
}
