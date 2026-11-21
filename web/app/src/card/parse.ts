import { exactListMember, LETTER_TYPES, nullish, SENDER_KINDS, type LetterCard, type ScamSign } from "./schema.js";

export interface ParseSuccess {
  ok: true;
  card: LetterCard;
}

export interface ParseFailure {
  ok: false;
  reason: string;
}

/** Strips one leading and one trailing markdown fence. Matches the Nano spike. */
export function stripOneFence(raw: string): { text: string; stripped: boolean } {
  let text = String(raw ?? "").trim();
  let stripped = false;
  if (text.startsWith("```json")) {
    text = text.slice(7);
    stripped = true;
  } else if (text.startsWith("```")) {
    text = text.slice(3);
    stripped = true;
  }
  const trimmedEnd = text.trimEnd();
  if (trimmedEnd.endsWith("```")) {
    text = trimmedEnd.slice(0, -3);
    stripped = true;
  }
  return { text: text.trim(), stripped };
}

/**
 * Parses one model reply into a schema v2 card.
 * Fence stripping and a JSON-object scan are local recovery, not the model retry.
 * `type` and `sender_kind` must be exact list members.
 */
export function parseModelCard(raw: string): ParseSuccess | ParseFailure {
  const unfenced = stripOneFence(raw);
  const parsed = parseJsonObject(unfenced.text) ?? parseJsonObject(extractJsonObject(unfenced.text) ?? "");
  if (!parsed) return { ok: false, reason: "The answer was not a JSON object." };
  return cardFromRecord(parsed);
}

function parseJsonObject(text: string): Record<string, unknown> | null {
  if (!text.trim()) return null;
  try {
    const value: unknown = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    return value as Record<string, unknown>;
  } catch {
    return null;
  }
}

/** First balanced `{...}` object, ignoring braces inside strings. */
export function extractJsonObject(text: string): string | null {
  const start = text.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inString = false;
  let escaping = false;
  for (let index = start; index < text.length; index += 1) {
    const character = text[index];
    if (inString) {
      if (escaping) escaping = false;
      else if (character === "\\") escaping = true;
      else if (character === '"') inString = false;
      continue;
    }
    if (character === '"') inString = true;
    else if (character === "{") depth += 1;
    else if (character === "}") {
      depth -= 1;
      if (depth === 0) return text.slice(start, index + 1);
    }
  }
  return null;
}

function cardFromRecord(record: Record<string, unknown>): ParseSuccess | ParseFailure {
  if ("card_schema_version" in record && record.card_schema_version !== 2) {
    return { ok: false, reason: "card_schema_version must be 2." };
  }
  if (!exactListMember(record.type, LETTER_TYPES)) {
    return { ok: false, reason: "type is not one of the allowed values." };
  }
  if (!exactListMember(record.sender_kind, SENDER_KINDS)) {
    return { ok: false, reason: "sender_kind is not one of the allowed values." };
  }
  if (typeof record.action !== "string") return { ok: false, reason: "action is missing." };
  if (!("deadline" in record) || !nullableString(record.deadline)) {
    return { ok: false, reason: "deadline is missing." };
  }
  if (!("deadline_quote" in record) || !nullableString(record.deadline_quote)) {
    return { ok: false, reason: "deadline_quote is missing." };
  }
  if (!("amount_quote" in record) || !nullableString(record.amount_quote)) {
    return { ok: false, reason: "amount_quote is missing." };
  }
  if (!Array.isArray(record.watch_outs) || record.watch_outs.some((item) => typeof item !== "string")) {
    return { ok: false, reason: "watch_outs must be a list of sentences." };
  }
  const signs = scamSigns(record.scam_signs);
  if (!signs) return { ok: false, reason: "scam_signs must be a list of sign and quote." };
  if (typeof record.no_action_needed !== "boolean") {
    return { ok: false, reason: "no_action_needed must be true or false." };
  }

  const card: LetterCard = {
    cardSchemaVersion: 2,
    type: record.type,
    senderKind: record.sender_kind,
    action: record.action,
    deadline: nullish(record.deadline),
    deadlineQuote: nullish(record.deadline_quote),
    amountQuote: nullish(record.amount_quote),
    watchOuts: record.watch_outs,
    scamSigns: signs,
    noActionNeeded: record.no_action_needed,
  };
  return { ok: true, card };
}

function nullableString(value: unknown): boolean {
  return value === null || typeof value === "string";
}

function scamSigns(value: unknown): ScamSign[] | null {
  if (!Array.isArray(value)) return null;
  const signs: ScamSign[] = [];
  for (const item of value) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const record = item as Record<string, unknown>;
    if (typeof record.sign !== "string") return null;
    if (!("quote" in record) || !nullableString(record.quote)) return null;
    signs.push({ sign: record.sign, quote: nullish(record.quote) });
  }
  return signs;
}
