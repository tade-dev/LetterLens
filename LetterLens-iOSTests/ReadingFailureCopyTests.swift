//
//  ReadingFailureCopyTests.swift
//  LetterLens-iOSTests
//

import Foundation
import Testing
@testable import LetterLens_iOS

@Suite("Reading failure copy")
struct ReadingFailureCopyTests {
    /// The reading-failed screen showed "The operation couldn't be completed.
    /// (FirebaseAILogic.GenerateContentError error 0.)" to someone holding a letter.
    @Test func sdkTextNeverReachesTheReader() {
        let sdk = NSError(
            domain: "FirebaseAILogic.GenerateContentError",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (FirebaseAILogic.GenerateContentError error 0.)"]
        )
        #expect(ScanReadingFailure.message(for: sdk) == ScanReadingFailure.generic)
    }

    @Test func developerTextIsRecognised() {
        for text in [
            "The operation couldn’t be completed. (FirebaseAILogic.GenerateContentError error 0.)",
            "Error Domain=NSURLErrorDomain Code=-999",
            "NSURLErrorDomain error -999",
            "some failure error 503",
        ] {
            #expect(ScanReadingFailure.readsLikeDeveloperText(text), "\(text)")
        }
    }

    @Test func ourOwnWordingIsKept() {
        for text in [
            "No text was found on the page.",
            "That file could not be read as a letter.",
            "This iPhone cannot run Apple Intelligence.",
        ] {
            #expect(!ScanReadingFailure.readsLikeDeveloperText(text), "\(text)")
        }
    }

    @Test func beingOfflineSaysSoAndSaysWhereTheLetterIs() {
        let offline = URLError(.notConnectedToInternet)
        #expect(ScanReadingFailure.message(for: offline) == ScanReadingFailure.offline)
        #expect(ScanReadingFailure.message(for: offline).contains("stayed on this iPhone"))
    }

    @Test func aBusyServiceSaysSo() {
        let busy = NSError(domain: ModelCallClassifier.backendErrorDomain, code: 503)
        #expect(ScanReadingFailure.message(for: busy) == ScanReadingFailure.busy)
    }
}
