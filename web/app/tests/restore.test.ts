import assert from "node:assert/strict";
import { test } from "node:test";
import { restoreCard } from "../src/card/restore.js";
import type { LetterCard } from "../src/card/schema.js";
import { hasLeftoverPlaceholder, type RedactionMap } from "../src/privacy/redactor.js";

const map: RedactionMap = {
  entries: [
    { token: "[NAME_1]", original: "Pat Example", kind: "NAME" },
    { token: "[ACCOUNT_1]", original: "12345678", kind: "ACCOUNT" },
  ],
};

function card(overrides: Partial<LetterCard> = {}): LetterCard {
  return {
    cardSchemaVersion: 2,
    type: "bill",
    senderKind: "bank",
    action: "Pay the balance.",
    deadline: "2027-03-03",
    deadlineQuote: "Pay by 3 March 2027",
    amountQuote: "£42.50",
    watchOuts: ["A further notice may follow."],
    scamSigns: [{ sign: "Asks for a fee", quote: null }],
    noActionNeeded: false,
    ...overrides,
  };
}

test("full tokens and broken placeholders are detected", () => {
  for (const sample of ["[NAME_1]", "[name_1]", "S[AMOUNT)", "[AMOUNT", "AMOUNT_1]", "[ACCOUNT]", "REF]"]) {
    assert.equal(hasLeftoverPlaceholder(sample), true, sample);
  }
  assert.equal(hasLeftoverPlaceholder("Pay £42.50 by 1 December 2026."), false);
});

test("a known token is restored before the card is shown", () => {
  const result = restoreCard(
    card({
      action: "Ask [NAME_1] to pay.",
      amountQuote: "Account [ACCOUNT_1] owes £42.50",
    }),
    map,
  );
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.card.action, "Ask Pat Example to pay.");
  assert.equal(result.card.amountQuote, "Account 12345678 owes £42.50");
});

test("a quote with a leftover placeholder becomes null", () => {
  const result = restoreCard(
    card({
      deadline: "AMOUNT_1]",
      deadlineQuote: "[AMOUNT",
      amountQuote: "The balance is S[AMOUNT).",
    }),
    map,
  );
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.card.deadline, null);
  assert.equal(result.card.deadlineQuote, null);
  assert.equal(result.card.amountQuote, null);
  assert.equal(result.card.action, "Pay the balance.");
});

test("a watch-out or scam sign with a leftover is dropped, and a bad quote is cleared", () => {
  const result = restoreCard(
    card({
      watchOuts: ["A further notice may follow.", "See [REF_1] for the fee."],
      scamSigns: [
        { sign: "S[AMOUNT)", quote: "Pay the fee" },
        { sign: "Asks for a fee", quote: "Send it to AMOUNT_1]" },
      ],
    }),
    map,
  );
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(result.card.watchOuts, ["A further notice may follow."]);
  assert.equal(result.card.scamSigns.length, 1);
  assert.equal(result.card.scamSigns[0]?.sign, "Asks for a fee");
  assert.equal(result.card.scamSigns[0]?.quote, null);
});

test("an action that still has a placeholder rejects the card", () => {
  const result = restoreCard(card({ action: "Pay [NAME_2] at once." }), map);
  assert.equal(result.ok, false);
  if (!result.ok) assert.match(result.reason, /placeholder/);
});
