import type { LetterType } from "./schema.js";

/**
 * The exact currency figure written in `quote`, or null.
 * One figure only. Nothing is reformatted, parsed, or added up.
 * £ and GBP are both accepted, including commas and pence.
 */
export function extractAmountFigure(quote: string): string | null {
  const pattern =
    /(?<![A-Za-z])(?:£\s*|GBP\s*)(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?!\d)(?!\.\d)(?!,)/gi;
  const figures = [...quote.matchAll(pattern)].map((match) => match[0]);
  return figures.length === 1 ? figures[0] : null;
}

/** Bill, reminder, final notice, and penalty show an amount. Every other type does not. */
export function showsAmount(type: LetterType): boolean {
  switch (type) {
    case "bill":
    case "reminder":
    case "final_notice":
    case "penalty":
      return true;
    case "change_notice":
    case "information_request":
    case "consent_request":
    case "refund":
    case "information":
    case "appointment":
    case "other":
    case "not_sure":
      return false;
  }
}
