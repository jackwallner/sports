import Shared
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var lastPersona: String
    @Binding var hasSeenOnboardingPaywall: Bool
    var isPro: Bool = false

    @Environment(StoreService.self) private var store

    @State private var page = 0
    @State private var pickedPersona: Persona = .cocktailParty
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    // The last page is the trial step. Kept as a constant so the CTA logic
    // reads clearly and there's a single place to bump if pages are added.
    private let trialPageIndex = 2

    private func isLocked(_ persona: Persona) -> Bool {
        !persona.isFree && !isPro
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                valueProp.tag(0)
                personaPick.tag(1)
                trialPage.tag(trialPageIndex)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif
            .background(Color.sidelineBackground)
            .safeAreaInset(edge: .bottom) {
                // One shared bar for every page. Because it lives outside the
                // TabView and every slot has a fixed height, the primary button
                // frame is pixel-identical on all three pages (Rev A zero-shift):
                // only its label and the reserved slots' contents change.
                ctaStack
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(
                        Color.sidelineBackground
                            .overlay(
                                Rectangle()
                                    .fill(SidelineTheme.rule)
                                    .frame(height: 1)
                                    .frame(maxHeight: .infinity, alignment: .top)
                            )
                    )
            }
        }
        .task {
            // Warm the products early so the trial step has live price / trial
            // copy by the time the user swipes to it.
            #if canImport(RevenueCat)
            if store.products.isEmpty { await store.fetchProducts() }
            #endif
        }
        .onAppear {
            if let persona = Persona(rawValue: lastPersona) {
                pickedPersona = persona
            }
            #if os(iOS)
            let control = UIPageControl.appearance()
            control.currentPageIndicatorTintColor = UIColor(SidelineTheme.brandPrimary)
            control.pageIndicatorTintColor = UIColor(SidelineTheme.brandPrimary.opacity(0.25))
            #endif
        }
    }

    // MARK: - Pages

    private var valueProp: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text("Sound like you follow sports.")
                .font(SidelineTheme.display(30))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("A few things to say and one question to ask, in under 20 seconds, before you walk into the room.")
                .font(.body)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var personaPick: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 12)
            Text("Pick the room you'll use this in")
                .font(SidelineTheme.title)
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Each room is its own daily briefing, with stories picked for that crowd. Cocktail Party is free; the rest unlock with Pro.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Persona.allCases) { persona in
                        personaRow(persona)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func personaRow(_ persona: Persona) -> some View {
        let locked = isLocked(persona)
        let isSelected = persona == pickedPersona && !locked
        return Button {
            // A free user can't start in a Pro room. Locked rows preview what
            // Pro unlocks (framed on the next step) but don't become the start
            // room, so the choice is never silently lost.
            guard !locked else { return }
            pickedPersona = persona
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: persona.symbolName)
                    .font(.title3)
                    .foregroundStyle(locked ? SidelineTheme.inkTertiary : SidelineTheme.brandPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(.headline)
                            .foregroundStyle(SidelineTheme.inkPrimary)
                        if locked {
                            Label("Pro", systemImage: "lock.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SidelineTheme.brandAccent.opacity(0.2), in: Capsule())
                                .foregroundStyle(SidelineTheme.amberText)
                        }
                    }
                    Text(persona.shortPitch)
                        .font(.footnote)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SidelineTheme.brandPrimary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .fill(isSelected ? SidelineTheme.brandPrimary.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .stroke(isSelected ? SidelineTheme.brandPrimary.opacity(0.45) : SidelineTheme.rule, lineWidth: isSelected ? 1.5 : 1)
            )
            .opacity(locked ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(persona.displayName), Pro, unlocks with Gist Pro" : persona.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // Reads like the next onboarding step, not a paywall sheet: same paper
    // background, display headline, and a short pitch + benefits.
    private var trialPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 16)
            Image(systemName: "sparkles")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text("Try every room, free for a week")
                .font(SidelineTheme.display(28))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Gist Pro opens all four rooms and keeps them fresh all day. Start free, cancel anytime.")
                .font(.body)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                trialBenefit("All four rooms, each with its own daily briefing")
                trialBenefit("Refreshed three times a day: morning, midday, evening")
                trialBenefit("Built for non-fans: no box scores, no jargon")
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trialBenefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - CTA stack (zero-shift)

    private var ctaStack: some View {
        VStack(spacing: 10) {
            softExitSlot
            disclosureSlot
            primaryButton
            legalSlot
        }
    }

    // Reserved 44pt row above the primary. Holds Back (page 1) or the soft
    // free-exit "Get Started" (trial page). Empty, but still reserved, on the
    // value-prop page so the primary never moves.
    private var softExitSlot: some View {
        ZStack {
            HStack {
                Button("Back") { withAnimation { page -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(SidelineTheme.inkSecondary)
                Spacer()
            }
            .opacity(page == 1 ? 1 : 0)
            .allowsHitTesting(page == 1)
            .accessibilityHidden(page != 1)

            Button("Get Started") { finishFree() }
                .buttonStyle(.plain)
                .font(.body.weight(.semibold))
                .foregroundStyle(SidelineTheme.inkSecondary)
                .opacity(page == trialPageIndex ? 1 : 0)
                .allowsHitTesting(page == trialPageIndex)
                .accessibilityHidden(page != trialPageIndex)
        }
        .frame(height: 44)
    }

    // Reserved disclosure row directly above the primary. Shows the auto-renew
    // terms on the trial page (or a purchase error), invisible elsewhere.
    private var disclosureSlot: some View {
        let text = purchaseError ?? trialDisclosure
        let visible = page == trialPageIndex && text != nil
        return Text(text ?? " ")
            .font(.caption2)
            .foregroundStyle(purchaseError != nil ? Color.red : SidelineTheme.inkTertiary)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 56, alignment: .top)
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(!visible)
    }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            ZStack {
                Text(primaryLabel)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .opacity(isPurchasing ? 0 : 1)
                if isPurchasing {
                    ProgressView().tint(.white)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(SidelineTheme.brandPrimary)
        .disabled(isPurchasing)
    }

    // Fixed-height legal footer, rendered on every page (Rev A). Real links on
    // the trial page; hidden and inert elsewhere so the primary stays put.
    private var legalSlot: some View {
        HStack(spacing: 12) {
            Button("Restore") {
                #if canImport(RevenueCat)
                Task { await store.restorePurchases() }
                #endif
            }
            Text("·").foregroundStyle(SidelineTheme.inkTertiary)
            Link("Terms", destination: PaywallLinks.standardEULA)
            Text("·").foregroundStyle(SidelineTheme.inkTertiary)
            Link("Privacy", destination: PaywallLinks.privacyPolicy)
        }
        .font(.caption2)
        .foregroundStyle(SidelineTheme.inkTertiary)
        .frame(height: 22)
        .opacity(page == trialPageIndex ? 1 : 0)
        .allowsHitTesting(page == trialPageIndex)
        .accessibilityHidden(page != trialPageIndex)
    }

    private var primaryLabel: String {
        switch page {
        case 0: return "Start"
        case 1: return "Use this room"
        default: return trialPrimaryLabel
        }
    }

    private var trialPrimaryLabel: String {
        #if canImport(RevenueCat)
        if let yearly = store.yearlyPackage {
            if store.isEligibleForIntroOffer(yearly), let trial = yearly.sidelineIntroOfferLabel {
                return "Start \(trial)"
            }
            return "Get Gist Pro"
        }
        #endif
        return "Start free trial"
    }

    private var trialDisclosure: String? {
        #if canImport(RevenueCat)
        return store.yearlyCTADisclosureText
        #else
        return nil
        #endif
    }

    // MARK: - Actions

    private func primaryAction() {
        switch page {
        case 0: withAnimation { page = 1 }
        case 1: withAnimation { page = trialPageIndex }
        default: startTrialPurchase()
        }
    }

    private func startTrialPurchase() {
        #if canImport(RevenueCat)
        guard let yearly = store.yearlyPackage else {
            // Products didn't load — fall back to the full PaywallView by
            // finishing onboarding without stamping the seen flag, so the
            // host's one-time paywall presents as the fallback conversion.
            finishWithPlanPickerFallback()
            return
        }
        purchaseError = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await store.purchase(yearly) {
                case .purchased, .pending:
                    finishFree()
                case .cancelled:
                    break
                }
            } catch {
                purchaseError = "Couldn't start your free trial. Please try again."
            }
        }
        #else
        finishFree()
        #endif
    }

    /// Complete onboarding and suppress the post-onboarding plan picker: reaching
    /// the trial page (or buying) means the user has already made the call.
    private func finishFree() {
        hasSeenOnboardingPaywall = true
        finish()
    }

    /// Emergency path only: products failed to load, so let the host's full
    /// PaywallView be the fallback conversion surface (leave the seen flag false).
    private func finishWithPlanPickerFallback() {
        finish()
    }

    private func finish() {
        // Never persist a locked Pro room as the start room for a free user.
        lastPersona = isLocked(pickedPersona) ? Persona.cocktailParty.rawValue : pickedPersona.rawValue
        hasCompletedOnboarding = true
    }
}
