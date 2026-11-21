//
//  LetterLensLogo.swift
//  LetterLens-iOS
//
//  Welcome mark, drawn from the brand SVG. Lens uses deviceBright because it sits on ink.

import SwiftUI

struct LetterLensLogo: View {
    var side: CGFloat = 56

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 48
            let tile = Path(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 12 * scale
            )
            context.fill(tile, with: .color(LLColor.ink))

            let envelope = CGRect(x: 9 * scale, y: 14 * scale, width: 24 * scale, height: 18 * scale)
            let envelopePath = Path(
                roundedRect: envelope,
                cornerRadius: 3 * scale
            )
            context.stroke(envelopePath, with: .color(LLColor.surface), lineWidth: 2.4 * scale)

            var flap = Path()
            flap.move(to: CGPoint(x: 9.5 * scale, y: 15.5 * scale))
            flap.addLine(to: CGPoint(x: 21 * scale, y: 24 * scale))
            flap.addLine(to: CGPoint(x: 32.5 * scale, y: 15.5 * scale))
            context.stroke(
                flap,
                with: .color(LLColor.surface),
                style: StrokeStyle(lineWidth: 2.4 * scale, lineJoin: .round)
            )

            let lensRect = CGRect(x: 25.5 * scale, y: 23.5 * scale, width: 13 * scale, height: 13 * scale)
            let lens = Path(ellipseIn: lensRect)
            context.fill(lens, with: .color(LLColor.ink))
            context.stroke(lens, with: .color(LLColor.deviceBright), lineWidth: 2.6 * scale)

            var handle = Path()
            handle.move(to: CGPoint(x: 36.8 * scale, y: 34.8 * scale))
            handle.addLine(to: CGPoint(x: 40 * scale, y: 38 * scale))
            context.stroke(
                handle,
                with: .color(LLColor.deviceBright),
                style: StrokeStyle(lineWidth: 2.8 * scale, lineCap: .round)
            )
        }
        .frame(width: side, height: side)
        .accessibilityLabel("LetterLens")
    }
}
