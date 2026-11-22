# LetterLens

LetterLens explains confusing UK official letters (HMRC, council, bank, benefits, school, utilities). You scan or share a letter. The app reads it on device and shows a short card: what it is, what they want you to do, the deadline (or none found), and signs to check.

Built for #BuildHybridAI. Inference goes through Firebase AI Logic, on-device first. Photos and unredacted personal details stay on the device.

There is also a Chrome web app in [web/app](web/app/README.md). It reads on device with Gemini Nano, takes pasted text or a `.txt` file rather than a photo, and sends a redacted letter to the cloud only after you agree to that exact text. [web/nano-spike](web/nano-spike/README.md) is the throwaway page the Prompt API behaviour was worked out on.

## Requirements

- Xcode 27
- iOS 26.0 or later
- Swift Package Manager only. The Firebase Apple SDK is already linked from `https://github.com/firebase/firebase-ios-sdk` at version 12.13.0 up to the next major. Linked products: `FirebaseAILogic`, `FirebaseAppCheck`, `FirebaseRemoteConfig`.

`12.13.0` itself has a `Package.swift` syntax error and does not include `AppAttestProviderFactory` (added in 12.14.0). The committed `Package.resolved` pins Firebase 12.19.3, the latest 12.x release at the time of this change.

## GoogleService-Info.plist

The file is gitignored because this repository is public. The app still compiles without it. At launch, a missing plist is logged and `FirebaseApp.configure()` is skipped. Remote Config then stays on the bundled defaults.

Xcode 27's JSON project format has no optional-resource attribute. A permanent file reference to a missing plist would fail the Copy Bundle Resources phase in CI. `LetterLens-iOS` is a synchronized folder (`kind: folder` in `project.xcproj`), so the file joins the LetterLens-iOS target on its own once it is present.

1. Create a Firebase project. Google Analytics can stay off. Register an iOS app with the bundle ID `com.tade.LetterLens-iOS` (`PRODUCT_BUNDLE_IDENTIFIER` in `LetterLens-iOS.xcodeproj/project.xcproj`).
2. In the console open **AI Services → AI Logic**, click **Get started**, and choose the **Gemini Developer API**. The app builds and reads on device without this step, then fails every cloud call, so do it before the first cloud read. Leave the project on the no-cost Spark plan, with no Cloud Billing account.
3. Download `GoogleService-Info.plist` for that iOS app and put it in `LetterLens-iOS/` (next to `LetterLens_iOSApp.swift`).
4. Rebuild. Do not commit the plist.

On the device, Firebase AI Logic is Apple Foundation Models (`FirebaseAI.SystemLanguageModel`). In the cloud it is the Gemini Developer API, `FirebaseAI.firebaseAI(backend: .googleAI())`. When a cloud read is allowed, the card session is a `HybridModel`: the system model is primary, and the Gemini model named by `card_model` is secondary.

## App Check debug token

Debug builds use `AppCheckDebugProviderFactory`. Release builds use `AppAttestProviderFactory` when App Attest is supported, and `DeviceCheckProvider` otherwise. Token auto-refresh is turned on after Firebase is configured.

The debug token is not in the repo. To pin one locally:

1. Run a Debug build once with `GoogleService-Info.plist` in the app.
2. In the Xcode console, find the line `[AppCheckCore][I-GAC004001] App Check debug token: '…'`.
3. Register that token in the Firebase console under App Check → Apps → Manage debug tokens.
4. Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables.
5. Add `FIRAAppCheckDebugToken` with that token as the value.
6. Leave the scheme unshared. It must stay under `LetterLens-iOS.xcodeproj/xcuserdata/`, which is gitignored. Do not commit the token, and do not commit a shared scheme that contains it.

## Remote Config

Bundled defaults live in `LetterLens-iOS/RemoteConfigDefaults.plist`. The keys match `firebase/remoteconfig.template.json`: `card_prompt`, `plan_prompt`, `card_schema_version` (2), `card_model` and `plan_model` (both `gemini-3.8-flash`), and `fallback_model` (`gemini-3.5-flash-lite`). The first cloud HTTP 429 or 503 moves later attempts onto `fallback_model` when that name is set. An empty name skips the switch. A letter gets at most three cloud attempts; 400, 401, and 403 stop immediately. `AppConfig` loads those defaults, calls `fetchAndActivate()` on launch when Firebase is configured, and exposes the values as typed properties.

Live Remote Config is deployed separately. From the repo root, `firebase.json` publishes `firebase/remoteconfig.template.json`:

```bash
firebase login
firebase use <project-id>
firebase deploy --only remoteconfig
firebase remoteconfig:get
```

