import Foundation
import Shared
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Free generated artwork for the briefing deck, served by pollinations.ai.
///
/// Pollinations renders an image on demand from a prompt embedded in the URL —
/// no API key, no upload, no storage of ours. We build one deterministic URL
/// per card (stable seed from the card's own text) so the same story always
/// gets the same art, on this device and on Pollinations' CDN cache.
///
/// The prompts deliberately ask for editorial *illustration* of the sport's
/// scene and the story's mood, never a named player: generated faces of real
/// athletes look uncanny and read as fake news. The vibe is the message.
enum CardArt {

    struct Sport {
        let symbol: String
        let name: String
        let scene: String
    }

    // MARK: - URLs

    static func imageURL(for bullet: BriefingBullet) -> URL? {
        // Prefer art stamped by the content pipeline: the cron has already
        // warmed that exact URL onto the CDN, so it loads instantly.
        if let stamped = bullet.imageURL { return stamped }
        let sport = sport(for: bullet)
        let prompt = "\(sport.scene), \(mood(for: bullet.tag)), \(style)"
        // Seed on the source URL, not the talking point: the same story keeps
        // the same art across personas and refresh windows.
        return pollinationsURL(prompt: prompt, seed: stableSeed(bullet.sourceURL.absoluteString))
    }

    static func leadImageURL(for briefing: Briefing) -> URL? {
        // The TL;DR summarizes the top story, so it shares that story's
        // pipeline-stamped (storage-hosted, always-fast) art when available.
        if let stamped = briefing.bullets.first?.imageURL { return stamped }
        let scene = briefing.bullets.first.map { sport(for: $0).scene } ?? fallbackScene
        let prompt = "\(scene), grand cinematic atmosphere, deep navy and emerald palette, \(style)"
        return pollinationsURL(prompt: prompt, seed: stableSeed(briefing.tlDR))
    }

    private static let style = "modern editorial sports illustration, bold graphic shapes, "
        + "screen print texture, high contrast, dramatic lighting, no readable faces, "
        + "no text, no words, no letters, no logos, no watermark"

    private static let fallbackScene = "packed sports stadium at night under floodlights, "
        + "crowd in silhouette, confetti in the air"

    private static func mood(for tag: BriefingTag?) -> String {
        switch tag {
        case .jerk, .drama:
            return "tense dramatic mood, stormy sky, deep red and charcoal palette"
        case .niceGuy, .redemption:
            return "uplifting hopeful mood, warm golden light, green and gold palette"
        default:
            return "energetic night-game mood, deep navy and teal palette"
        }
    }

    private static func pollinationsURL(prompt: String, seed: UInt32) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "image.pollinations.ai"
        components.path = "/prompt/\(prompt)"
        components.queryItems = [
            URLQueryItem(name: "width", value: "768"),
            URLQueryItem(name: "height", value: "960"),
            URLQueryItem(name: "nologo", value: "true"),
            URLQueryItem(name: "safe", value: "true"),
            URLQueryItem(name: "seed", value: String(seed))
        ]
        return components.url
    }

    /// FNV-1a, masked to 31 bits (Pollinations rejects seeds above int32 max).
    /// Swift's `hashValue` is randomly seeded per launch; the art URL must be
    /// identical across launches (and users) or every open regenerates a
    /// brand-new image and the cache never hits. Twin of the pipeline's
    /// `fnv1a32` in `SupabaseFunctions/_shared/cardArt.ts`.
    private static func stableSeed(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash & 0x7fff_ffff
    }

    // MARK: - Sport detection

    /// Names the sport (chip + scene) from the story's own words. League
    /// keywords first, then league-unique team nicknames so the chip names the
    /// league even when the story only mentions the team.
    static func sport(for bullet: BriefingBullet) -> Sport {
        let hay = ((bullet.subject ?? "") + " " + bullet.sourceHeadline).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { hay.contains($0) } }

        if has(["nfl", "football", "quarterback", "touchdown", "super bowl", " qb",
                "cowboys", "eagles", "chiefs", "packers", "steelers", "49ers", "niners",
                "patriots", "bills", "ravens", "dolphins", "bengals", "broncos", "raiders",
                "browns", "seahawks", "vikings", "buccaneers", "commanders"]) {
            return Sport(symbol: "football.fill", name: "NFL",
                         scene: "american football stadium at night, floodlights, players in silhouette on the field")
        }
        if has(["wnba"]) {
            return Sport(symbol: "basketball.fill", name: "WNBA",
                         scene: "basketball arena, single spotlight on the hardwood court, hoop in silhouette")
        }
        if has(["nba", "basketball", "dunk", "three-pointer",
                "knicks", "lakers", "celtics", "warriors", "bulls", "mavericks", "nuggets",
                "bucks", "sixers", "76ers", "timberwolves", "cavaliers", "thunder"]) {
            return Sport(symbol: "basketball.fill", name: "NBA",
                         scene: "basketball arena, single spotlight on the hardwood court, hoop in silhouette")
        }
        if has(["mlb", "baseball", "pitcher", "home run", "world series",
                "yankees", "dodgers", "red sox", "mets", "cubs", "astros", "braves",
                "phillies", "orioles"]) {
            return Sport(symbol: "baseball.fill", name: "MLB",
                         scene: "baseball stadium at dusk, batter in silhouette at home plate, stadium lights glowing")
        }
        if has(["soccer", "fifa", "premier league", "la liga", " mls", "world cup", "messi", "ronaldo"]) {
            return Sport(symbol: "soccerball", name: "SOCCER",
                         scene: "soccer stadium, vivid green pitch under lights, ball in the foreground")
        }
        if has(["tennis", "wimbledon", "grand slam", "djokovic", "serena", "alcaraz"]) {
            return Sport(symbol: "tennis.racket", name: "TENNIS",
                         scene: "tennis court at golden hour, long shadows, racket and ball")
        }
        if has(["nhl", "hockey", "stanley cup",
                "bruins", "oilers", "maple leafs", "canadiens", "blackhawks", "penguins"]) {
            return Sport(symbol: "figure.hockey", name: "NHL",
                         scene: "ice hockey rink, skater in silhouette, ice spray frozen mid-stop, cold arena light")
        }
        if has(["golf", "pga", "masters", "mcilroy"]) {
            return Sport(symbol: "figure.golf", name: "GOLF",
                         scene: "golf course at sunrise, rolling fairway, lone flag on the green")
        }
        if has(["olympic", "medal"]) {
            return Sport(symbol: "trophy.fill", name: "OLYMPICS",
                         scene: "olympic stadium at night, torch flame burning, fireworks above")
        }

        switch bullet.tag {
        case .drama, .jerk:
            return Sport(symbol: "flame.fill", name: "", scene: fallbackScene)
        case .niceGuy, .redemption:
            return Sport(symbol: "star.fill", name: "", scene: fallbackScene)
        default:
            return Sport(symbol: "sportscourt.fill", name: "", scene: fallbackScene)
        }
    }
}

