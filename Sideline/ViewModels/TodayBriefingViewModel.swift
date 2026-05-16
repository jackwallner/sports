import Foundation
import Observation
import Shared

@Observable
@MainActor
final class TodayBriefingViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case populated(Briefing, isOffline: Bool)
        case failed(String)
        case refreshLimit
    }

    var selectedPersona: Persona = .cocktailParty
    var state: LoadState = .idle

    private let service: any BriefingServing
    private let entitlement: any EntitlementProviding
    #if canImport(SwiftData)
    private let cache: BriefingCache?
    #endif

    init(
        service: any BriefingServing,
        entitlement: any EntitlementProviding
    ) {
        self.service = service
        self.entitlement = entitlement
        #if canImport(SwiftData)
        self.cache = try? BriefingCache()
        #endif
    }

    func load() async {
        state = .loading

        do {
            let briefing = try await service.latestBriefing(persona: selectedPersona, scope: .national)
            #if canImport(SwiftData)
            try? cache?.save(briefing)
            #endif
            state = .populated(briefing, isOffline: false)
        } catch {
            #if canImport(SwiftData)
            if let cached = try? cache?.load(persona: selectedPersona, scope: .national) {
                state = .populated(cached, isOffline: true)
                return
            }
            #endif

            state = .failed(error.localizedDescription)
        }
    }

    func select(_ persona: Persona) async -> Bool {
        guard entitlement.canUse(persona: persona) else {
            return false
        }

        selectedPersona = persona
        await load()
        return true
    }

    func refresh() async {
        guard entitlement.isPro || selectedPersona == .cocktailParty else {
            state = .refreshLimit
            return
        }

        await load()
    }
}
