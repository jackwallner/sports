import XCTest

/// Proves the `converted_*` half of the fleet paywall record actually reaches
/// RevenueCat, not just the impression half.
///
/// `rc-funnel-probe` drives an impression and reads the `pitch_views_*`
/// attributes back, but it cannot buy anything: RevenueCat's Test Store puts up
/// its own confirmation sheet and `simctl` has no way to tap it. This does.
///
/// Test Store purchases are simulated. No StoreKit, no App Store, no revenue,
/// no real transaction, and the customer it creates cannot appear in App Store
/// charts. A Test Store subscription expires five minutes after purchase, so
/// read the attributes promptly:
///
///     rc-funnel-attributes gist --user <the id this run used>
final class PaywallFunnelUITests: XCTestCase {

    func testTestStorePurchaseRecordsTheConversion() {
        let probeUser = ProcessInfo.processInfo.environment["RC_PROBE_USER"]
            ?? "funnel-probe-gist-uitest"

        // Addressed by bundle id rather than by the implicit initialiser: several
        // apps in this fleet have a PRODUCT_NAME that differs from the target
        // name, and XCUIApplication() cannot resolve those, failing with "pid 0".
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sports")
        app.launchArguments += ["-rcfunnelprobe", "-rcfunnelprobepurchase"]
        app.launchEnvironment["RC_PROBE_USER"] = probeUser
        app.launch()

        // Offerings have to load before the sheet can appear, so this waits
        // rather than checking once.
        let confirm = app.buttons["Test valid purchase"]
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 60),
            "RevenueCat's Test Store sheet never appeared, so no purchase was attempted"
        )
        confirm.tap()

        // `setAttributes` only queues. A purchase flushes it on its own, because
        // RevenueCat folds pending attributes into the receipt POST, but
        // backgrounding is the guaranteed trigger so it is done too when the app
        // is still alive. It is not always: some apps finish the purchase and the
        // runner has already let go of them, which is not a failure of what this
        // test checks.
        sleep(10)
        if app.state == .runningForeground {
            XCUIDevice.shared.press(.home)
            sleep(10)
        }
    }
}

/// Persona audit flows (experienced, repeat user). Deterministic: the DEBUG
/// `-SidelineScreenshotDemo` sample service, no network, no RevenueCat, no
/// purchase. These record observations as attachments and a log instead of
/// failing on them, so one run yields every screenshot. Kept in this file so
/// the generated project needs no new source entry.
final class ExperiencedUserAuditUITests: XCTestCase {
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

