import XCTest

/// Persona audit: a tired, busy user who is interrupted mid-task and returns
/// later, expecting state and context to survive. Deterministic (DEBUG
/// `-SidelineScreenshotDemo` sample service, no network, no RevenueCat, no
/// purchase). Observations are recorded as attachments and a log, not asserted,
/// so one run yields every screenshot.
final class InterruptedUserAuditUITests: XCTestCase {
    private var log: [String] = []

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        let a = XCTAttachment(string: log.joined(separator: "\n"))
        a.name = "observations"
        a.lifetime = .keepAlways
        add(a)
    }

    private func makeApp(
        onboarded: Bool? = true,
        pro: Bool = false,
        persona: String? = "cocktail_party",
        swiped: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sports")
        var args = ["-SidelineScreenshotDemo"]
        if let persona { args += ["-sideline.lastPersona", persona] }
        if let onboarded { args += ["-sideline.hasCompletedOnboarding", onboarded ? "YES" : "NO"] }
        args += ["-sideline.hasSwipedDeck", swiped ? "YES" : "NO"]
        if pro { args.append("-SidelineForcePro") }
        app.launchArguments += args
        return app
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func note(_ s: String) {
        log.append(s)
        print("AUDIT: \(s)")
    }

    private func settle(_ s: TimeInterval = 1.0) { Thread.sleep(forTimeInterval: s) }

    private func cardValue(_ app: XCUIApplication) -> String {
        let p = NSPredicate(format: "value BEGINSWITH 'Card '")
        let e = app.descendants(matching: .any).matching(p).firstMatch
        return e.exists ? "\(e.value ?? "?")" : "no card value"
    }

    private func has(_ app: XCUIApplication, _ fragment: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch.exists
    }

    private func background(_ app: XCUIApplication, seconds: TimeInterval = 4) {
        XCUIDevice.shared.press(.home)
        settle(seconds)
        app.activate()
        settle(1.5)
    }

    /// I1: mid-deck, flipped to the backstory, phone call / home press, return.
    func testI1_backgroundMidDeck() {
        let app = makeApp()
        app.launch(); settle(2.0)
        app.swipeLeft(); settle(0.7)
        app.swipeLeft(); settle(0.7)
        app.swipeLeft(); settle(0.7)
        app.tap(); settle(1.0)
        note("I1 before background: \(cardValue(app)) backstoryHint=\(has(app, "Tap to flip back"))")
        shot("I1a-card4-flipped")
        background(app)
        shot("I1b-after-return")
        note("I1 after background return: \(cardValue(app)) backstoryHint=\(has(app, "Tap to flip back")) loading=\(app.staticTexts["Loading briefing"].exists)")
    }

    /// I2: the app is killed while the user is on card 4 (memory pressure,
    /// swipe-up from the switcher), then reopened.
    func testI2_killAndRelaunchMidDeck() {
        let app = makeApp()
        app.launch(); settle(2.0)
        for _ in 0..<3 { app.swipeLeft(); settle(0.7) }
        note("I2 before kill: \(cardValue(app))")
        shot("I2a-card4")
        app.terminate(); settle(1.0)
        app.launch(); settle(2.5)
        shot("I2b-after-relaunch")
        note("I2 after relaunch: \(cardValue(app))")
    }

    /// I3: an interrupted user swipes the wrong way / one card too far. Is there
    /// any way back?
    func testI3_overswipeRecovery() {
        let app = makeApp()
        app.launch(); settle(2.0)
        app.swipeLeft(); settle(0.7)
        app.swipeLeft(); settle(0.7)
        note("I3 on card: \(cardValue(app))")
        shot("I3a-card3")
        app.swipeRight(); settle(0.8)
        note("I3 after swipe RIGHT (expecting back): \(cardValue(app))")
        shot("I3b-after-swipe-right")
        let back = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'previous' OR label CONTAINS[c] 'back'")).firstMatch
        note("I3 visible back/previous control exists=\(back.exists)")
        let dots = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'page'"))
        note("I3 tappable page dots=\(dots.count)")
    }

    /// I4: interrupted during first-run onboarding (page 2), then killed.
    func testI4_onboardingInterrupted() {
        let app = makeApp(onboarded: false, swiped: false)
        app.launch(); settle(1.5)
        app.buttons["Start"].tap(); settle(1.0)
        shot("I4a-persona-page")
        background(app)
        shot("I4b-persona-page-after-background")
        note("I4 after background: still on persona page=\(has(app, "Start with your free briefing"))")
        app.terminate(); settle(1.0)
        app.launch(); settle(1.5)
        shot("I4c-after-kill-relaunch")
        note("I4 after kill: on value-prop page=\(has(app, "Sports, made simple."))  on persona page=\(has(app, "Start with your free briefing"))")
    }

    /// I5: the user opens a locked room, reaches the paywall, gets interrupted.
    func testI5_paywallInterrupted() {
        let app = makeApp()
        app.launch(); settle(2.0)
        app.buttons["Date Night, Pro context"].tap(); settle(1.0)
        shot("I5a-pro-preview")
        background(app)
        shot("I5b-preview-after-background")
        let unlock = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Unlock' OR label BEGINSWITH 'Try'")).firstMatch
        note("I5 preview survives background=\(unlock.exists)")
        unlock.tap(); settle(2.0)
        shot("I5c-paywall")
        background(app)
        shot("I5d-paywall-after-background")
        note("I5 paywall survives background (Restore visible)=\(app.buttons["Restore Purchases"].exists)")
        app.buttons["Not now"].tap(); settle(1.0)
        shot("I5e-after-not-now")
        note("I5 after Not now: \(cardValue(app)) cocktailSelected=\(app.buttons["Cocktail Party, selected"].exists) dateNightSelected=\(app.buttons["Date Night, selected"].exists)")
    }

    /// I6: Pro user changes room, app is killed, reopened. Which room and card?
    func testI6_roomPersistsAcrossRelaunch() {
        let app = makeApp(pro: true, persona: nil)
        app.launch(); settle(2.0)
        app.buttons["Office Watercooler"].tap(); settle(2.0)
        app.swipeLeft(); settle(0.7)
        app.swipeLeft(); settle(0.7)
        note("I6 before kill: \(cardValue(app)) officeSelected=\(app.buttons["Office Watercooler, selected"].exists)")
        shot("I6a-office-card3")
        app.terminate(); settle(1.0)
        app.launch(); settle(2.5)
        shot("I6b-after-relaunch")
        note("I6 after relaunch: \(cardValue(app)) officeSelected=\(app.buttons["Office Watercooler, selected"].exists) cocktailSelected=\(app.buttons["Cocktail Party, selected"].exists)")
        // Restore default so later tests are not affected.
        app.buttons["Cocktail Party"].tap(); settle(1.0)
    }

    /// I7: user opens a source from a card, is pulled away, returns, closes it.
    func testI7_sourceSheetThenReturn() {
        let app = makeApp()
        app.launch(); settle(2.0)
        app.swipeLeft(); settle(0.7)
        app.swipeLeft(); settle(0.7)
        app.tap(); settle(1.0)
        let learn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Learn more'")).firstMatch
        note("I7 before source: \(cardValue(app)) learnMore=\(learn.exists)")
        if learn.exists {
            learn.tap(); settle(2.5)
            shot("I7a-source-sheet")
            background(app)
            shot("I7b-source-sheet-after-background")
        }
        // Dismiss whatever is up (SFSafariViewController Done, or swipe down).
        if app.buttons["Done"].exists { app.buttons["Done"].tap() } else { app.swipeDown() }
        settle(1.5)
        shot("I7c-after-source-closed")
        note("I7 after source closed: \(cardValue(app)) backstoryHint=\(has(app, "Tap to flip back"))")
    }

    /// I8: Pro manual refresh from Settings: where does the user land and does
    /// the deck keep its place?
    func testI8_proRefreshKeepsPlace() {
        let app = makeApp(pro: true)
        app.launch(); settle(2.0)
        for _ in 0..<3 { app.swipeLeft(); settle(0.6) }
        note("I8 before refresh: \(cardValue(app))")
        app.buttons["Settings"].tap(); settle(1.0)
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Manual refresh'")).firstMatch.tap()
        settle(0.15)
        shot("I8a-refresh-immediate")
        settle(2.0)
        shot("I8b-refresh-settled")
        note("I8 after refresh: \(cardValue(app))")
    }
}
