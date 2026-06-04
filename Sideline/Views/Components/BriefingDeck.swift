import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The briefing as a small deck of swipeable cards: one self-contained story
/// per card, then a single "Your move" question to keep the conversation going.
///
/// Each story card is the whole job in one glance — the line to say, one beat
/// of backup so you sound like you actually know, and a Learn-more link to the
/// real source. Swipe and you're on a brand-new story. No summary cover, no
/// fragments: one card, one story.
struct BriefingDeck: View {
    let briefing: Briefing
    @Binding var index: Int
    let onOpenSource: (URL) -> Void

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 7
    @ScaledMetric(relativeTo: .footnote) private var activeDotWidth: CGFloat = 22

    private var cards: [DeckCard] {
        briefing.bullets.map(DeckCard.point)
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
                        storyCount: briefing.bullets.count,
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
    case point(BriefingBullet)
    case question(String)
}

private struct DeckCardView: View {
    let card: DeckCard
    let position: Int
    let storyCount: Int
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
        case .point(let bullet):
            HStack(spacing: 8) {
                if let tag = bullet.tag, tag != .neutral {
                    tagPill(tag)
                }
                if let subject = bullet.subject, !subject.isEmpty {
                    Text(subject.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(SidelineTheme.inkSecondary)
                }
                Spacer(minLength: 0)
                Text("\(position + 1) / \(storyCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SidelineTheme.inkTertiary)
                    .tracking(0.5)
                    .accessibilityLabel("Story \(position + 1) of \(storyCount)")
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

    // MARK: Body (the line + one beat of backup)

    @ViewBuilder
    private func body(for card: DeckCard) -> some View {
        switch card {
        case .point(let bullet):
            VStack(alignment: .leading, spacing: 18) {
                // The line to say — the hero of the card.
                Text(bullet.talkingPoint)
                    .font(SidelineTheme.display(24))
                    .foregroundStyle(SidelineTheme.inkPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .copyable(bullet.talkingPoint)

                // One beat of backup so you sound in-the-know. Prefer the
                // spicy tie-in; fall back to why it's a story.
                if let backup = backupDetail(for: bullet) {
                    HStack(alignment: .top, spacing: 12) {
                        Capsule()
                            .fill(SidelineTheme.brandAccent.opacity(0.55))
                            .frame(width: 3)
                        Text(backup)
                            .font(.callout)
                            .foregroundStyle(SidelineTheme.inkSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

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

    /// The supporting beat for a story: the gossipy tie-in if we have one,
    /// otherwise the reason it earned its tag. Nil when the line stands alone.
    private func backupDetail(for bullet: BriefingBullet) -> String? {
        if let tieIn = bullet.tieIn, !tieIn.isEmpty { return tieIn }
        if let reason = bullet.tagReason, !reason.isEmpty { return reason }
        return nil
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        switch card {
        case .point(let bullet):
            Button {
                onOpenSource(bullet.sourceURL)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text("Learn more")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SidelineTheme.brandPrimary)

                    Text(bullet.sourceHeadline)
                        .font(.caption)
                        .foregroundStyle(SidelineTheme.inkTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Learn more. Source: \(bullet.sourceHeadline)")
            .accessibilityHint("Opens the original story")
            .accessibilityAddTraits(.isButton)

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
