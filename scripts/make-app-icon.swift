import AppKit
import CoreGraphics
import Foundation

// Builds the three 1024 app icons from one piece of artwork.
//
//   swift scripts/make-app-icon.swift design/app-icon-1024.png LetterLens-iOS/Assets.xcassets/AppIcon.appiconset
//
// Light and dark are the artwork itself, flattened onto an opaque bitmap:
// the App Store rejects an icon with an alpha channel, and this artwork
// already carries its own dark ground, so it needs no separate dark cut.
// Tinted is the same artwork in greyscale, which is what iOS asks for: it
// applies the wallpaper tint to the luminance itself.

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make-app-icon.swift <source.png> <AppIcon.appiconset>\n".utf8))
    exit(2)
}
let sourcePath = arguments[1]
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)

let side = 1024

guard let source = NSImage(contentsOfFile: sourcePath),
      let artwork = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("could not read \(sourcePath)\n".utf8))
    exit(1)
}

func draw(greyscale: Bool) -> CGImage? {
    // Grey takes `.none`; RGB has no 8-bit `.none` layout, so it skips the
    // fourth byte instead. Neither keeps an alpha channel.
    let space = greyscale
        ? CGColorSpaceCreateDeviceGray()
        : CGColorSpaceCreateDeviceRGB()
    let alpha: CGImageAlphaInfo = greyscale ? .none : .noneSkipLast
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: alpha.rawValue
    ) else { return nil }
    context.interpolationQuality = .high
    context.draw(artwork, in: CGRect(x: 0, y: 0, width: side, height: side))
    return context.makeImage()
}

func write(_ image: CGImage, to name: String) {
    let url = outputDirectory.appendingPathComponent(name)
    let bitmap = NSBitmapImageRep(cgImage: image)
    bitmap.size = NSSize(width: side, height: side)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("could not encode \(name)\n".utf8))
        exit(1)
    }
    do {
        try data.write(to: url)
        print("wrote \(url.path)")
    } catch {
        FileHandle.standardError.write(Data("could not write \(name): \(error)\n".utf8))
        exit(1)
    }
}

guard let colour = draw(greyscale: false), let grey = draw(greyscale: true) else {
    FileHandle.standardError.write(Data("could not draw the icon\n".utf8))
    exit(1)
}

write(colour, to: "AppIcon-1024.png")
write(colour, to: "AppIcon-1024-dark.png")
write(grey, to: "AppIcon-1024-tinted.png")
