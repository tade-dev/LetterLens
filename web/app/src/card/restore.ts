import type { LetterCard, ScamSign } from "./schema.js";
import { hasLeftoverPlaceholder, reinsert, type RedactionMap } from "../privacy/redactor.js";

export type RestoreResult =
  | { ok: true; card: LetterCard }
  | { ok: false; reason: string };

/**
 * Fills placeholders back in on this device. A quote that still contains a
 * token, or a broken piece of one, becomes null. A watch-out or scam sign
 * whose own text still has one is dropped. The action is not shown half-restored:
 * that answer is rejected.
 */
export function restoreCard(card: LetterCard, map: RedactionMap): RestoreResult {
  const action = reinsert(map, card.action);
  if (hasLeftoverPlaceholder(action)) {
    return { ok: false, reason: "The answer still contained a redaction placeholder." };
  }
  return {
    ok: true,
    card: {
      ...card,
      action,
      deadline: cleanQuote(card.deadline, map),
      deadlineQuote: cleanQuote(card.deadlineQuote, map),
      amountQuote: cleanQuote(card.amountQuote, map),
      watchOuts: card.watchOuts
        .map((item) => reinsert(map, item))
        .filter((item) => item.trim().length > 0 && !hasLeftoverPlaceholder(item)),
      scamSigns: card.scamSigns.flatMap((sign) => keptSign(sign, map)),
    },
  };
}

function cleanQuote(value: string | null, map: RedactionMap): string | null {
  if (!value) return null;
  const restored = reinsert(map, value);
  return hasLeftoverPlaceholder(restored) ? null : restored;
}

function keptSign(sign: ScamSign, map: RedactionMap): ScamSign[] {
  const label = reinsert(map, sign.sign);
  if (!label.trim() || hasLeftoverPlaceholder(label)) return [];
  return [{ sign: label, quote: cleanQuote(sign.quote, map) }];
}
