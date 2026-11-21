import AppKit
import CoreGraphics
import Foundation

// Geometry copied from LetterLensLogo.swift, which draws on a 48pt grid.
// The icon drops the logo's own rounded tile: iOS masks the corners itself,
// so the artwork is full bleed.

struct Paint { var r: CGFloat; var g: CGFloat; var b: CGFloat }
func hex(_ v: UInt32) -> Paint {
    Paint(r: CGFloat((v >> 16) & 0xFF) / 255,
          g: CGFloat((v >> 8) & 0xFF) / 255,
          b: CGFloat(v & 0xFF) / 255)
}
let ink        = hex(0x14213D)
let surface    = hex(0xFFFFFF)
let bright     = hex(0x3FC79A)
let cameraBg   = hex(0x0B1220)
let tintGlyph  = hex(0xFFFFFF)
let tintLens   = hex(0xB8B8B8)

func cg(_ p: Paint, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: p.r, green: p.g, blue: p.b, alpha: a)
}

// Mark bounding box on the 48 grid, stroke widths included.
let bbox = CGRect(x: 7.8, y: 12.8, width: 33.6, height: 26.6)

func drawMark(_ c: CGContext, side: CGFloat, coverage: CGFloat,
              background: Paint?, envelope: Paint, lensFill: Paint, lens: Paint) {
    if let background {
        c.setFillColor(cg(background))
        c.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }

    // Flip to SwiftUI's top-left origin, then fit the mark's bbox into `coverage`.
    c.translateBy(x: 0, y: side)
    c.scaleBy(x: 1, y: -1)

    let s = (coverage * side) / bbox.width
    c.translateBy(x: side / 2 - bbox.midX * s, y: side / 2 - bbox.midY * s)
    c.scaleBy(x: s, y: s)

    c.setLineJoin(.round)

    let env = CGPath(roundedRect: CGRect(x: 9, y: 14, width: 24, height: 18),
                     cornerWidth: 3, cornerHeight: 3, transform: nil)
    c.addPath(env)
    c.setStrokeColor(cg(envelope))
    c.setLineWidth(2.4)
    c.strokePath()

    c.move(to: CGPoint(x: 9.5, y: 15.5))
    c.addLine(to: CGPoint(x: 21, y: 24))
    c.addLine(to: CGPoint(x: 32.5, y: 15.5))
    c.setStrokeColor(cg(envelope))
    c.setLineWidth(2.4)
    c.strokePath()

    let lensRect = CGRect(x: 25.5, y: 23.5, width: 13, height: 13)
    c.addEllipse(in: lensRect)
    c.setFillColor(cg(lensFill))
    c.fillPath()
    c.addEllipse(in: lensRect)
    c.setStrokeColor(cg(lens))
    c.setLineWidth(2.6)
    c.strokePath()

    c.setLineCap(.round)
    c.move(to: CGPoint(x: 36.8, y: 34.8))
    c.addLine(to: CGPoint(x: 40, y: 38))
    c.setStrokeColor(cg(lens))
    c.setLineWidth(2.8)
    c.strokePath()
}

func render(_ path: String, background: Paint?, envelope: Paint, lensFill: Paint, lens: Paint) {
    let side: CGFloat = 1024
    guard let c = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {  // no alpha: App Store rejects icons with one
        fatalError("context")
    }
    c.setAllowsAntialiasing(true)
    c.interpolationQuality = .high
    drawMark(c, side: side, coverage: 0.60, background: background,
             envelope: envelope, lensFill: lensFill, lens: lens)
    guard let image = c.makeImage() else { fatalError("image") }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: 1024, height: 1024)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

let out = CommandLine.arguments[1]
render("\(out)/AppIcon-1024.png",        background: ink,      envelope: surface,   lensFill: ink,      lens: bright)
render("\(out)/AppIcon-1024-dark.png",   background: cameraBg, envelope: surface,   lensFill: cameraBg, lens: bright)
// Tinted is a grayscale version of the same icon, full bleed: the system
// maps its luminance onto the user's tint. The lens keeps its ink-coloured
// fill so it still occludes the envelope, here as the background grey.
let tintBg = hex(0x1C1C1E)
render("\(out)/AppIcon-1024-tinted.png", background: tintBg, envelope: tintGlyph, lensFill: tintBg, lens: tintLens)
