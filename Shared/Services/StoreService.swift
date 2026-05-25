import Foundation
import Observation

#if canImport(RevenueCat)
import RevenueCat

public enum SidelinePurchaseState: Sendable {
    case purchased
    case cancelled
    case pending
}

public enum SidelinePackageKind: Int, Sendable {
    case lifetime = 0
    case annual = 1
    case monthly = 2
    case other = 3
}

extension SidelinePackageKind {
    public init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .annual
        case .monthly:
            self = .monthly
        default:
            let identifiers = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if identifiers.contains(where: { $0.contains("lifetime") }) {
                self = .lifetime
            } else if identifiers.contains(where: { $0.contains("annual") || $0.contains("year") }) {
                self = .annual
            } else if identifiers.contains(where: { $0.contains("monthly") || $0.contains("month") }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    public var sidelinePackageKind: SidelinePackageKind {
        SidelinePackageKind(package: self)
    }

    public var sidelineDisplayName: String {
        switch sidelinePackageKind {
        case .lifetime:
            return "Lifetime"
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        case .other:
            return storeProduct.localizedTitle
        }
    }

    public var sidelinePriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        }
        return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    /// For annual/year packages, returns the per-month-equivalent price string
    /// (e.g. "$2.49/mo") using the product's own locale-aware formatter.
    public var sidelineMonthlyEquivalentLabel: String? {
        guard let period = storeProduct.subscriptionPeriod, period.value > 0 else { return nil }
        let months: Decimal
        switch period.unit {
        case .year:  months = Decimal(12 * period.value)
        case .month: months = Decimal(period.value)
        default:     return nil
        }
        guard months > 1 else { return nil }
        let perMonth = storeProduct.price / months
        let formatter = storeProduct.priceFormatter ?? sidelineFallbackPriceFormatter()
        guard let str = formatter.string(from: perMonth as NSDecimalNumber) else { return nil }
        return "\(str)/mo"
    }

    /// Whole-percent savings of this package's per-month price vs the supplied
    /// monthly package (e.g. 60 for "Save 60%"). Returns nil when the
    /// comparison isn't meaningful.
    public func sidelineSavingsPercent(vsMonthly monthly: Package) -> Int? {
        guard let period = storeProduct.subscriptionPeriod, period.value > 0 else { return nil }
        let months: Decimal
        switch period.unit {
        case .year:  months = Decimal(12 * period.value)
        case .month where period.value > 1: months = Decimal(period.value)
        default:     return nil
        }
        guard let monthlyPeriod = monthly.storeProduct.subscriptionPeriod,
              monthlyPeriod.unit == .month, monthlyPeriod.value == 1 else { return nil }
        let monthlyPrice = monthly.storeProduct.price
        guard monthlyPrice > 0 else { return nil }
        let perMonth = storeProduct.price / months
        let savings = (monthlyPrice - perMonth) / monthlyPrice
        let pct = NSDecimalNumber(decimal: savings * 100).doubleValue
        guard pct >= 1 else { return nil }
        return Int(pct.rounded())
    }

    public var sidelineIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
    }
}

private func sidelineFallbackPriceFormatter() -> NumberFormatter {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = .current
    return f
}

extension CustomerInfo {
    var hasSidelineProEntitlement: Bool {
        entitlements["pro"]?.isActive == true
    }
}

extension Offering {
    var sidelineSortedPackages: [Package] {
        availablePackages.sorted {
            let lhs = $0.sidelinePackageKind
            let rhs = $1.sidelinePackageKind
            if lhs.rawValue != rhs.rawValue {
                return lhs.rawValue < rhs.rawValue
            }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}

extension Offerings {
    var sidelinePaywallOffering: Offering? {
        offering(identifier: "default") ?? current
    }
}

@Observable
@MainActor
public final class StoreService: NSObject, EntitlementProviding {
    public static let shared = StoreService()

    public private(set) var isPro = false
    public private(set) var products: [Package] = []
    public private(set) var currentOffering: Offering?
    public private(set) var purchaseInFlight = false
    public private(set) var isLoadingProducts = false
    public private(set) var lastError: String?
    public private(set) var introEligibility: [String: Bool] = [:]

    private var paywallImpressionsThisSession: Set<String> = []
    private let entitlementIdentifier = "pro"

    private override init() {
        super.init()
    }

    public func start() {
        guard Purchases.isConfigured else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineForcePro") {
            isPro = true
            return
        }
        #endif
        Purchases.shared.delegate = self
        Task { await updateCustomerProductStatus(fetchPolicy: .fetchCurrent) }
        Task { await fetchProducts() }
    }

    public func refresh() async {
        await updateCustomerProductStatus(fetchPolicy: .fetchCurrent)
    }

    public func fetchProducts() async {
        guard Purchases.isConfigured else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.sidelinePaywallOffering
            currentOffering = offering
            products = offering?.sidelineSortedPackages ?? []
            lastError = nil
            await refreshIntroEligibility()
        } catch {
            consoleError("StoreService product fetch failed", error)
            lastError = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    public func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.sidelineIntroOfferLabel != nil else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? true
    }

    public func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard Purchases.isConfigured else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineScreenshotMode") {
            return
        }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    @discardableResult
    public func purchase(_ package: Package) async throws -> SidelinePurchaseState {
        guard Purchases.isConfigured else { throw StoreError.notConfigured }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        }
        if result.customerInfo.hasSidelineProEntitlement {
            return .purchased
        }
        return .pending
    }

    public func updateCustomerProductStatus(fetchPolicy: CacheFetchPolicy = .default) async {
        guard Purchases.isConfigured else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SidelineForcePro") {
            isPro = true
            return
        }
        #endif
        do {
            let info = try await Purchases.shared.customerInfo(fetchPolicy: fetchPolicy)
            apply(customerInfo: info)
            lastError = nil
        } catch {
            consoleError("StoreService customer info refresh failed", error)
            lastError = "Couldn't refresh your subscription status. Check your connection and try again."
        }
    }

    public func restorePurchases() async {
        guard Purchases.isConfigured else { return }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            lastError = isPro ? nil : "No active The Sideline Pro purchase was found for this Apple ID."
        } catch {
            consoleError("StoreService restore failed", error)
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    func apply(customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[entitlementIdentifier]?.isActive == true
        if isPro != active {
            isPro = active
        }
    }

    private func consoleError(_ message: String, _ error: Error) {
        print("[Sideline] \(message): \(error)")
    }
}

extension StoreService: PurchasesDelegate {
    nonisolated public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            StoreService.shared.apply(customerInfo: customerInfo)
        }
    }
}

public enum StoreError: Error, Sendable {
    case notConfigured
}

#endif
