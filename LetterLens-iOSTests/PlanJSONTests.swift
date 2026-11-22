//
//  PlanJSONTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@Suite("Next steps plan JSON")
struct PlanJSONTests {
    @Test func aFencedReplyIsDecodedAndMarkedCloud() throws {
        let text = """
        ```json
        {
          "steps": [
            {"title": "Pay what you can", "detail": "Call them before the date in the letter."}
          ],
          "what_to_say": "Hello, this is [NAME_1]. My reference is [REF_1].",
          "where_to_get_help": ["Citizens Advice", "StepChange Debt Charity"]
        }
        ```
        """
        let plan = PlanJSONDecode.plan(from: try PlanJSONDecode.decode(text))
        #expect(plan.steps.count == 1)
        #expect(plan.steps[0].title == "Pay what you can")
        #expect(plan.whereToGetHelp == ["Citizens Advice", "StepChange Debt Charity"])
        // Tokens survive: the screen re-inserts the originals on this iPhone.
        #expect(plan.script.contains("[NAME_1]"))
        #expect(plan.madeInCloud)
    }

    @Test func theFourStepCapFromThePromptIsEnforced() throws {
        let steps = (1...7).map { "{\"title\": \"Step \($0)\", \"detail\": \"d\"}" }.joined(separator: ",")
        let plan = PlanJSONDecode.plan(
            from: try PlanJSONDecode.decode("{\"steps\": [\(steps)], \"what_to_say\": \"hi\"}")
        )
        #expect(plan.steps.count == PlanPrompt.maxSteps)
        #expect(plan.steps.last?.title == "Step 4")
    }

    @Test func emptyStepsAndBlankHelpLinesAreDropped() throws {
        let text = """
        {"steps": [{"title": "", "detail": ""}, {"title": "Real", "detail": "x"}],
         "what_to_say": "  hi  ",
         "where_to_get_help": ["", "   ", "Citizens Advice"]}
        """
        let plan = PlanJSONDecode.plan(from: try PlanJSONDecode.decode(text))
        #expect(plan.steps.count == 1)
        #expect(plan.script == "hi")
        #expect(plan.whereToGetHelp == ["Citizens Advice"])
    }

    @Test func missingFieldsDoNotThrow() throws {
        let plan = PlanJSONDecode.plan(from: try PlanJSONDecode.decode("{}"))
        #expect(plan.steps.isEmpty)
        #expect(plan.script.isEmpty)
        #expect(plan.whereToGetHelp.isEmpty)
    }

    @Test func nonJSONIsRejected() {
        #expect(throws: (any Error).self) {
            _ = try PlanJSONDecode.decode("I cannot help with that.")
        }
    }

    @Test func thePromptTemplateIsFilledWithEveryPlaceholder() {
        let filled = PlanPrompt.filled(
            template: "A {redacted_text} B {card_json} C {user_note}",
            redactedText: "letter",
            cardJSON: "{\"type\":\"bill\"}",
            note: "I cannot pay"
        )
        #expect(filled == "A letter B {\"type\":\"bill\"} C I cannot pay")
        #expect(!filled.contains("{redacted_text}"))
    }

    /// The local sample is the offline stand-in. It must never claim the cloud.
    @Test func theLocalSampleNeverClaimsTheCloud() async {
        let card = try! CardJSON.decodeModelText("{\"type\": \"bill\", \"sender_kind\": \"council\", \"action\": \"Pay it\"}")
        let plan = await LocalSampleNextStepsPlanner()
            .plan(redactedText: "Dear [NAME_1]", card: card, note: "")
        #expect(plan.madeInCloud == false)
        #expect(plan.whereToGetHelp.isEmpty)
    }
}
