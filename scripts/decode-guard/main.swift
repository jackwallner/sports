import Foundation

// Decodes the live Supabase row shape with the app's own decoder. Run on
// swift:6.1 (the Foundation shipped in iOS 17 and 18), which rejects
// fractional seconds under plain `.iso8601`.
let stamps = [
    "2026-10-29T23:11:08.104+00:00",
    "2026-10-29T23:11:08.1+00:00",
    "2026-10-29T23:11:08.104123+00:00",
    "2026-10-29T23:11:08+00:00",
    "2026-10-29T23:11:08Z",
]
var failures = 0
for stamp in stamps {
    let json = """
    [{"id":"11111111-1111-1111-1111-111111111111","persona":"cocktail_party","scope":"national",
      "refresh_window":"evening","headline":"h","tl_dr":"t","bullets":[],"suggested_question":"q",
      "source_count":1,"generated_at":"\(stamp)","expires_at":"\(stamp)"}]
    """
    do {
        let rows = try JSONDecoder.sideline.decode([Briefing].self, from: Data(json.utf8))
        let seconds = rows[0].generatedAt.timeIntervalSince1970
        guard Int(seconds) == 1793315468 else {
            print("FAIL \(stamp): decoded \(seconds)")
            failures += 1
            continue
        }
        print("ok   \(stamp)")
    } catch {
        print("FAIL \(stamp): \(error)")
        failures += 1
    }
}
exit(failures == 0 ? 0 : 1)
