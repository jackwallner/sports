import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/sports/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store

    let entitlement: any EntitlementProviding
    var context: Persona = .cocktailParty
    var displayCloseButton: Bool = true
    var impressionId: String = "sideline_paywall_sheet"

    #if canImport(RevenueCat)
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    #endif

    private var usesNativeStore: Bool {
        #if canImport(RevenueCat)
        Purchases.isConfigured
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if usesNativeStore {
                nativePaywall
            } else {
                fallbackPaywall
            }
        }
        #if canImport(RevenueCat)
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismiss() }
        }
        .task(id: impressionId) {
            store.trackPaywallImpression(id: impressionId)
        }
        .task {
            if store.products.isEmpty { await store.fetchProducts() }
            selectDefaultPackageIfNeeded()
        }
        .onChange(of: store.products.count) { _, _ in
            selectDefaultPackageIfNeeded()
        }
        #endif
    }

    #if canImport(RevenueCat)
    private var nativePaywall: some View {
        NavigationStack {
            ZStack {
                Color.sidelineBackground.ignoresSafeArea()

                if store.isLoadingProducts && store.products.isEmpty {
                    loadingState
                } else if store.products.isEmpty {
                    emptyState
                } else {
                    paywallContent
                }
            }
            .navigationTitle("The Sideline Pro")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if displayCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { dismiss() }
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Loading plans…")
                .font(.footnote)
                .foregroundStyle(SidelineTheme.inkTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(SidelineTheme.inkTertiary)
            Text("Couldn't Load Plans")
                .font(.headline)
                .foregroundStyle(SidelineTheme.inkSecondary)
            Text(store.lastError ?? "Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task {
                    await store.fetchProducts()
                    selectDefaultPackageIfNeeded()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SidelineTheme.brandPrimary)
        }
    }

    private var paywallContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            benefits
            Spacer(minLength: 8)
            planCards
            purchaseSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !context.isFree {
                HStack(spacing: 6) {
                    Image(systemName: context.symbolName)
                        .font(.caption.weight(.bold))
                    Text(context.contextHeader)
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(SidelineTheme.brandPrimary)
            }

            Text(paywallHeadline)
                .font(SidelineTheme.display(28))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Four 30-second briefings so you never get caught flat-footed when sports come up.")
                .font(.subheadline)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("4 rooms, 4 briefings a day", "Each room gets its own stories, picked and told for that crowd.")
            benefit("Refreshed 3× a day", "Morning, midday, and evening, so you're never quoting last week.")
            benefit("Built for non-fans", "No box scores, no jargon, no expectation that you care.")
        }
    }

    private var planCards: some View {
        let monthly = store.products.first { $0.sidelinePackageKind == .monthly }
        return VStack(spacing: 10) {
            ForEach(store.products, id: \.identifier) { package in
                PaywallPlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: store.isEligibleForIntroOffer(package),
                    isBestValue: package.sidelinePackageKind == .annual,
                    savingsPercent: monthly.flatMap { package.sidelineSavingsPercent(vsMonthly: $0) }
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private var trialDayCount: Int? {
        guard let package = selectedPackage,
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return nil
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 10) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(SidelineTheme.brandPrimary)
            .disabled(isPurchasing || selectedPackage == nil)

            // The single biggest trial-start objection is "will I get charged
            // today". Answer it in plain words, directly under the button.
            if let package = selectedPackage,
               package.sidelinePackageKind != .lifetime,
               store.isEligibleForIntroOffer(package) {
                Label("No payment now. Cancel anytime during the trial.", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SidelineTheme.brandPrimary)
            }

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(SidelineTheme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.footnote)
                    .foregroundStyle(SidelineTheme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                Button(action: startRestore) {
                    Text(isRestoring ? "Restoring…" : "Restore Purchases")
                }
                .disabled(isRestoring || isPurchasing)
                Text("·").foregroundStyle(SidelineTheme.inkTertiary)
                Link("Terms", destination: PaywallLinks.standardEULA)
                Text("·").foregroundStyle(SidelineTheme.inkTertiary)
                Link("Privacy", destination: PaywallLinks.privacyPolicy)
            }
            .font(.caption2)
            .foregroundStyle(SidelineTheme.inkTertiary)
            .padding(.top, 4)
        }
    }

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continue" }
        if package.sidelinePackageKind == .lifetime { return "Unlock Lifetime" }
        if store.isEligibleForIntroOffer(package) {
            if let days = trialDayCount { return "Try \(days) Days Free" }
            return "Start Free Trial"
        }
        return "Subscribe"
    }

    private var disclosureText: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.sidelinePriceLabel
        if package.sidelinePackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless turned off at least 24 hours before the end of the current period. Cancel anytime."
        if store.isEligibleForIntroOffer(package), let trial = package.sidelineIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !store.products.isEmpty else { return }
        selectedPackage = store.products.first { $0.sidelinePackageKind == .annual }
            ?? store.products.first
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await store.purchase(package) {
                case .purchased:
                    // store.isPro flips and the onChange handler dismisses.
                    break
                case .pending:
                    restoreMessage = "Your purchase is pending approval. The Sideline Pro unlocks automatically once it's approved."
                case .cancelled:
                    // A deliberate cancel is not an error. Stay quiet; the
                    // button re-enables so they can try again.
                    break
                }
            } catch {
                errorMessage = "Couldn't complete the purchase. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
        restoreMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await store.restorePurchases()
            if !store.isPro {
                restoreMessage = store.lastError ?? "No active The Sideline Pro purchase found for this Apple ID."
            }
        }
    }
    #endif

    private var fallbackPaywall: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    if !context.isFree {
                        HStack(spacing: 6) {
                            Image(systemName: context.symbolName)
                                .font(.caption.weight(.bold))
                            Text(context.contextHeader)
                                .font(.caption.weight(.heavy))
                                .tracking(1.2)
                        }
                        .foregroundStyle(SidelineTheme.brandPrimary)
                    }

                    Text(paywallHeadline)
                        .font(SidelineTheme.display(34))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Four 30-second briefings so you never get caught flat-footed when sports come up.")
                        .font(.body)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    benefit("4 rooms, 4 briefings a day", "Each room gets its own stories, picked and told for that crowd.")
                    benefit("Refreshed 3× a day", "Morning, midday, and evening, so you're never quoting last week.")
                    benefit("Built for non-fans", "No box scores, no jargon, no expectation that you care.")
                }

                Spacer()

                Button {
                    #if DEBUG
                    if let local = entitlement as? LocalEntitlementStore {
                        local.setProForDebug(true)
                    }
                    #endif
                    dismiss()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(SidelineTheme.brandPrimary)

                Button("Restore Purchases") {
                    Task { await entitlement.refresh() }
                }
                .frame(maxWidth: .infinity)
                .font(.footnote)

                HStack(spacing: 4) {
                    Link("Terms", destination: PaywallLinks.standardEULA)
                    Text("·")
                    Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                }
                .font(.caption2)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationTitle("The Sideline Pro")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if displayCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { dismiss() }
                    }
                }
            }
        }
    }

    private var paywallHeadline: String {
        switch context {
        case .cocktailParty:      return "Walk in knowing what to say"
        case .officeWatercooler:  return "Walk into Monday knowing what to say"
        case .sportsTalkForMoms:  return "Keep up with your kid's favorite topic"
        case .dateNight:          return "Sound like you actually follow it"
        }
    }

    private func benefit(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(SidelineTheme.brandPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(SidelineTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if canImport(RevenueCat)
private struct PaywallPlanCard: View {
    let package: Package
    let isSelected: Bool
    let showsTrialBadge: Bool
    let isBestValue: Bool
    let savingsPercent: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? SidelineTheme.brandPrimary : SidelineTheme.inkSecondary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(SidelineTheme.brandPrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(package.sidelineDisplayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SidelineTheme.inkPrimary)
                        if let savings = savingsPercent {
                            Text("SAVE \(savings)%")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SidelineTheme.brandPrimary, in: Capsule())
                        } else if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SidelineTheme.brandPrimary, in: Capsule())
                        }
                    }
                    if showsTrialBadge, let trial = package.sidelineIntroOfferLabel {
                        Text(trial.capitalized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SidelineTheme.brandPrimary)
                    } else if let perMonth = package.sidelineMonthlyEquivalentLabel {
                        Text(perMonth)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(SidelineTheme.inkTertiary)
                    }
                }

                Spacer(minLength: 8)

                Text(package.sidelinePriceLabel)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(SidelineTheme.inkSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .stroke(isSelected ? SidelineTheme.brandPrimary : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
#endif
