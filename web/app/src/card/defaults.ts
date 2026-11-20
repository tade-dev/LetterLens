import { CARD_SCHEMA_VERSION, LETTER_TYPES, SENDER_KINDS } from "./schema.js";

/** Cloud model names bundled with the iOS v2 defaults. */
export const DEFAULT_CARD_MODEL = "gemini-3.8-flash";
export const DEFAULT_FALLBACK_MODEL = "gemini-3.5-flash-lite";

/**
 * In-app card prompt, schema version 2.
 * The deadline rule matches the iOS prompt. `card_schema_version` is included
 * because on-device Chrome ignores responseSchema, so the list has to be in the text.
 * `{ocr_text}` is replaced with the letter before the call.
 */
export const DEFAULT_CARD_PROMPT = `You read UK official letters and explain them in plain English.
Use ONLY the letter text below. If something is not written in the letter, leave it null.

Reply with JSON only, matching card_schema_version ${CARD_SCHEMA_VERSION} exactly:
{
  "card_schema_version": ${CARD_SCHEMA_VERSION},
  "type": "${LETTER_TYPES.join(" | ")}",
  "sender_kind": "${SENDER_KINDS.join(" | ")}",
  "action": "what they want the reader to do, 1-2 short sentences, second person",
  "deadline": "YYYY-MM-DD or null",
  "deadline_quote": "the exact words from the letter that state the deadline, or null",
  "amount_quote": "exact words stating an amount owed or due, or null",
  "watch_outs": ["consequence or important condition, short sentence", "..."],
  "scam_signs": [{"sign": "short description", "quote": "exact words or null"}],
  "no_action_needed": true or false
}

Rules:
- card_schema_version must be ${CARD_SCHEMA_VERSION}.
- type must be exactly one of the values listed above. sender_kind must be exactly one of the values listed above. If you are not sure, use not_sure.
- A deadline is only a date by which the reader must do something: pay, reply, send, book, apply, appeal, or attend. A date when a change takes effect, starts, or ends is not a deadline. If there is no action date, deadline and deadline_quote must be null. Do not guess.
- Quotes must be copied word for word from the letter.
- Never say a letter is safe or genuine.
- Scam signs include: asking for a fee to release money, payment links not on the official domain, extreme urgency, requests for passwords or card details, mismatched sender details.

LETTER:
<<<
{ocr_text}
>>>`;

export const JSON_RETRY_SUFFIX = `

Your previous reply was not valid JSON. Return only one JSON object matching the schema. No markdown and no commentary.`;

export function fillPrompt(template: string, letter: string): string {
  if (template.includes("{ocr_text}")) {
    return template.replaceAll("{ocr_text}", letter);
  }
  return `${template}\n\nLETTER:\n<<<\n${letter}\n>>>`;
}
