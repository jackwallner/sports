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

    private static let lastPersonaKey = "sideline.lastPersona"
    private static let favoriteTeamKey = "favoriteTeam"
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
        state = .loading

        let scope = currentScope
        let team = currentTeam

        do {
            let briefing = try await service.latestBriefing(persona: selectedPersona, scope: scope, team: team)
            #if canImport(SwiftData)
            try? cache?.save(briefing)
            #endif
            lastBriefing = briefing
            state = .populated(briefing, isOffline: false)
        } catch {
            #if canImport(SwiftData)
            if let cached = try? cache?.load(persona: selectedPersona, scope: scope) {
                lastBriefing = cached
                state = .populated(cached, isOffline: true)
                return
            }
            #endif

            state = .failed(friendlyMessage(for: error))
        }
    }

    public func select(_ persona: Persona) async -> Bool {
        guard entitlement.canUse(persona: persona) else {
            return false
        }

        selectedPersona = persona
        UserDefaults.standard.set(persona.rawValue, forKey: Self.lastPersonaKey)
        await load()
        return true
    }

    public func refresh() async {
        if !entitlement.isPro {
            if selectedPersona != .cocktailParty || isFreeRefreshExhaustedToday {
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

    public func reloadAfterPreferenceChange() async {
        await load()
    }

    // MARK: - Helpers

    private var currentScope: BriefingScope {
        selectedPersona == .localTeam ? .local : .national
    }

    private var currentTeam: String? {
        let team = UserDefaults.standard.string(forKey: Self.favoriteTeamKey) ?? ""
        return team.isEmpty ? nil : team
    }

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
}
