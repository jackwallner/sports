import Shared
import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var lastPersona: String
    @Binding var favoriteTeam: String

    @State private var page = 0
    @State private var pickedPersona: Persona = .cocktailParty
    @State private var teamDraft = ""

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                valueProp.tag(0)
                personaPick.tag(1)
                teamPick.tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif
            .background(Color.sidelineBackground)
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            if let persona = Persona(rawValue: lastPersona) {
                pickedPersona = persona
            }
            teamDraft = favoriteTeam
        }
    }

    private var valueProp: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 24)
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(SidelineTheme.brandPrimary)
            Text("Sound like you follow sports.")
                .font(SidelineTheme.display(34))
                .foregroundStyle(SidelineTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Three things to say and one question to ask — in under 20 seconds, before you walk into the room.")
                .font(.title3)
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
            Text("You can switch anytime. Cocktail Party is free; the rest unlock with Pro.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)

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
        Button {
            pickedPersona = persona
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: persona.symbolName)
                    .font(.title3)
                    .foregroundStyle(SidelineTheme.brandPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(persona.displayName)
                            .font(.headline)
                        if !persona.isFree {
                            Text("Pro")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SidelineTheme.brandAccent.opacity(0.2), in: Capsule())
                                .foregroundStyle(SidelineTheme.amberText)
                        }
                    }
                    Text(persona.shortPitch)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if persona == pickedPersona {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SidelineTheme.brandPrimary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .fill(persona == pickedPersona ? SidelineTheme.brandPrimary.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                    .stroke(persona == pickedPersona ? SidelineTheme.brandPrimary.opacity(0.45) : SidelineTheme.rule, lineWidth: persona == pickedPersona ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var teamPick: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 12)
            Text("Got a team?")
                .font(SidelineTheme.title)
                .foregroundStyle(SidelineTheme.inkPrimary)
            Text("Optional. Pro briefings can lean toward your team. Skip if you'd rather not.")
                .font(.callout)
                .foregroundStyle(SidelineTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("e.g. Philadelphia Eagles", text: $teamDraft)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 4)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                #endif

            Text("You can change or clear this anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var actionBar: some View {
        HStack {
            if page > 0 {
                Button("Back") { withAnimation { page -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(primaryLabel) {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(SidelineTheme.brandPrimary)
        }
    }

    private var primaryLabel: String {
        switch page {
        case 0: return "Start"
        case 1: return "Use this room"
        default: return "Done"
        }
    }

    private func advance() {
        switch page {
        case 0:
            withAnimation { page = 1 }
        case 1:
            withAnimation { page = 2 }
        default:
            finish()
        }
    }

    private func finish() {
        lastPersona = pickedPersona.rawValue
        favoriteTeam = teamDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        hasCompletedOnboarding = true
    }
}
