import Foundation

public enum ProFeature: String, CaseIterable, Sendable {
    case allPersonas
    case threeDailyRefreshes
    case localTeam
}

@MainActor
public protocol EntitlementProviding: AnyObject {
    var isPro: Bool { get }
    func refresh() async
    func canUse(persona: Persona) -> Bool
}

public extension EntitlementProviding {
    func canUse(persona: Persona) -> Bool {
        isPro || persona.isFree
    }
}

@MainActor
public final class LocalEntitlementStore: EntitlementProviding {
    public private(set) var isPro: Bool

    public init(isPro: Bool = false) {
        self.isPro = isPro
    }

    public func setProForDebug(_ isPro: Bool) {
        self.isPro = isPro
    }

    public func refresh() async {
        // RevenueCat-backed implementation can update this value without changing UI callers.
    }
}
