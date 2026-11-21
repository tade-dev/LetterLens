import { nullish } from "./schema.js";
import { escapeRegExp, isWhitespace } from "../text.js";

interface IndexedText {
  text: string;
  indexes: number[];
}

/**
 * A quote is in the letter when the words match after whitespace is collapsed.
 * Comparison is case-insensitive. The returned string is copied from the letter,
 * so a lowercased model quote becomes the original letters.
 */
export function verbatimSpan(quote: string | null, letter: string): string | null {
  const cleaned = nullish(quote);
  if (!cleaned) return null;
  const needle = indexedNormalisation(cleaned);
  if (!needle.text) return null;
  const haystack = indexedNormalisation(letter);
  const found = indexOfCaseInsensitive(haystack.text, needle.text);
  if (!found) return null;
  const start = haystack.indexes[found.start];
  const end = haystack.indexes[found.end - 1];
  if (start === undefined || end === undefined) return null;
  return letter.slice(start, end + 1);
}

function indexOfCaseInsensitive(haystack: string, needle: string): { start: number; end: number } | null {
  const match = new RegExp(escapeRegExp(needle), "i").exec(haystack);
  if (!match) return null;
  return { start: match.index, end: match.index + match[0].length };
}

function indexedNormalisation(text: string): IndexedText {
  let normalised = "";
  const indexes: number[] = [];
  let pendingSpace: number | null = null;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index] ?? "";
    if (isWhitespace(character)) {
      if (normalised.length > 0 && pendingSpace === null) pendingSpace = index;
      continue;
    }
    if (pendingSpace !== null) {
      normalised += " ";
      indexes.push(pendingSpace);
      pendingSpace = null;
    }
    normalised += character;
    indexes.push(index);
  }
  return { text: normalised, indexes };
}
