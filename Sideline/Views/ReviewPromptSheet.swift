import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation {
        case rateOrFeedback
        case feedbackOnly
    }

    @Published var pendingPresentation: Presentation?

    private init() {}

    func requestRateOrFeedback() {
        pendingPresentation = .rateOrFeedback
    }

    func requestFeedback() {
        pendingPresentation = .feedbackOnly
    }

    func clear() {
        pendingPresentation = nil
    }
}

enum ReviewPromptDismissOutcome: Sendable {
    case notNow
    case feedbackSubmitted
    case openedWriteReview
}

/// Manual rate-or-feedback sheet. Per App Store Guideline 1.1.7 we do NOT
/// pre-screen sentiment and route only happy users to the store: "Rate on the
/// App Store" and "Send feedback" are peer options shown to everyone on the
/// same screen. The automatic, behaviorally-gated prompt uses the native
/// `requestReview()` instead (see TodayBriefingView).
struct ReviewPromptSheet: View {
    enum Step {
        case choose
        case feedback
    }

    let initialStep: Step
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .choose, onFinish: @escaping (ReviewPromptDismissOutcome) -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose:
                    chooseContent
                case .feedback:
                    feedbackContent
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        handleNotNow()
                    }
                }
            }
        }
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var navigationTitle: String {
        switch step {
        case .choose: "Rate or send feedback"
        case .feedback: "Help us improve"
        }
    }

    private var chooseContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(SidelineTheme.brandPrimary)
                    .frame(width: 64, height: 64)
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text("A quick App Store rating helps more non-fans find Gist. Got a problem or an idea instead? Send feedback and it goes straight to the developer.")
                .font(.subheadline)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    ReviewPromptTracker.markOpenedWriteReview()
                    openWriteReviewURL()
                    finish(.openedWriteReview)
                } label: {
                    primaryButtonLabel("Rate on the App Store")
                }
                .buttonStyle(.plain)

                Button {
                    step = .feedback
                } label: {
                    secondaryButtonLabel("Send feedback")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make Gist work better for you?")
                .font(.subheadline)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(.body)
                .frame(minHeight: 140)
                .padding(10)
                .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: 12))
                .focused($feedbackFocused)

            Text("Opens your mail app with a draft to the developer.")
                .font(.caption)
                .foregroundStyle(SidelineTheme.inkSecondary)

            Button {
                sendFeedback()
            } label: {
                primaryButtonLabel("Send feedback")
            }
            .buttonStyle(.plain)
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear { feedbackFocused = true }
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SidelineTheme.brandPrimary, in: Capsule())
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SidelineTheme.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private func handleNotNow() {
        ReviewPromptTracker.markShown()
        finish(.notNow)
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = Self.feedbackMailURL(body: trimmed) else { return }
        ReviewPromptTracker.markFeedbackSubmitted()
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
        finish(.feedbackSubmitted)
    }

    private func finish(_ outcome: ReviewPromptDismissOutcome) {
        onFinish(outcome)
        dismiss()
    }

    private func openWriteReviewURL() {
        #if canImport(UIKit)
        UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
        #endif
    }

    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jack@jackwallner.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Gist feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
