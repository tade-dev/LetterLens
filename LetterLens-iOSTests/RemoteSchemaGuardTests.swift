//
//  RemoteSchemaGuardTests.swift
//  LetterLens-iOSTests
//

import Testing
@testable import LetterLens_iOS

@Suite("Remote Config schema guard")
struct RemoteSchemaGuardTests {
    /// Live Remote Config published card_schema_version 1 with the v1 free-text prompt
    /// while the app decoded v2's closed lists, so every letter came back not_sure.
    /// The web build already refused a mismatched schema; iOS took whatever was published.
    @Test func aPromptForAnotherSchemaIsRefused() {
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 1, supported: 2) == false)
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 3, supported: 2) == false)
    }

    @Test func theSupportedSchemaIsAccepted() {
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 2, supported: 2))
    }

    /// A missing key reads as 0. That is the bundled default, which is already this build's.
    @Test func anAbsentSchemaKeyIsFine() {
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 0, supported: 2))
    }

    /// The default argument must track what LetterCard actually decodes.
    @Test func theDefaultMatchesTheShippedSchema() {
        #expect(AppConfig.supportedCardSchemaVersion == 2)
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 2))
        #expect(AppConfig.acceptsRemotePrompts(remoteSchema: 1) == false)
    }
}
