import { JSON_RETRY_SUFFIX } from "../card/defaults.js";
import { parseModelCard } from "../card/parse.js";
import { restoreCard } from "../card/restore.js";
import type { LetterCard } from "../card/schema.js";
import { validateCard } from "../card/validator.js";
import type { RedactionMap } from "../privacy/redactor.js";

export interface Generation {
  text: string;
  inferenceSource?: string;
}

export interface CardGenerator {
  generate(prompt: string): Promise<Generation>;
}

export type AnswerPlace = "on_device" | "in_cloud";

export type CardRequestResult =
  | { ok: true; card: LetterCard; place: AnswerPlace; attempts: number }
  | { ok: false; code: "invalid" | "left-device" | "model-error"; message: string; retryable: boolean; attempts: number };

/**
 * Asks once, and retries once when the reply is not a valid card.
 * An on-device request that the SDK reports as in-cloud is discarded and not retried.
 */
export async function requestCard(input: {
  generator: CardGenerator;
  prompt: string;
  letter: string;
  expected: AnswerPlace;
  redactionMap?: RedactionMap;
}): Promise<CardRequestResult> {
  let attempts = 0;
  let invalidReason = "The answer was not a valid card.";
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const prompt = attempt === 0 ? input.prompt : `${input.prompt}${JSON_RETRY_SUFFIX}`;
    attempts += 1;
    let generated: Generation;
    try {
      generated = await input.generator.generate(prompt);
    } catch (error) {
      return {
        ok: false,
        code: "model-error",
        message: publicError(error),
        retryable: isRetryableCloudError(error),
        attempts,
      };
    }
    const reported = normaliseInferenceSource(generated.inferenceSource);
    if (input.expected === "on_device" && reported === "in_cloud") {
      return {
        ok: false,
        code: "left-device",
        message: "The on-device request was answered in the cloud. That answer was discarded.",
        retryable: false,
        attempts,
      };
    }
    const parsed = parseModelCard(generated.text);
    if (!parsed.ok) {
      invalidReason = parsed.reason;
      continue;
    }
    const restored = restoreCard(parsed.card, input.redactionMap ?? { entries: [] });
    if (!restored.ok) {
      invalidReason = restored.reason;
      continue;
    }
    const place: AnswerPlace = reported === "unreported" ? input.expected : reported;
    return { ok: true, card: validateCard(restored.card, input.letter), place, attempts };
  }
  return { ok: false, code: "invalid", message: invalidReason, retryable: false, attempts };
}

export function normaliseInferenceSource(value: string | undefined): AnswerPlace | "unreported" {
  if (value === "on_device" || value === "ON_DEVICE") return "on_device";
  if (value === "in_cloud" || value === "IN_CLOUD" || value === "cloud") return "in_cloud";
  return "unreported";
}

export function isRetryableCloudError(error: unknown): boolean {
  return /\b429\b|\b503\b|resource-exhausted|unavailable/i.test(errorText(error));
}

export function publicError(error: unknown): string {
  const code = errorCode(error);
  return code ? `The model call failed (${code}).` : "The model call failed before a card came back.";
}

function errorCode(error: unknown): string {
  if (!error || typeof error !== "object" || !("code" in error)) return "";
  const code = String((error as { code: unknown }).code);
  return /^[A-Za-z0-9_./:-]{1,48}$/.test(code) ? code : "";
}

function errorText(error: unknown): string {
  const code = errorCode(error);
  const message = error instanceof Error ? error.message : "";
  return `${code} ${message}`;
}
