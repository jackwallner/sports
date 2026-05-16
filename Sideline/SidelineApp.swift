import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct SidelineApp: App {
    private let entitlement: any EntitlementProviding
    private let service: any BriefingServing

    init() {
        if let config = AppConfig.fromBundle() ?? AppConfig.fromEnvironment() {
            self.service = SupabaseBriefingService(config: config)
        } else {
            self.service = SampleBriefingService()
        }

        #if canImport(RevenueCat)
        if
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "SIDELINE_REVENUECAT_API_KEY") as? String,
            !apiKey.isEmpty,
            !apiKey.hasPrefix("$(")
        {
            Purchases.configure(withAPIKey: apiKey)
            let revenueCatStore = RevenueCatEntitlementStore()
            self.entitlement = revenueCatStore
            Task {
                await revenueCatStore.refresh()
            }
        } else {
            self.entitlement = LocalEntitlementStore()
        }
        #else
        self.entitlement = LocalEntitlementStore()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TodayBriefingView(service: service, entitlement: entitlement)
        }
    }
}
