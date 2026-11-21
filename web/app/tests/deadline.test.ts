import assert from "node:assert/strict";
import { test } from "node:test";
import { containsActionCue, isEffectiveDateWithoutAction } from "../src/card/deadline.js";
import { firstDate } from "../src/card/dates.js";
import { validateCard } from "../src/card/validator.js";
import type { LetterCard } from "../src/card/schema.js";

function card(deadlineQuote: string, deadline = "2027-01-01"): LetterCard {
  return {
    cardSchemaVersion: 2,
    type: "change_notice",
    senderKind: "utility",
    action: "Read the notice.",
    deadline,
    deadlineQuote,
    amountQuote: null,
    watchOuts: [],
    scamSigns: [],
    noActionNeeded: false,
  };
}

test("an effective date is not a deadline", () => {
  const quotes = [
    "These changes take effect from 1 January 2027.",
    "The new rate takes effect from 1 January 2027.",
    "The new rate is taking effect from 1 January 2027.",
    "The new rate is effective from 1 January 2027.",
    "The new rate is effective on 1 January 2027.",
  ];
  for (const quote of quotes) {
    assert.equal(isEffectiveDateWithoutAction(quote), true);
    const validated = validateCard(card(quote), quote);
    assert.equal(validated.deadline, null);
    assert.equal(validated.deadlineQuote, null);
  }
});

test("a reply before the effective date is kept", () => {
  const quote = "Please reply before the changes take effect on 1 January 2027";
  const validated = validateCard(card(quote), quote);
  assert.equal(validated.deadline, "2027-01-01");
  assert.equal(validated.deadlineQuote, quote);
  assert.equal(isEffectiveDateWithoutAction(quote), false);
});

test("a pay-by date is kept", () => {
  const quote = "Pay by 3 March 2027";
  const validated = validateCard(card(quote, "2027-03-03"), quote);
  assert.equal(validated.deadline, "2027-03-03");
  assert.equal(validated.deadlineQuote, quote);
  assert.equal(containsActionCue(quote), true);
});

test("nearby and byte do not count as the word by", () => {
  assert.equal(containsActionCue("our nearby branch"), false);
  assert.equal(containsActionCue("byte"), false);
  assert.equal(containsActionCue("bystander"), false);
  const quote = "These changes take effect from 1 January 2027 at our nearby branch";
  assert.equal(isEffectiveDateWithoutAction(quote), true);
  const validated = validateCard(card(quote), quote);
  assert.equal(validated.deadline, null);
  assert.equal(validated.deadlineQuote, null);
});

test("effective-date matching is case insensitive", () => {
  const quote = "THESE CHANGES TAKE EFFECT FROM 1 JANUARY 2027.";
  assert.equal(isEffectiveDateWithoutAction(quote), true);
  assert.equal(isEffectiveDateWithoutAction("EFFECTIVE ON 1 January 2027"), true);
  const validated = validateCard(card(quote), quote);
  assert.equal(validated.deadline, null);
  assert.equal(validated.deadlineQuote, null);
});

test("a deadline quote that is not verbatim is dropped", () => {
  const validated = validateCard(card("Pay by 3 March 2027", "2027-03-03"), "Pay by 4 March 2027.");
  assert.equal(validated.deadline, null);
  assert.equal(validated.deadlineQuote, null);
});

test("a relative phrase is not a deadline", () => {
  const quote = "Pay within 14 days";
  const validated = validateCard(card(quote, "2027-03-03"), quote);
  assert.equal(validated.deadline, null);
  assert.equal(validated.deadlineQuote, null);
});

test("a quote matches after whitespace is collapsed and keeps the letter's words", () => {
  const letter = "Pay by\n3 March 2027.";
  const validated = validateCard(card("pay by 3 march 2027", "2026-01-01"), letter);
  assert.equal(validated.deadline, "2027-03-03");
  assert.equal(validated.deadlineQuote, "Pay by\n3 March 2027");
});

test("UK numeric dates are day then month", () => {
  assert.equal(firstDate("Due on 03/04/2026."), "2026-04-03");
  assert.equal(firstDate("Due on 31 April 2026."), null);
});
