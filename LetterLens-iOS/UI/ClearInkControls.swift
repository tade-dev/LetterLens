//
//  ClearInkControls.swift
//  LetterLens-iOS
//
//  Controls that float above Clear Ink content.
//  System glass button styles, with the opaque token buttons when Reduce Transparency is on.
//  Content cards do not use this.

import SwiftUI

/// 14pt is in the mockups and not in `LLFont` (footnote is 13, body is 15).
/// `Font.system` has no `relativeTo`, so Dynamic Type comes from `ScaledMetric`.
struct ClearInkBody14: ViewModifier {
    var weight: Font.Weight = .regular
    @ScaledMetric(relativeTo: .subheadline) private var labelSize: CGFloat = 14

    func body(content: Content) -> some View {
        content.font(.system(size: labelSize, weight: weight))
    }
}

extension View {
    func clearInkBody14(weight: Font.Weight = .regular) -> some View {
        modifier(ClearInkBody14(weight: weight))
    }
}

struct ClearInkGlassButton: View {
    enum Kind {
        case prominent(Color)
        case regular
    }

    var title: LocalizedStringKey
    var kind: Kind
    /// Opaque fill for the secondary button when Reduce Transparency is on.
    var opaqueSecondaryFill: Color
    var action: () -> Void

    init(
        _ title: LocalizedStringKey,
        kind: Kind,
        opaqueSecondaryFill: Color = LLColor.ground,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.opaqueSecondaryFill = opaqueSecondaryFill
        self.action = action
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var primaryHeight = LLSize.primaryButton
    @ScaledMetric(relativeTo: .body) private var secondaryHeight = LLSize.secondaryButton

    var body: some View {
        if reduceTransparency {
            opaqueButton
        } else {
            glassButton
        }
    }

    private var label: some View {
        Text(title)
            .font(LLFont.button)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: height)
    }

    private var height: CGFloat {
        switch kind {
        case .prominent: primaryHeight
        case .regular: secondaryHeight
        }
    }

    @ViewBuilder
    private var opaqueButton: some View {
        switch kind {
        case .prominent(let color):
            Button(action: action) { label }
                .buttonStyle(LLPrimaryButtonStyle(fill: color))
        case .regular:
            Button(action: action) { label }
                .buttonStyle(LLSecondaryButtonStyle(fill: opaqueSecondaryFill))
        }
    }

    @ViewBuilder
    private var glassButton: some View {
        switch kind {
        case .prominent(let color):
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .controlSize(.large)
                .tint(color)
        case .regular:
            Button(action: action) { label }
                .buttonStyle(.glass)
                .buttonSizing(.flexible)
                .controlSize(.large)
                .tint(LLColor.ink)
        }
    }
}

struct ClearInkIconTile: View {
    var systemName: String
    var foreground: Color
    var tile: Color
    var side: CGFloat
    var symbolSize: CGFloat
    var cornerRadius: CGFloat
    var bounceTrigger: Bool

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(foreground)
            .modifier(ClearInkSymbolBounce(trigger: bounceTrigger))
            .frame(width: side, height: side)
            .background(tile, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ClearInkEntrance: ViewModifier {
    var index: Int
    var appeared: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(animation.delay(delay), value: appeared)
    }

    private var delay: Double {
        reduceMotion ? 0 : 0.05 * Double(index)
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .snappy
    }
}

extension View {
    func clearInkEntrance(index: Int, appeared: Bool) -> some View {
        modifier(ClearInkEntrance(index: index, appeared: appeared))
    }
}

private struct ClearInkSymbolBounce: ViewModifier {
    var trigger: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: trigger)
        }
    }
}
