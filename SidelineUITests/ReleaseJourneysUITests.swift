import XCTest

/// The release gate's journeys (`qa-gate run`): onboarding to the first
/// briefing, a Pro room's preview and the Gist Pro paywall shown and closed,
/// Settings, and a return visit with an interruption. Each step ends in
/// `QA.checkpoint`, which runs the fleet oracles on the screen. Assert
/// reachability only.
///
/// `-SidelineSafeScreenshot` serves the seeded offline briefings. Simulator
/// runs never configure the production RevenueCat key, so journeys that show
/// prices add `-rcfunnelprobe`: the Test Store, a separate RevenueCat app,
/// supplies them. Its customer never buys.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    private static let bundle = "com.jackwallner.sports"
    private static let probe = ["RC_PROBE_USER": "qa-sports-journeys"]
    private static let freeArgs = ["-SidelineSafeScreenshot", "-rcfunnelprobe"]

    func test01OnboardingToFirstBriefing() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: Self.freeArgs)
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
        QA.launch(app, environment: Self.probe, arguments: Self.freeArgs + ["-DuoScreen", "brief"])
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
}
