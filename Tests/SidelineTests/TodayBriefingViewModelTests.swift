import Foundation
import Shared
import XCTest

@MainActor
final class TodayBriefingViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "sideline.lastFreeRefreshDay")
        UserDefaults.standard.removeObject(forKey: "sideline.lastPersona")
    }

    private func makeBriefing(
        tlDR: String = "Test TLDR",
        persona: Persona = .cocktailParty,
        generatedAt: Date = Date()
    ) -> Briefing {
        Briefing(
            persona: persona,
            scope: .national,
            refreshWindow: .daily,
            headline: "Test headline",
            tlDR: tlDR,
            bullets: [
                BriefingBullet(
                    talkingPoint: "Test point",
                    sourceHeadline: "Test - Source",
                    sourceURL: URL(string: "https://example.com/test")!
                )
            ],
            suggestedQuestion: "Test question?",
            sourceCount: 1,
            generatedAt: generatedAt
        )
    }

    // MARK: - Mocks

    private final class MockService: BriefingServing, @unchecked Sendable {
        var result: Result<Briefing, Error>?

        func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
            guard let result else {
                throw BriefingServiceError.emptyResult
            }
            return try result.get()
        }
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        let vm = TodayBriefingViewModel(
            service: MockService(),
            entitlement: LocalEntitlementStore()
        )

        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.selectedPersona, .cocktailParty)
        XCTAssertNil(vm.lastBriefing)
    }

    // MARK: - Foreground reload

    func testForegroundReloadSwapsInANewerRow() async {
        let service = MockService()
        service.result = .success(makeBriefing(tlDR: "Morning"))
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())
        await vm.load()

        service.result = .success(makeBriefing(tlDR: "Evening"))
        await vm.reloadIfStale(olderThan: 0)

        guard case .populated(let briefing, savedBecause: nil) = vm.state else {
            return XCTFail("Expected .populated, got \(vm.state)")
        }
        XCTAssertEqual(briefing.tlDR, "Evening")
    }

    func testForegroundReloadKeepsTheDeckForTheSameRow() async {
        let service = MockService()
        let morning = makeBriefing(tlDR: "Morning")
        service.result = .success(morning)
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())
        await vm.load()

        await vm.reloadIfStale(olderThan: 0)

        XCTAssertEqual(vm.state, .populated(morning, savedBecause: nil))
    }

    func testForegroundReloadSkipsARecentFetch() async {
        let service = MockService()
        let morning = makeBriefing(tlDR: "Morning")
        service.result = .success(morning)
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())
        await vm.load()

        service.result = .success(makeBriefing(tlDR: "Evening"))
        await vm.reloadIfStale()

        XCTAssertEqual(vm.state, .populated(morning, savedBecause: nil))
    }

    func testForegroundReloadFailureKeepsTheBriefingOnScreen() async {
        let service = MockService()
        let morning = makeBriefing(tlDR: "Morning")
        service.result = .success(morning)
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())
        await vm.load()

        service.result = .failure(BriefingServiceError.network(underlying: URLError(.notConnectedToInternet)))
        await vm.reloadIfStale(olderThan: 0)

        XCTAssertEqual(vm.state, .populated(morning, savedBecause: nil))
    }

    // MARK: - Entitlement changes

    func testBuyingProOpensTheRoomTheUserWasUnlocking() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let entitlement = LocalEntitlementStore(isPro: false)
        let vm = TodayBriefingViewModel(service: service, entitlement: entitlement)
        await vm.load()

        let selected = await vm.select(.dateNight)
        XCTAssertFalse(selected)
        entitlement.setProForDebug(true)
        await vm.entitlementDidChange(storedPersona: .cocktailParty)

        XCTAssertEqual(vm.selectedPersona, .dateNight)
        XCTAssertNil(vm.roomAwaitingUnlock)
    }

    func testClosingThePreviewForgetsTheRoom() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let entitlement = LocalEntitlementStore(isPro: false)
        let vm = TodayBriefingViewModel(service: service, entitlement: entitlement)
        await vm.load()

        _ = await vm.select(.dateNight)
        vm.clearRoomAwaitingUnlock()
        entitlement.setProForDebug(true)
        await vm.entitlementDidChange(storedPersona: .officeWatercooler)

        XCTAssertEqual(vm.selectedPersona, .officeWatercooler)
    }

    func testLapsedProLeavesThePaidRoom() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let entitlement = LocalEntitlementStore(isPro: true)
        let vm = TodayBriefingViewModel(service: service, entitlement: entitlement)
        _ = await vm.select(.dateNight)
        XCTAssertEqual(vm.selectedPersona, .dateNight)

        entitlement.setProForDebug(false)
        await vm.entitlementDidChange(storedPersona: .dateNight)

        XCTAssertEqual(vm.selectedPersona, .cocktailParty)
    }

    // MARK: - Load

    func testLoadPopulatesBriefing() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())

        await vm.load()

        guard case .populated(let briefing, let savedBecause) = vm.state else {
            XCTFail("Expected .populated, got \(vm.state)")
            return
        }
        XCTAssertEqual(briefing.tlDR, "Test TLDR")
        XCTAssertNil(savedBecause)
    }

    func testLoadFailureTransitionsToFailed() async {
        let service = MockService()
        service.result = .failure(BriefingServiceError.emptyResult)
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())

        // Use a persona that hasn't been cached by any preceding test
        vm.selectedPersona = .sportsTalkForMoms

        await vm.load()

        guard case .failed(let message) = vm.state else {
            XCTFail("Expected .failed, got \(vm.state)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Select Persona

    func testSelectFreePersonaWithoutProSucceeds() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        let didSelect = await vm.select(.cocktailParty)

        XCTAssertTrue(didSelect)
        XCTAssertEqual(vm.selectedPersona, .cocktailParty)
    }

    func testSelectLockedPersonaWithoutProReturnsFalse() async {
        let service = MockService()
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        let didSelect = await vm.select(.dateNight)

        XCTAssertFalse(didSelect)
        XCTAssertEqual(vm.selectedPersona, .cocktailParty)
    }

    func testSelectLockedPersonaWithProSucceeds() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: true)
        )

        let didSelect = await vm.select(.dateNight)

        XCTAssertTrue(didSelect)
        XCTAssertEqual(vm.selectedPersona, .dateNight)
    }

    // MARK: - Refresh

    func testRefreshOnFreePersonaWorksWithoutPro() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        await vm.load()
        await vm.refresh()

        guard case .populated = vm.state else {
            XCTFail("Expected .populated after refresh on free persona, got \(vm.state)")
            return
        }
    }

    func testSecondFreeRefreshSameDayHitsLimit() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        await vm.load()
        await vm.refresh()
        guard case .populated = vm.state else {
            XCTFail("First refresh should populate, got \(vm.state)")
            return
        }

        await vm.refresh()
        XCTAssertEqual(vm.state, .refreshLimit)
    }

    func testRefreshOnLockedPersonaHitsLimitForNonPro() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        // Simulate having selected a locked persona (e.g. via state restoration)
        vm.selectedPersona = .dateNight
        await vm.refresh()

        XCTAssertEqual(vm.state, .refreshLimit)
    }

    func testRefreshOnLockedPersonaWorksWithPro() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: true)
        )

        await vm.load()
        _ = await vm.select(.officeWatercooler)
        await vm.refresh()

        guard case .populated = vm.state else {
            XCTFail("Expected .populated after pro refresh, got \(vm.state)")
            return
        }
    }

    // MARK: - Stale responses

    /// Slow responder for the persona the user is leaving; instant for the rest.
    private final class DelayedMockService: BriefingServing, @unchecked Sendable {
        func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing {
            if persona == .cocktailParty {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            return Briefing(
                persona: persona,
                scope: scope,
                refreshWindow: .daily,
                headline: "h",
                tlDR: persona.rawValue,
                bullets: [],
                suggestedQuestion: "q",
                sourceCount: 1,
                generatedAt: Date()
            )
        }
    }

    func testSlowStaleLoadDoesNotOverwriteNewerSelection() async {
        let vm = TodayBriefingViewModel(
            service: DelayedMockService(),
            entitlement: LocalEntitlementStore(isPro: true)
        )

        let slowLoad = Task { await vm.load() } // cocktailParty, slow
        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = await vm.select(.dateNight) // resolves before the slow response lands
        await slowLoad.value

        guard case .populated(let briefing, _) = vm.state else {
            XCTFail("Expected .populated, got \(vm.state)")
            return
        }
        XCTAssertEqual(briefing.persona, .dateNight, "Stale cocktailParty response overwrote the newer selection")
    }

    // MARK: - Last Briefing

    func testLastBriefingIsSetAfterSuccessfulLoad() async {
        let service = MockService()
        service.result = .success(makeBriefing())
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())

        await vm.load()

        XCTAssertNotNil(vm.lastBriefing)
        XCTAssertEqual(vm.lastBriefing?.tlDR, "Test TLDR")
    }

    func testLastBriefingUpdatesOnSubsequentLoad() async {
        let service = MockService()

        let first = makeBriefing(tlDR: "First")
        let second = makeBriefing(tlDR: "Second")

        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore())

        service.result = .success(first)
        await vm.load()
        XCTAssertEqual(vm.lastBriefing?.tlDR, "First")

        service.result = .success(second)
        await vm.load()
        XCTAssertEqual(vm.lastBriefing?.tlDR, "Second")
    }

    func testLastBriefingSurvivesRefreshLimit() async {
        let service = MockService()
        service.result = .success(makeBriefing(tlDR: "Original"))
        let vm = TodayBriefingViewModel(
            service: service,
            entitlement: LocalEntitlementStore(isPro: false)
        )

        await vm.load()
        XCTAssertEqual(vm.lastBriefing?.tlDR, "Original")

        // Switch persona to trigger refreshLimit, lastBriefing should still be intact
        vm.selectedPersona = .dateNight
        await vm.refresh()

        XCTAssertEqual(vm.state, .refreshLimit)
        XCTAssertEqual(vm.lastBriefing?.tlDR, "Original")
    }

    // MARK: - Saved copy

    private let noConnection = BriefingServiceError.network(underlying: URLError(.notConnectedToInternet))

    /// Loads a live Office Watercooler row (cached), then fails the next load
    /// with `failure` and returns why the saved copy is on screen.
    private func savedCopyReason(after failure: Error) async -> SavedCopyReason? {
        let service = MockService()
        service.result = .success(makeBriefing(persona: .officeWatercooler))
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: true))
        vm.selectedPersona = .officeWatercooler
        await vm.load()

        service.result = .failure(failure)
        await vm.load()
        guard case .populated(_, let savedBecause) = vm.state else {
            XCTFail("Expected the saved copy, got \(vm.state)")
            return nil
        }
        return savedBecause
    }

    func testNoConnectionShowsTheSavedCopyAsOffline() async {
        let reason = await savedCopyReason(after: noConnection)
        XCTAssertEqual(reason, .offline)
    }

    func testServerErrorIsNotLabelledOffline() async {
        let reason = await savedCopyReason(after: BriefingServiceError.invalidResponse(statusCode: 503, body: ""))
        XCTAssertEqual(reason, .serverUnavailable)
    }

    func testEmptyResultIsNotLabelledOffline() async {
        let reason = await savedCopyReason(after: BriefingServiceError.emptyResult)
        XCTAssertEqual(reason, .serverUnavailable)
    }

    func testUndecodableBodyIsNotLabelledOffline() async {
        let decodeFailure = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "new row shape"))
        let reason = await savedCopyReason(after: decodeFailure)
        XCTAssertEqual(reason, .serverUnavailable)
    }

    func testServerUnavailableBannerDoesNotSayOffline() {
        XCTAssertFalse(SavedCopyReason.serverUnavailable.bannerText.contains("Offline"))
        XCTAssertNotEqual(SavedCopyReason.serverUnavailable.bannerIcon, SavedCopyReason.offline.bannerIcon)
    }

    /// A five-day-old saved row opened offline: the footer gives its age and
    /// the stale warning, the same as a live row that old.
    func testOldSavedCopyShowsItsAgeAndTheStaleWarning() async {
        let service = MockService()
        service.result = .success(makeBriefing(persona: .dateNight, generatedAt: Date().addingTimeInterval(-5 * 86_400)))
        let vm = TodayBriefingViewModel(service: service, entitlement: LocalEntitlementStore(isPro: true))
        vm.selectedPersona = .dateNight
        await vm.load()
        service.result = .failure(noConnection)
        await vm.load()
        guard case .populated(let briefing, let savedBecause) = vm.state else {
            return XCTFail("Expected the saved copy, got \(vm.state)")
        }
        XCTAssertEqual(savedBecause, .offline)

        let now = Date()
        let freshness = BriefingFreshness(briefing: briefing, savedBecause: savedBecause)
        let text = freshness.text(now: now)
        XCTAssertTrue(freshness.isStale(now: now))
        XCTAssertTrue(text.hasPrefix("Updated "), text)
        XCTAssertTrue(text.hasSuffix("Double-check before quoting."), text)
        XCTAssertFalse(text.contains("Offline"), text)
        XCTAssertTrue(freshness.accessibilityText(now: now).contains("double-check"))
        XCTAssertEqual(freshness.iconName(now: now), "exclamationmark.triangle")
        XCTAssertFalse(freshness.showsNextRefreshHint(now: now))
    }

    func testRecentSavedCopyShowsItsAge() {
        let now = Date()
        let briefing = makeBriefing(generatedAt: now.addingTimeInterval(-2 * 3_600))
        for reason in [SavedCopyReason.offline, .serverUnavailable] {
            let freshness = BriefingFreshness(briefing: briefing, savedBecause: reason)
            XCTAssertFalse(freshness.isStale(now: now))
            XCTAssertTrue(freshness.text(now: now).hasPrefix("Updated "), freshness.text(now: now))
            XCTAssertTrue(freshness.accessibilityText(now: now).hasPrefix("Updated "))
        }
        XCTAssertEqual(BriefingFreshness(briefing: briefing, savedBecause: .offline).iconName(now: now), "wifi.slash")
    }
}
