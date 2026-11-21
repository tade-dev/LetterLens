import assert from "node:assert/strict";
import { test } from "node:test";
import { DEFAULT_CARD_MODEL, DEFAULT_CARD_PROMPT, DEFAULT_FALLBACK_MODEL } from "../src/card/defaults.js";
import { resolveCardSettings } from "../src/card/settings.js";
import { estimateTokens, exceedsOnDeviceLimit, ON_DEVICE_TOKEN_LIMIT } from "../src/tokens.js";
import { countPromptTokens } from "../src/tokens.js";

const V1_PROMPT = 'Reply with JSON. "type": "short label, e.g. council tax reminder"';

test("a published schema 1 prompt is ignored in favour of the bundled v2 prompt", () => {
  const settings = resolveCardSettings({
    prompt: V1_PROMPT,
    schemaVersion: 1,
    cardModel: "",
    fallbackModel: "",
  });
  assert.equal(settings.promptSource, "bundled");
  assert.equal(settings.prompt, DEFAULT_CARD_PROMPT);
  assert.match(settings.prompt, /final_notice/);
  assert.match(settings.prompt, /takes effect/);
  assert.equal(settings.schemaVersion, 2);
  assert.equal(settings.cardModel, "gemini-3.5-flash-lite");
  assert.equal(settings.fallbackModel, "gemini-3.5-flash-lite");
  assert.equal(settings.cardModel, DEFAULT_CARD_MODEL);
  assert.equal(settings.fallbackModel, DEFAULT_FALLBACK_MODEL);
});

test("a schema 2 remote prompt is used", () => {
  const remote = `${DEFAULT_CARD_PROMPT}\nExtra remote line.`;
  const settings = resolveCardSettings({
    prompt: remote,
    schemaVersion: 2,
    cardModel: "gemini-example",
    fallbackModel: "gemini-example-lite",
  });
  assert.equal(settings.promptSource, "remote");
  assert.equal(settings.prompt, remote);
  assert.equal(settings.cardModel, "gemini-example");
  assert.equal(settings.fallbackModel, "gemini-example-lite");
});

test("the token estimate is stricter than four characters per token", () => {
  assert.equal(estimateTokens(""), 0);
  assert.equal(estimateTokens("abcd"), 2);
  assert.equal(exceedsOnDeviceLimit(ON_DEVICE_TOKEN_LIMIT), false);
  assert.equal(exceedsOnDeviceLimit(ON_DEVICE_TOKEN_LIMIT + 1), true);
});

test("a failed on-device counter falls back to the estimate", async () => {
  const counted = await countPromptTokens("abcdef", async () => {
    throw new Error("countTokens() is not supported for on-device models.");
  });
  assert.equal(counted.method, "estimate");
  assert.equal(counted.tokens, 2);
});
