# LetterLens

LetterLens explains confusing UK official letters (HMRC, council, bank, benefits, school, utilities). You scan or share a letter. The app reads it on device and shows a short card: what it is, what they want you to do, the deadline (or none found), and signs to check.

Built for #BuildHybridAI. Inference goes through Firebase AI Logic, on-device first. Photos and unredacted personal details stay on the device.

## Requirements

- Xcode 27
- iOS 26.0 or later
- Swift Package Manager only. The Firebase Apple SDK is already linked from `https://github.com/firebase/firebase-ios-sdk` at version 12.13.0 up to the next major. Linked products: `FirebaseAILogic`, `FirebaseAppCheck`, `FirebaseRemoteConfig`.

`12.13.0` itself has a `Package.swift` syntax error and does not include `AppAttestProviderFactory` (added in 12.14.0). The committed `Package.resolved` pins Firebase 12.19.3, the latest 12.x release at the time of this change.

## GoogleService-Info.plist

The file is gitignored because this repository is public. The LetterLens-iOS target has a Run Script phase, **Check GoogleService-Info.plist**, ordered before Compile Sources. It requires `${SRCROOT}/LetterLens-iOS/GoogleService-Info.plist`. When that file is missing the build fails with:

```
error: GoogleService-Info.plist is missing. Put it in LetterLens-iOS/ (it is gitignored); see README.
```

User script sandboxing is enabled (`ENABLE_USER_SCRIPT_SANDBOXING`). The phase declares the plist as an input so the sandbox can read it. It also declares the existing `LetterLens-iOS` directory and runs on every build. A missing plist is not a file the sandbox can grant by itself, and dependency analysis would otherwise stop the build with "Build input file cannot be found" before the script prints the message above. `test -f` needs to read the parent directory.

There is no placeholder plist in the repo. Xcode 27's JSON project format has no optional-resource attribute, so the plist is not a permanent file reference. `LetterLens-iOS` is a synchronized folder (`kind: folder` in `project.xcproj`); once the real file is in that directory, the target copies it into the app.

If a built app is still missing the plist, launch logs an error and skips `FirebaseApp.configure()`. Remote Config then stays on the bundled defaults.

1. In the Firebase console, register the iOS app (`com.tade.LetterLens-iOS`) and download `GoogleService-Info.plist`.
2. Put that file in `LetterLens-iOS/` (next to `LetterLens_iOSApp.swift`).
3. Rebuild. Do not commit the plist.

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

Bundled defaults live in `LetterLens-iOS/RemoteConfigDefaults.plist`. The keys match `firebase/remoteconfig.template.json`: `card_prompt`, `plan_prompt`, `card_schema_version` (2), `card_model` and `plan_model` (both `gemini-3.8-flash`), and `fallback_model` (`gemini-3.5-flash-lite`). The first cloud HTTP 429 or 503 moves later attempts onto `fallback_model` when that name is set. An empty name skips the switch. A letter gets at most three cloud attempts; 400, 401, and 403 stop immediately. `AppConfig` loads those defaults, calls `fetchAndActivate()` on launch when Firebase is configured, and exposes the values as typed properties. Live Remote Config is deployed separately.

## Scan to card

The debug screen (the app's current UI) scans a letter with VisionKit, imports a photo or PDF, or pastes text. OCR stays on device (`RecognizeDocumentsRequest`, falling back to `VNRecognizeTextRequest`). The card prompt comes from `AppConfig`. Inference goes through Firebase AI Logic.

- **Never upload** off, and **Allow cloud fallback** off: on-device only, full OCR text, no network for the letter. If the system model is unavailable, the screen says it can't read privately on this iPhone.
- **Allow cloud fallback** on: a sheet shows the redacted text and how many details were removed. Nothing is uploaded until you tap Send. The session is a `HybridModel` (on-device first, cloud model from `card_model` as the fallback) or cloud-only when the system model is unavailable. Only the redacted text is in the prompt. Tokens such as `[NAME_1]` are filled back in on device before the quote check.
- Photos are not sent. The saved history is the OCR text and the card, in a local SwiftData store.

The badge is **Read on this iPhone** or **Read in the cloud**, from `response.rawResponse.modelVersion`. On-device is reported as `apple-foundation-models-system-language-model`.

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

`--txt` reads the `.txt` files and skips OCR. `--consent` sets cloud consent so a repeated on-device guardrail, internal error, or 60-second timeout can fall back to redacted cloud text. `--never-upload` forces on-device. `LL_SIM_UDID`, when set, chooses the Simulator. When it is unset the script uses `booted`. The script deletes `run.json` in the output directory before launch. If `LL_APPCHECK_DEBUG_TOKEN` is set in the environment, the script forwards it to the app as `FIRAAppCheckDebugToken`. It does not read a token from a file and it does not print the token.

An on-device guardrail or sensitive-content error is retried once on the same route. A cloud HTTP 429 or 503 waits 2s, then 5s, then 12s, plus up to 250ms of jitter, or `Retry-After` capped at 60s. The first of those moves later attempts onto `fallback_model` when that name is set. An empty name skips the switch. A letter gets at most three cloud attempts. 400, 401, and 403 stop immediately. `run.json` records `attempts` and the final `route` for each letter, plus `failed` and `exit_code` for the run. `NN.raw.json` records each attempt, including `model` and `backoff_ms`.

For each letter number `NN` the output folder contains:

| File | What it is |
|---|---|
| `NN.ocr.txt` | OCR text, or the `.txt` letter when text mode is on |
| `NN.txt` | The same text. `score.py` looks for this name first |
| `NN.raw.json` | Raw model replies (`responses[].text`), plus `error`, `model`, and `backoff_ms` on each attempt |
| `NN.validated.json` | Validated card |
| `NN.json` | The same validated card. This is the file `score.py` reads first |
| `run.json` | `failed`, `exit_code`, and per letter `route`, `model`, `latency_ms`, `attempts`, `error` |

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
