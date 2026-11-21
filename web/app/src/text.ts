/** Escapes a string for use as a literal inside a regular expression. */
export function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function isWhitespace(character: string): boolean {
  return /\s/u.test(character);
}
