import { isEffectiveDateWithoutAction } from "./deadline.js";
import { firstDate } from "./dates.js";
import { verbatimSpan } from "./quotes.js";
import type { LetterCard, ScamSign } from "./schema.js";
import { cleaned } from "./safety.js";

/**
 * Drops anything whose quote is not in the letter, replaces the model's deadline
 * with the date parsed from the quote, and clears effective dates that do not
 * also ask the reader to act.
 */
export function validateCard(card: LetterCard, letter: string): LetterCard {
  const next: LetterCard = {
    ...card,
    action: cleaned(card.action),
    watchOuts: card.watchOuts.map(cleaned).filter((item) => item.length > 0),
    scamSigns: [],
  };
  applyDeadline(next, letter);
  next.amountQuote = verbatimSpan(next.amountQuote, letter);
  next.scamSigns = card.scamSigns.flatMap((sign) => {
    const kept = keptSign(sign, letter);
    return kept ? [kept] : [];
  });
  return next;
}

function applyDeadline(card: LetterCard, letter: string): void {
  const exact = verbatimSpan(card.deadlineQuote, letter);
  if (!exact) {
    card.deadline = null;
    card.deadlineQuote = null;
    return;
  }
  const parsed = firstDate(exact);
  if (!parsed || isEffectiveDateWithoutAction(exact)) {
    card.deadline = null;
    card.deadlineQuote = null;
    return;
  }
  card.deadlineQuote = exact;
  card.deadline = parsed;
}

/** A sign with no quote is structural and is kept. A quote missing from the letter drops the sign. */
function keptSign(sign: ScamSign, letter: string): ScamSign | null {
  const label = cleaned(sign.sign).trim();
  if (!label) return null;
  if (!sign.quote) return { sign: label, quote: null };
  const exact = verbatimSpan(sign.quote, letter);
  if (!exact) return null;
  return { sign: label, quote: exact };
}
