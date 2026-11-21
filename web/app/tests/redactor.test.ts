import assert from "node:assert/strict";
import { test } from "node:test";
import { describeRemovals, redact, reinsert } from "../src/privacy/redactor.js";

test("a salutation name is tokenised and the date stays", () => {
  const result = redact("Dear Pat Example, pay by 1 December 2026.");
  assert.match(result.text, /\[NAME_1\]/);
  assert.match(result.text, /1 December 2026/);
  assert.equal(result.map.entries.find((entry) => entry.token === "[NAME_1]")?.original, "Pat Example");
  assert.match(result.text, /Dear/);
  assert.equal(result.text.includes("Pat Example"), false);
});

test("a generic salutation is left alone", () => {
  const result = redact("Dear Sir or Madam, there is nothing to pay.");
  assert.equal(result.text.includes("[NAME_"), false);
  assert.match(result.text, /Sir or Madam/);
});

test("postcode, sort code, account, email, phone, reference, NI and NHS numbers are removed", () => {
  const letter = [
    "Write to 12 Sample Street, AA9 9AA.",
    "Sort code 00-11-22. Account number 12345678.",
    "Email pat.example@example.com or call 020 7946 0958.",
    "Our reference: ZX98SAMPLE. NI QQ 12 34 56 C. NHS number 999 999 9999.",
    "Amount £42.50 is due on 5th Jan 2027.",
  ].join(" ");
  const result = redact(letter);
  const original = (token: string) => result.map.entries.find((entry) => entry.token === token)?.original;
  assert.equal(original("[POSTCODE_1]"), "AA9 9AA");
  assert.equal(original("[SORTCODE_1]"), "00-11-22");
  assert.equal(original("[ACCOUNT_1]"), "12345678");
  assert.equal(original("[EMAIL_1]"), "pat.example@example.com");
  assert.equal(original("[PHONE_1]"), "020 7946 0958");
  assert.equal(original("[REF_1]"), "ZX98SAMPLE");
  assert.equal(original("[NI_1]"), "QQ 12 34 56 C");
  assert.equal(original("[NHS_1]"), "999 999 9999");
  assert.match(result.text, /\[ADDRESS_1\]/);
  assert.equal(result.text.includes("12 Sample Street"), false);
  assert.equal(result.text.includes("AA9 9AA"), false);
  assert.equal(result.text.includes("pat.example@example.com"), false);
  assert.match(result.text, /£42\.50/);
  assert.match(result.text, /5th Jan 2027/);
  assert.match(describeRemovals(result), /Removed/);
});

test("two names get separate tokens in order", () => {
  const result = redact("Dear Pat Example,\nHello Sam Sample.");
  assert.equal(result.map.entries.find((entry) => entry.token === "[NAME_1]")?.original, "Pat Example");
  assert.equal(result.map.entries.find((entry) => entry.token === "[NAME_2]")?.original, "Sam Sample");
});

test("reinsertion restores the original and ignores token case", () => {
  const result = redact("Dear Pat Example, email pat.example@example.com.");
  const restored = reinsert(result.map, "Hello [name_1] at [EMAIL_1].");
  assert.equal(restored, "Hello Pat Example at pat.example@example.com.");
});

test("a titled name and a PO Box are removed", () => {
  const result = redact("Contact Dr Sam Sample at PO Box 123 about the bill.");
  assert.match(result.text, /\[NAME_1\]/);
  assert.match(result.text, /\[ADDRESS_1\]/);
  assert.equal(result.text.includes("Sam Sample"), false);
  assert.equal(result.text.includes("PO Box 123"), false);
});
