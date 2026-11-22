//
//  ScamHelp.swift
//  LetterLens-iOS
//
//  The words behind screen 06's two buttons. Everything here is fixed copy:
//  no model wrote it, and nothing on these screens is sent anywhere.
//  The advice is the same one every time: use contact details you find
//  yourself, never the ones printed on the letter in front of you.

import Foundation

struct ScamHelpContent: Equatable, Identifiable {
    /// Each sheet has its own title, which is enough to tell the two apart.
    var id: String { title }
    var title: String
    var lead: String
    var steps: [String]
    var footnote: String
}

enum ScamHelp {
    /// "How to check with the council", "How to check with HMRC".
    static func checkTitle(sender: SenderKind) -> String {
        "How to check with \(contactName(sender))"
    }

    static func check(sender: SenderKind) -> ScamHelpContent {
        ScamHelpContent(
            title: checkTitle(sender: sender),
            lead: "A scam letter puts its own number, link and address in front of you. Use details you find yourself instead.",
            steps: [
                "Do not use the phone number, link or address printed on this letter.",
                findLine(sender),
                "Ask whether the letter is theirs, and read them any reference you can see on it.",
                "If they say it is not theirs, pay nothing and keep the letter.",
            ],
            footnote: "LetterLens cannot tell you a letter is safe. Only the sender can."
        )
    }

    static func report(sender: SenderKind) -> ScamHelpContent {
        var steps = [
            "Keep the letter. Pay nothing, and do not call a number printed on it.",
            "In England, Wales and Northern Ireland, report it to Action Fraud at actionfraud.police.uk or on 0300 123 2040.",
            "In Scotland, call Police Scotland on 101.",
        ]
        switch sender {
        case .hmrc:
            steps.append("A letter claiming to be from HMRC can also be reported to phishing@hmrc.gov.uk.")
        case .bank:
            steps.append("Tell your bank as well, using the number on the back of your card.")
        default:
            break
        }
        return ScamHelpContent(
            title: "Report a suspicious letter",
            lead: "You do not have to be sure. Reporting it helps stop the same letter reaching someone else.",
            steps: steps,
            footnote: "LetterLens does not report anything for you. Nothing on this screen has left this iPhone."
        )
    }

    /// Reads inside a sentence: "How to check with the council".
    static func contactName(_ sender: SenderKind) -> String {
        switch sender {
        case .council: "the council"
        case .hmrc: "HMRC"
        case .bank: "your bank"
        case .benefits: "DWP"
        case .school: "the school"
        case .utility: "your supplier"
        case .landlord: "your landlord"
        case .nhs: "the NHS"
        case .other, .notSure: "the sender"
        }
    }

    private static func findLine(_ sender: SenderKind) -> String {
        switch sender {
        case .council:
            "Find your council on GOV.UK and call the number on their own website."
        case .hmrc:
            "Search GOV.UK for HMRC’s contact details. HMRC never asks for a fee to release a refund."
        case .bank:
            "Call the number on the back of your bank card, or the one inside your banking app."
        case .benefits:
            "Find the Jobcentre Plus or DWP number on GOV.UK."
        case .school:
            "Call the school on a number you already have, or the one on its own website."
        case .utility:
            "Call the number on a bill you already have, or on your supplier’s own website."
        case .landlord:
            "Use a number from your tenancy agreement or an earlier letter."
        case .nhs:
            "Call your GP surgery or hospital using NHS.uk or an appointment letter you already have."
        case .other, .notSure:
            "Look the sender up yourself: an earlier bill, a statement, or their own website."
        }
    }
}
