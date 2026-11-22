import { escapeRegExp } from "../text.js";

export type RedactionKind =
  | "NAME"
  | "ADDRESS"
  | "POSTCODE"
  | "PHONE"
  | "EMAIL"
  | "NI"
  | "NHS"
  | "SORTCODE"
  | "ACCOUNT"
  | "REF";

export interface RedactionEntry {
  token: string;
  original: string;
  kind: RedactionKind;
}

export interface RedactionMap {
  entries: RedactionEntry[];
}

export interface RedactionResult {
  text: string;
  map: RedactionMap;
  removedCount: number;
}

interface Span {
  start: number;
  end: number;
  kind: RedactionKind;
  priority: number;
}

const GENERIC_NAMES = new Set([
  "sir",
  "madam",
  "sir or madam",
  "customer",
  "colleague",
  "resident",
  "occupier",
  "householder",
  "sir/madam",
  "all",
]);

const KIND_LABELS: Record<RedactionKind, [string, string]> = {
  NAME: ["name", "names"],
  ADDRESS: ["address", "addresses"],
  POSTCODE: ["postcode", "postcodes"],
  PHONE: ["phone number", "phone numbers"],
  EMAIL: ["email address", "email addresses"],
  NI: ["National Insurance number", "National Insurance numbers"],
  NHS: ["NHS number", "NHS numbers"],
  SORTCODE: ["sort code", "sort codes"],
  ACCOUNT: ["account number", "account numbers"],
  REF: ["reference", "references"],
};

/** Dates and amounts are left in the text. They are needed for the card. */
export function redact(text: string): RedactionResult {
  return apply(resolve(candidates(text), text), text);
}

export function reinsert(map: RedactionMap, text: string): string {
  const ordered = [...map.entries].sort((left, right) => right.token.length - left.token.length);
  let result = text;
  for (const entry of ordered) {
    result = result.replace(new RegExp(escapeRegExp(entry.token), "gi"), () => entry.original);
  }
  return result;
}

/**
 * A redaction token is `[LABEL_N]`. A fragment counts as well: an uppercase
 * label with a lone `[` or `]`, including a mismatched closer such as
 * `S[AMOUNT)`, `[AMOUNT`, and `AMOUNT_1]`.
 *
 * A token is one unbroken word, so a bracketed phrase with a space in it is
 * text the letter itself contains. `[ACCOUNT` used to match inside
 * `reference [ACCOUNT REF]`, and `REF]` inside the same phrase, which threw
 * away a deadline the model had read correctly: the card then said
 * "No deadline found" while its own action quoted the date.
 */
const LEFTOVER_PLACEHOLDER =
  /\[[A-Za-z]{2,}_\d+\]?|\[[A-Za-z]{2,}(?![A-Za-z0-9 ])|[A-Za-z]{2,}_\d+\]|(?<![A-Za-z ])[A-Z]{2,}\]/;

export function hasLeftoverPlaceholder(text: string): boolean {
  return LEFTOVER_PLACEHOLDER.test(text);
}

export function describeRemovals(result: RedactionResult): string {
  if (result.removedCount === 0) {
    return "No names, addresses, numbers, or email addresses were found.";
  }
  const counts = new Map<RedactionKind, number>();
  for (const entry of result.map.entries) {
    counts.set(entry.kind, (counts.get(entry.kind) ?? 0) + 1);
  }
  const parts = [...counts].map(([kind, count]) => {
    const [one, many] = KIND_LABELS[kind];
    return `${count} ${count === 1 ? one : many}`;
  });
  return `Removed ${parts.join(", ")}.`;
}

