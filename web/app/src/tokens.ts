/** Chrome's on-device Prompt API refuses prompts above this many tokens. */
export const ON_DEVICE_TOKEN_LIMIT = 9216;

export type TokenCountMethod = "countTokens" | "estimate";

export interface TokenCount {
  tokens: number;
  method: TokenCountMethod;
}

/**
 * Over-estimates tokens so a letter near the limit is refused.
 * Three characters per token is stricter than the usual four for English.
 */
export function estimateTokens(text: string): number {
  if (text.length === 0) return 0;
  return Math.ceil(text.length / 3);
}

export function exceedsOnDeviceLimit(tokens: number): boolean {
  return tokens > ON_DEVICE_TOKEN_LIMIT;
}

/**
 * Uses an on-device counter when the caller has one. A throw, or a missing
 * counter, falls back to {@link estimateTokens}. The caller must not pass a
 * counter that would upload the text.
 */
export async function countPromptTokens(
  text: string,
  countTokens?: (text: string) => Promise<number>,
): Promise<TokenCount> {
  if (countTokens) {
    try {
      const tokens = await countTokens(text);
      if (Number.isFinite(tokens) && tokens >= 0) {
        return { tokens, method: "countTokens" };
      }
    } catch {
      // firebase-js-sdk 13.4.0 throws for ONLY_ON_DEVICE countTokens.
    }
  }
  return { tokens: estimateTokens(text), method: "estimate" };
}
