import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remotePaywallReady = false
    let entitlement: any EntitlementProviding
    var context: Persona = .cocktailParty

    var body: some View {
        #if canImport(RevenueCatUI) && canImport(RevenueCat)
        if remotePaywallReady, Purchases.isConfigured {
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    Task {
                        await entitlement.refresh()
                        dismiss()
                    }
                }
                .onRestoreCompleted { _ in
                    Task {
                        await entitlement.refresh()
                        dismiss()
                    }
                }
                .task {
                    remotePaywallReady = await Self.hasRemoteOffering()
                }
        } else {
            fallbackPaywall
        }
        #else
        fallbackPaywall
        #endif
    }

    private var fallbackPaywall: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: context.isFree ? "quote.bubble.fill" : context.symbolName)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(SidelineTheme.brandPrimary)

                    Text(context.isFree ? "Every Room, Covered" : context.paywallHook)
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
                    Task {
                        await entitlement.refresh()
                    }
                }
                .frame(maxWidth: .infinity)
                .font(.footnote)

                Text("Subscription terms and privacy policy apply. Pricing and trial length are supplied by RevenueCat in production.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationTitle("The Sideline Pro")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        dismiss()
                    }
                }
            }
        }
    }

    #if canImport(RevenueCat)
    private static func hasRemoteOffering() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.current?.availablePackages.isEmpty == false
        } catch {
            return false
        }
    }
    #endif

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
