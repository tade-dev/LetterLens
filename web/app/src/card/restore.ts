import type { LetterCard } from "./schema.js";
import type { RedactionMap } from "../privacy/redactor.js";
import { reinsert } from "../privacy/redactor.js";

/** Puts redacted originals back into card strings before the quote check. */
export function restoreCard(card: LetterCard, map: RedactionMap): LetterCard {
  const put = (value: string) => reinsert(map, value);
  return {
    ...card,
    action: put(card.action),
    deadline: card.deadline ? put(card.deadline) : null,
    deadlineQuote: card.deadlineQuote ? put(card.deadlineQuote) : null,
    amountQuote: card.amountQuote ? put(card.amountQuote) : null,
    watchOuts: card.watchOuts.map(put),
    scamSigns: card.scamSigns.map((sign) => ({
      sign: put(sign.sign),
      quote: sign.quote ? put(sign.quote) : null,
    })),
  };
}
