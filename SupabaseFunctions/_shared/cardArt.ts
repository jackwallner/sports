import type { BriefingTag, GeneratedBullet } from "./types.ts";

// Card art for the briefing deck, generated for free by pollinations.ai from a
// prompt embedded in the URL. This module is the server-side twin of the app's
// `Sideline/Utilities/CardArt.swift` — keep prompt text, query order, and the
// FNV-1a seed in sync so both ends agree on a story's art.
//
// The pipeline stamps `image_url` on every bullet at generation time, and the
// GitHub Actions cron then fetches each URL once. Pollinations caches a
// generated image by URL, so by the time a phone asks, the art is a CDN hit
// instead of a multi-second generation that counts against the free tier's
// one-request-per-IP queue.
//
// Prompts ask for editorial illustration of the sport's scene and the story's
// mood, never a named player: generated faces of real athletes look uncanny
// and read as fake news.

const STYLE = "modern editorial sports illustration, bold graphic shapes, " +
  "screen print texture, high contrast, dramatic lighting, no readable faces, " +
  "no text, no words, no letters, no logos, no watermark";

const FALLBACK_SCENE = "packed sports stadium at night under floodlights, " +
  "crowd in silhouette, confetti in the air";

export function imageURLForBullet(bullet: GeneratedBullet): string {
  const prompt = `${sceneFor(bullet)}, ${moodFor(bullet.tag ?? null)}, ${STYLE}`;
  return pollinationsURL(prompt, fnv1a32(bullet.source_url));
}

function moodFor(tag: BriefingTag | null): string {
  switch (tag) {
    case "jerk":
    case "drama":
      return "tense dramatic mood, stormy sky, deep red and charcoal palette";
    case "nice_guy":
    case "redemption":
      return "uplifting hopeful mood, warm golden light, green and gold palette";
    default:
      return "energetic night-game mood, deep navy and teal palette";
  }
}

function sceneFor(bullet: GeneratedBullet): string {
  const hay = `${bullet.subject ?? ""} ${bullet.source_headline}`.toLowerCase();
  const has = (words: string[]) => words.some((word) => hay.includes(word));

  if (
    has([
      "nfl", "football", "quarterback", "touchdown", "super bowl", " qb",
      "cowboys", "eagles", "chiefs", "packers", "steelers", "49ers", "niners",
      "patriots", "bills", "ravens", "dolphins", "bengals", "broncos", "raiders",
      "browns", "seahawks", "vikings", "buccaneers", "commanders",
    ])
  ) {
    return "american football stadium at night, floodlights, players in silhouette on the field";
  }
  if (
    has([
      "wnba", "nba", "basketball", "dunk", "three-pointer",
      "knicks", "lakers", "celtics", "warriors", "bulls", "mavericks", "nuggets",
      "bucks", "sixers", "76ers", "timberwolves", "cavaliers", "thunder",
    ])
  ) {
    return "basketball arena, single spotlight on the hardwood court, hoop in silhouette";
  }
  if (
    has([
      "mlb", "baseball", "pitcher", "home run", "world series",
      "yankees", "dodgers", "red sox", "mets", "cubs", "astros", "braves",
      "phillies", "orioles",
    ])
  ) {
    return "baseball stadium at dusk, batter in silhouette at home plate, stadium lights glowing";
  }
  if (has(["soccer", "fifa", "premier league", "la liga", " mls", "world cup", "messi", "ronaldo"])) {
    return "soccer stadium, vivid green pitch under lights, ball in the foreground";
  }
  if (has(["tennis", "wimbledon", "grand slam", "djokovic", "serena", "alcaraz"])) {
    return "tennis court at golden hour, long shadows, racket and ball";
  }
  if (
    has([
      "nhl", "hockey", "stanley cup",
      "bruins", "oilers", "maple leafs", "canadiens", "blackhawks", "penguins",
    ])
  ) {
    return "ice hockey rink, skater in silhouette, ice spray frozen mid-stop, cold arena light";
  }
  if (has(["golf", "pga", "masters", "mcilroy"])) {
    return "golf course at sunrise, rolling fairway, lone flag on the green";
  }
  if (has(["olympic", "medal"])) {
    return "olympic stadium at night, torch flame burning, fireworks above";
  }
  return FALLBACK_SCENE;
}

function pollinationsURL(prompt: string, seed: number): string {
  // Match Swift's URLComponents encoding: spaces become %20, commas stay.
  const path = encodeURIComponent(prompt).replace(/%2C/g, ",");
  return `https://image.pollinations.ai/prompt/${path}` +
    `?width=768&height=960&nologo=true&safe=true&seed=${seed}`;
}

/// FNV-1a, 32-bit — identical to CardArt.stableSeed in the app.
function fnv1a32(text: string): number {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(text)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}
