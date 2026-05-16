import Foundation

#if canImport(RevenueCat)
import RevenueCat

public final class RevenueCatEntitlementStore: EntitlementProviding, @unchecked Sendable {
    public private(set) var isPro = false
    private let entitlementIdentifier: String

    public init(entitlementIdentifier: String = "pro") {
        self.entitlementIdentifier = entitlementIdentifier
    }

    public func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements[entitlementIdentifier]?.isActive == true
        } catch {
            consoleError("RevenueCat entitlement refresh failed", error)
        }
    }

    private func consoleError(_ message: String, _ error: Error) {
        print("[Sideline] \(message): \(error)")
    }
}
#endif