`firebase login` opens a browser so you sign in yourself. Pass your own project id to `firebase use`; that command rewrites `.firebaserc`, so leave the committed file as it is. `firebase remoteconfig:get` prints the template now live on the project. Publishing replaces the whole template.

Skipping this is fine. The app reads the bundled defaults at launch, so it still runs with no live template, no plist, or a failed `fetchAndActivate()`.

The Gemini Developer API free tier caps requests per minute, and crossing a cap returns HTTP 429. That is the case `fallback_model` exists for.

## Scan to card

`RootView` opens Welcome on a first launch, then Home. Home pushes Scan, Privacy settings, and any stored letter. Scan takes a letter from VisionKit's document camera, a photo, or a PDF, and pushes the reading screen, which lands on the letter card or the scam warning. The card's **Plan next steps** pushes what-gets-sent, then the plan.

OCR stays on device (`RecognizeDocumentsRequest`, falling back to `VNRecognizeTextRequest`). The card prompt comes from `AppConfig`. Inference goes through Firebase AI Logic.

**Never upload** is the only privacy switch, and it is off by default.

- **Never upload on:** on-device only, full OCR text, no network for the letter. Nothing is ever sent, and **Plan next steps** is turned off. If the system model is unavailable, the app says it can't read privately on this iPhone and stops.
- **Never upload off:** a letter is still read on device first. Only when that is unavailable or fails does a sheet offer the cloud, and it asks before every cloud read. The sheet shows the redacted text and how many details were removed; nothing is uploaded until you tap Send. The session is a `HybridModel` (on-device first, cloud model from `card_model` as the fallback) or cloud-only when the system model is unavailable. Only the redacted text is in the prompt. Tokens such as `[NAME_1]` are filled back in on device before the quote check.
- A plan is always a cloud call, so Never upload blocks it. With the switch off, what-gets-sent still asks first.
- Photos are not sent. The saved history is the OCR text and the card, in a local SwiftData store.

The badge is **Read on this iPhone** or **Read in the cloud**, from `response.rawResponse.modelVersion`. On-device is reported as `apple-foundation-models-system-language-model`.

## Hosting the web app

`firebase.json` deploys `web/app/dist` to Firebase Hosting. Build first, then deploy:

```bash
cd web/app && npm install && npm run build
cd ../.. && firebase deploy --only hosting
```

That publishes to `https://letterlens-ios.web.app` (substitute your own project). `firebase deploy --only hosting --dry-run` checks the config without shipping anything.

The App Check debug token is read only under `import.meta.env.DEV`, so a production build drops that branch and the token is never in `dist/`. A hosted build needs `VITE_FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY` instead. Without one, App Check does not start, the page says so, and **cloud reads stay off** — on-device reading in Chrome still works.

## Share sheet

`LetterLensShare` is a Share Extension. Sharing a photo or PDF from Mail, Files or Photos offers **LetterLens**, and the letter opens in the reading screen.

The extension does not read anything. It has no Firebase, no model and no OCR: it copies the bytes into the App Group container (`group.com.tade.LetterLens-iOS`) and finishes. The app drains that inbox whenever Home is on screen, renders the pages, and runs the same pipeline a camera scan runs, so every privacy rule stays in one place.

`NSExtensionContext.open` asks iOS to bring the app forward. That request is allowed to fail: the inbox is the contract, so a share still arrives the next time the app is opened. Both targets need the App Group in their entitlements; `Shared/SharedInbox.swift` is the only file compiled into both.

The app target sets `ENABLE_USER_SCRIPT_SANDBOXING = NO`, which the project otherwise leaves on. The `Embed LetterLensShare` script phase copies the built `.appex` into `PlugIns`, and the script sandbox blocks a phase from reading another target's product. Xcode's own embed phase has no spelling in the Xcode 27 JSON project format that we could find; adding the target through Xcode's UI would write one, and this setting can go back to `YES` the moment it does.

## App icon

`AppIcon.appiconset` holds the light, dark and tinted 1024s. They are generated, not hand-drawn: `scripts/make-app-icon.swift` redraws the `LetterLensLogo` geometry at 1024 so the icon and the in-app mark cannot drift apart.

```bash
swift scripts/make-app-icon.swift LetterLens-iOS/Assets.xcassets/AppIcon.appiconset
```

The icon drops the logo's own rounded tile, because iOS masks the corners itself. The files carry no alpha channel: App Store Connect rejects an icon that has one.

## 15-letter harness

Debug builds only. Launch argument `-LLHarness`. The test-kit letters are not in this repo. Point the environment variables at a local copy of that `letters` folder.

