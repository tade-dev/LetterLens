//
//  ScamHelpTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite("Scam help") struct ScamHelpTests {
    @Test func theCheckTitleReadsAsASentence() {
        #expect(ScamHelp.checkTitle(sender: .hmrc) == "How to check with HMRC")
        #expect(ScamHelp.checkTitle(sender: .council) == "How to check with the council")
        #expect(ScamHelp.checkTitle(sender: .notSure) == "How to check with the sender")
        #expect(ScamHelp.checkTitle(sender: .other) == "How to check with the sender")
    }

    @Test func everySenderGetsAFullCheckSheet() {
        for sender in SenderKind.allCases {
            let content = ScamHelp.check(sender: sender)
            #expect(content.steps.count == 4)
            #expect(!content.steps.contains { $0.isEmpty })
            #expect(!content.lead.isEmpty)
            #expect(!content.footnote.isEmpty)
        }
    }

    /// The whole point of the screen: never the details printed on the letter.
    @Test func theFirstCheckStepRulesOutTheLettersOwnDetails() {
        for sender in SenderKind.allCases {
            #expect(ScamHelp.check(sender: sender).steps[0].contains("Do not use the phone number"))
        }
    }

    @Test func reportingNamesActionFraudAndAddsTheSenderSpecificRoute() {
        let generic = ScamHelp.report(sender: .utility)
        #expect(generic.steps.contains { $0.contains("Action Fraud") })
        #expect(generic.steps.contains { $0.contains("Police Scotland") })
        #expect(generic.steps.count == 3)

        let hmrc = ScamHelp.report(sender: .hmrc)
        #expect(hmrc.steps.count == 4)
        #expect(hmrc.steps.contains { $0.contains("phishing@hmrc.gov.uk") })

        let bank = ScamHelp.report(sender: .bank)
        #expect(bank.steps.count == 4)
        #expect(bank.steps.contains { $0.contains("back of your card") })
    }

    /// `.sheet(item:)` swaps content when the id changes, so the two must differ.
    @Test func theTwoSheetsAreToldApart() {
        #expect(ScamHelp.check(sender: .hmrc).id != ScamHelp.report(sender: .hmrc).id)
    }
}
