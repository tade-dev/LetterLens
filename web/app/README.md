# LetterLens for Chrome

LetterLens turns a UK official letter into a plain-English card: who sent it, what kind of letter it is, what you need to do, any deadline quoted from the letter, and signs to check.

This is the #BuildHybridAI web app. Inference goes through Firebase AI Logic. The letter is read **on this device by default**. A cloud model is a separate request. It runs only when on-device reading is unavailable or fails, and only after you have seen the redacted text and chosen to send it.

## What you need

- Node.js 22 or later, for the toolchain. The page itself runs in the browser.
- [Google Chrome](https://www.google.com/chrome/) with the built-in on-device model. The Prompt API page is a useful check: `chrome://on-device-internals` should show the model as ready, or you can download it from this app.
- A Firebase web app config and App Check. The real values stay in `.env.local`, which is gitignored.

Photos and PDFs are not read here. Paste the letter, or upload a `.txt` file. There is no OCR dependency.

## Setup

From this folder:

```bash
cp .env.example .env.local
npm install
npm test
npm run dev
```

Fill in `.env.local` from the Firebase console. Do not commit that file, an App Check debug token, an API key, or `GoogleService-Info.plist`.

| Name | What it is |
| --- | --- |
| `VITE_FIREBASE_API_KEY` | Web API key |
| `VITE_FIREBASE_AUTH_DOMAIN` | Usually `your-project.firebaseapp.com` |
| `VITE_FIREBASE_PROJECT_ID` | Firebase project id |
| `VITE_FIREBASE_STORAGE_BUCKET` | Optional |
| `VITE_FIREBASE_MESSAGING_SENDER_ID` | Optional |
| `VITE_FIREBASE_APP_ID` | Web app id |
| `VITE_FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY` | reCAPTCHA Enterprise site key for App Check |
| `VITE_FIREBASE_APPCHECK_DEBUG_TOKEN` | Local development only. Leave it empty for any shared build. |

Open [http://127.0.0.1:5173](http://127.0.0.1:5173) in Google Chrome. Use `127.0.0.1` or `localhost`. A debug token is only accepted from there.

The first time you run a local debug build, Chrome's console may print an App Check debug token. Register that token in the Firebase console under App Check, and put it in `.env.local` if you want to pin it. Do not paste it into the repo.

`npm run build` typechecks and writes `dist/`. This app is not deployed from here.

## Hybrid flow

1. The page checks that it is Google Chrome and asks the Prompt API whether the on-device model is `available`, `downloadable`, `downloading`, or `unavailable`. That check does not read the letter. The page never calls Chrome's `LanguageModel` to generate text. Every model call goes through Firebase AI Logic.
2. If the model needs a download, a button starts it. `initializeDeviceModel` reports progress. The download does not start on its own.
3. **Read on this device** calls `getGenerativeModel` with `InferenceMode.ONLY_ON_DEVICE`. Before that call, the full prompt is checked against the 9,216-token on-device limit. `countTokens` is tried only when the on-device model is ready. Firebase JS SDK 13.4.0 does not support `countTokens` for `ONLY_ON_DEVICE` (it throws, and does not count the letter in the cloud when the Chrome adapter is present). The app then uses a conservative estimate of 3 characters per token. A letter over the limit is not sent.
4. On-device Chrome ignores `responseSchema`, so the reply is parsed by stripping one markdown fence and checking the card exactly. `type` and `sender_kind` must be members of the schema v2 lists. Anything else is tried once more on the device, then shown as an error.
5. The SDK can report `inferenceSource: "in_cloud"` for a request that was supposed to stay on device. That answer is discarded. It is not shown as an on-device card.
6. **Cloud is separate.** It is offered when Chrome cannot read on device, the letter is too long, or the on-device read fails. The letter is redacted first. The dialog shows the exact prompt that would be sent. **Send this text** is the only way it leaves the computer. Choosing **Don't send**, or pressing Escape, sends nothing.
7. The cloud call is `getGenerativeModel` with `InferenceMode.ONLY_IN_CLOUD` on `getAI(app, { backend: new GoogleAIBackend(), useLimitedUseAppCheckTokens: true })`. The model name is Remote Config `card_model`, then `fallback_model` if the first cloud call fails with a rate limit or an unavailable response. The same redacted text is sent. There is no silent switch from the on-device button to the cloud.
8. Every card has a badge for the path that actually answered: **Read on this device** or **Read in the cloud**.

Redaction removes names, postal addresses, postcodes, account numbers, sort codes, reference numbers, National Insurance numbers, NHS numbers, phone numbers, and email addresses. Dates and amounts stay, because the deadline quote needs them. Tokens such as `[NAME_1]` are filled back in on this computer before the quote check, so the card can quote the letter you pasted.

A deadline is kept only when its quote appears word for word in the letter and the quote is a date by which you must act. A date that only says when something takes effect or is effective from is dropped, unless that same quote also asks you to act. Action words are matched on word boundaries, so "by" matches "Pay by 3 March 2027" and does not match "nearby".

## Card prompt

The prompt, schema version, and model names are read from Firebase Remote Config:

| Key | Bundled default |
| --- | --- |
| `card_prompt` | Schema v2 prompt in `src/card/defaults.ts` |
| `card_schema_version` | `2` |
| `card_model` | `gemini-3.8-flash` |
| `fallback_model` | `gemini-3.5-flash-lite` |

If Remote Config is still publishing schema 1, or it cannot be fetched, the built-in v2 prompt is used. The page says which one it is using. Live Remote Config is not changed by running this app.

`sender_kind`: council, hmrc, bank, benefits, school, utility, landlord, nhs, other, not_sure.

`type`: bill, reminder, final_notice, change_notice, information_request, consent_request, refund, information, appointment, penalty, other, not_sure.

## Tests

`npm test` compiles the validator, the deadline rule, and the redactor with `tsc`, then runs them with `node --test`. The fixtures are made-up strings. No letter from a real person is in the tests.

```bash
npm test
npm run build
```
