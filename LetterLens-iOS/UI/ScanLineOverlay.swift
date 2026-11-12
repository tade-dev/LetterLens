//
//  ScanLineOverlay.swift
//  LetterLens-iOS
//
//  The sweep sits on the captured page. It is not a progress timer.

import SwiftUI

private struct ScanSweep {
    var progress: CGFloat = 0
    var opacity: Double = 1
}

struct ScanLineOverlay: View {
    var tint: Color
    var visible: Bool
    var reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            sweep(in: geo.size)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .opacity(visible ? 1 : 0)
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: ReadingMotion.settleFade), value: visible)
    }

    @ViewBuilder
    private func sweep(in size: CGSize) -> some View {
        if reduceMotion {
            ScanLineMark(tint: tint, width: size.width)
                .opacity(ReadingMotion.reduceMotionOpacity)
                .offset(y: lineOffset(progress: ReadingMotion.reduceMotionLine, height: size.height))
        } else {
            KeyframeAnimator(initialValue: ScanSweep(), repeating: true) { sweep in
                ScanLineMark(tint: tint, width: size.width)
                    .opacity(sweep.opacity)
                    .offset(y: lineOffset(progress: sweep.progress, height: size.height))
                    .frame(width: size.width, height: size.height, alignment: .top)
            } keyframes: { _ in
                KeyframeTrack(\ScanSweep.progress) {
                    CubicKeyframe(
                        CGFloat(1),
                        duration: ReadingMotion.sweepDuration,
                        startVelocity: CGFloat.zero,
                        endVelocity: CGFloat.zero
                    )
                    LinearKeyframe(CGFloat(1), duration: ReadingMotion.sweepFade)
                }
                KeyframeTrack(\ScanSweep.opacity) {
                    LinearKeyframe(Double(1), duration: ReadingMotion.sweepDuration)
                    LinearKeyframe(Double(0), duration: ReadingMotion.sweepFade)
                }
            }
        }
    }

    /// Puts the 2pt line at `progress` of the page, with the tint trailing above it.
    private func lineOffset(progress: CGFloat, height: CGFloat) -> CGFloat {
        progress * height - ReadingMotion.trailLength - ReadingMotion.lineWeight
    }
}

private struct ScanLineMark: View {
    var tint: Color
    var width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [tint.opacity(0), tint.opacity(ReadingMotion.trailOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: ReadingMotion.trailLength)
            Rectangle()
                .fill(tint)
                .frame(height: ReadingMotion.lineWeight)
        }
        .frame(width: width, alignment: .bottom)
    }
}
