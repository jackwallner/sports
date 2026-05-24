import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SuggestedQuestionCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption.weight(.bold))
                Text("Your move")
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
            }
            .foregroundStyle(SidelineTheme.amberText)

            HStack(alignment: .top, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 38, weight: .black, design: .serif))
                    .foregroundStyle(SidelineTheme.brandAccent.opacity(0.55))
                    .offset(y: 6)
                Text(question)
                    .font(SidelineTheme.title)
                    .foregroundStyle(SidelineTheme.inkPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .fill(Color.sidelineCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                .stroke(SidelineTheme.brandAccent, lineWidth: 1)
        )
        .contextMenu {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = question
                #endif
            } label: {
                Label("Copy question", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your move, suggested question: \(question)")
    }
}
