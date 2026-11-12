//
//  ClearInkGallery.swift
//  LetterLens-iOS
//
//  Debug-only review surface for the Clear Ink tokens.
//  Open the "Clear Ink" preview. This is not a product screen.
//

#if DEBUG

import SwiftUI
import UIKit

struct ClearInkGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LLSpace.l) {
                header
                colourSection
                typeSection
                scaleSection
                componentSection
            }
            .padding(LLSpace.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LLColor.ground)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LLSpace.xs) {
            Text("Clear Ink")
                .font(LLFont.displayM)
                .tracking(-0.6)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Token gallery. The section headers are LLSectionLabel.")
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(fontStatus)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fontStatus: String {
        if UIFont(name: "BricolageGrotesque-Bold", size: 12) != nil {
            return "Bricolage Grotesque Bold is registered (BricolageGrotesque-Bold)."
        }
        return "Display lines are using the system face until Bricolage Grotesque Bold registers."
    }

    private var colourSection: some View {
        VStack(alignment: .leading, spacing: LLSpace.block) {
            LLSectionLabel(text: "Colour")
            VStack(alignment: .leading, spacing: LLSpace.s) {
                ForEach(swatches) { swatch in
                    SwatchRow(swatch: swatch)
                }
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: LLSpace.block) {
            LLSectionLabel(text: "Type")
            VStack(alignment: .leading, spacing: LLSpace.card) {
                ForEach(typeRows) { row in
                    TypeRow(row: row)
                }
                VStack(alignment: .leading, spacing: LLSpace.xxs) {
                    Text("label").font(LLFont.caption).foregroundStyle(LLColor.inkSecondary)
                    LLSectionLabel(text: "Deadline")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: LLSpace.block) {
            LLSectionLabel(text: "Scale")
            Text(spacingLine)
                .font(LLFont.body)
                .foregroundStyle(LLColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(sizeLine)
                .font(LLFont.body)
                .foregroundStyle(LLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: LLSpace.m)],
                alignment: .leading,
                spacing: LLSpace.m
            ) {
                ForEach(radii) { radius in
                    RadiusChip(radius: radius)
                }
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: LLSpace.block) {
            LLSectionLabel(text: "Components")
            componentCaption("LLProvenanceBadge")
            VStack(alignment: .leading, spacing: LLSpace.s) {
                LLProvenanceBadge(kind: .device)
                LLProvenanceBadge(kind: .cloudRead)
                LLProvenanceBadge(kind: .cloudPlanned)
            }
            componentCaption("LLCard")
            LLCard {
                Text("What this is").font(LLFont.cardTitle).tracking(-0.5).foregroundStyle(LLColor.ink)
                Text("A letter card stays on surface, radius 18, with no shadow.")
                    .font(LLFont.body)
                    .foregroundStyle(LLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            componentCaption("LLDeadlineBlock. Amber only when a date and a quote are both present.")
            LLDeadlineBlock(date: "Fri 4 December", quote: "Please pay by 4 December 2026.")
            componentCaption("Date without a quote stays neutral.")
            LLDeadlineBlock(date: "Fri 4 December", quote: nil)
            componentCaption("No date stays neutral.")
            LLDeadlineBlock(date: nil, quote: nil)
            componentCaption("LLPrimaryButtonStyle")
            Button("Primary action") {}
                .buttonStyle(LLPrimaryButtonStyle())
            componentCaption("LLPrimaryButtonStyle, cloud fill. Consent sheet only.")
            Button("Read it in the cloud") {}
                .buttonStyle(LLPrimaryButtonStyle(fill: LLColor.cloud))
            componentCaption("LLSecondaryButtonStyle")
            Button("Secondary action") {}
                .buttonStyle(LLSecondaryButtonStyle())
            componentCaption("LLSecondaryButtonStyle, ground fill on a white sheet.")
            LLCard {
                Button("Not now") {}
                    .buttonStyle(LLSecondaryButtonStyle(fill: LLColor.ground))
            }
        }
    }

    private func componentCaption(_ text: String) -> some View {
        Text(text)
            .font(LLFont.caption)
            .foregroundStyle(LLColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, LLSpace.s)
    }

    private var spacingLine: String {
        let values = [
            LLSpace.xxs, LLSpace.xs, LLSpace.s, LLSpace.sm, LLSpace.m,
            LLSpace.block, LLSpace.card, LLSpace.blockLoose, LLSpace.screen, LLSpace.l,
        ]
        return values.map { String(Int($0)) }.joined(separator: "  ")
    }

    private var sizeLine: String {
        "Touch \(Int(LLSize.touchMin)) · Primary \(Int(LLSize.primaryButton)) · Secondary \(Int(LLSize.secondaryButton)) · Hero \(Int(LLSize.heroButton))"
    }
}

private struct Swatch: Identifiable {
    let name: String
    let hex: String
    let color: Color
    var id: String { name }
}

private struct RadiusSample: Identifiable {
    let name: String
    let value: CGFloat
    var id: String { name }
}

private struct TypeSample: Identifiable {
    let name: String
    let sample: String
    let font: Font
    var tracking: CGFloat = 0
    var color: Color = LLColor.ink
    var id: String { name }
}

private struct SwatchRow: View {
    let swatch: Swatch

    var body: some View {
        HStack(spacing: LLSpace.m) {
            RoundedRectangle(cornerRadius: LLRadius.iconButton)
                .fill(swatch.color)
                .frame(width: LLSize.touchMin, height: LLSize.touchMin)
                .overlay(
                    RoundedRectangle(cornerRadius: LLRadius.iconButton)
                        .stroke(LLColor.line)
                )
            VStack(alignment: .leading, spacing: LLSpace.xxs) {
                Text(swatch.name)
                    .font(LLFont.body)
                    .foregroundStyle(LLColor.ink)
                Text(swatch.hex)
                    .font(LLFont.caption)
                    .foregroundStyle(LLColor.inkSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct TypeRow: View {
    let row: TypeSample

    var body: some View {
        VStack(alignment: .leading, spacing: LLSpace.xxs) {
            Text(row.name)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
            Text(row.sample)
                .font(row.font)
                .tracking(row.tracking)
                .foregroundStyle(row.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RadiusChip: View {
    let radius: RadiusSample

    var body: some View {
        VStack(spacing: LLSpace.xs) {
            RoundedRectangle(cornerRadius: radius.value, style: .continuous)
                .fill(LLColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: radius.value, style: .continuous)
                        .stroke(LLColor.ink, lineWidth: 1.5)
                )
                .frame(width: radius.value >= 999 ? 96 : 64, height: 64)
            Text(radius.name)
                .font(LLFont.caption)
                .foregroundStyle(LLColor.inkSecondary)
        }
    }
}

private let swatches: [Swatch] = [
    Swatch(name: "ink", hex: "#14213D", color: LLColor.ink),
    Swatch(name: "inkSecondary", hex: "#4A5568", color: LLColor.inkSecondary),
    Swatch(name: "ground", hex: "#F5F6F8", color: LLColor.ground),
    Swatch(name: "surface", hex: "#FFFFFF", color: LLColor.surface),
    Swatch(name: "line", hex: "#E3E6EC", color: LLColor.line),
    Swatch(name: "fillQuiet", hex: "#EEF0F4", color: LLColor.fillQuiet),
    Swatch(name: "controlBorder", hex: "#7B8497", color: LLColor.controlBorder),
    Swatch(name: "cameraBackground", hex: "#0B1220", color: LLColor.cameraBackground),
    Swatch(name: "device", hex: "#0E7A5A", color: LLColor.device),
    Swatch(name: "deviceTint", hex: "#E6F4EE", color: LLColor.deviceTint),
    Swatch(name: "deviceBright", hex: "#3FC79A", color: LLColor.deviceBright),
    Swatch(name: "cloud", hex: "#2D5BD7", color: LLColor.cloud),
    Swatch(name: "cloudTint", hex: "#E8EEFC", color: LLColor.cloudTint),
    Swatch(name: "deadline", hex: "#9A4D00", color: LLColor.deadline),
    Swatch(name: "deadlineTint", hex: "#FDF1E1", color: LLColor.deadlineTint),
    Swatch(name: "deadlineQuote", hex: "#5C3A10", color: LLColor.deadlineQuote),
    Swatch(name: "deadlineRule", hex: "#F1D9B5", color: LLColor.deadlineRule),
    Swatch(name: "warning", hex: "#B42318", color: LLColor.warning),
    Swatch(name: "warningTint", hex: "#FDECEA", color: LLColor.warningTint),
    Swatch(name: "AccentColor", hex: "#14213D", color: Color("AccentColor")),
]

private let typeRows: [TypeSample] = [
    TypeSample(name: "displayL · 38 · -0.6", sample: "Welcome", font: LLFont.displayL, tracking: -0.6),
    TypeSample(name: "displayM · 34 · -0.6", sample: "Letters", font: LLFont.displayM, tracking: -0.6),
    TypeSample(name: "cardTitle · 30 · -0.5", sample: "What this is", font: LLFont.cardTitle, tracking: -0.5),
    TypeSample(name: "displayS · 28 · -0.4", sample: "Reading", font: LLFont.displayS, tracking: -0.4),
    TypeSample(name: "title · 26 · -0.4", sample: "Fri 4 December", font: LLFont.title, tracking: -0.4),
    TypeSample(name: "titleS · 22", sample: "No deadline found", font: LLFont.titleS),
    TypeSample(name: "bodyL · 17 medium", sample: "What they want you to do", font: LLFont.bodyL),
    TypeSample(name: "callout · 16", sample: "Check the date, then the amount.", font: LLFont.callout),
    TypeSample(name: "body · 15", sample: "We only show a date when the letter states one.", font: LLFont.body),
    TypeSample(name: "quote · 15", sample: "“Please pay by 4 December 2026.”", font: LLFont.quote, color: LLColor.deadlineQuote),
    TypeSample(name: "badge · 15 semibold", sample: "Read on this iPhone", font: LLFont.badge),
    TypeSample(name: "caption · 12", sample: "Explains letters. Not legal or financial advice.", font: LLFont.caption, color: LLColor.inkSecondary),
    TypeSample(name: "button · 17 semibold", sample: "Primary action", font: LLFont.button),
]

private let radii: [RadiusSample] = [
    RadiusSample(name: "12 icon", value: LLRadius.iconButton),
    RadiusSample(name: "14 tile", value: LLRadius.tile),
    RadiusSample(name: "16 button", value: LLRadius.button),
    RadiusSample(name: "18 card", value: LLRadius.card),
    RadiusSample(name: "24 panel", value: LLRadius.panel),
    RadiusSample(name: "28 sheet", value: LLRadius.sheet),
    RadiusSample(name: "999 pill", value: 999),
]

#Preview("Clear Ink") {
    ClearInkGallery()
}

#endif
