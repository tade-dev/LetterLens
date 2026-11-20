# LetterLens

## Use your own Firebase project

LetterLens calls Firebase AI Logic. On the device that is Apple Foundation Models (`FirebaseAI.SystemLanguageModel`). In the cloud it is the Gemini Developer API, `FirebaseAI.firebaseAI(backend: .googleAI())`. When a cloud fallback is allowed, the card session is a `HybridModel`: the system model is primary, and the Gemini model named by `card_model` is secondary.

1. Create a Firebase project. Google Analytics can stay off. Register an iOS app with the bundle ID `com.tade.LetterLens-iOS` (`PRODUCT_BUNDLE_IDENTIFIER` in `LetterLens-iOS.xcodeproj/project.xcproj`). In the console open **AI Services > AI Logic**, click **Get started**, and choose the **Gemini Developer API**. Use the free tier: leave the project on the no-cost Spark plan, with no Cloud Billing account.

2. Download `GoogleService-Info.plist` for that iOS app and save it as `LetterLens-iOS/GoogleService-Info.plist` (beside `LetterLens_iOSApp.swift`). `LetterLens-iOS` is a synchronized folder, so the app target copies the file once it is there. The plist must never be committed. `.gitignore` already ignores `GoogleService-Info.plist` and `**/GoogleService-Info.plist`.

3. Publish the Remote Config template from the repo root. `firebase.json` deploys `firebase/remoteconfig.template.json`.

   ```bash
   firebase login
   firebase use <project-id>
   firebase deploy --only remoteconfig
   firebase remoteconfig:get
   ```

   `firebase login` opens a browser so you can sign in yourself. Pass your own project id to `firebase use` (that command updates `.firebaserc`; leave the committed file unchanged). `firebase remoteconfig:get` prints the template now live on the project. Publishing replaces the whole Remote Config template.

   The app also ships bundled defaults in `LetterLens-iOS/RemoteConfigDefaults.plist` (`card_prompt`, `plan_prompt`, `card_schema_version`, `card_model`, `plan_model`, `fallback_model`). It reads those at launch, so it still runs if you skip this step, if the plist is missing, or if `fetchAndActivate()` fails.

4. Debug builds use `AppCheckDebugProviderFactory`. Run a Debug build on the simulator. On the first App Check request, the Xcode console prints a line of this form: `[AppCheckCore][I-GAC004001] App Check debug token: '<token>'`. To see that line, run once without `FIRAAppCheckDebugToken` set. In the Firebase console open **Security > App Check > Apps**, open this app's overflow menu, and choose **Manage debug tokens**. Register the token from your own console. Never paste a real token into this README, a commit, or a shared Xcode scheme.

5. The Gemini Developer API free tier limits how many requests you can make per minute. Crossing a limit can return HTTP 429. The first cloud HTTP 429 or 503 moves later attempts onto `fallback_model` when that name is set. In the bundled defaults and the pipeline template that name is `gemini-3.5-flash-lite`. `card_model` and `plan_model` are `gemini-3.8-flash`, and `card_schema_version` is `2`.
