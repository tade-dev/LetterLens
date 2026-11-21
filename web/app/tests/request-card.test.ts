import assert from "node:assert/strict";
import { test } from "node:test";
import type { CardGenerator, Generation } from "../src/read/request-card.js";
import { requestCard } from "../src/read/request-card.js";

const LETTER = "Pay by 3 March 2027.";

function validReply(): Generation {
  return {
    text: JSON.stringify({
      card_schema_version: 2,
      type: "reminder",
      sender_kind: "council",
      action: "Pay the balance.",
      deadline: "2027-03-03",
      deadline_quote: "Pay by 3 March 2027",
      amount_quote: null,
      watch_outs: [],
      scam_signs: [],
      no_action_needed: false,
    }),
    inferenceSource: "on_device",
  };
}

function scripted(replies: Array<Generation | Error>): CardGenerator & { calls: number } {
  let calls = 0;
  return {
    get calls() {
      return calls;
    },
    async generate() {
      const reply = replies[calls];
      calls += 1;
      if (reply instanceof Error) throw reply;
      if (!reply) throw new Error("missing reply");
      return reply;
    },
  };
}

test("invalid output is retried once", async () => {
  const generator = scripted([{ text: "not json" }, validReply()]);
  const result = await requestCard({
    generator,
    prompt: "PROMPT",
    letter: LETTER,
    expected: "on_device",
  });
  assert.equal(generator.calls, 2);
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.place, "on_device");
    assert.equal(result.card.deadline, "2027-03-03");
    assert.equal(result.attempts, 2);
  }
});

test("a second invalid answer is a clear error", async () => {
  const generator = scripted([{ text: "nope" }, { text: "still nope" }]);
  const result = await requestCard({
    generator,
    prompt: "PROMPT",
    letter: LETTER,
    expected: "on_device",
  });
  assert.equal(generator.calls, 2);
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "invalid");
});

test("an action that still has a placeholder is retried once", async () => {
  const leftover = {
    text: JSON.stringify({
      card_schema_version: 2,
      type: "reminder",
      sender_kind: "council",
      action: "Pay S[AMOUNT) today.",
      deadline: null,
      deadline_quote: null,
      amount_quote: "£42.50",
      watch_outs: [],
      scam_signs: [],
      no_action_needed: false,
    }),
    inferenceSource: "in_cloud" as const,
  };
  const generator = scripted([leftover, validReply()]);
  const result = await requestCard({
    generator,
    prompt: "PROMPT",
    letter: LETTER,
    expected: "in_cloud",
    redactionMap: { entries: [] },
  });
  assert.equal(generator.calls, 2);
  assert.equal(result.ok, true);
  if (result.ok) assert.equal(result.card.action, "Pay the balance.");
});

test("a placeholder that survives the retry is an error", async () => {
  const leftover = {
    text: JSON.stringify({
      card_schema_version: 2,
      type: "reminder",
      sender_kind: "council",
      action: "Pay [NAME_1] today.",
      deadline: null,
      deadline_quote: null,
      amount_quote: null,
      watch_outs: [],
      scam_signs: [],
      no_action_needed: false,
    }),
    inferenceSource: "in_cloud" as const,
  };
  const generator = scripted([leftover, leftover]);
  const result = await requestCard({
    generator,
    prompt: "PROMPT",
    letter: LETTER,
    expected: "in_cloud",
  });
  assert.equal(generator.calls, 2);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.code, "invalid");
    assert.match(result.message, /placeholder/);
  }
});

test("an on-device call answered in the cloud is discarded without a retry", async () => {
  const generator = scripted([{ text: validReply().text, inferenceSource: "in_cloud" }, validReply()]);
  const result = await requestCard({
    generator,
    prompt: "PROMPT",
    letter: LETTER,
    expected: "on_device",
  });
  assert.equal(generator.calls, 1);
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.code, "left-device");
});
