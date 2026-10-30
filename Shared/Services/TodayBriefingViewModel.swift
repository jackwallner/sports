import Foundation
import Observation

@Observable
@MainActor
public final class TodayBriefingViewModel {
    public enum LoadState: Equatable {
        case idle
        case loading
        case populated(Briefing, isOffline: Bool)
        case failed(String)
        case refreshLimit
    }

    public var selectedPersona: Persona = TodayBriefingViewModel.initialPersona()
    public var state: LoadState = .idle
    public private(set) var lastBriefing: Briefing?
    /// When the last successful fetch landed, so coming back to the app
    /// refetches only once the briefing on screen may have been replaced.
    public private(set) var lastFetchedAt: Date?
    /// The locked room the user last asked for, opened once Pro unlocks it.
    public private(set) var roomAwaitingUnlock: Persona?

    private static let lastPersonaKey = "sideline.lastPersona"
    private static let lastFreeRefreshKey = "sideline.lastFreeRefreshDay"

    private static func initialPersona() -> Persona {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-SidelinePersona"), idx + 1 < args.count {
            return Persona(rawValue: args[idx + 1]) ?? .cocktailParty
        }
        #endif
        if let raw = UserDefaults.standard.string(forKey: lastPersonaKey),
           let persona = Persona(rawValue: raw) {
            return persona
        }
        return .cocktailParty
    }

    private let service: any BriefingServing
    private let entitlement: any EntitlementProviding
    private var hasShownLimitThisSession = false
    private var shouldRecordPositiveMomentOnNextSuccess = false
    /// Bumped on every load. A response only lands if its generation is still
    /// current, so a slow fetch for a previously selected persona can't
    /// overwrite the briefing the user is actually looking at.
    private var loadGeneration = 0
    #if canImport(SwiftData)
    private let cache: BriefingCache?
    #endif

    public init(
        service: any BriefingServing,
        entitlement: any EntitlementProviding
    ) {
        self.service = service
        self.entitlement = entitlement
        #if canImport(SwiftData)
        self.cache = try? BriefingCache()
        #endif
    }

    public func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        let persona = selectedPersona

        do {
            let briefing = try await service.latestBriefing(persona: persona, scope: .national)
            guard generation == loadGeneration else { return }
            #if canImport(SwiftData)
            try? cache?.save(briefing)
            #endif
            lastBriefing = briefing
            lastFetchedAt = Date()
            state = .populated(briefing, isOffline: false)
            notifyPositiveMomentIfRequested()
        } catch {
            guard generation == loadGeneration else { return }
            #if canImport(SwiftData)
            if let cached = try? cache?.load(persona: persona, scope: .national) {
                lastBriefing = cached
                state = .populated(cached, isOffline: true)
                return
            }
            #endif

            state = .failed(friendlyMessage(for: error))
            shouldRecordPositiveMomentOnNextSuccess = false
        }
    }

    /// Coming back to the app. Keeps the deck on screen while it fetches and
    /// swaps only when a different row lands; a failed fetch changes nothing.
    /// A failed screen retries with a full load.
    public func reloadIfStale(olderThan interval: TimeInterval = 5 * 60) async {
        let current: Briefing
        switch state {
        case .idle, .loading, .refreshLimit:
            return
        case .failed:
            await load()
            return
        case .populated(let briefing, let isOffline):
            if !isOffline, let lastFetchedAt, Date().timeIntervalSince(lastFetchedAt) < interval {
                return
            }
            current = briefing
        }

        loadGeneration += 1
        let generation = loadGeneration
        guard let briefing = try? await service.latestBriefing(persona: selectedPersona, scope: .national),
              generation == loadGeneration
        else { return }
        lastFetchedAt = Date()
        #if canImport(SwiftData)
        try? cache?.save(briefing)
        #endif
        if case .populated(_, isOffline: false) = state, briefing.id == current.id {
            return
        }
        lastBriefing = briefing
        state = .populated(briefing, isOffline: false)
    }

    public func select(_ persona: Persona) async -> Bool {
        guard entitlement.canUse(persona: persona) else {
            roomAwaitingUnlock = persona
            return false
        }
        roomAwaitingUnlock = nil

        selectedPersona = persona
        UserDefaults.standard.set(persona.rawValue, forKey: Self.lastPersonaKey)
        shouldRecordPositiveMomentOnNextSuccess = true
        await load()
        return true
    }

    public func clearRoomAwaitingUnlock() {
        roomAwaitingUnlock = nil
    }

    /// Pro changed. Gaining it opens the room the user was unlocking, else the
    /// stored room a cold launch fell back from before entitlements arrived.
    /// Losing it moves a paid room back to the free one.
    public func entitlementDidChange(storedPersona: Persona?) async {
        guard entitlement.isPro else {
            roomAwaitingUnlock = nil
            if !entitlement.canUse(persona: selectedPersona) {
                await open(.cocktailParty)
            }
            return
        }
        let target = roomAwaitingUnlock ?? storedPersona
        roomAwaitingUnlock = nil
        guard let target, target != selectedPersona, entitlement.canUse(persona: target) else { return }
        await open(target)
    }

    /// Switches room without counting a positive moment: this follows a
    /// paywall, which never leads into a rating ask.
    private func open(_ persona: Persona) async {
        selectedPersona = persona
        UserDefaults.standard.set(persona.rawValue, forKey: Self.lastPersonaKey)
        await load()
    }

    public func refresh() async {
        shouldRecordPositiveMomentOnNextSuccess = true
        if !entitlement.isPro {
            if selectedPersona != .cocktailParty || isFreeRefreshExhaustedToday {
                shouldRecordPositiveMomentOnNextSuccess = false
                showLimitOrStayPopulated()
                return
            }
            await load()
            if case .populated = state {
                UserDefaults.standard.set(Self.todayStamp(), forKey: Self.lastFreeRefreshKey)
            }
            return
        }

        await load()
    }

    // MARK: - Helpers

    private var isFreeRefreshExhaustedToday: Bool {
        guard let stamp = UserDefaults.standard.string(forKey: Self.lastFreeRefreshKey) else {
            return false
        }
        return stamp == Self.todayStamp()
    }

    private func showLimitOrStayPopulated() {
        if hasShownLimitThisSession, let _ = lastBriefing {
            // Quiet repeat upsell — keep the user on their briefing.
            return
        }
        hasShownLimitThisSession = true
        state = .refreshLimit
    }

    private func friendlyMessage(for error: Error) -> String {
        if let serviceError = error as? BriefingServiceError {
            return serviceError.errorDescription ?? "Couldn't reach today's briefing."
        }
        return "Couldn't reach today's briefing. Check your connection and try again."
    }

    private static func todayStamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date())
    }

    private func notifyPositiveMomentIfRequested() {
        guard shouldRecordPositiveMomentOnNextSuccess else { return }
        shouldRecordPositiveMomentOnNextSuccess = false
        guard case .populated(_, isOffline: false) = state else { return }
        ReviewPromptTracker.recordPositiveMoment()
    }
}
