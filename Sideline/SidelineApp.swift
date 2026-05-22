import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct SidelineApp: App {
    private let entitlement: any EntitlementProviding
    private let service: any BriefingServing
    private let isDemo: Bool

    init() {
        if let config = AppConfig.fromBundle() ?? AppConfig.fromEnvironment() {
            self.service = SupabaseBriefingService(config: config)
            self.isDemo = false
        } else {
            self.service = SampleBriefingService()
            self.isDemo = true
        }

        #if canImport(RevenueCat)
        if
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "SIDELINE_REVENUECAT_API_KEY") as? String,
            !apiKey.isEmpty,
            !apiKey.hasPrefix("$(")
        {
            Purchases.configure(withAPIKey: apiKey)
        }
        #endif

        self.entitlement = Self.makeEntitlement()

        #if canImport(RevenueCat)
        if let revenueCatStore = self.entitlement as? RevenueCatEntitlementStore {
            Task { await revenueCatStore.refresh() }
        }
        #endif
    }

    private static func makeEntitlement() -> any EntitlementProviding {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineForcePro") {
            return LocalEntitlementStore(isPro: true)
        }
        #endif

        #if canImport(RevenueCat)
        if Purchases.isConfigured {
            return RevenueCatEntitlementStore()
        }
        #endif
        return LocalEntitlementStore()
    }

    var body: some Scene {
        WindowGroup {
            TodayBriefingView(service: service, entitlement: entitlement, isDemo: isDemo)
        }
    }
}
