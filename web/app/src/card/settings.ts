import { DEFAULT_CARD_MODEL, DEFAULT_CARD_PROMPT, DEFAULT_FALLBACK_MODEL } from "./defaults.js";
import { CARD_SCHEMA_VERSION } from "./schema.js";

export interface RemoteCardValues {
  prompt: string;
  schemaVersion: number;
  cardModel: string;
  fallbackModel: string;
}

export interface CardSettings {
  prompt: string;
  schemaVersion: typeof CARD_SCHEMA_VERSION;
  cardModel: string;
  fallbackModel: string;
  promptSource: "remote" | "bundled";
}

const V2_MARKERS = ["final_notice", "not_sure", "sender_kind", "deadline_quote"];

/**
 * Remote Config is used only when it already publishes schema 2 and a prompt
 * that names the closed lists. Until then the bundled v2 prompt is used, so a
 * published v1 prompt cannot define the card.
 */
export function resolveCardSettings(remote: RemoteCardValues): CardSettings {
  const remotePrompt = remote.prompt.trim();
  const remoteIsV2 =
    remote.schemaVersion === CARD_SCHEMA_VERSION &&
    remotePrompt.length > 0 &&
    V2_MARKERS.every((marker) => remotePrompt.includes(marker));
  return {
    prompt: remoteIsV2 ? remote.prompt : DEFAULT_CARD_PROMPT,
    schemaVersion: CARD_SCHEMA_VERSION,
    cardModel: remote.cardModel.trim() || DEFAULT_CARD_MODEL,
    fallbackModel: remote.fallbackModel.trim() || DEFAULT_FALLBACK_MODEL,
    promptSource: remoteIsV2 ? "remote" : "bundled",
  };
}
