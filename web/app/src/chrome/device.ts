export type DeviceAvailability = "available" | "downloadable" | "downloading" | "unavailable" | "missing";

export interface DeviceStatus {
  browser: "chrome" | "other";
  promptApi: boolean;
  availability: DeviceAvailability;
}

interface Brand {
  brand: string;
  version: string;
}

interface UserAgentData {
  brands?: Brand[];
}

interface PromptModel {
  availability: () => Promise<string>;
}

/**
 * Detection only. The page may call `availability()`.
 * It never calls `LanguageModel.create` or `prompt`. Inference goes through Firebase AI Logic.
 */
export async function detectDevice(): Promise<DeviceStatus> {
  const browser = (await isGoogleChrome()) ? "chrome" : "other";
  const api = promptModel();
  if (browser !== "chrome" || !api) {
    return { browser, promptApi: Boolean(api), availability: "missing" };
  }
  try {
    return { browser, promptApi: true, availability: normaliseAvailability(await api.availability()) };
  } catch {
    return { browser, promptApi: true, availability: "unavailable" };
  }
}

export async function isGoogleChrome(): Promise<boolean> {
  const nav = navigator as Navigator & { userAgentData?: UserAgentData; brave?: unknown };
  if ("brave" in nav) return false;
  const brands = nav.userAgentData?.brands?.map((brand) => brand.brand) ?? [];
  if (brands.length > 0) {
    if (brands.some((brand) => /edge|opera|brave/i.test(brand))) return false;
    return brands.includes("Google Chrome");
  }
  const agent = nav.userAgent;
  if (/Edg\/|OPR\/|Brave/i.test(agent)) return false;
  return /Chrome\/\d+/.test(agent) && !/Chromium\/\d+/.test(agent);
}

function promptModel(): PromptModel | undefined {
  const candidate = (globalThis as { LanguageModel?: PromptModel }).LanguageModel;
  if (!candidate || typeof candidate.availability !== "function") return undefined;
  return candidate;
}

function normaliseAvailability(value: string): DeviceAvailability {
  if (value === "available" || value === "readily") return "available";
  if (value === "downloadable" || value === "after-download") return "downloadable";
  if (value === "downloading") return "downloading";
  return "unavailable";
}

export function deviceMessage(status: DeviceStatus): string {
  if (status.browser !== "chrome") {
    return "This browser is not Google Chrome. On-device reading needs Google Chrome and its built-in model. You can review a redacted copy and send that to the cloud instead.";
  }
  if (!status.promptApi || status.availability === "missing") {
    return "This copy of Chrome does not have the on-device Prompt API. Update Google Chrome and reopen this page. A cloud read is available after you review the redacted text.";
  }
  if (status.availability === "unavailable") {
    return "Chrome's on-device model is not available on this computer. You can check chrome://on-device-internals, or review a redacted copy for a cloud read.";
  }
  if (status.availability === "downloadable") {
    return "The on-device model is not on this computer yet. Download it to read the letter here. The download can take several minutes and starts only when you click the button.";
  }
  if (status.availability === "downloading") {
    return "The on-device model is downloading. You can watch the progress, or review a redacted copy instead.";
  }
  return "The on-device model is ready. A letter you read here stays on this computer.";
}
