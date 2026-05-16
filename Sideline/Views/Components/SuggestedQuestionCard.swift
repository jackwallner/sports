import SwiftUI

struct SuggestedQuestionCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ask them this", systemImage: "questionmark.bubble")
                .font(.caption.weight(.bold))
                .foregroundStyle(SidelineTheme.amberText)

            Text(question)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .fill(SidelineTheme.brandAccent.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .stroke(SidelineTheme.brandAccent, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested question: \(question)")
    }
}
