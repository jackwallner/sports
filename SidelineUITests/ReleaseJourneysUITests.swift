import XCTest

/// The release gate's journeys (`qa-gate run`): onboarding to the first
/// briefing, a Pro room's preview and the Gist Pro paywall shown and closed,
/// Settings, and a return visit with an interruption. Each step ends in
/// `QA.checkpoint`, which runs the fleet oracles on the screen. Assert
/// reachability only.
///
/// `-SidelineSafeScreenshot` serves the seeded offline briefings and hides
/// the locked rooms, so the Pro room journey uses `-SidelineScreenshotDemo`. Simulator
/// runs never configure the production RevenueCat key, so journeys that show
/// prices add `-rcfunnelprobe`: the Test Store, a separate RevenueCat app,
/// supplies them. Its customer never buys.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    private static let bundle = "com.jackwallner.sports"
    // A new Test Store customer per run: a purchase made by any earlier run would
    // otherwise leave every later run Pro, and a Pro user never sees the preview.
    private static let probe = ["RC_PROBE_USER": "qa-sports-journeys-\(UUID().uuidString.prefix(8))"]
    private static let freeArgs = ["-SidelineSafeScreenshot", "-rcfunnelprobe"]

    func test01OnboardingToFirstBriefing() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: Self.freeArgs + ["-SidelineFreshOnboarding"])
        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "welcome never rendered")
        QA.checkpoint(app, "welcome")

        start.tap()
        let briefing = app.buttons["See today's briefing"]
        XCTAssertTrue(briefing.waitForExistence(timeout: 10))
        QA.checkpoint(app, "pick-room")

        briefing.tap()
        XCTAssertTrue(briefing.waitForNonExistence(timeout: 15), "onboarding never finished")
        QA.checkpoint(app, "first-briefing")
    }

    func test02ProRoomPreviewAndPaywall() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: ["-SidelineScreenshotDemo", "-rcfunnelprobe", "-DuoScreen", "brief"])
        let proRoom = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Pro context")).firstMatch
        XCTAssertTrue(proRoom.waitForExistence(timeout: 20), "no Pro room on the rail for a free user")
        QA.checkpoint(app, "briefing-free")

        proRoom.tap()
        let seePro = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Try ' OR label BEGINSWITH 'Unlock '")).firstMatch
        XCTAssertTrue(seePro.waitForExistence(timeout: 10), "Pro preview never rendered")
        QA.checkpoint(app, "pro-preview", paywall: false)

        seePro.tap()
        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 15), "paywall never rendered")
        QA.checkpoint(app, "pro-paywall", paywall: true)

        notNow.tap()
        XCTAssertTrue(proRoom.waitForExistence(timeout: 15))
        QA.checkpoint(app, "briefing-after-paywall", paywall: false)
    }

    func test03SettingsAndReturnVisit() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, arguments: ["-SidelineSafeScreenshot", "-SidelineForcePro", "-DuoScreen", "settings"])
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20))
        sleep(2)
        QA.checkpoint(app, "settings")

        QA.interrupt(app)
        QA.checkpoint(app, "settings-after-interruption")

        QA.relaunch(app)
        sleep(2)
        QA.checkpoint(app, "after-relaunch")
    }

    /// The core loop: a new user gets through onboarding, reads today's
    /// briefing card by card to the end of the free deck, opens a card's
    /// backstory, and finds the same briefing again after a relaunch.
    func testCoreLoopReadBriefingSurvivesRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe,
                  arguments: ["-SidelineScreenshotDemo", "-rcfunnelprobe", "-SidelineFreshOnboarding"])

        // Onboarding to the first briefing.
        XCTAssertTrue(app.staticTexts["Sports, made simple."].waitForExistence(timeout: 15))
        QA.checkpoint(app, "onboarding-welcome")
        app.buttons["Start"].tap()
        let free = app.buttons["Cocktail Party"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        XCTAssertTrue(free.isSelected, "the free room is not preselected")
        QA.checkpoint(app, "onboarding-room")
        app.buttons["See today's briefing"].tap()

        // Lead card with the day's TL;DR; a free deck is six cards.
        let deck = waitForDeck(app)
        XCTAssertEqual(deck.value as? String, "Card 1 of 6")
        XCTAssertTrue(text(app, containing: "got benched").waitForExistence(timeout: 5), "lead TL;DR missing")
        QA.checkpoint(app, "briefing-lead")

        // The lead card turns over to its setup and back.
        deck.tap()
        XCTAssertTrue(text(app, containing: "swapping CEOs").waitForExistence(timeout: 5), "lead setup missing")
        QA.checkpoint(app, "briefing-lead-back")
        deck.tap()
        XCTAssertTrue(text(app, containing: "got benched").waitForExistence(timeout: 5))

        // First story card, then its backstory.
        swipeToNextCard(app, expecting: "Card 2 of 6")
        XCTAssertTrue(text(app, containing: "longtime starter").waitForExistence(timeout: 5), "story 1 missing")
        QA.checkpoint(app, "story-1")
        deck.tap()
        XCTAssertTrue(text(app, containing: "started every game for 9 years").waitForExistence(timeout: 5),
                      "story 1 backstory missing")
        QA.checkpoint(app, "story-1-back")
        deck.tap()

        // Through the remaining stories to "Your move" and the rooms card.
        swipeToNextCard(app, expecting: "Card 3 of 6")
        XCTAssertTrue(text(app, containing: "feel-good story").waitForExistence(timeout: 5), "story 2 missing")
        QA.checkpoint(app, "story-2")
        swipeToNextCard(app, expecting: "Card 4 of 6")
        XCTAssertTrue(text(app, containing: "disrespectful").waitForExistence(timeout: 5), "story 3 missing")
        QA.checkpoint(app, "story-3")
        swipeToNextCard(app, expecting: "Card 5 of 6")
        XCTAssertTrue(text(app, containing: "right call").waitForExistence(timeout: 5), "closing question missing")
        QA.checkpoint(app, "your-move")
        swipeToNextCard(app, expecting: "Card 6 of 6")
        QA.checkpoint(app, "rooms-card")

        // Still there after a kill and relaunch: no onboarding, same briefing.
        app.launchArguments.removeAll { $0 == "-SidelineFreshOnboarding" }
        QA.relaunch(app)
        XCTAssertEqual(waitForDeck(app).value as? String, "Card 1 of 6")
        XCTAssertTrue(text(app, containing: "got benched").waitForExistence(timeout: 5), "briefing gone after relaunch")
        XCTAssertFalse(app.staticTexts["Sports, made simple."].exists, "onboarding came back after relaunch")
        QA.checkpoint(app, "relaunch-briefing")
    }

    // MARK: - Helpers

    private func text(_ app: XCUIApplication, containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    /// The deck is the element whose value reads "Card N of M".
    private func deck(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "value BEGINSWITH 'Card '")).firstMatch
    }

    @discardableResult
    private func waitForDeck(_ app: XCUIApplication) -> XCUIElement {
        let deck = deck(app)
        XCTAssertTrue(deck.waitForExistence(timeout: 20), "the briefing deck never appeared")
        return deck
    }

    private func swipeToNextCard(_ app: XCUIApplication, expecting value: String, journey: String = #function) {
        let deck = deck(app)
        deck.swipeLeft()
        let moved = NSPredicate(format: "value == %@", value)
        let result = XCTWaiter.wait(for: [expectation(for: moved, evaluatedWith: deck)], timeout: 5)
        XCTAssertEqual(result, .completed, "swipe did not reach \(value) in \(journey)")
    }
}
