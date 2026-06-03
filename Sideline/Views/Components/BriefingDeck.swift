import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The whole briefing as one full-bleed deck of swipeable cards:
/// Lead (the line to say) -> one card per talking point -> "Your move".
///
/// One idea per card, lots of air. The deck is the screen, so the user only
/// ever reads a single thought at a time instead of a wall of stacked text.
struct BriefingDeck: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 7
    @ScaledMetric(relativeTo: .footnote) private var activeDotWidth: CGFloat = 22

    private var cards: [DeckCard] {
        [.lead(briefing)]
            + briefing.bullets.map(DeckCard.point)
            + [.question(briefing.suggestedQuestion)]
    }

    var body: some View {
        let cards = self.cards
        VStack(spacing: 14) {
            TabView(selection: $index) {
                ForEach(Array(cards.enumerated()), id: \.offset) { position, card in
                    DeckCardView(
                        card: card,
                        position: position,
                        talkingPointCount: briefing.bullets.count,
                        onOpenSource: onOpenSource
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityElement(children: .contain)
            .accessibilityValue("Card \(min(index, cards.count - 1) + 1) of \(cards.count)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if index < cards.count - 1 { index += 1 }
                case .decrement: if index > 0 { index -= 1 }
                default: break
                }
            }

            pageDots(count: cards.count)
        }
    }

    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? SidelineTheme.brandPrimary : SidelineTheme.rule)
                    .frame(width: i == index ? activeDotWidth : dotSize, height: dotSize)
                    .animation(.snappy(duration: 0.22), value: index)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

enum DeckCard {
    case lead(Briefing)
    case point(BriefingBullet)
    case question(String)
}

private struct DeckCardView: View {
    let card: DeckCard
    let position: Int
    let talkingPointCount: Int
    let onOpenSource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            kicker

            ScrollView(.vertical, showsIndicators: false) {
                body(for: card)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.sidelineDeckCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(SidelineTheme.rule, lineWidth: 1)
        )
        .shadow(color: SidelineTheme.inkPrimary.opacity(0.07), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    // MARK: Kicker (top label row)

    @ViewBuilder
    private var kicker: some View {
        switch card {
        case .lead(let briefing):
            eyebrow(symbol: briefing.persona.symbolName,
                    text: briefing.persona.contextHeader,
                    color: SidelineTheme.brandPrimary)
        case .point(let bullet):
            HStack(spacing: 8) {
                if let tag = bullet.tag, tag != .neutral {
                    tagPill(tag)
                }
                if let subject = bullet.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SidelineTheme.inkSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SidelineTheme.rule, in: Capsule())
                }
                Spacer(minLength: 0)
                Text("\(position) / \(talkingPointCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SidelineTheme.inkTertiary)
                    .tracking(0.5)
            }
        case .question:
            eyebrow(symbol: "arrow.turn.down.right",
                    text: "YOUR MOVE",
                    color: SidelineTheme.amberText)
        }
    }

    private func eyebrow(symbol: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(SidelineTheme.eyebrow)
                .tracking(1.3)
        }
        .foregroundStyle(color)
    }

    // MARK: Body (the single idea)

    @ViewBuilder
    private func body(for card: DeckCard) -> some View {
        switch card {
        case .lead(let briefing):
            Text(briefing.tlDR)
                .font(SidelineTheme.display(26))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .copyable(briefing.tlDR)

        case .point(let bullet):
            Text(bullet.talkingPoint)
                .font(.title2.weight(.semibold))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .copyable(bullet.talkingPoint)

        case .question(let question):
            HStack(alignment: .top, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .foregroundStyle(SidelineTheme.brandAccent.opacity(0.5))
                    .offset(y: 10)
                Text(question)
                    .font(SidelineTheme.display(24))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .copyable(question)
            }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        switch card {
        case .lead:
            HStack(spacing: 5) {
                Text(talkingPointCount == 1 ? "Swipe for the talking point" : "Swipe for \(talkingPointCount) talking points")
                Image(systemName: "chevron.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(SidelineTheme.brandPrimary)
            .accessibilityHidden(true)

        case .point(let bullet):
            Button {
                onOpenSource(bullet.sourceURL)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(bullet.sourceHeadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(SidelineTheme.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Source: \(bullet.sourceHeadline), opens link")

        case .question:
            Text("Ask a fan to keep it going.")
                .font(.caption)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .accessibilityHidden(true)
        }
    }

    private func tagPill(_ tag: BriefingTag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.symbolName)
                .font(.caption2.weight(.bold))
            Text(tag.displayName.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tagColor(tag))
        .background(SidelineTheme.tagFill(tagColor(tag)), in: Capsule())
    }

    private func tagColor(_ tag: BriefingTag) -> Color {
        switch tag {
        case .niceGuy, .redemption: return SidelineTheme.tagNiceGuy
        case .jerk, .drama: return SidelineTheme.tagJerk
        case .neutral: return SidelineTheme.inkSecondary
        }
    }
}

// MARK: - Copy affordance

private extension View {
    /// Long-press to copy the card's line. Kept tiny so a card stays one idea.
    @ViewBuilder
    func copyable(_ text: String) -> some View {
        self.contextMenu {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = text
                #endif
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
