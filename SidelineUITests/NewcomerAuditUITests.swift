import XCTest

/// Deterministic first-run walk for the newcomer persona audit. No backend
/// config on the runner, so the app serves its bundled sample briefing.
/// Every step attaches a screenshot; nothing here asserts visual quality.
final class NewcomerAuditUITests: XCTestCase {
    private let bundleID = "com.jackwallner.sports"

    private func launch(freshInstall: Bool) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        if freshInstall {
            app.launchArguments += ["-sideline.hasCompletedOnboarding", "NO", "-sideline.hasSwipedDeck", "NO"]
        }
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func dumpButtons(_ app: XCUIApplication, _ name: String) {
        let text = app.buttons.allElementsBoundByIndex.map { "\($0.label) | \($0.frame)" }.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "buttons-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstRunToFirstBriefing() {
        let app = launch(freshInstall: true)
        _ = app.buttons["Start"].waitForExistence(timeout: 20)
        shot(app, "01-onboarding-welcome")

        app.buttons["Start"].tap()
        sleep(1)
        shot(app, "02-onboarding-rooms")
        dumpButtons(app, "onboarding-rooms")

        // A newcomer taps a locked room to see what happens.
        let locked = app.buttons["Date Night, unlocks with Gist Pro"]
        if locked.exists {
            locked.tap()
            sleep(1)
            shot(app, "03-onboarding-tapped-locked-room")
        }

        let go = app.buttons["See today's briefing"]
        XCTAssertTrue(go.exists)
        go.tap()
        sleep(3)
        shot(app, "04-first-briefing-lead")
        dumpButtons(app, "first-briefing")

        // Tap the card to flip it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        sleep(2)
        shot(app, "05-lead-flipped")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        sleep(1)

        // Swipe through the deck.
        for i in 1...5 {
            app.swipeLeft()
            sleep(2)
            shot(app, "06-deck-card-\(i)")
        }

        // Flip a story card and look at the source link.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        sleep(2)
        shot(app, "07-story-flipped")
    }

    func testLockedRoomAndPaywallFromRail() {
        let app = launch(freshInstall: true)
        if app.buttons["Start"].waitForExistence(timeout: 20) { app.buttons["Start"].tap() }
        if app.buttons["See today's briefing"].waitForExistence(timeout: 5) { app.buttons["See today's briefing"].tap() }
        sleep(3)

        let rail = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Office Watercooler'")).firstMatch
        XCTAssertTrue(rail.waitForExistence(timeout: 10))
        rail.tap()
        sleep(2)
        shot(app, "10-locked-room-preview")

        let see = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Free' OR label CONTAINS 'Unlock'")).firstMatch
        if see.exists {
            see.tap()
            sleep(4)
            shot(app, "11-paywall-from-locked-room")
            dumpButtons(app, "paywall")
            let notNow = app.buttons["Not now"]
            if notNow.exists { notNow.tap() }
            sleep(1)
            shot(app, "12-after-paywall-dismiss")
        }
    }

    func testReturnVisitAndSettings() {
        let first = launch(freshInstall: true)
        if first.buttons["Start"].waitForExistence(timeout: 20) { first.buttons["Start"].tap() }
        if first.buttons["See today's briefing"].waitForExistence(timeout: 5) { first.buttons["See today's briefing"].tap() }
        sleep(3)
        first.terminate()

        let app = launch(freshInstall: false)
        sleep(4)
        shot(app, "20-return-visit")

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        sleep(2)
        shot(app, "21-settings")
        app.swipeUp()
        sleep(1)
        shot(app, "22-settings-bottom")
    }
}
