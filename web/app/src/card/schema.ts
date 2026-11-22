export const CARD_SCHEMA_VERSION = 2;

export const SENDER_KINDS = [
  "council",
  "hmrc",
  "bank",
  "benefits",
  "school",
  "utility",
  "landlord",
  "nhs",
  "other",
  "not_sure",
] as const;

export const LETTER_TYPES = [
  "bill",
  "reminder",
  "final_notice",
  "change_notice",
  "information_request",
  "consent_request",
  "refund",
  "information",
  "appointment",
  "penalty",
  "other",
  "not_sure",
] as const;

export type SenderKind = (typeof SENDER_KINDS)[number];
export type LetterType = (typeof LETTER_TYPES)[number];

export const SENDER_LABELS: Record<SenderKind, string> = {
  council: "Council tax",
  hmrc: "HMRC",
  bank: "Bank",
  benefits: "Benefits",
  school: "School",
  utility: "Utility",
  landlord: "Landlord",
  nhs: "NHS",
  other: "Other",
  not_sure: "Not sure",
};

export const TYPE_LABELS: Record<LetterType, string> = {
  bill: "Bill",
  reminder: "Reminder",
  final_notice: "Final notice",
  change_notice: "Change notice",
  information_request: "Information request",
  consent_request: "Consent request",
  refund: "Refund",
  information: "Information",
  appointment: "Appointment",
  penalty: "Penalty",
  other: "Other",
  not_sure: "Not sure",
};

export interface ScamSign {
  sign: string;
  quote: string | null;
}

/** Card schema version 2. Field names match the shared prompt. */
export interface LetterCard {
  cardSchemaVersion: 2;
  type: LetterType;
  senderKind: SenderKind;
  action: string;
  deadline: string | null;
  deadlineQuote: string | null;
  amountQuote: string | null;
  watchOuts: string[];
  scamSigns: ScamSign[];
  noActionNeeded: boolean;
}

export function displayTitle(card: LetterCard): string {
  return `${SENDER_LABELS[card.senderKind]} · ${TYPE_LABELS[card.type]}`;
}

export function senderLabel(card: LetterCard): string {
  return SENDER_LABELS[card.senderKind];
}

/** A quoted scam sign switches the card to the warning layout, as on iOS. */
export function opensScamWarning(card: LetterCard): boolean {
  return card.scamSigns.length > 0;
}

/** Blank, "null", and "none" are the same as JSON null. */
export function nullish(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  if (trimmed.toLowerCase() === "null" || trimmed.toLowerCase() === "none") return null;
  return trimmed;
}

export function exactListMember<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === "string" && (allowed as readonly string[]).includes(value);
}
