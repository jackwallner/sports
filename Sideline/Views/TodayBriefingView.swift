import Shared
import StoreKit
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(UIKit)
import UIKit
#endif

struct TodayBriefingView: View {
    @State private var viewModel: TodayBriefingViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var pendingPaywallContext: Persona?
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false

    private enum ActiveSheet: Identifiable {
        case proPreview(Persona)
        case paywall(Persona)
        case review(ReviewPromptSheet.Step)
        case source(URL)

        var id: String {
            switch self {
            case .proPreview(let persona): return "preview-\(persona.rawValue)"
            case .paywall(let persona): return "paywall-\(persona.rawValue)"
            case .review: return "review"
            case .source(let url): return "source-\(url.absoluteString)"
            }
        }
    }

    @Environment(\.requestReview) private var requestReview

    @AppStorage("sideline.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("sideline.lastPersona") private var lastPersonaRaw = Persona.cocktailParty.rawValue
    @AppStorage("favoriteTeam") private var favoriteTeam = ""

    private let entitlement: any EntitlementProviding
    private let store: StoreService
    private let isDemo: Bool

    init(
        service: any BriefingServing,
        entitlement: any EntitlementProviding,
        store: StoreService = .shared,
        isDemo: Bool = false
    ) {
        self.entitlement = entitlement
        self.store = store
        self.isDemo = isDemo
        _viewModel = State(wrappedValue: TodayBriefingViewModel(service: service, entitlement: entitlement))
    }

    private var isPro: Bool {
        #if canImport(RevenueCat)
        if Purchases.isConfigured, entitlement is StoreService {
            return store.isPro
        }
        #endif
        return entitlement.isPro
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PersonaRail(selected: viewModel.selectedPersona, isPro: isPro) { persona in
                        Task {
                            let didSelect = await viewModel.select(persona)
                            if !didSelect {
                                activeSheet = .proPreview(persona)
                            }
                        }
                    }

                    content
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color.sidelineBackground)
            .navigationTitle("The Sideline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView(
                            entitlement: entitlement,
                            store: store,
                            onManualRefresh: { Task { await viewModel.refresh() } },
                            onTeamChanged: { Task { await viewModel.reloadAfterPreferenceChange() } }
                        )
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if case .idle = viewModel.state {
                    if let persona = Persona(rawValue: lastPersonaRaw),
                       entitlement.canUse(persona: persona) {
                        viewModel.selectedPersona = persona
                    }
                    await viewModel.load()
                }
            }
            .sheet(item: $activeSheet, onDismiss: handleSheetDismiss) { sheet in
                switch sheet {
                case .proPreview(let persona):
                    ProPreviewSheet(
                        persona: persona,
                        onSeePro: {
                            pendingPaywallContext = persona
                            activeSheet = nil
                        },
                        onDismiss: { activeSheet = nil }
                    )
                case .paywall(let persona):
                    PaywallView(
                        entitlement: entitlement,
                        context: persona,
                        impressionId: "sideline_paywall_sheet"
                    )
                case .review(let step):
                    ReviewPromptSheet(initialStep: step, onFinish: handleReviewPromptFinish)
                case .source(let url):
                    #if canImport(SafariServices) && canImport(UIKit)
                    SafariView(url: url)
                    #else
                    EmptyView()
                    #endif
                }
            }
            .modifier(OnboardingPresenter(
                isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { newValue in hasCompletedOnboarding = !newValue }
                ),
                content: {
                    OnboardingView(
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        lastPersona: $lastPersonaRaw,
                        favoriteTeam: $favoriteTeam
                    )
                    .onDisappear {
                        if let persona = Persona(rawValue: lastPersonaRaw),
                           entitlement.canUse(persona: persona) {
                            viewModel.selectedPersona = persona
                        }
                        Task { await viewModel.load() }
                    }
                }
            ))
            .onReceive(NotificationCenter.default.publisher(for: .sidelinePositiveMomentForReview)) { _ in
                scheduleReviewPromptAfterPositiveMoment()
            }
            .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
                guard let presentation else { return }
                defer { reviewPromptCoordinator.clear() }
                guard activeSheet == nil else { return }
                switch presentation {
                case .enjoymentPrompt:
                    presentReviewPrompt(step: .enjoyment)
                case .feedbackOnly:
                    presentReviewPrompt(step: .feedback)
                }
            }
        }
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard !isDemo,
              hasCompletedOnboarding,
              ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              activeSheet == nil
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard activeSheet == nil,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            ReviewPromptTracker.consumePendingPositiveMoment()
            presentReviewPrompt(step: .enjoyment)
        }
    }

    private func handleSheetDismiss() {
        if let persona = pendingPaywallContext {
            pendingPaywallContext = nil
            activeSheet = .paywall(persona)
            return
        }
        if pendingNativeReviewAfterDismiss {
            pendingNativeReviewAfterDismiss = false
            requestReview()
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        activeSheet = nil
        if outcome == .enjoyedMaybeLater {
            pendingNativeReviewAfterDismiss = true
        }
    }

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptShownThisSession = true
        activeSheet = .review(step)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            skeleton
        case .populated(let briefing, let isOffline):
            briefingView(briefing, isOffline: isOffline)
                .transition(.opacity)
        case .failed(let message):
            emptyState(message: message)
        case .refreshLimit:
            refreshLimitCard
            if let briefing = viewModel.lastBriefing {
                briefingView(briefing, isOffline: false, suppressOfflineBanner: true)
                    .transition(.opacity)
            }
        }
    }

    private func briefingView(_ briefing: Briefing, isOffline: Bool, suppressOfflineBanner: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if isDemo {
                demoBanner
            } else if isOffline && !suppressOfflineBanner {
                offlineBanner
            }

            heroBlock(briefing: briefing)

            Text("\(briefing.bullets.count) talking points".uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .padding(.top, 2)

            Divider()

            VStack(spacing: 0) {
                ForEach(Array(briefing.bullets.enumerated()), id: \.element.id) { index, bullet in
                    BulletCard(
                        bullet: bullet,
                        index: index + 1,
                        total: briefing.bullets.count
                    ) { url in
                        activeSheet = .source(url)
                    }

                    if index < briefing.bullets.count - 1 {
                        Divider()
                            .padding(.leading, 18)
                    }
                }
            }

            SuggestedQuestionCard(question: briefing.suggestedQuestion)

            FreshnessFooter(briefing: briefing, isOffline: isOffline, isPro: isPro)
                .padding(.top, 4)
        }
    }

    private func heroBlock(briefing: Briefing) -> some View {
        // Newsroom: no card chrome — the eyebrow, a serif headline, and
        // spacing carry the hero. The page background does the rest.
        VStack(alignment: .leading, spacing: SidelineTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.selectedPersona.symbolName)
                    .font(.caption2.weight(.bold))
                Text(viewModel.selectedPersona.contextHeader.uppercased())
                    .font(SidelineTheme.eyebrow)
                    .tracking(1.4)
            }
            .foregroundStyle(SidelineTheme.brandPrimary)

            Text(briefing.tlDR)
                .font(SidelineTheme.display())
                .foregroundStyle(SidelineTheme.inkPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu {
                    Button {
                        copyToClipboard(briefing.tlDR)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

            Text(briefing.headline)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "newspaper")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(SidelineTheme.inkTertiary)
            Text("Can't reach today's briefing")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SidelineTheme.inkPrimary)
            Text(message)
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Capsule().fill(SidelineTheme.rule).frame(width: 90, height: 10)
                Capsule().fill(SidelineTheme.rule).frame(height: 22)
                Capsule().fill(SidelineTheme.rule).frame(height: 22)
                Capsule().fill(SidelineTheme.rule).frame(width: 200, height: 22)
            }

            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(SidelineTheme.rule)
                        .frame(width: 4, height: 78)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(SidelineTheme.rule).frame(width: 60, height: 10)
                        Capsule().fill(SidelineTheme.rule).frame(height: 12)
                        Capsule().fill(SidelineTheme.rule).frame(width: 220, height: 12)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading briefing")
    }

    private var offlineBanner: some View {
        let bg = SidelineTheme.tagFill(SidelineTheme.inkPrimary)
        return Label("Offline. Showing yesterday's update.", systemImage: "wifi.slash")
            .font(.callout)
            .foregroundStyle(SidelineTheme.inkSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SidelineTheme.rule, lineWidth: 1)
            )
    }

    private var demoBanner: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preview briefing")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                Text("Not today's news. For demo only.")
                    .font(.caption)
                    .foregroundStyle(SidelineTheme.inkSecondary)
            }
        } icon: {
            Image(systemName: "eye")
                .foregroundStyle(SidelineTheme.amberText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SidelineTheme.brandAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var refreshLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You're caught up".uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(SidelineTheme.amberText)
            Text("Today's free briefing is already the latest. Pro refreshes 3× a day: morning, midday, and evening.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
            Button("See Pro") {
                activeSheet = .paywall(viewModel.selectedPersona)
            }
            .buttonStyle(.borderedProminent)
            .tint(SidelineTheme.brandPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .stroke(SidelineTheme.brandAccent, lineWidth: 1)
        )
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private struct OnboardingPresenter<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> SheetContent

    func body(content base: Content) -> some View {
        #if os(iOS)
        base.fullScreenCover(isPresented: $isPresented, content: content)
        #else
        base.sheet(isPresented: $isPresented, content: content)
        #endif
    }
}