// MARK: - Loading + cache

#if canImport(UIKit)
/// Image store tuned for Pollinations' free tier, which allows ONE in-flight
/// request per IP (HTTP 402 past that) and takes seconds to generate a fresh
/// image. So: every download goes through a serial chain, rate-limit answers
/// back off and retry, duplicate requests for the same URL join the existing
/// download, and successes land on disk so a card's art is fetched at most
/// once ever. Cards sit on their gradient until art arrives; a miss just
/// means the card stays the way it looks today.
@MainActor
enum CardArtStore {
    private static let memory = NSCache<NSURL, UIImage>()
    private static var inFlight: [URL: Task<UIImage?, Never>] = [:]
    /// Tail of the serial download chain. Each new download awaits the
    /// previous one so we never have two requests racing for the one slot.
    private static var tail: Task<Void, Never>?

    static func cached(_ url: URL) -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        if let image = readDisk(url) {
            memory.setObject(image, forKey: url as NSURL)
            return image
        }
        return nil
    }

    static func fetch(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let running = inFlight[url] { return await running.value }
        let previous = tail
        let task = Task<UIImage?, Never> {
            await previous?.value
            return await download(url)
        }
        inFlight[url] = task
        tail = Task { _ = await task.value }
        let image = await task.value
        inFlight[url] = nil
        return image
    }

    static func prefetch(_ urls: [URL]) {
        for url in urls where cached(url) == nil {
            Task { _ = await fetch(url) }
        }
    }

    private static func download(_ url: URL) async -> UIImage? {
        for attempt in 0..<3 {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 60
            guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            if (200..<300).contains(status), let image = UIImage(data: data) {
                memory.setObject(image, forKey: url as NSURL)
                writeDisk(url, data: data)
                return image
            }
            // 402/429: our one free slot is busy. Wait it out and try again.
            guard status == 402 || status == 429, attempt < 2 else { return nil }
            try? await Task.sleep(nanoseconds: UInt64(5_000_000_000 * (attempt + 1)))
        }
        return nil
    }

    // MARK: Disk cache (Caches/CardArt, purgeable by the system)

    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("CardArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func diskURL(_ url: URL) -> URL? {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in url.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return directory?.appendingPathComponent("\(hash).img")
    }

    private static func readDisk(_ url: URL) -> UIImage? {
        guard let file = diskURL(url), let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    private static func writeDisk(_ url: URL, data: Data) {
        guard let file = diskURL(url) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
#endif

/// Full-bleed card art. Renders nothing until the image is in hand, so the
/// card's gradient stays the floor and the art fades in over it.
struct CardArtImage: View {
    let url: URL?

    #if canImport(UIKit)
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let hit = CardArtStore.cached(url) {
                image = hit
                return
            }
            guard let fetched = await CardArtStore.fetch(url) else { return }
            withAnimation(.easeIn(duration: 0.35)) { image = fetched }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    #else
    var body: some View { Color.clear }
    #endif
}
