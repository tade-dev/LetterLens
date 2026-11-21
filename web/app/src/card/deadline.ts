import { escapeRegExp } from "../text.js";

/** Phrases that name when a change takes effect, not when the reader must act. */
const EFFECT_PHRASES = ["take effect", "takes effect", "taking effect", "effective from", "effective on"];

/**
 * Cues that the same quote also asks the reader to do something.
 * Matched on word boundaries so "by" matches "Pay by 3 March" and not "nearby".
 */
const ACTION_CUES = [
  "no later than",
  "let us know",
  "tell us",
  "opt out",
  "pay",
  "reply",
  "respond",
  "contact",
  "call",
  "cancel",
  "switch",
  "apply",
  "appeal",
  "send",
  "return",
  "before",
  "by",
];

/** True when the quote is an effective date and does not also ask the reader to act. */
export function isEffectiveDateWithoutAction(quote: string): boolean {
  const lowered = quote.toLowerCase();
  if (!EFFECT_PHRASES.some((phrase) => lowered.includes(phrase))) return false;
  return !containsActionCue(quote);
}

/** True when `quote` contains an action cue as a whole word or phrase. */
export function containsActionCue(quote: string): boolean {
  return ACTION_CUES.some((cue) => matchesTerm(cue, quote));
}

function matchesTerm(term: string, text: string): boolean {
  return new RegExp(`\\b${escapeRegExp(term)}\\b`, "i").test(text);
}
