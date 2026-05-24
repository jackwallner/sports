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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                benefits
                planCards
                purchaseSection
            }
            .padding(24)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: context.isFree ? "quote.bubble.fill" : context.symbolName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)

            Text(context.isFree ? "Every room, covered" : context.paywallHook)
                .font(SidelineTheme.display(34))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("One room is free. Pro gives you all 5 contexts, fresher briefings, and your local team.")
                .font(.body)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("person.3", "All 5 contexts", "Cocktail party, office, date night, family, and local team.")
            benefit("clock.arrow.circlepath", "Fresh 3\u{00D7} a day", "Morning, midday, and evening when the sports world moves.")
            benefit("mappin.and.ellipse", "Local Team", "Conversation fuel for the teams people around you care about.")
        }
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(store.products, id: \.identifier) { package in
                PaywallPlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: store.isEligibleForIntroOffer(package),
                    isBestValue: package.sidelinePackageKind == .annual
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
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

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(.caption)
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

            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
            }
            .font(.footnote)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 4) {
                Link("Terms", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(.caption2)
            .foregroundStyle(SidelineTheme.inkTertiary)
        }
    }

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continue" }
        if package.sidelinePackageKind == .lifetime { return "Unlock Lifetime" }
        if store.isEligibleForIntroOffer(package) { return "Start Free Trial" }
        return "Subscribe"
    }

    private var disclosureText: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.sidelinePriceLabel
        if package.sidelinePackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings."
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
                case .purchased, .pending:
                    break
                case .cancelled:
                    errorMessage = "Purchase cancelled. Tap again to continue."
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
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: context.isFree ? "quote.bubble.fill" : context.symbolName)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(SidelineTheme.brandPrimary)

                    Text(context.isFree ? "Every room, covered" : context.paywallHook)
                        .font(SidelineTheme.display(34))
                        .foregroundStyle(SidelineTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("One room is free. Pro gives you all 5 contexts, fresher briefings, and your local team.")
                        .font(.body)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    benefit("person.3", "All 5 contexts", "Cocktail party, office, date night, family, and local team.")
                    benefit("clock.arrow.circlepath", "Fresh 3\u{00D7} a day", "Morning, midday, and evening when the sports world moves.")
                    benefit("mappin.and.ellipse", "Local Team", "Conversation fuel for the teams people around you care about.")
                }

                Spacer()

                Button {
                    if let local = entitlement as? LocalEntitlementStore {
                        local.setProForDebug(true)
                    }
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

    private func benefit(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(SidelineTheme.brandAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? SidelineTheme.brandPrimary : SidelineTheme.inkTertiary.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(SidelineTheme.brandPrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(package.sidelineDisplayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SidelineTheme.inkPrimary)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
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
