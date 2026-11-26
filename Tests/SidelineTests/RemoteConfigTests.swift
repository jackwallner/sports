import Foundation
import Shared
import XCTest

/// The offering-metadata reader: control for anything it does not know, the
/// right arm for each shipped value, and control copy that equals the copy the
/// app shipped before the reader existed.
final class RemoteConfigTests: XCTestCase {
    private func arm(_ metadata: [String: Any]?) -> TrialCTA { TrialCTA.from(metadata: metadata) }

    func testMissingMetadataIsControl() {
        XCTAssertEqual(arm(nil), .control)
        XCTAssertEqual(arm([:]), .control)
    }

    func testNonStringAndUnknownValuesAreControl() {
        XCTAssertEqual(arm([TrialCTA.metadataKey: 7]), .control)
        XCTAssertEqual(arm([TrialCTA.metadataKey: true]), .control)
        XCTAssertEqual(arm([TrialCTA.metadataKey: "free_beer"]), .control)
        XCTAssertEqual(arm([TrialCTA.metadataKey: ""]), .control)
    }

    func testEachKnownValueIsItsArm() {
        XCTAssertEqual(arm([TrialCTA.metadataKey: "seven_day"]), .control)
        XCTAssertEqual(arm([TrialCTA.metadataKey: "my"]), .my)
        XCTAssertEqual(arm([TrialCTA.metadataKey: "your"]), .your)
    }

    func testPaywallTitlePerArm() {
        let label = "7-day free trial"
        XCTAssertEqual(TrialCTA.my.paywallTitle(trialLabel: label), "Start My Free Trial")
        XCTAssertEqual(TrialCTA.your.paywallTitle(trialLabel: label), "Start Your Free Trial")
    }

    func testPreviewTitlePerArm() {
        XCTAssertEqual(TrialCTA.my.previewTitle(room: "Date Night", trialAvailable: true), "Start My Free Trial")
        XCTAssertEqual(TrialCTA.your.previewTitle(room: "Date Night", trialAvailable: true), "Start Your Free Trial")
    }

    /// Today's copy, character for character: "Start My " plus the intro
    /// offer's label capitalized, and "Try <Room> Free".
    func testControlCopyIsTheShippedCopy() {
        XCTAssertEqual(TrialCTA.control.paywallTitle(trialLabel: "7-day free trial"), "Start My 7-Day Free Trial")
        XCTAssertEqual(TrialCTA.control.paywallTitle(trialLabel: "3-day free trial"), "Start My 3-Day Free Trial")
        XCTAssertEqual(TrialCTA.control.previewTitle(room: "Date Night", trialAvailable: true), "Try Date Night Free")
    }

    /// An account that already used its trial gets no trial promise (3.1.2),
    /// whichever arm the offering names.
    func testIneligibleWordingIsUnchangedForEveryArm() {
        for arm in TrialCTA.allCases {
            XCTAssertEqual(arm.paywallTitle(trialLabel: nil), "Subscribe")
            XCTAssertEqual(arm.previewTitle(room: "Date Night", trialAvailable: false), "Unlock Date Night")
        }
    }

    func testRatingPromptIsOnByDefault() {
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
    }

    func testRatingPromptIsOffOnlyForOff() {
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
    }
}
