import Shared
import SwiftUI

struct ProPreviewSheet: View {
    let persona: Persona
    let onSeePro: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: persona.symbolName)
                            .font(.caption.weight(.bold))
                        Text(persona.contextHeader)
                            .font(.caption.weight(.heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(SidelineTheme.brandPrimary)

                    Text(persona.displayName)
                        .font(.largeTitle.weight(.bold))
                    Text(persona.shortPitch)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Here's how this room sounds")
                    .font(.caption.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(.tertiary)

                Text(teaser)
                    .font(.title3.weight(.semibold))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                            .fill(SidelineTheme.brandPrimary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SidelineTheme.cardCornerRadius)
                            .stroke(SidelineTheme.brandPrimary.opacity(0.18), lineWidth: 1)
                    )
                    .blur(radius: 4)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundStyle(SidelineTheme.brandPrimary)
                    )

                Spacer()

                Button {
                    onSeePro()
                } label: {
                    Text("Unlock \(persona.displayName)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(SidelineTheme.brandPrimary)
            }
            .padding(24)
            .navigationTitle(persona.paywallHook)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onDismiss() }
                }
            }
        }
    }

    private var teaser: String {
        Briefing.sample.tlDR
    }
}
