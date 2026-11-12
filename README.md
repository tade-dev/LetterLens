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

Bundled defaults live in `LetterLens-iOS/RemoteConfigDefaults.plist`. The keys match `firebase/remoteconfig.template.json`: `card_prompt`, `plan_prompt`, `card_schema_version` (1), `card_model` and `plan_model` (both `gemini-3.8-flash`). `AppConfig` loads those defaults, calls `fetchAndActivate()` on launch when Firebase is configured, and exposes the values as typed properties.

## Licence

MIT License. See [LICENSE](LICENSE).