PNG is the default and goes through Vision OCR. `LL_HARNESS_SOURCE=txt`, or a second argument `-LLHarnessText`, reads the `.txt` files and skips OCR.

Default consent is off, so the run is on-device only. `LL_CLOUD_CONSENT=1` allows the redacted cloud/hybrid path. `LL_NEVER_UPLOAD=1` forces on-device even if consent is set.

From the repo, with a booted Simulator that has the Debug app installed:

```bash
SIMCTL_CHILD_LL_HARNESS_IN="/absolute/path/to/letters" \
SIMCTL_CHILD_LL_HARNESS_OUT="/absolute/path/to/run" \
xcrun simctl launch --console --terminate-running-process booted com.tade.LetterLens-iOS -LLHarness
```

Text instead of OCR:

```bash
SIMCTL_CHILD_LL_HARNESS_IN="/absolute/path/to/letters" \
SIMCTL_CHILD_LL_HARNESS_OUT="/absolute/path/to/run" \
SIMCTL_CHILD_LL_HARNESS_SOURCE="txt" \
xcrun simctl launch --console --terminate-running-process booted com.tade.LetterLens-iOS -LLHarness
```

`simctl launch` passes each `SIMCTL_CHILD_` variable through to the app without the prefix. The same variables can be set on the Run action of a local scheme, with `-LLHarness` as an argument. Do not commit that scheme if it contains an App Check token.

`xcrun simctl launch --console` always exits 0. The app still writes `exit_code` into `run.json` (`0` every letter produced a card, `1` a letter failed, `2` the input or output path could not be used). Use the script, which reads that file and exits with it:

```bash
scripts/run-harness.sh /absolute/path/to/letters /absolute/path/to/run
scripts/run-harness.sh /absolute/path/to/letters /absolute/path/to/run --txt
scripts/run-harness.sh /absolute/path/to/letters /absolute/path/to/run --consent
scripts/run-harness.sh /absolute/path/to/letters /absolute/path/to/run --never-upload
```

`--txt` reads the `.txt` files and skips OCR. `--consent` sets cloud consent so a repeated on-device guardrail, internal error, or 60-second timeout can fall back to redacted cloud text. `--never-upload` forces on-device. `LL_SIM_UDID`, when set, chooses the Simulator. When it is unset the script uses `booted`. `LL_LETTER_GAP_SECONDS`, when set to a positive number of seconds, is the pause between letters. When it is unset the pause is 0. The script deletes `run.json` in the output directory before launch. If `LL_APPCHECK_DEBUG_TOKEN` is set in the environment, the script forwards it to the app as `FIRAAppCheckDebugToken`. It does not read a token from a file and it does not print the token.

An on-device guardrail or sensitive-content error is retried once on the same route. A cloud HTTP 429 or 503 waits 2s, then 5s, then 12s, plus up to 250ms of jitter, or `Retry-After` capped at 60s. The first of those moves later attempts onto `fallback_model` when that name is set. An empty name skips the switch. A letter gets at most three cloud attempts. 400, 401, and 403 stop immediately. `run.json` records `attempts` and the final `route` for each letter, plus `failed` and `exit_code` for the run. `NN.raw.json` records each attempt, including `model` and `backoff_ms`.

For each letter number `NN` the output folder contains:

| File | What it is |
|---|---|
| `NN.ocr.txt` | OCR text, or the `.txt` letter when text mode is on |
| `NN.txt` | The same text. `score.py` looks for this name first |
| `NN.raw.json` | Raw model replies (`responses[].text`), plus `error`, `model`, and `backoff_ms` on each attempt |
| `NN.validated.json` | Validated card |
| `NN.json` | The same validated card. This is the file `score.py` reads first |
| `run.json` | `failed`, `exit_code`, `letter_gap_seconds`, and per letter `route`, `model`, `latency_ms`, `attempts`, `error` |

Score against the local answer key, from the test-kit directory (that directory is not in this repo):

```bash
python score.py --outputs /absolute/path/to/run --answers /absolute/path/to/answer_key.json --ocr /absolute/path/to/run
```

Unit tests for the redactor, quote check, date parser, card validator, and guardrail classifier live in `LetterLens-iOSTests` and use Swift Testing. They use short synthetic strings, not the test-kit letters. Pick an iOS 26 simulator you have installed:

```bash
xcodebuild test -scheme LetterLens-iOS -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' -only-testing:LetterLens-iOSTests
```

Change the simulator name to one listed by `xcrun simctl list devices available`.

## Licence

MIT License. See [LICENSE](LICENSE).
