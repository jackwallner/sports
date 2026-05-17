import Shared
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let entitlement: any EntitlementProviding

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(SidelineTheme.brandPrimary)

                    Text("Every Room, Covered")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("One room is free. Pro gives you all 5 contexts, fresher briefings, and your local team.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    benefit("person.3", "All 5 contexts", "Cocktail party, office, date night, family, and local team.")
                    benefit("clock.arrow.circlepath", "Fresh 3× a day", "Morning, midday, and evening when the sports world moves.")
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
