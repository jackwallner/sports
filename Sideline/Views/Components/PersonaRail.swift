import Shared
import SwiftUI

struct PersonaRail: View {
    let selected: Persona
    let isPro: Bool
    let onSelect: (Persona) -> Void

    var body: some View {
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
