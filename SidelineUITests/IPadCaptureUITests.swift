import XCTest

/// Layout capture for iPad: every main screen plus onboarding, the Pro
/// preview and the paywall, in portrait and landscape, attached as
/// screenshots for a visual pass. Reachability is never asserted, so one
/// missed screen does not hide the rest.
@MainActor
final class IPadCaptureUITests: XCTestCase {

    private static let bundle = "com.jackwallner.sports"
    private static let probe = ["RC_PROBE_USER": "qa-sports-ipad-\(UUID().uuidString.prefix(8))"]
    private var shotNumber = 0

    func testCapturePortrait() { capture(.portrait, "portrait") }

    func testCaptureLandscape() { capture(.landscapeLeft, "landscape") }

    /// Raw store evidence: the Cocktail Party deck on each card, portrait, with
    /// the safe screenshot briefings. Card 4 is "Your move".
    func testCaptureStore() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        for (name, card) in [("lead", 0), ("story1", 1), ("story2", 2), ("story3", 3), ("question", 4)] {
            let app = launch(["-SidelineSafeScreenshot", "-SidelineForcePro", "-DuoScreen", "brief",
                              "-SidelineDeckStart", "\(card)"], .portrait)
            sleep(6)
            shot(app, "store-\(name)")
            app.terminate()
        }
    }

    /// The first story flipped to its backstory.
    func testCaptureStoreBack() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-SidelineSafeScreenshot", "-SidelineForcePro", "-DuoScreen", "brief",
                          "-SidelineDeckStart", "1"], .portrait)
        sleep(6)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45)).tap()
        sleep(3)
        shot(app, "store-back")
    }

    private func capture(_ orientation: UIDeviceOrientation, _ label: String) {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = orientation
        let filter = ProcessInfo.processInfo.environment["IPAD_SCREENS"]?.split(separator: ",").map(String.init)
        func wants(_ name: String) -> Bool { filter?.contains(name) ?? true }

        for screen in ["brief", "story", "question", "settings"] where wants(screen) {
            let app = launch(["-SidelineSafeScreenshot", "-SidelineForcePro", "-DuoScreen", screen], orientation)
            sleep(6)
            shot(app, "\(label)-\(screen)")
            app.terminate()
        }

        if wants("onboarding") {
            let app = launch(["-SidelineSafeScreenshot", "-rcfunnelprobe", "-SidelineFreshOnboarding"], orientation)
            let start = app.buttons["Start"]
            _ = start.waitForExistence(timeout: 20)
            shot(app, "\(label)-onboarding-1")
            start.tap()
            let briefing = app.buttons["See today's briefing"]
            _ = briefing.waitForExistence(timeout: 10)
            shot(app, "\(label)-onboarding-2")
            app.terminate()
        }

        if wants("paywall") {
            let app = launch(["-SidelineScreenshotDemo", "-rcfunnelprobe", "-DuoScreen", "brief"], orientation)
            let proRoom = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Pro context")).firstMatch
            _ = proRoom.waitForExistence(timeout: 20)
            proRoom.tap()
            let seePro = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Try ' OR label BEGINSWITH 'Unlock '")).firstMatch
            _ = seePro.waitForExistence(timeout: 10)
            sleep(2)
            shot(app, "\(label)-preview")
            seePro.tap()
            _ = app.buttons["Not now"].waitForExistence(timeout: 15)
            sleep(3)
            shot(app, "\(label)-paywall")
            app.terminate()
        }
    }

    private func launch(_ arguments: [String], _ orientation: UIDeviceOrientation) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        app.terminate()
        QA.launch(app, environment: Self.probe, arguments: arguments)
        XCUIDevice.shared.orientation = orientation
        sleep(2)
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        shotNumber += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", shotNumber, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
