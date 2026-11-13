//
//  ImportHandler.swift
//  LetterLens-iOS
//

import Foundation

/// Loads a photo or PDF the user picked. The bytes stay on device for OCR.
enum ImportHandler {
    static func load(url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}
