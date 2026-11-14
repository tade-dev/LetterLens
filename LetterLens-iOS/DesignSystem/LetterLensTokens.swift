// LetterLens "Clear Ink" design tokens for SwiftUI (iOS 26).
// Source of truth: docs/BRAND.md + design/html. Spec: DESIGN-SYSTEM.md.
// Colours live in the asset catalog (Any appearance only); this file only names them.
// Light only for the hackathon: apply .preferredColorScheme(.light) at the app root.
// Settings switches: native Toggle with .tint(LLColor.ink). Green is reserved for read letters.
// Disclaimer: one string, Localizable.xcstrings key "disclaimer.short" = "Explains letters. Not legal or financial advice."

import SwiftUI

// MARK: - Colour roles

enum LLColor {
    // Neutrals
    static let ink            = Color("ink")            // #14213D  text, primary button fill
    static let inkSecondary   = Color("inkSecondary")   // #4A5568  secondary text, labels
    static let ground         = Color("ground")         // #F5F6F8  screen background
    static let surface        = Color("surface")        // #FFFFFF  cards, sheets
    static let line           = Color("line")           // #E3E6EC  dividers only
    static let fillQuiet      = Color("fillQuiet")      // #EEF0F4  neutral icon tile / status pill (new)
    static let controlBorder  = Color("controlBorder")  // #7B8497  empty rings, 3.47:1 on ground (new)
    static let cameraBackground = Color("cameraBg")     // #0B1220

    // Provenance. Use ONLY to say where a letter was read or planned.
    static let device       = Color("device")           // #0E7A5A
    static let deviceTint   = Color("deviceTint")       // #E6F4EE
    static let deviceBright = Color("deviceBright")     // #3FC79A  logo lens on dark only
    static let cloud        = Color("cloud")            // #2D5BD7
    static let cloudTint    = Color("cloudTint")        // #E8EEFC

    // Deadline. Use ONLY for a deadline the letter states, with its quote.
    static let deadline      = Color("deadline")        // #9A4D00
    static let deadlineTint  = Color("deadlineTint")    // #FDF1E1
    static let deadlineQuote = Color("deadlineQuote")   // #5C3A10
    static let deadlineRule  = Color("deadlineRule")    // #F1D9B5

    // Warning. Use ONLY for "Signs to check", penalties, and destructive actions.
    static let warning     = Color("warning")           // #B42318
    static let warningTint = Color("warningTint")       // #FDECEA
    static let warningOn   = Color("warningOn")         // #FCE3E0  text on the warning fill
}

// MARK: - Type
// Bundle the STATIC Bricolage Grotesque Bold .ttf (not the variable font) and list it in UIAppFonts.
// Confirm the PostScript name once with UIFont.fontNames(forFamilyName: "Bricolage Grotesque").

enum LLFont {
    private static let display = "BricolageGrotesque-Bold"

    // Display (Bricolage 700) scales with Dynamic Type via relativeTo:
    static let displayL  = Font.custom(display, size: 38, relativeTo: .largeTitle)  // onboarding
    static let displayM  = Font.custom(display, size: 34, relativeTo: .largeTitle)  // screen title, tracking -0.6
    static let cardTitle = Font.custom(display, size: 30, relativeTo: .title)       // letter-card title, tracking -0.5
    static let displayS  = Font.custom(display, size: 28, relativeTo: .title)       // status/error title, tracking -0.4
    static let title     = Font.custom(display, size: 26, relativeTo: .title2)      // deadline date, sheet title
    static let titleS    = Font.custom(display, size: 22, relativeTo: .title3)      // "No deadline found…"

    // Body: SF Pro. Use text styles so Dynamic Type is automatic.
    static let bodyL    = Font.body.weight(.medium)       // 17  key answer ("What they want you to do")
    static let body     = Font.subheadline                // 15  explanations
    static let callout  = Font.callout                    // 16  list rows, steps (Reading)
    static let quote    = Font.subheadline                // 15  verbatim deadline quote
    static let label    = Font.footnote.weight(.semibold) // 13  UPPERCASE, tracking 0.6
    static let badge    = Font.subheadline.weight(.semibold)
    static let caption  = Font.caption                    // 12  disclaimer, footers
    static let button   = Font.body.weight(.semibold)     // 17 primary (mockups show 16; use the text style)
}

// MARK: - Spacing, radius, size

