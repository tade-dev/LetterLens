import { initializeApp, getApps, type FirebaseApp, type FirebaseOptions } from "firebase/app";
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from "firebase/app-check";
import { getAI, getGenerativeModel, GoogleAIBackend, InferenceMode, type GenerativeModel } from "firebase/ai";
import { fetchAndActivate, getRemoteConfig, getValue } from "firebase/remote-config";
import { DEFAULT_CARD_MODEL, DEFAULT_CARD_PROMPT, DEFAULT_FALLBACK_MODEL } from "../card/defaults.js";
import { CARD_SCHEMA_VERSION } from "../card/schema.js";
import { resolveCardSettings, type CardSettings } from "../card/settings.js";
import type { CardGenerator } from "../read/request-card.js";

interface DebugGlobal {
  FIREBASE_APPCHECK_DEBUG_TOKEN?: string;
}

export interface AppCheckState {
  ready: boolean;
  note: string;
}

export function readFirebaseConfig(): FirebaseOptions | null {
  const apiKey = clean(import.meta.env.VITE_FIREBASE_API_KEY);
  const projectId = clean(import.meta.env.VITE_FIREBASE_PROJECT_ID);
  const appId = clean(import.meta.env.VITE_FIREBASE_APP_ID);
  if (!apiKey || !projectId || !appId) return null;
  const storageBucket = clean(import.meta.env.VITE_FIREBASE_STORAGE_BUCKET);
  const messagingSenderId = clean(import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID);
  return {
    apiKey,
    authDomain: clean(import.meta.env.VITE_FIREBASE_AUTH_DOMAIN) || `${projectId}.firebaseapp.com`,
    projectId,
    appId,
    ...(storageBucket ? { storageBucket } : {}),
    ...(messagingSenderId ? { messagingSenderId } : {}),
  };
}

export function initFirebase(): FirebaseApp | null {
  if (!readFirebaseConfig()) return null;
  const existing = getApps()[0];
  if (existing) return existing;
  const config = readFirebaseConfig();
  return config ? initializeApp(config) : null;
}

/**
 * The debug token is read only in local `vite` dev, and it is never logged.
 * Production builds drop this branch.
 */
export function startAppCheck(app: FirebaseApp): AppCheckState {
  const siteKey = clean(import.meta.env.VITE_FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY);
  let debugToken = "";
  if (import.meta.env.DEV) {
    debugToken = clean(import.meta.env.VITE_FIREBASE_APPCHECK_DEBUG_TOKEN);
    if (debugToken) {
      (globalThis as DebugGlobal).FIREBASE_APPCHECK_DEBUG_TOKEN = debugToken;
    }
  }
  const key = siteKey || (debugToken ? "debug-only-placeholder" : "");
  if (!key) {
    return {
      ready: false,
      note: "Cloud reads need an App Check reCAPTCHA site key, or a local debug token in .env.local. Nothing is sent without it.",
    };
  }
  try {
    initializeAppCheck(app, {
      provider: new ReCaptchaEnterpriseProvider(key),
      isTokenAutoRefreshEnabled: true,
    });
  } catch {
    return { ready: false, note: "App Check could not be started. Cloud reads stay off until it is." };
  }
  return {
    ready: true,
    note: debugToken ? "App Check is using a local debug token." : "App Check is on.",
  };
}

export async function loadCardSettings(app: FirebaseApp): Promise<CardSettings> {
  const remoteConfig = getRemoteConfig(app);
  remoteConfig.settings.minimumFetchIntervalMillis = import.meta.env.DEV ? 0 : 3_600_000;
  remoteConfig.settings.fetchTimeoutMillis = 10_000;
  remoteConfig.defaultConfig = {
    card_prompt: DEFAULT_CARD_PROMPT,
    card_schema_version: CARD_SCHEMA_VERSION,
    card_model: DEFAULT_CARD_MODEL,
    fallback_model: DEFAULT_FALLBACK_MODEL,
  };
  try {
    await fetchAndActivate(remoteConfig);
  } catch {
    // Keep the in-app v2 prompt when Remote Config cannot be fetched.
  }
  const values = {
    prompt: getValue(remoteConfig, "card_prompt").asString(),
    schemaVersion: getValue(remoteConfig, "card_schema_version").asNumber(),
    cardModel: getValue(remoteConfig, "card_model").asString(),
    fallbackModel: getValue(remoteConfig, "fallback_model").asString(),
  };
  if (remoteConfig.lastFetchStatus !== "success") {
    return resolveCardSettings({ ...values, prompt: "", schemaVersion: 0 });
  }
  return resolveCardSettings(values);
}

/**
 * One AI instance per Firebase app and backend. The limited-use App Check flag
 * is fixed on the first call, so on-device and cloud reads share this instance.
 * On-device inference does not attach the letter to a cloud request.
 */
export function letterLensAi(app: FirebaseApp) {
  return getAI(app, { backend: new GoogleAIBackend(), useLimitedUseAppCheckTokens: true });
}

export function onDeviceModel(app: FirebaseApp, cloudModelName: string): GenerativeModel {
  return getGenerativeModel(letterLensAi(app), {
    mode: InferenceMode.ONLY_ON_DEVICE,
    inCloudParams: { model: cloudModelName },
  });
}

export function cloudModel(app: FirebaseApp, modelName: string): GenerativeModel {
  return getGenerativeModel(letterLensAi(app), {
    mode: InferenceMode.ONLY_IN_CLOUD,
    inCloudParams: {
      model: modelName,
      generationConfig: { temperature: 0.1 },
    },
  });
}

export function asGenerator(model: GenerativeModel): CardGenerator {
  return {
    async generate(prompt: string) {
      const result = await model.generateContent(prompt);
      return {
        text: result.response.text(),
        inferenceSource: result.response.inferenceSource,
      };
    },
  };
}

export async function countWithModel(model: GenerativeModel, prompt: string): Promise<number> {
  const counted = await model.countTokens(prompt);
  return counted.totalTokens;
}

export async function downloadDeviceModel(
  model: GenerativeModel,
  onProgress: (fraction: number) => void,
): Promise<void> {
  await model.initializeDeviceModel(onProgress);
}

function clean(value: string | undefined): string {
  return value?.trim() ?? "";
}
