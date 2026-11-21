import assert from "node:assert/strict";
import { test } from "node:test";
import { extractAmountFigure, showsAmount } from "../src/card/amount.js";
import { LETTER_TYPES, type LetterType } from "../src/card/schema.js";

test("one currency figure is returned as an exact substring", () => {
  assert.equal(extractAmountFigure("Please pay £42.50 by Friday."), "£42.50");
  assert.equal(extractAmountFigure("The total is £1,234.56."), "£1,234.56");
  assert.equal(extractAmountFigure("Send GBP 40 today."), "GBP 40");
  assert.equal(extractAmountFigure("The fee is £40."), "£40");
});

test("no figure, or more than one, returns null", () => {
  assert.equal(extractAmountFigure("Please pay the balance when you can."), null);
  assert.equal(extractAmountFigure("Pay £10 now or £20 later."), null);
  assert.equal(extractAmountFigure("Send GBP 40 or £40."), null);
});

test("the amount row is only for bills, reminders, final notices, and penalties", () => {
  const shown = new Set<LetterType>(["bill", "reminder", "final_notice", "penalty"]);
  for (const type of LETTER_TYPES) {
    assert.equal(showsAmount(type), shown.has(type), type);
  }
  assert.equal(showsAmount("refund"), false);
  assert.equal(showsAmount("change_notice"), false);
});
