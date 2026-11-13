//
//  CapturedPageLoader.swift
//  LetterLens-iOS
//
//  Turns a scan, a photo, or a PDF into page images on this iPhone.
//  Nothing here is uploaded.

import CoreGraphics
import Foundation
import PDFKit
import UIKit

enum CapturedPageLoader {
    static func images(fromPNG pages: [Data]) -> [UIImage] {
        pages.compactMap { UIImage(data: $0) }
    }

    static func image(fromPhotoData data: Data) -> UIImage? {
        UIImage(data: data)
    }

    static func images(fromPDFAt url: URL) -> [UIImage] {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return images(fromPDF: data)
    }

    static func images(fromPDF data: Data) -> [UIImage] {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { return [] }
        return (0..<document.pageCount).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            return render(page)
        }
    }

    /// Renders one PDF page for the reading preview. The bitmap stays on device.
    private static func render(_ page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        guard let image = context.makeImage() else { return nil }
        return UIImage(cgImage: image)
    }
}
