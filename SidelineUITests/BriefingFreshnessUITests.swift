import XCTest

/// Room switches and coming back to the app: the deck a user lands on and
/// the age the footer reads.
@MainActor
final class BriefingFreshnessUITests: XCTestCase {

    private static let bundle = "com.jackwallner.sports"

    /// A new room opens on its brief, not at the old room's card.
    /// `-SidelineSlowNetwork` makes the switch pass through the skeleton.
    func testRoomSwitchOpensTheNewRoomOnItsBrief() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: ["-SidelineSafeScreenshot", "-SidelineForcePro", "-SidelineSlowNetwork",
                                   "-DuoScreen", "brief"])
        let deck = deck(app)
        XCTAssertTrue(deck.waitForExistence(timeout: 20), "the briefing deck never appeared")
        XCTAssertTrue(waitFor(deck, valueBeginsWith: "Card 1 of "))

        QA.swipe(deck)
        XCTAssertTrue(waitFor(deck, valueBeginsWith: "Card 2 of "))
        QA.swipe(deck)
        XCTAssertTrue(waitFor(deck, valueBeginsWith: "Card 3 of "))

        let dateNight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Date Night'")).firstMatch
        XCTAssertTrue(dateNight.waitForExistence(timeout: 5), "no Date Night chip")
        dateNight.tap()

        let brief = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Comebacks are the story'")).firstMatch
        XCTAssertTrue(brief.waitForExistence(timeout: 10), "Date Night did not open on its brief")
        XCTAssertTrue(waitFor(deck, valueBeginsWith: "Card 1 of "), "deck reads \(deck.value ?? "nil")")
        QA.checkpoint(app, "date-night-after-switch")
    }

    /// The footer's "Updated ..." age moves on while the app sits in the
    /// background.
    func testFooterAgeAdvancesAfterBackground() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: ["-SidelineScreenshotDemo", "-SidelineForcePro", "-DuoScreen", "brief"])
        let footer = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 20), "no freshness footer")
        let before = footer.label

        XCUIDevice.shared.press(.home)
        sleep(80)
        app.activate()

        let moved = NSPredicate(format: "label != %@", before)
        let result = XCTWaiter.wait(for: [expectation(for: moved, evaluatedWith: footer)], timeout: 10)
        XCTAssertEqual(result, .completed, "footer still reads \(before)")
        QA.checkpoint(app, "after-80s-in-background")
    }

    // MARK: - Helpers

    private func deck(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "value BEGINSWITH 'Card '")).firstMatch
    }

    private func waitFor(_ element: XCUIElement, valueBeginsWith prefix: String) -> Bool {
        let predicate = NSPredicate(format: "value BEGINSWITH %@", prefix)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10) == .completed
    }
}
