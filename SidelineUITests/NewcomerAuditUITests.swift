import XCTest

/// Deterministic first-run walk for the newcomer persona audit. No backend
/// config on the runner, so the app serves its bundled sample briefing.
/// One sequential test: onboarding state lives in UserDefaults and launch
/// arguments cannot be overridden by the app's own writes, so the walk relies
/// on the fresh simulator default and relaunches without arguments.
/// Every step attaches a screenshot; nothing here asserts visual quality.
final class NewcomerAuditUITests: XCTestCase {
    private let bundleID = "com.jackwallner.sports"

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

    private func tapCard(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
    }

    func testNewcomerWalk() {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launch()
        _ = app.buttons["Start"].waitForExistence(timeout: 20)
        shot(app, "01-onboarding-welcome")

        app.buttons["Start"].tap()
        sleep(1)
        shot(app, "02-onboarding-rooms")

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
        sleep(4)
        shot(app, "04-first-briefing-lead")
        dumpButtons(app, "first-briefing")

        // Tap the card to flip it.
        tapCard(app)
        sleep(2)
        shot(app, "05-lead-flipped")
        tapCard(app)
        sleep(1)

        // Swipe right first: a newcomer who swipes the "wrong" way.
        app.swipeRight()
        sleep(2)
        shot(app, "06-swipe-right-first")

        for i in 1...6 {
            app.swipeLeft()
            sleep(2)
            shot(app, "07-deck-card-\(i)")
        }

        // Flip a story card.
        tapCard(app)
        sleep(2)
        shot(app, "08-story-flipped")
        dumpButtons(app, "story-flipped")

        // Locked room from the rail.
        let rail = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Office Watercooler'")).firstMatch
        if rail.waitForExistence(timeout: 5) {
            rail.tap()
            sleep(2)
            shot(app, "10-locked-room-preview")
            dumpButtons(app, "locked-room")

            let see = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Free' OR label CONTAINS 'Unlock' OR label CONTAINS 'Pro'")).firstMatch
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

        // Return visit and settings.
        app.terminate()
        app.launch()
        sleep(4)
        shot(app, "20-return-visit")
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 10) {
            settings.tap()
            sleep(2)
            shot(app, "21-settings")
        }
    }
}
