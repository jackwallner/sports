import Foundation

public enum Persona: String, Codable, CaseIterable, Identifiable, Sendable {
    case cocktailParty = "cocktail_party"
    case sportsTalkForMoms = "sports_talk_for_moms"
    case officeWatercooler = "office_watercooler"
    case dateNight = "date_night"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cocktailParty:
            return "Cocktail Party"
        case .sportsTalkForMoms:
            return "Sports Talk for Moms"
        case .officeWatercooler:
            return "Office Watercooler"
        case .dateNight:
            return "Date Night"
        }
    }

    public var shortPitch: String {
        switch self {
        case .cocktailParty:
            return "Broad, witty, easy to drop anywhere."
        case .sportsTalkForMoms:
            return "Warm prompts for talking with a sports-obsessed kid."
        case .officeWatercooler:
            return "Safe, current takes for coworkers."
        case .dateNight:
            return "A charming story and a follow-up question."
        }
    }

    public var symbolName: String {
        switch self {
        case .cocktailParty:
            return "wineglass"
        case .sportsTalkForMoms:
            return "figure.2.and.child.holdinghands"
        case .officeWatercooler:
            return "cup.and.saucer"
        case .dateNight:
            return "heart.text.square"
        }
    }

    public var isFree: Bool {
        self == .cocktailParty
    }

    public var contextHeader: String {
        switch self {
        case .cocktailParty: return "WHEN TALK TURNS TO SPORTS"
        case .sportsTalkForMoms: return "WHEN YOUR KID BRINGS IT UP"
        case .officeWatercooler: return "AT THE OFFICE TODAY"
        case .dateNight: return "FOR THE DINNER TABLE"
        }
    }

    /// A real, readable taste of how this room sounds. Shown unblurred in the
    /// Pro preview so the user can actually evaluate the value before upselling.
    public var proPreviewTeaser: String {
        switch self {
        case .cocktailParty:
            return "\"Everyone's calling it the upset of the year, but honestly the favorite looked tired all night.\" Drop that and you're in the conversation."
        case .sportsTalkForMoms:
            return "Your kid won't stop talking about the rookie everyone's hyping. Try: \"Is he actually better than the guy who got hurt?\" Watch them light up."
        case .officeWatercooler:
            return "Someone will bring up last night's blown call. Safe line: \"The refs are having a rough season, huh?\" Agreeable, current, done."
        case .dateNight:
            return "Lead with the comeback: a player benched all year won it in the final seconds. Then ask, \"Do you root for the underdog or the favorite?\""
        }
    }

    public var paywallHook: String {
        switch self {
        case .cocktailParty: return "Sound prepared anywhere"
        case .sportsTalkForMoms: return "Sound tuned-in to your kid"
        case .officeWatercooler: return "Sound prepared at the office"
        case .dateNight: return "Sound prepared at dinner"
        }
    }
}