function candidates(text: string): Span[] {
  const spans: Span[] = [];
  const add = (
    pattern: RegExp,
    kind: RedactionKind,
    priority: number,
    group = 0,
    accept?: (snippet: string) => boolean,
  ) => {
    for (const match of text.matchAll(pattern)) {
      const range = rangeOf(match, group);
      if (!range) continue;
      const snippet = text.slice(range[0], range[1]);
      if (accept && !accept(snippet)) continue;
      spans.push({ start: range[0], end: range[1], kind, priority });
    }
  };

  add(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/gi, "EMAIL", 100);
  add(/\b([A-Z]{2})\s*(\d{2})\s*(\d{2})\s*(\d{2})\s*([A-D])\b/gi, "NI", 90);
  add(/\bnhs(?:\s+(?:number|no\.?))?\s*[:#-]?\s*(\d{3}[\s-]?\d{3}[\s-]?\d{4})\b/gi, "NHS", 88, 1);
  add(/\b(\d{3}[\s-]\d{3}[\s-]\d{4})\b/g, "NHS", 72, 1, (snippet) => !snippet.startsWith("0"));
  add(/\b([A-Z]{1,2}\d[A-Z\d]?)\s*(\d[A-Z]{2})\b/gi, "POSTCODE", 85);
  add(/\bsort\s*code\b[:\s]*(\d{2}[-\s]?\d{2}[-\s]?\d{2})\b/gi, "SORTCODE", 81, 1);
  add(/\b\d{2}-\d{2}-\d{2}\b/g, "SORTCODE", 80);
  add(/\b(?:\d{4}[ -]){3}\d{4}\b/g, "ACCOUNT", 76);
  add(/\b\d{13,19}\b/g, "ACCOUNT", 75);
  add(/\b(?:account(?:\s+number)?|a\/c)\b[:\s#]*(\d{6,10})\b/gi, "ACCOUNT", 70, 1);
  add(/(?<!\d)(?:\+44[\s-]?\d(?:[\s-]?\d){8,10}|0\d(?:[\s-]?\d){8,10})(?!\d)/g, "PHONE", 65);
  add(
    /\b(?:our\s+reference|reference|ref\.?|customer\s+reference|account\s+ref(?:erence)?)\b[:\s]*([A-Z0-9][A-Z0-9\-/]{4,})/gi,
    "REF",
    55,
    1,
  );
  add(/\b(?=[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{8,}\b/gi, "REF", 50);
  add(
    /\b(?:dear|hello|hi)\s+([^,\n]{1,80}?)(?=\s*[,.\n])/gi,
    "NAME",
    46,
    1,
    (snippet) => {
      const name = snippet.trim();
      return name.length >= 2 && !GENERIC_NAMES.has(name.toLowerCase());
    },
  );
  // Initials count: "Mr A Patel" at the head of a letter is still a name.
  add(
    /\b(?:Mr|Mrs|Ms|Miss|Mx|Dr|Prof|Sir|Dame|Lady|Rev)\.?[ \t]+[A-Z][A-Za-z'\u2019-]*\.?(?:[ \t]+[A-Z][A-Za-z'\u2019-]*\.?){0,2}/g,
    "NAME",
    44,
  );
  // A flat or unit line in the address block, on a line of its own.
  add(
    /^[ \t]*((?:flat|apartment|apt|unit|room)[ \t]+\d{1,4}[a-z]?)[ \t]*,?[ \t]*$/gim,
    "ADDRESS",
    43,
    1,
  );
  add(
    /(?:^|\n)\s*(?:address|property)\s*:\s*([^\n]{5,160})/gi,
    "ADDRESS",
    48,
    1,
  );
  add(
    /\b\d{1,5}[a-z]?\s+(?:[a-z0-9][a-z0-9'.-]{0,30}\s+){0,5}(?:street|st|road|rd|avenue|ave|lane|ln|close|drive|court|gardens|way|place|terrace|crescent|square|grove)\b/gi,
    "ADDRESS",
    42,
  );
  add(/\bP\.?\s*O\.?\s*Box\s+\d{1,6}\b/gi, "ADDRESS", 42);
  add(
    /\[(NAME|OFFICER NAME|ADDRESS LINE \d+|POSTCODE|PHONE|NI NUMBER|NHS NUMBER|ACCOUNT NUMBER|ACCOUNT REF|SORT CODE|EMAIL|REF|BANK ADDRESS|COUNCIL ADDRESS|HMRC OFFICE ADDRESS|PO BOX)\]/gi,
    "REF",
    35,
  );

  return spans.map((span) => {
    const snippet = text.slice(span.start, span.end);
    if (!snippet.startsWith("[")) return span;
    return { ...span, kind: kindForPlaceholder(snippet), priority: span.priority };
  });
}

function kindForPlaceholder(placeholder: string): RedactionKind {
  const word = placeholder.replaceAll("[", "").replaceAll("]", "").toLowerCase();
  if (word.includes("name")) return "NAME";
  if (word.includes("postcode")) return "POSTCODE";
  if (word.includes("phone")) return "PHONE";
  if (word.includes("email")) return "EMAIL";
  if (word.includes("sort")) return "SORTCODE";
  if (word.includes("nhs")) return "NHS";
  if (word.includes("ni")) return "NI";
  if (word.includes("account")) return "ACCOUNT";
  if (word.includes("address") || word.includes("po box")) return "ADDRESS";
  return "REF";
}

function resolve(spans: Span[], text: string): Span[] {
  const tidied = spans.map((span) => {
    if (span.kind !== "EMAIL" && span.kind !== "PHONE") return span;
    return { ...span, end: trimPunctuationEnd(text, span.start, span.end) };
  });
  const sorted = [...tidied].sort((left, right) => {
    if (left.priority !== right.priority) return right.priority - left.priority;
    const leftLength = left.end - left.start;
    const rightLength = right.end - right.start;
    if (leftLength !== rightLength) return rightLength - leftLength;
    return left.start - right.start;
  });

  const accepted: Span[] = [];
  for (const candidate of sorted) {
    let pieces = [{ start: candidate.start, end: candidate.end }];
    for (const existing of accepted) {
      const next: Array<{ start: number; end: number }> = [];
      for (const piece of pieces) next.push(...subtract(existing, piece));
      pieces = next;
    }
    for (const piece of pieces) {
      const trimmed = trimRange(text, piece.start, piece.end);
      if (!trimmed) continue;
      const snippet = text.slice(trimmed.start, trimmed.end).trim();
      const minimum = candidate.kind === "NAME" ? 2 : 3;
      if (snippet.length < minimum) continue;
      accepted.push({ ...candidate, start: trimmed.start, end: trimmed.end });
    }
  }
  return accepted.sort((left, right) => left.start - right.start);
}

function trimPunctuationEnd(text: string, start: number, end: number): number {
  let cursor = end;
  while (cursor > start && ",.;:)]".includes(text[cursor - 1] ?? "")) cursor -= 1;
  return cursor;
}

function trimRange(text: string, start: number, end: number): { start: number; end: number } | null {
  let left = start;
  let right = end;
  while (left < right && /\s/u.test(text[left] ?? "")) left += 1;
  while (right > left && /\s/u.test(text[right - 1] ?? "")) right -= 1;
  if (left >= right) return null;
  return { start: left, end: right };
}

function subtract(
  taken: { start: number; end: number },
  source: { start: number; end: number },
): Array<{ start: number; end: number }> {
  if (source.end <= taken.start || taken.end <= source.start) return [source];
  const pieces: Array<{ start: number; end: number }> = [];
  if (source.start < taken.start) pieces.push({ start: source.start, end: taken.start });
  if (taken.end < source.end) pieces.push({ start: taken.end, end: source.end });
  return pieces;
}

function apply(spans: Span[], text: string): RedactionResult {
  const counts = new Map<RedactionKind, number>();
  const entries: RedactionEntry[] = [];
  let result = "";
  let cursor = 0;
  for (const span of spans) {
    if (span.start < cursor || span.end <= span.start) continue;
    result += text.slice(cursor, span.start);
    const original = text.slice(span.start, span.end);
    const number = (counts.get(span.kind) ?? 0) + 1;
    counts.set(span.kind, number);
    const token = `[${span.kind}_${number}]`;
    entries.push({ token, original, kind: span.kind });
    result += token;
    cursor = span.end;
  }
  result += text.slice(cursor);
  return { text: result, map: { entries }, removedCount: entries.length };
}

function rangeOf(match: RegExpMatchArray, group: number): [number, number] | null {
  const indices = (match as RegExpMatchArray & { indices?: Array<[number, number] | undefined> }).indices;
  const indexed = indices?.[group];
  if (indexed && indexed[0] >= 0) return [indexed[0], indexed[1]];
  if (match.index === undefined) return null;
  if (group === 0) return [match.index, match.index + match[0].length];
  const groupText = match[group];
  if (groupText === undefined) return null;
  const local = match[0].indexOf(groupText);
  if (local < 0) return null;
  return [match.index + local, match.index + local + groupText.length];
}
