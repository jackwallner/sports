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

    private static func initialPersona() -> Persona {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-SidelinePersona"), idx + 1 < args.count {
            return Persona(rawValue: args[idx + 1]) ?? .cocktailParty
        }
        #endif
        return .cocktailParty
    }

    private let service: any BriefingServing
    private let entitlement: any EntitlementProviding
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

        do {
            let briefing = try await service.latestBriefing(persona: selectedPersona, scope: .national)
            #if canImport(SwiftData)
            try? cache?.save(briefing)
            #endif
            lastBriefing = briefing
            state = .populated(briefing, isOffline: false)
        } catch {
            #if canImport(SwiftData)
            if let cached = try? cache?.load(persona: selectedPersona, scope: .national) {
                lastBriefing = cached
                state = .populated(cached, isOffline: true)
                return
            }
            #endif

            state = .failed(error.localizedDescription)
        }
    }

    public func select(_ persona: Persona) async -> Bool {
        guard entitlement.canUse(persona: persona) else {
            return false
        }

        selectedPersona = persona
        await load()
        return true
    }

    public func refresh() async {
        guard entitlement.isPro || selectedPersona == .cocktailParty else {
            state = .refreshLimit
            return
        }

        await load()
    }
}
