//
//  AppConfig.swift
//  LetterLens-iOS
//

import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import Observation
import os

/// Bundled and fetched copies of the shared Remote Config parameters.
///
/// Keys match `firebase/remoteconfig.template.json` exactly. Values are readable
/// immediately from `RemoteConfigDefaults.plist`. When Firebase is configured,
/// `fetchAndActivate()` replaces them with the activated remote values.
@Observable
final class AppConfig {
    private(set) var cardPrompt: String
    private(set) var planPrompt: String
    private(set) var cardSchemaVersion: Int
    private(set) var cardModel: String
    private(set) var planModel: String

    static let defaultsPlistName = "RemoteConfigDefaults"

    static let cardPromptKey = "card_prompt"
    static let planPromptKey = "plan_prompt"
    static let cardSchemaVersionKey = "card_schema_version"
    static let cardModelKey = "card_model"
    static let planModelKey = "plan_model"

    /// Used only when the bundled plist cannot be read. These match the template.
    private static let fallbackSchemaVersion = 1
    private static let fallbackModel = "gemini-3.8-flash"

    init() {
        let bundled = Self.loadBundledDefaults()
        cardPrompt = bundled.cardPrompt
        planPrompt = bundled.planPrompt
        cardSchemaVersion = bundled.cardSchemaVersion
        cardModel = bundled.cardModel
        planModel = bundled.planModel
    }

    /// Fetches Remote Config and activates it. Keeps the bundled defaults if Firebase
    /// was not configured or the fetch fails.
    func fetchAndActivate() async {
        guard FirebaseApp.app() != nil else {
            LetterLensLog.firebase.error(
                "Skipping Remote Config fetchAndActivate because Firebase is not configured. Bundled defaults remain in use."
            )
            return
        }

        let remoteConfig = RemoteConfig.remoteConfig()
        remoteConfig.setDefaults(fromPlist: Self.defaultsPlistName)

        #if DEBUG
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        #endif

        do {
            let status = try await remoteConfig.fetchAndActivate()
            apply(remoteConfig)
            let description = String(describing: status)
            LetterLensLog.firebase.notice(
                "Remote Config fetchAndActivate finished with status \(description, privacy: .public)."
            )
        } catch {
            LetterLensLog.firebase.error(
                "Remote Config fetchAndActivate failed: \(error.localizedDescription, privacy: .public). Bundled defaults remain in use."
            )
        }
    }

    private func apply(_ remoteConfig: RemoteConfig) {
        let cardPrompt = remoteConfig.configValue(forKey: Self.cardPromptKey).stringValue
        if !cardPrompt.isEmpty {
            self.cardPrompt = cardPrompt
        }

        let planPrompt = remoteConfig.configValue(forKey: Self.planPromptKey).stringValue
        if !planPrompt.isEmpty {
            self.planPrompt = planPrompt
        }

        let cardModel = remoteConfig.configValue(forKey: Self.cardModelKey).stringValue
        if !cardModel.isEmpty {
            self.cardModel = cardModel
        }

        let planModel = remoteConfig.configValue(forKey: Self.planModelKey).stringValue
        if !planModel.isEmpty {
            self.planModel = planModel
        }

        let schemaVersion = remoteConfig.configValue(forKey: Self.cardSchemaVersionKey).numberValue.intValue
        if schemaVersion > 0 {
            cardSchemaVersion = schemaVersion
        }
    }

    private static func loadBundledDefaults() -> (
        cardPrompt: String,
        planPrompt: String,
        cardSchemaVersion: Int,
        cardModel: String,
        planModel: String
    ) {
        let fallback = (
            cardPrompt: "",
            planPrompt: "",
            cardSchemaVersion: fallbackSchemaVersion,
            cardModel: fallbackModel,
            planModel: fallbackModel
        )

        guard
            let url = Bundle.main.url(forResource: defaultsPlistName, withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            LetterLensLog.firebase.error(
                "RemoteConfigDefaults.plist is missing or unreadable. Model name and schema version fell back to the template values. Prompts are empty until the plist is in the app bundle."
            )
            return fallback
        }

        guard
            let cardPrompt = raw[cardPromptKey] as? String,
            let planPrompt = raw[planPromptKey] as? String,
            let cardModel = raw[cardModelKey] as? String,
            let planModel = raw[planModelKey] as? String,
            let cardSchemaVersion = schemaVersion(from: raw[cardSchemaVersionKey])
        else {
            LetterLensLog.firebase.error(
                "RemoteConfigDefaults.plist is missing one of card_prompt, plan_prompt, card_schema_version, card_model, or plan_model."
            )
            return fallback
        }

        return (cardPrompt, planPrompt, cardSchemaVersion, cardModel, planModel)
    }

    private static func schemaVersion(from raw: Any?) -> Int? {
        switch raw {
        case let number as Int:
            return number
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }
}
