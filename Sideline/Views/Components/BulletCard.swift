import Shared
import SwiftUI

struct BulletCard: View {
    let bullet: BriefingBullet
    let onOpenSource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(bullet.talkingPoint)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let tieIn = bullet.tieIn, !tieIn.isEmpty {
                Text(tieIn)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tag = bullet.tag {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(tag.displayName, systemImage: tag.symbolName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(tagColor(tag), in: Capsule())

                    if let reason = bullet.tagReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(tagAccessibility(tag: tag, reason: bullet.tagReason))
            }

            Button {
                onOpenSource(bullet.sourceURL)
            } label: {
                Label(bullet.sourceHeadline, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Source: \(bullet.sourceHeadline), link")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sidelineCard, in: RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius))
        .accessibilityElement(children: .contain)
    }

    private func tagColor(_ tag: BriefingTag) -> Color {
        switch tag {
        case .niceGuy, .redemption:
            return SidelineTheme.tagNiceGuy
        case .jerk, .drama:
            return SidelineTheme.tagJerk
        case .neutral:
            return Color(.systemGray)
        }
    }

    private func tagAccessibility(tag: BriefingTag, reason: String?) -> String {
        if let reason {
            return "Tagged: \(tag.displayName), \(reason)"
        }

        return "Tagged: \(tag.displayName)"
    }
}
