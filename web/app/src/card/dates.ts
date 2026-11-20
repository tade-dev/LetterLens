const MONTHS: Record<string, number> = {
  january: 1,
  jan: 1,
  february: 2,
  feb: 2,
  march: 3,
  mar: 3,
  april: 4,
  apr: 4,
  may: 5,
  june: 6,
  jun: 6,
  july: 7,
  jul: 7,
  august: 8,
  aug: 8,
  september: 9,
  sept: 9,
  sep: 9,
  october: 10,
  oct: 10,
  november: 11,
  nov: 11,
  december: 12,
  dec: 12,
};

/** Longer names first so "sept" does not win over "september". */
const MONTH_NAMES = [
  "january",
  "february",
  "march",
  "april",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december",
  "sept",
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
].join("|");

const TEXTUAL = new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(${MONTH_NAMES})\\s+(\\d{4})\\b`, "gi");
const NUMERIC = /\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b/g;

/**
 * The first valid calendar date in `text`, as `YYYY-MM-DD`.
 * UK order: day, then month, then year. "within 14 days" has no calendar date.
 */
export function firstDate(text: string): string | null {
  TEXTUAL.lastIndex = 0;
  NUMERIC.lastIndex = 0;
  const found: Array<{ location: number; iso: string }> = [];
  for (const match of text.matchAll(TEXTUAL)) {
    const day = numberAt(match, 1);
    const month = MONTHS[(match[2] ?? "").toLowerCase()];
    const year = numberAt(match, 3);
    const iso = day !== null && month !== undefined && year !== null ? isoDate(day, month, year) : null;
    if (iso && match.index !== undefined) found.push({ location: match.index, iso });
  }
  for (const match of text.matchAll(NUMERIC)) {
    const day = numberAt(match, 1);
    const month = numberAt(match, 2);
    const year = numberAt(match, 3);
    const iso = day !== null && month !== null && year !== null ? isoDate(day, month, year) : null;
    if (iso && match.index !== undefined) found.push({ location: match.index, iso });
  }
  found.sort((left, right) => left.location - right.location);
  return found[0]?.iso ?? null;
}

function numberAt(match: RegExpMatchArray, group: number): number | null {
  const raw = match[group];
  if (!raw || !/^\d+$/.test(raw)) return null;
  return Number(raw);
}

/** Day / month / year. 03/04/2026 is 3 April 2026. */
function isoDate(day: number, month: number, year: number): string | null {
  if (year < 1900 || year > 2200 || month < 1 || month > 12) return null;
  if (day < 1 || day > daysInMonth(year, month)) return null;
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

export function formatIsoDate(iso: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match) return iso;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}
