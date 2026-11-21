import assert from "node:assert/strict";
import { test } from "node:test";
import { parseModelCard, stripOneFence } from "../src/card/parse.js";
import type { LetterCard } from "../src/card/schema.js";
import { validateCard } from "../src/card/validator.js";

const LETTER = "Pay by 3 March 2027. The balance is £42.50. A further notice may follow.";

function raw(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    card_schema_version: 2,
    type: "reminder",
    sender_kind: "council",
    action: "Pay the outstanding balance.",
    deadline: "2027-03-03",
    deadline_quote: "Pay by 3 March 2027",
    amount_quote: "£42.50",
    watch_outs: ["A further notice may follow."],
    scam_signs: [{ sign: "Asks for a fee to release money", quote: null }],
    no_action_needed: false,
    ...overrides,
  });
}

test("one markdown fence is stripped before parsing", () => {
  const fenced = "```json\n" + raw() + "\n```";
  const stripped = stripOneFence(fenced);
  assert.equal(stripped.stripped, true);
  const parsed = parseModelCard(fenced);
  assert.equal(parsed.ok, true);
  if (!parsed.ok) return;
  assert.equal(parsed.card.type, "reminder");
  assert.equal(parsed.card.senderKind, "council");
  assert.equal(parsed.card.cardSchemaVersion, 2);
});

test("a preamble is ignored and the JSON object is read", () => {
  const parsed = parseModelCard("Here is the card:\n" + raw());
  assert.equal(parsed.ok, true);
});

test("type and sender_kind must match the lists exactly", () => {
  const type = parseModelCard(raw({ type: "council tax reminder" }));
  assert.equal(type.ok, false);
  if (!type.ok) assert.match(type.reason, /type/);

  const sender = parseModelCard(raw({ sender_kind: "HMRC" }));
  assert.equal(sender.ok, false);
  if (!sender.ok) assert.match(sender.reason, /sender_kind/);

  const version = parseModelCard(raw({ card_schema_version: 1 }));
  assert.equal(version.ok, false);
});

test("a missing card_schema_version is still schema 2 when the lists match", () => {
  const body = JSON.parse(raw()) as Record<string, unknown>;
  delete body.card_schema_version;
  const parsed = parseModelCard(JSON.stringify(body));
  assert.equal(parsed.ok, true);
  if (parsed.ok) assert.equal(parsed.card.cardSchemaVersion, 2);
});

test("safety claims are rewritten and a missing amount quote is dropped", () => {
  const parsed = parseModelCard(
    raw({
      action: "This letter is safe. Pay the balance.",
      amount_quote: "£99.00",
      scam_signs: [
        { sign: "This is genuine.", quote: null },
        { sign: "Payment link", quote: "not in the letter" },
      ],
    }),
  );
  assert.equal(parsed.ok, true);
  if (!parsed.ok) return;
  const validated = validateCard(parsed.card, LETTER);
  assert.equal(validated.action.includes("safe"), false);
  assert.match(validated.action, /signs to check/);
  assert.match(validated.action, /Pay the balance/);
  assert.equal(validated.amountQuote, null);
  assert.equal(validated.scamSigns.length, 1);
  assert.equal(validated.scamSigns[0]?.sign.includes("genuine"), false);
  assert.match(validated.scamSigns[0]?.sign ?? "", /signs to check/);
});

test("an invalid second field still fails closed", () => {
  const parsed = parseModelCard(raw({ no_action_needed: "false" }));
  assert.equal(parsed.ok, false);
});

function sampleCard(): LetterCard {
  const parsed = parseModelCard(raw());
  if (!parsed.ok) throw new Error(parsed.reason);
  return parsed.card;
}

test("a verbatim amount quote is kept", () => {
  const validated = validateCard(sampleCard(), LETTER);
  assert.equal(validated.amountQuote, "£42.50");
  assert.equal(validated.deadline, "2027-03-03");
});