enum LLSpace {
    static let xxs: CGFloat = 4,  xs: CGFloat = 6,  s: CGFloat = 8,  sm: CGFloat = 10, m: CGFloat = 12
    static let block: CGFloat = 14, card: CGFloat = 16, blockLoose: CGFloat = 18, screen: CGFloat = 20, l: CGFloat = 24
}

enum LLRadius {
    static let iconButton: CGFloat = 12, tile: CGFloat = 14, button: CGFloat = 16
    static let card: CGFloat = 18, warningCard: CGFloat = 20, panel: CGFloat = 24, sheet: CGFloat = 28
}

enum LLSize {
    static let touchMin: CGFloat = 44
    /// System large control. Was 56, which plus glass padding became about 100pt.
    static let primaryButton: CGFloat = 50
    /// System large control. Was 52.
    static let secondaryButton: CGFloat = 50
    static let heroButton: CGFloat = 60   // Home "Scan a letter" only
}

// MARK: - Components (reference implementations)

struct LLSectionLabel: View {
    let text: String
    var color: Color = LLColor.inkSecondary

    var body: some View {
        Text(text.uppercased())
            .font(LLFont.label).tracking(0.6)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

enum Provenance { case device, cloudRead, cloudPlanned }

struct LLProvenanceBadge: View {
    let kind: Provenance
    var body: some View {
        Label(title, systemImage: kind == .device ? "lock.fill" : "cloud")
            .font(LLFont.badge)
            .foregroundStyle(kind == .device ? LLColor.device : LLColor.cloud)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(kind == .device ? LLColor.deviceTint : LLColor.cloudTint, in: Capsule())
    }
    private var title: String {
        switch kind {
        case .device: "Read on this iPhone"
        case .cloudRead: "Read in the cloud"
        case .cloudPlanned: "Planned in the cloud"
        }
    }
}

struct LLCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: LLSpace.xs) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LLSpace.card)
            .background(LLColor.surface, in: .rect(cornerRadius: LLRadius.card))
    }
}

/// Deadline block. Amber only when a date AND its verbatim quote exist.
struct LLDeadlineBlock: View {
    let date: String?      // already formatted, e.g. "Fri 4 December"
    let quote: String?     // verbatim from the letter
    var body: some View {
        if let date, let quote {
            VStack(alignment: .leading, spacing: LLSpace.s) {
                Label("Deadline", systemImage: "calendar.badge.clock")
                    .font(LLFont.label).tracking(0.6).textCase(.uppercase)
                    .foregroundStyle(LLColor.deadline)
                Text(date).font(LLFont.title).foregroundStyle(LLColor.ink)
                Divider().overlay(LLColor.deadlineRule)
                Text("“\(quote)”").font(LLFont.quote).foregroundStyle(LLColor.deadlineQuote)
            }
            .padding(LLSpace.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LLColor.deadlineTint, in: .rect(cornerRadius: LLRadius.card))
        } else {
            VStack(alignment: .leading, spacing: LLSpace.s) {
                LLSectionLabel(text: "Deadline")
                Text("No deadline found in this letter.").font(LLFont.titleS)
                Divider().overlay(LLColor.line)
                Text("We only show a date when the letter states one. If you expected a date, check the letter itself.")
                    .font(LLFont.body).foregroundStyle(LLColor.inkSecondary)
            }
            .padding(LLSpace.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LLColor.surface, in: .rect(cornerRadius: LLRadius.card))
            .overlay(RoundedRectangle(cornerRadius: LLRadius.card).stroke(LLColor.line))
        }
    }
}

struct LLPrimaryButtonStyle: ButtonStyle {
    var fill: Color = LLColor.ink   // LLColor.cloud ONLY on the cloud-consent sheet
    @ScaledMetric(relativeTo: .body) private var height = LLSize.primaryButton
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LLFont.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: .rect(cornerRadius: LLRadius.button))
    }
}

struct LLSecondaryButtonStyle: ButtonStyle {
    var fill: Color = LLColor.surface   // use LLColor.ground on a white sheet
    @ScaledMetric(relativeTo: .body) private var height = LLSize.secondaryButton
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LLFont.button)
            .foregroundStyle(LLColor.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill.opacity(configuration.isPressed ? 0.7 : 1), in: .rect(cornerRadius: LLRadius.button))
    }
}
