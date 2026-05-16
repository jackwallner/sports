import Foundation

public enum ProFeature: String, CaseIterable, Sendable {
    case allPersonas
    case threeDailyRefreshes
    case localTeam
}

public protocol EntitlementProviding: AnyObject, Sendable {
    var isPro: Bool { get }
    func refresh() async
    func canUse(persona: Persona) -> Bool
}

public extension EntitlementProviding {
    func canUse(persona: Persona) -> Bool {
        isPro || persona.isFree
    }
}

public final class LocalEntitlementStore: EntitlementProviding, @unchecked Sendable {
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
