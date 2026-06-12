import Foundation
import Shared
import XCTest

final class BriefingDecodingTests: XCTestCase {
    func testDecodesSupabaseBriefingContract() throws {
        let json = """
        [{
          "id": "11111111-1111-1111-1111-111111111111",
          "persona": "cocktail_party",
          "scope": "national",
          "refresh_window": "daily",
          "headline": "What everyone's arguing about this week",
          "tl_dr": "A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month.",
          "lead_image_url": "https://example.supabase.co/storage/v1/object/public/card-art/lead.jpg",
          "lead_backstory": "The Cowboys, the most-watched team in football, benched their starter of 9 years mid-playoff race.",
          "bullets": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "talking_point": "The team benched their longtime starter, and fans are split.",
            "tie_in": "His wife posted a cryptic quote about loyalty.",
            "backstory": "He has started every game for 9 years, but the team lost 5 straight and the front office blinked first.",
            "tag": "drama",
            "tag_reason": "Locker-room sources are frustrated.",
            "source_headline": "Veteran QB benched amid playoff push - The Athletic",
            "source_url": "https://example.com/story",
            "image_url": "https://image.pollinations.ai/prompt/test?seed=1"
          }, {
            "id": "33333333-3333-3333-3333-333333333333",
            "talking_point": "Older bullet without pipeline-stamped art still decodes.",
            "source_headline": "From warehouse shifts to starting QB - ESPN",
            "source_url": "https://example.com/other"
          }],
          "suggested_question": "Do you think they made the right call?",
          "source_count": 1,
          "generated_at": "2026-05-16T12:00:00Z",
          "expires_at": "2026-05-17T12:00:00Z"
        }]
        """.data(using: .utf8)!

        let briefings = try JSONDecoder.sideline.decode([Briefing].self, from: json)

        XCTAssertEqual(briefings.first?.persona, .cocktailParty)
        XCTAssertEqual(briefings.first?.bullets.first?.tag, .drama)
        XCTAssertEqual(briefings.first?.sourceCount, 1)
        XCTAssertEqual(
            briefings.first?.bullets.first?.imageURL,
            URL(string: "https://image.pollinations.ai/prompt/test?seed=1")
        )
        XCTAssertEqual(
            briefings.first?.leadImageURL,
            URL(string: "https://example.supabase.co/storage/v1/object/public/card-art/lead.jpg")
        )
        XCTAssertEqual(
            briefings.first?.leadBackstory,
            "The Cowboys, the most-watched team in football, benched their starter of 9 years mid-playoff race."
        )
        XCTAssertEqual(
            briefings.first?.bullets.first?.backstory,
            "He has started every game for 9 years, but the team lost 5 straight and the front office blinked first."
        )
        XCTAssertNil(briefings.first?.bullets.last?.imageURL)
        // Pre-v2 rows decode without the new fields.
        XCTAssertNil(briefings.first?.bullets.last?.backstory)
    }

    func testSampleBriefingHasRequiredSourceLinks() throws {
        XCTAssertFalse(Briefing.sample.bullets.isEmpty)
        XCTAssertTrue(Briefing.sample.bullets.allSatisfy { $0.sourceURL.scheme == "https" })
    }
}