    private func launch(
        onboarded: Bool = true,
        pro: Bool = false,
        swiped: Bool = true,
        extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sports")
        var args = ["-SidelineScreenshotDemo", "-sideline.lastPersona", "cocktail_party"]
        args += ["-sideline.hasCompletedOnboarding", onboarded ? "YES" : "NO"]
        args += ["-sideline.hasSwipedDeck", swiped ? "YES" : "NO"]
        if pro { args.append("-SidelineForcePro") }
        app.launchArguments += args + extra
        app.launch()
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

    private func frameNote(_ label: String, _ e: XCUIElement) {
        if e.exists {
            let f = e.frame
            note("\(label) frame w=\(Int(f.width)) h=\(Int(f.height)) x=\(Int(f.minX)) y=\(Int(f.minY))")
        } else {
            note("\(label) NOT FOUND")
        }
    }

    private func has(_ app: XCUIApplication, _ fragment: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch.exists
    }

    private func settle(_ s: TimeInterval = 1.0) { Thread.sleep(forTimeInterval: s) }

    /// The deck's card position, from its VoiceOver value.
    private func cardValue(_ app: XCUIApplication) -> String {
        let p = NSPredicate(format: "value BEGINSWITH 'Card '")
        let e = app.descendants(matching: .any).matching(p).firstMatch
        return e.exists ? "\(e.value ?? "?")" : "no card value"
    }

    func testA_firstRunOnboarding() {
        let app = launch(onboarded: false, swiped: false)
        settle()
        shot("A1-onboarding-page1")
        let start = app.buttons["Start"]
        note("Start exists=\(start.exists)")
        frameNote("Start button", start)
        start.tap(); settle()
        shot("A2-onboarding-persona-pick")
        let locked = app.buttons["Date Night, unlocks with Gist Pro"]
        frameNote("Locked Date Night row", locked)
        locked.tap(); settle(0.8)
        shot("A3-after-tap-locked-row")
        note("After tapping locked onboarding row, sheet/paywall present=\(app.sheets.count + app.otherElements["PopoverDismissRegion"].count)")
        app.buttons["See today's briefing"].tap()
        settle(2.0)
        shot("A4-first-deck-with-hint")
        note("First deck card value: \(cardValue(app))")
        note("Nav title Gist? \(app.navigationBars["Gist"].exists) SportsCheatSheet? \(app.navigationBars["Sports Cheat Sheet"].exists)")
    }

    func testB_freeDeckWalk() {
        let app = launch()
        settle(2.0)
        shot("B0-lead-card")
        note("start value: \(cardValue(app))")
        var seen: [String] = []
        for i in 1...7 {
            app.swipeLeft()
            settle(0.7)
            seen.append(cardValue(app))
            shot("B\(i)-after-swipe-left-\(i)")
        }
        note("values after 7 left swipes: \(seen)")
        // Reverse direction: does a right swipe go back, or forward?
        let before = cardValue(app)
        app.swipeRight()
        settle(0.7)
        let after = cardValue(app)
        shot("B8-after-swipe-right")
        note("swipe right: \(before) -> \(after)")
        // Can a user jump via the page dots?
        let dots = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'page'"))
        note("page-dot accessibility elements=\(dots.count)")
    }

    func testC_flipCopySource() {
        let app = launch()
        settle(1.5)
        app.swipeLeft(); settle(0.8)
        shot("C0-story-front")
        app.tap(); settle(1.0)
        shot("C1-story-back")
        let learn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Learn more'")).firstMatch
        frameNote("Learn more source button", learn)
        app.tap(); settle(0.8)
        shot("C2-after-second-tap")
        app.press(forDuration: 1.2); settle(0.8)
        shot("C3-long-press-menu")
        note("Context menu Copy exists=\(app.buttons["Copy"].exists) Share exists=\(app.buttons["Share"].exists)")
        if app.buttons["Copy"].exists { app.buttons["Copy"].tap() }
        settle(0.5)
        shot("C4-after-copy")
        if learn.exists {
            learn.tap(); settle(2.0)
            shot("C5-source-sheet")
        }
    }

    func testD_lockedRoomPath() {
        let app = launch()
        settle(1.5)
        shot("D0-rail")
        for name in ["Cocktail Party, selected", "Sports Talk for Moms, Pro context", "Office Watercooler, Pro context", "Date Night, Pro context"] {
            frameNote("Chip \(name)", app.buttons[name])
        }
        frameNote("Settings button", app.buttons["Settings"])
        let t0 = Date()
        app.buttons["Date Night, Pro context"].tap()
        settle(1.0)
        shot("D1-pro-preview")
        let unlock = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Unlock' OR label BEGINSWITH 'Try'")).firstMatch
        frameNote("Unlock button", unlock)
        unlock.tap()
        settle(2.0)
        shot("D2-after-unlock-tap")
        note("Preview -> paywall chain took ~\(Date().timeIntervalSince(t0))s incl. sleeps; paywall visible via Restore=\(app.buttons["Restore Purchases"].exists)")
        let close = app.buttons["Close"]
        note("Paywall close button exists=\(close.exists)")
        shot("D3-paywall")
        if close.exists { close.tap() } else { app.swipeDown() }
        settle(1.0)
        shot("D4-back-on-deck")
        note("After paywall dismissal, chip state: cocktail selected=\(app.buttons["Cocktail Party, selected"].exists) value=\(cardValue(app))")
    }

    func testE_refreshAffordancesFree() {
        let app = launch()
        settle(1.5)
        app.swipeDown(); settle(1.0)
        shot("E0-after-swipe-down-pull")
        note("Pull-down did anything? loading=\(app.staticTexts["Loading briefing"].exists)")
        app.buttons["Settings"].tap(); settle(1.0)
        shot("E1-settings")
        let refresh = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Manual refresh'")).firstMatch
        frameNote("Manual refresh row", refresh)
        refresh.tap(); settle(1.5)
        shot("E2-free-manual-refresh-tap")
        note("Free manual refresh -> paywall? Restore visible=\(app.buttons["Restore Purchases"].exists)")
    }

    func testF_proSwitchAndRefresh() {
        let app = launch(pro: true)
        settle(1.5)
        shot("F0-pro-lead")
        for _ in 0..<3 { app.swipeLeft(); settle(0.6) }
        note("before room switch: \(cardValue(app))")
        shot("F1-pro-card3")
        app.buttons["Office Watercooler"].tap()
        settle(0.3)
        shot("F2-room-switch-immediate")
        settle(1.5)
        shot("F3-room-switch-settled")
        note("after switch to office: \(cardValue(app)) tlDR-prefixed=\(has(app, "Office Watercooler:"))")
        app.buttons["Cocktail Party"].tap()
        settle(1.5)
        note("switch back to cocktail: \(cardValue(app))")
        shot("F4-back-to-cocktail")
        app.swipeLeft(); settle(0.6)
        app.buttons["Settings"].tap(); settle(0.8)
        let refresh = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Manual refresh'")).firstMatch
        refresh.tap()
        settle(0.2)
        shot("F5-refresh-immediate")
        settle(1.5)
        shot("F6-refresh-settled")
        note("after manual refresh: \(cardValue(app))")
        // Background and return: does the briefing refresh?
        XCUIDevice.shared.press(.home); settle(2.0)
        app.activate(); settle(1.5)
        shot("F7-after-background-return")
    }

    func testG_largeTextRail() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"])
        settle(2.0)
        shot("G0-axxl-deck")
        for name in ["Cocktail Party, selected", "Date Night, Pro context"] {
            frameNote("AXXL chip \(name)", app.buttons[name])
        }
        app.swipeLeft(); settle(0.8)
        app.tap(); settle(1.0)
        shot("G1-axxl-story-back")
    }

    func testH_darkDeck() {
        let app = launch(extra: ["-AppleInterfaceStyle", "Dark"])
        settle(2.0)
        shot("H0-dark-lead")
        app.swipeLeft(); settle(0.8)
        shot("H1-dark-story")
        for _ in 0..<4 { app.swipeLeft(); settle(0.6) }
        shot("H2-dark-rooms-card")
    }
}
