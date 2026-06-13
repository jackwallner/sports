import Shared
import SwiftUI

struct PersonaRail: View {
    let selected: Persona
    let isPro: Bool
    let onSelect: (Persona) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The chips alone read as ambiguous filters. Frame the choice the
            // way the user actually makes it: who am I about to talk to?
            HStack(spacing: 6) {
                Text("ROOMS")
                    .font(SidelineTheme.eyebrow)
                    .tracking(1.4)
                    .foregroundStyle(SidelineTheme.brandPrimary)
                Text("Pick who you'll be talking to")
                    .font(.caption)
                    .foregroundStyle(SidelineTheme.inkTertiary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            chips

            // The selected room's pitch, so switching rooms visibly changes
            // what the briefing below is for.
            Text(selected.shortPitch)
                .font(.caption)
                .foregroundStyle(SidelineTheme.inkTertiary)
                .lineLimit(1)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .animation(nil, value: selected)
                .accessibilityLabel("\(selected.displayName): \(selected.shortPitch)")
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Persona.allCases) { persona in
                    Button {
                        onSelect(persona)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: persona.symbolName)
                            Text(persona.displayName)
                                .lineLimit(1)
                            if !persona.isFree && !isPro {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .accessibilityLabel("Pro")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(foreground(for: persona))
                        .background(
                            Capsule().fill(persona == selected ? SidelineTheme.brandPrimary : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(persona == selected ? Color.clear : SidelineTheme.rule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: persona))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func foreground(for persona: Persona) -> some ShapeStyle {
        persona == selected
            ? AnyShapeStyle(Color.white)
            : AnyShapeStyle(SidelineTheme.inkPrimary)
    }

    private func accessibilityLabel(for persona: Persona) -> String {
        if !persona.isFree && !isPro {
            return "\(persona.displayName), Pro context"
        }

        if persona == selected {
            return "\(persona.displayName), selected"
        }

        return persona.displayName
    }
}
