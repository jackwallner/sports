import SwiftUI

/// The Sideline — visual system tokens.
///
/// "Newsroom" direction: paper-warm cream surface, ink type, brand
/// green as the system color, gold as a restrained accent. No card
/// chrome by default — separation is by rules and spacing. This file
/// is the single source of truth; nothing in the app should declare
/// a Color or font value outside of it.
enum SidelineTheme {

    // MARK: - Brand
    /// The defining green. Selection, the eyebrow / kicker, system tint.
    static let brandPrimary = Color(red: 0.122, green: 0.361, blue: 0.271)  // #1F5C45

    /// The single accent. Reserved for sparks: the SuggestedQuestionCard
    /// tint, the "tie-in" sparkle, small markers. Never the main surface.
    static let brandAccent  = Color(red: 0.773, green: 0.565, blue: 0.102)  // #C5901A

    /// Darker accent for inline text on cream (AAA on #FAF6EE).
    static let amberText    = Color(red: 0.353, green: 0.251, blue: 0.067)  // #5A4011

    // MARK: - Surfaces (Newsroom is cream-first)
    /// Paper. The single background colour for ~95% of the app.
    static let paperSurface = Color(red: 0.980, green: 0.965, blue: 0.933)  // #FAF6EE

    /// Ink. Headlines, body, and 100%-opacity primary content.
    static let inkPrimary   = Color(red: 0.102, green: 0.086, blue: 0.071)  // #1A1612
    /// 62% ink — secondary text (headlines under TL;DR, source links).
    static let inkSecondary = inkPrimary.opacity(0.62)
    /// 40% ink — tertiary (counts, captions, freshness footer).
    static let inkTertiary  = inkPrimary.opacity(0.40)
    /// 10% ink — rules and dividers. Prefer a real `Divider()` when you can.
    static let rule         = inkPrimary.opacity(0.10)

    // MARK: - Tags (retuned for legibility on cream)
    static let tagNiceGuy = Color(red: 0.180, green: 0.490, blue: 0.310)    // #2E7D4F
    static let tagJerk    = Color(red: 0.706, green: 0.271, blue: 0.184)    // #B4452F

    // MARK: - Shape
    /// Newsroom suppresses most card chrome; reserved for surfaces that
    /// MUST visually float (SuggestedQuestionCard, refreshLimitCard).
    static let cardCornerRadius: CGFloat = 12

    // MARK: - Spacing
    /// 4-pt grid. Reach for these instead of literals so the rhythm holds.
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 28
        static let xxxl: CGFloat = 40
    }

    // MARK: - Type
    //
    // Two voices: a serif for headlines and the eyebrow, the system sans
    // for everything else. We use the system serif *design* rather than a
    // bundled face, so Dynamic Type keeps working and nothing extra has to
    // ship in the bundle. Body text stays on the default system font.

    /// Display — TL;DR hero, large surfaces.
    static func display(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Title — section headings and floated-card titles.
    static let title = Font.system(.title2, design: .serif).weight(.semibold)

    /// Eyebrow / kicker — rendered uppercase with tracking at call sites.
    static let eyebrow = Font.system(.caption, design: .serif).weight(.semibold)

    /// Sans body — defers to .body so Dynamic Type works.
    static let body           = Font.body
    static let bodyEmphasized = Font.callout.weight(.medium)
    static let footnote       = Font.footnote
    static let caption        = Font.caption
}

// MARK: - Color extensions
//
// Drop-in compatibility: the codebase asks for `Color.sidelineCard` and
// `Color.sidelineBackground`. We keep those names but retune the values for
// Newsroom. `sidelineCard` is now a faint gold wash for the few surfaces
// that MUST float; everything else uses `sidelineBackground` and lets rules
// and spacing structure the content.
extension Color {

    static var sidelineBackground: Color {
        #if os(iOS)
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.066, green: 0.058, blue: 0.047, alpha: 1)   // deep paper
                : UIColor(red: 0.980, green: 0.965, blue: 0.933, alpha: 1)   // #FAF6EE
        })
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        SidelineTheme.paperSurface
        #endif
    }

    static var sidelineCard: Color {
        // Same tint, day and night — used so rarely it doesn't need a flip.
        SidelineTheme.brandAccent.opacity(0.10)
    }
}
