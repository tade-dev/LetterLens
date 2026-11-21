/** Removes wording that calls a letter safe, genuine, or not a scam. */
const CLAIMS = [
  "this letter is safe",
  "the letter is safe",
  "letter is safe",
  "this is safe",
  "it is safe",
  "it's safe",
  "it is genuine",
  "this letter is genuine",
  "the letter is genuine",
  "letter is genuine",
  "this is genuine",
  "is legitimate",
  "not a scam",
  "isn't a scam",
  "is not a scam",
];

export const SAFETY_REPLACEMENT = "These are signs to check.";

export function cleaned(text: string): string {
  const sentences = splitSentences(text);
  const rewritten = sentences.map((sentence) => (claimsMatch(sentence) ? SAFETY_REPLACEMENT : sentence));
  return rewritten.join(" ").replaceAll("  ", " ").trim();
}

function claimsMatch(sentence: string): boolean {
  const lowered = sentence.toLowerCase();
  return CLAIMS.some((claim) => lowered.includes(claim));
}

function splitSentences(text: string): string[] {
  const parts = [...text.matchAll(/[^.!?]+[.!?]?/g)]
    .map((match) => match[0].trim())
    .filter((sentence) => sentence.length > 0);
  return parts.length > 0 ? parts : [text];
}
