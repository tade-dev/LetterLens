//
//  SharedInbox.swift
//  LetterLens-iOS, LetterLensShare
//
//  A drop box in the App Group container. The share extension writes a letter
//  here and the app reads it the next time it is on screen.
//
//  The extension never runs the pipeline. It has no Firebase, no model and no
//  OCR: it only copies bytes across the group boundary, so a share stays fast
//  and the privacy rules keep living in one place, in the app.

import Foundation

enum SharedInboxError: Error {
    /// The App Group is missing from the entitlements, or the container is unavailable.
    case noContainer
}

enum SharedInbox {
    static let appGroupID = "group.com.tade.LetterLens-iOS"

    enum Kind {
        case image
        case pdf

        var fileExtension: String {
            switch self {
            case .image: "png"
            case .pdf: "pdf"
            }
        }
    }

    static var directoryURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Inbox", directoryHint: .isDirectory)
    }

    @discardableResult
    static func write(_ data: Data, kind: Kind) throws -> URL {
        guard let directoryURL else { throw SharedInboxError.noContainer }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = directoryURL.appending(path: "\(UUID().uuidString).\(kind.fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Oldest first, so the pages of one share keep the order they were sent in.
    static func pending() -> [URL] {
        guard let directoryURL else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.sorted { left, right in
            let l = (try? left.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let r = (try? right.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if l == r { return left.lastPathComponent < right.lastPathComponent }
            return l < r
        }
    }

    /// Called once the app has turned the files into pages. The bytes are a copy,
    /// so removing them here does not touch the user's original photo or PDF.
    static func clear(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
