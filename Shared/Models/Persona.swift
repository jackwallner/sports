import Foundation

public enum Persona: String, Codable, CaseIterable, Identifiable, Sendable {
    case cocktailParty = "cocktail_party"
    case sportsTalkForMoms = "sports_talk_for_moms"
    case officeWatercooler = "office_watercooler"
    case dateNight = "date_night"
    case localTeam = "local_team"

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
        case .localTeam:
            return "Local Team"
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
        case .localTeam:
            return "Stories biased toward your city."
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
        case .localTeam:
            return "mappin.and.ellipse"
        }
    }

    public var isFree: Bool {
        self == .cocktailParty
    }

    public var contextHeader: String {
        switch self {
        case .cocktailParty: return "LEAD WITH THIS"
        case .sportsTalkForMoms: return "WHEN YOUR KID BRINGS IT UP"
        case .officeWatercooler: return "AT THE OFFICE TODAY"
        case .dateNight: return "FOR THE DINNER TABLE"
        case .localTeam: return "FOR YOUR LOCAL CROWD"
        }
    }

    public var paywallHook: String {
        switch self {
        case .cocktailParty: return "Sound prepared anywhere"
        case .sportsTalkForMoms: return "Sound tuned-in to your kid"
        case .officeWatercooler: return "Sound prepared at the office"
        case .dateNight: return "Sound prepared at dinner"
        case .localTeam: return "Sound like a local fan"
        }
    }
}
