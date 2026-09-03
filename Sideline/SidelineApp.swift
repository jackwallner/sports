import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

@main
struct SidelineApp: App {
    @AppStorage("sideline.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    private let entitlement: any EntitlementProviding
    private let store = StoreService.shared
    private let service: any BriefingServing
    private let isDemo: Bool

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    init() {
        var debugService: (any BriefingServing)?
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineEdgeCases") {
            debugService = EdgeCaseBriefingService()
        }
        #endif

        if let debugService {
            self.service = debugService
            self.isDemo = true
        } else if let config = AppConfig.fromBundle() ?? AppConfig.fromEnvironment() {
            self.service = SupabaseBriefingService(config: config)
            self.isDemo = false
        } else {
            self.service = SampleBriefingService()
            self.isDemo = true
        }

        #if canImport(RevenueCat) && !targetEnvironment(simulator)
        if
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "SIDELINE_REVENUECAT_API_KEY") as? String,
            !apiKey.isEmpty,
            !apiKey.hasPrefix("$(")
        {
            Purchases.configure(withAPIKey: apiKey)
            StoreService.shared.start()
        }
        #endif
        #if canImport(RevenueCat) && targetEnvironment(simulator) && DEBUG
        // The one simulator path allowed to configure RevenueCat, and only ever
        // with the Test Store key: a separate RevenueCat app inside the same
        // project, so a probe run cannot touch App Store customers, revenue or
        // charts. See RevenueCatProbe.
        if RevenueCatProbe.isEnabled {
            Purchases.logLevel = .debug
            Purchases.configure(
                with: Configuration.Builder(withAPIKey: RevenueCatProbe.testStoreKey)
                    .with(appUserID: RevenueCatProbe.appUserID)
                    .build()
            )
            StoreService.shared.start()
        }
        #endif

        self.entitlement = Self.makeEntitlement()
        ReviewPromptTracker.recordAppLaunch()
        ConversionDiagnostics.recordAppOpen()
        #if canImport(RevenueCat) && DEBUG
        if RevenueCatProbe.isEnabled {
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            StoreService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
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
            return StoreService.shared
        }
        #endif
        return LocalEntitlementStore()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = PaywallScreenshotMode.current {
                PaywallScreenshotHarness(mode: mode)
                    .environment(store)
                    .preferredColorScheme(appearanceMode.colorScheme)
            } else {
                TodayBriefingView(service: service, entitlement: entitlement, store: store, isDemo: isDemo)
                    .environment(store)
                    .preferredColorScheme(appearanceMode.colorScheme)
            }
            #else
            TodayBriefingView(service: service, entitlement: entitlement, store: store, isDemo: isDemo)
                .environment(store)
                .preferredColorScheme(appearanceMode.colorScheme)
            #endif
        }
    }
}

#if DEBUG && canImport(RevenueCat)
/// Simulator-only proof path for the fleet-wide funnel attributes.
///
/// Under the normal rules the attributes cannot be verified on a simulator: the
/// production key must never be configured there, so RevenueCat is never
/// configured, so nothing is ever sent, so a physical device is the only
/// witness. The Test Store key is a different RevenueCat app inside the same
/// project, so a probe run cannot touch App Store customers, revenue or charts.
///
/// DEBUG only, and only with the launch argument, so it cannot reach a Release
/// build or an ordinary simulator run.
enum RevenueCatProbe {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobe")
    }

    static let testStoreKey = "test_wQHrMUOWwwPqnWHeqxyPdiTcyNt"

    static var appUserID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_USER"] ?? "funnel-probe-sports"
    }

    static var impressionID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_SURFACE"] ?? "sideline_onboarding_paywall"
    }
}
#endif
