import Foundation
import Shared
import XCTest

/// State machine audit repro suite (2026-11-06). Failing tests here assert the
/// behaviour the app's own copy or doc comments promise. Controls pass.
@MainActor
final class StateMachineAuditRepro: XCTestCase {
    // MARK: - Fixtures

    /// Answers per persona from a queue the test flips between success and failure.
    private final class ScriptedService: BriefingServing, @unchecked Sendable {
        var failure: Error?
        var generatedAt: Date = Date()

        func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
            if let failure { throw failure }
            return Briefing(
                persona: persona,
                scope: scope,
                refreshWindow: .morning,
                headline: "h-\(persona.rawValue)",
                tlDR: "t-\(persona.rawValue)",
                bullets: [
                    BriefingBullet(
                        talkingPoint: "p",
                        sourceHeadline: "s",
                        sourceURL: URL(string: "https://example.com/a")!
                    )
                ],
                suggestedQuestion: "q",
                sourceCount: 1,
                generatedAt: generatedAt
            )
        }
    }

    private var savedPending = false
    private var savedMoments = 0

    override func setUp() {
        super.setUp()
        savedPending = ReviewPromptTracker.hasPendingPositiveMoment
        savedMoments = ReviewPromptTracker.positiveMomentCount
        ReviewPromptTracker.hasPendingPositiveMoment = false
        UserDefaults.standard.removeObject(forKey: "sideline.lastPersona")
    }

    override func tearDown() {
        ReviewPromptTracker.hasPendingPositiveMoment = savedPending
        ReviewPromptTracker.positiveMomentCount = savedMoments
        super.tearDown()
    }

    private let offline = BriefingServiceError.network(underlying: URLError(.notConnectedToInternet))

    // MARK: - SM-1: positive-moment flag leaks past an offline fallback

    /// Promise: TodayBriefingViewModel.open doc comment, "Switches room without
    /// counting a positive moment: this follows a paywall, which never leads
    /// into a rating ask." and AGENTS.md "a paywall or Pro preview never does".
    func testSM1_OfflineRoomTapThenPurchaseDoesNotCountAPositiveMoment() async {
        let service = ScriptedService()
        let entitlement = LocalEntitlementStore(isPro: false)
        let vm = TodayBriefingViewModel(service: service, entitlement: entitlement)
        await vm.load()
        XCTAssertFalse(ReviewPromptTracker.hasPendingPositiveMoment, "precondition: no moment yet")

        // Offline, the user taps the Cocktail Party chip (the free room) again.
        service.failure = offline
        let selected = await vm.select(.cocktailParty)
        XCTAssertTrue(selected, "precondition: the free room is selectable")
        guard case .populated(_, isOffline: true) = vm.state else {
            return XCTFail("precondition: expected cached offline state, got \(vm.state)")
        }
        XCTAssertFalse(ReviewPromptTracker.hasPendingPositiveMoment, "precondition: offline load records nothing")

        // Back online, they buy Pro; the app opens the room they were unlocking.
        service.failure = nil
        entitlement.setProForDebug(true)
        await vm.entitlementDidChange(storedPersona: .dateNight)
        XCTAssertEqual(vm.selectedPersona, .dateNight, "precondition: the paywall flow opened the room")

        XCTAssertFalse(
            ReviewPromptTracker.hasPendingPositiveMoment,
            "a room opened after a paywall must not count a positive moment"
        )
    }

    /// Control: the same purchase with no offline tap before it records nothing.
    func testSM1_Control_PurchaseWithoutOfflineTapRecordsNothing() async {
        let service = ScriptedService()
        let entitlement = LocalEntitlementStore(isPro: false)
        let vm = TodayBriefingViewModel(service: service, entitlement: entitlement)
        await vm.load()
        entitlement.setProForDebug(true)
        await vm.entitlementDidChange(storedPersona: .dateNight)
        XCTAssertEqual(vm.selectedPersona, .dateNight, "precondition")
        XCTAssertFalse(ReviewPromptTracker.hasPendingPositiveMoment)
    }

    // MARK: - SM-2: any fetch error with a cache is shown as "Offline"

    /// Promise: TodayBriefingView.offlineBanner and FreshnessFooter, "Offline.
    /// Showing your last saved briefing." The device is online here; the server
    /// answered 503.
    func testSM2_ServerErrorIsNotLabelledOffline() async {
        let service = ScriptedService()
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: true))
        vm.selectedPersona = .officeWatercooler
        await vm.load()
        guard case .populated(_, isOffline: false) = vm.state else {
            return XCTFail("precondition: expected a live briefing, got \(vm.state)")
        }

        service.failure = BriefingServiceError.invalidResponse(statusCode: 503, body: "")
        await vm.load()
        guard case .populated(_, let isOffline) = vm.state else {
            return XCTFail("precondition: expected the cached briefing, got \(vm.state)")
        }
        XCTAssertFalse(isOffline, "a 503 from a reachable server was labelled Offline")
    }

    /// Control: a real connectivity failure is labelled Offline.
    func testSM2_Control_NoConnectionIsLabelledOffline() async {
        let service = ScriptedService()
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: true))
        vm.selectedPersona = .officeWatercooler
        await vm.load()
        service.failure = offline
        await vm.load()
        guard case .populated(_, let isOffline) = vm.state else {
            return XCTFail("expected the cached briefing, got \(vm.state)")
        }
        XCTAssertTrue(isOffline)
    }

    // MARK: - SM-3: reachability of an old cached briefing (render path is Code path)

    /// Passes. Shows the state the footer renders: a 5 day old briefing arrives
    /// as `.populated(_, isOffline: true)` with nothing in the state that marks
    /// it stale. The footer text for that state is in FreshnessFooter.swift:61-63.
    func testSM3_FiveDayOldCacheIsServedAsPopulatedOffline() async {
        let service = ScriptedService()
        service.generatedAt = Date().addingTimeInterval(-5 * 86_400)
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: true))
        vm.selectedPersona = .sportsTalkForMoms
        await vm.load()
        service.failure = offline
        await vm.load()
        guard case .populated(let briefing, isOffline: true) = vm.state else {
            return XCTFail("expected cached offline state, got \(vm.state)")
        }
        XCTAssertGreaterThan(Date().timeIntervalSince(briefing.generatedAt), 4 * 86_400)
    }

    // MARK: - Product call evidence

    /// Passes. A free user on the free room gets a newer row on foreground,
    /// the same as Pro, so "Pro refreshes 3 times a day" is not a difference
    /// between the tiers.
    func testProductCall_FreeUserForegroundReloadSwapsInNewerRow() async {
        let service = ScriptedService()
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: false))
        await vm.load()
        guard case .populated(let first, _) = vm.state else { return XCTFail("precondition") }
        XCTAssertEqual(vm.selectedPersona, .cocktailParty)

        // A new generation lands: the fake returns a fresh row (new id).
        await vm.reloadIfStale(olderThan: 0)
        guard case .populated(let second, isOffline: false) = vm.state else { return XCTFail("got \(vm.state)") }
        XCTAssertNotEqual(first.id, second.id)
    }
}
