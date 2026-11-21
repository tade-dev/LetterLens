//
//  LetterCardSchemaTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@MainActor
@Suite struct LetterCardSchemaTests {
    @Test func enumsRoundTripThroughJSON() throws {
        let card = LetterCard(
            type: .finalNotice,
            senderKind: .hmrc,
            action: "Pay the balance.",
            deadline: nil,
            deadlineQuote: nil,
            amountQuote: nil,
            watchOuts: [],
            scamSigns: [],
            noActionNeeded: false
        )
        let data = try CardJSON.encode(card)
        let decoded = try JSONDecoder().decode(LetterCard.self, from: data)
        #expect(decoded.type == .finalNotice)
        #expect(decoded.senderKind == .hmrc)
        #expect(decoded.displayTitle == "HMRC · Final notice")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["type"] as? String == "final_notice")
        #expect(object?["sender_kind"] as? String == "hmrc")
    }

    @Test func unknownAndMissingValuesBecomeNotSure() throws {
        let unknown = """
        {"type":"spaceship","sender_kind":"university","action":"Wait.","no_action_needed":false}
        """
        let missing = """
        {"action":"Wait.","no_action_needed":true}
        """
        let unknownCard = try JSONDecoder().decode(LetterCard.self, from: Data(unknown.utf8))
        let missingCard = try JSONDecoder().decode(LetterCard.self, from: Data(missing.utf8))
        #expect(unknownCard.type == .notSure)
        #expect(unknownCard.senderKind == .notSure)
        #expect(missingCard.type == .notSure)
        #expect(missingCard.senderKind == .notSure)
        #expect(missingCard.noActionNeeded)
    }

    @Test func aStoredV1LabelMapsOntoTheClosedList() throws {
        let stored = """
        {"type":"council tax reminder","sender_kind":"council","action":"Pay.","deadline":null,"deadline_quote":null,"amount_quote":null,"watch_outs":[],"scam_signs":[],"no_action_needed":false}
        """
        let card = try JSONDecoder().decode(LetterCard.self, from: Data(stored.utf8))
        #expect(card.type == .reminder)
        #expect(card.senderKind == .council)
        #expect(card.displayTitle == "Council tax · Reminder")
        #expect(card.action == "Pay.")
    }
}
