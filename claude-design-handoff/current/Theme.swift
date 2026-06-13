import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    /// Lifts in dark mode so it pops against deep paper without losing the brand.
    static let brandPrimary: Color = {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.353, green: 0.682, blue: 0.502, alpha: 1)  // #5AAE80
                : UIColor(red: 0.122, green: 0.361, blue: 0.271, alpha: 1)  // #1F5C45
        })
        #else
        return Color(red: 0.122, green: 0.361, blue: 0.271)
        #endif
    }()

    /// The single accent. Reserved for sparks: the SuggestedQuestionCard
    /// tint, the "tie-in" sparkle, small markers. Never the main surface.
    static let brandAccent  = Color(red: 0.773, green: 0.565, blue: 0.102)  // #C5901A

    /// Darker accent for inline text on cream (AAA on #FAF6EE).
    /// In dark mode, lifts to a warm gold so it stays legible on deep paper.
    static let amberText: Color = {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.937, green: 0.788, blue: 0.439, alpha: 1)  // #EFC970
                : UIColor(red: 0.353, green: 0.251, blue: 0.067, alpha: 1)  // #5A4011
        })
        #else
        return Color(red: 0.353, green: 0.251, blue: 0.067)
        #endif
    }()

    // MARK: - Surfaces (Newsroom is cream-first)
    /// Paper. The single background colour for ~95% of the app.
    static let paperSurface = Color(red: 0.980, green: 0.965, blue: 0.933)  // #FAF6EE

    /// Ink. Headlines, body, and 100%-opacity primary content.
    /// Flips to a warm off-white in dark mode so type stays legible on deep paper.
    static let inkPrimary: Color = {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.953, green: 0.937, blue: 0.910, alpha: 1)  // #F3EFE8
                : UIColor(red: 0.102, green: 0.086, blue: 0.071, alpha: 1)  // #1A1612
        })
        #else
        return Color(red: 0.102, green: 0.086, blue: 0.071)
        #endif
    }()
    /// 62% ink — secondary text (headlines under TL;DR, source links).
    static let inkSecondary = inkPrimary.opacity(0.70)
    /// 64% ink — tertiary (counts, captions, freshness footer). Bumped from
    /// 48% so small text clears WCAG AA contrast on both the cream surface
    /// and the elevated card surface (source links on cards).
    static let inkTertiary  = inkPrimary.opacity(0.64)
    /// 10% ink — rules and dividers. Prefer a real `Divider()` when you can.
    static let rule         = inkPrimary.opacity(0.14)

    // MARK: - Tags (retuned for legibility on cream AND deep paper)
    /// Green tag (nice-guy / redemption). Lifts in dark mode so it stays readable
    /// at full opacity over warm-deep paper.
    static let tagNiceGuy: Color = {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.451, green: 0.788, blue: 0.580, alpha: 1)  // #73C994
                : UIColor(red: 0.180, green: 0.490, blue: 0.310, alpha: 1)  // #2E7D4F
        })
        #else
        return Color(red: 0.180, green: 0.490, blue: 0.310)
        #endif
    }()

    /// Red tag (jerk / drama). Lifts in dark mode.
    static let tagJerk: Color = {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.937, green: 0.490, blue: 0.404, alpha: 1)  // #EF7D67
                : UIColor(red: 0.706, green: 0.271, blue: 0.184, alpha: 1)  // #B4452F
        })
        #else
        return Color(red: 0.706, green: 0.271, blue: 0.184)
        #endif
    }()

    /// Opacity for tag pill fills. Lifts in dark mode so the wash stays visible
    /// against deep paper.
    static let tagFillOpacity: Double = {
        #if canImport(UIKit)
        // Best-effort: read current trait at first access; UIColor dynamic
        // can't drive a Double directly, so call sites use a Color wrapper.
        return 0.18
        #else
        return 0.16
        #endif
    }()

    /// Dynamic tag-fill color: tints `base` and bumps opacity in dark mode.
    static func tagFill(_ base: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            let alpha: CGFloat = trait.userInterfaceStyle == .dark ? 0.26 : 0.16
            return UIColor(base).withAlphaComponent(alpha)
        })
        #else
        return base.opacity(0.16)
        #endif
    }

    // MARK: - Deck hero art bands
    //
    // Full-bleed gradient panels that top each swipe card so a story leads with
    // a visual, not a wall of text. Tuned deep on purpose: white type and a
    // faded glyph sit on top, so these stay fixed (not Dynamic) and clear
    // contrast in both light and dark mode. Keyed to the story's tag.
    static let heroGreen: [Color] = [Color(red: 0.07, green: 0.36, blue: 0.27),
                                     Color(red: 0.16, green: 0.52, blue: 0.40)]
    static let heroRed: [Color]   = [Color(red: 0.50, green: 0.15, blue: 0.12),
                                     Color(red: 0.78, green: 0.45, blue: 0.16)]
    static let heroNavy: [Color]  = [Color(red: 0.10, green: 0.19, blue: 0.31),
                                     Color(red: 0.15, green: 0.34, blue: 0.30)]
    static let heroGold: [Color]  = [Color(red: 0.46, green: 0.31, blue: 0.06),
                                     Color(red: 0.77, green: 0.56, blue: 0.10)]

    // MARK: - Deck card anatomy
    //
    // Every card is two zones: art on top, words on one solid panel below.
    // The panel is the SAME deep brand green on every story card — one
    // surface for the whole deck is what makes it read as a set instead of
    // a stack of unrelated posters. Fixed (not Dynamic): white type on top.
    /// The panel the card's words sit on. Top color is also the fade target
    /// at the bottom of the art zone, so art settles into the panel seamlessly.
    static let cardPanel: [Color] = [Color(red: 0.082, green: 0.216, blue: 0.165),  // #15372A
                                     Color(red: 0.122, green: 0.361, blue: 0.271)]  // #1F5C45
    /// The finale "Your move" card goes gold — the single accent at the end.
    static let cardPanelGold: [Color] = heroGold
    /// Eyebrows / kickers on the dark panel.
    static let goldOnDark = Color(red: 0.937, green: 0.788, blue: 0.439)  // #EFC970
    /// Art-zone floor while generated art loads; darkens toward the panel.
    static let artPlaceholder: [Color] = [Color(red: 0.165, green: 0.420, blue: 0.318),
                                          Color(red: 0.106, green: 0.282, blue: 0.212)]
    /// Fixed-depth tag pill fills (white text on top) for pills sitting on art.
    static let tagPillNice  = Color(red: 0.149, green: 0.420, blue: 0.275)
    static let tagPillDrama = Color(red: 0.620, green: 0.230, blue: 0.160)
    /// Swipe-deck card corner radius (cards + loading skeleton).
    static let deckCornerRadius: CGFloat = 28

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
    ///
    /// Keeps the editorial serif at a deliberate point size but scales it with
    /// the user's Dynamic Type setting (via `UIFontMetrics`), so the hero
    /// TL;DR, onboarding, and paywall headlines grow for larger text settings
    /// instead of staying frozen.
    static func display(_ size: CGFloat = 28) -> Font {
        #if canImport(UIKit)
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        let serif = UIFont(descriptor: descriptor, size: size)
        return Font(UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: serif))
        #else
        return .system(size: size, weight: .semibold, design: .serif)
        #endif
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

    /// Elevated card surface for the swipeable briefing deck. A clean near-white
    /// in light mode (floats above the cream page) and a lifted deep-paper tone
    /// in dark mode. Pairs with a hairline border + soft shadow so each card
    /// reads as a physical card you can swipe.
    static var sidelineDeckCard: Color {
        #if os(iOS)
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.118, green: 0.106, blue: 0.090, alpha: 1)  // lifted deep paper
                : UIColor(red: 1.0, green: 0.996, blue: 0.984, alpha: 1)     // #FFFEFB clean card
        })
        #else
        SidelineTheme.paperSurface
        #endif
    }
}
