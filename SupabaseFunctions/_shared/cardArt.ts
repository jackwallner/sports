import { logError, logInfo } from "./logger.ts";
import type { BriefingTag, GeneratedBullet } from "./types.ts";

// Card art for the briefing deck.
//
// Preferred path (POLLINATIONS_API_KEY set): generate each image once via
// gen.pollinations.ai using the API key, upload it to the public `card-art`
// storage bucket, and stamp the storage URL on the bullet. Every phone then
// downloads the same image from our own storage — no third-party rate limits
// at runtime, fully deterministic. Images are keyed by prompt+seed, so the
// same story reuses the same file across personas and refresh windows.
//
// Fallback path (no key, or generation/upload fails): stamp the legacy
// pollinations.ai on-demand URL. The app can still fetch that from a
// residential IP, and its own gradient is the floor below that. This module
// is the server-side twin of `Sideline/Utilities/CardArt.swift` — keep prompt
// text, query order, and the FNV-1a seed in sync.
//
// Prompts ask for editorial illustration of the sport's scene and the story's
// mood, never a named player: generated faces of real athletes look uncanny
// and read as fake news.

const BUCKET = "card-art";

/** Stamp `image_url` on every bullet, generating + storing art when possible. */
export async function stampCardArt(
  supabase: any,
  trace_id: string,
  bullets: GeneratedBullet[],
): Promise<GeneratedBullet[]> {
  const hasProvider = Boolean(
    (Deno.env.get("CF_ACCOUNT_ID") && Deno.env.get("CF_API_TOKEN")) ||
      Deno.env.get("POLLINATIONS_API_KEY"),
  );
  const stamped: GeneratedBullet[] = [];
  for (const bullet of bullets) {
    stamped.push({
      ...bullet,
      image_url: hasProvider
        ? await storedImageURL(supabase, trace_id, bullet)
        : imageURLForBullet(bullet),
    });
  }
  return stamped;
}

async function storedImageURL(
  supabase: any,
  trace_id: string,
  bullet: GeneratedBullet,
): Promise<string> {
  const prompt = promptFor(bullet);
  const seed = fnv1a32(bullet.source_url);
  const path = `${seed}-${fnv1a32(prompt)}.jpg`;
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  const publicUrl: string = data.publicUrl;

  try {
    // Same story already rendered (other persona, earlier window)? Reuse it.
    const head = await fetch(publicUrl, { method: "HEAD" });
    if (head.ok) {
      return publicUrl;
    }

    const bytes = await generateImage(prompt, seed);

    // Self-provision the public bucket on first ever use.
    await supabase.storage.createBucket(BUCKET, { public: true }).catch(() => {});
    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(path, bytes, { contentType: contentType(bytes), upsert: true });
    if (uploadError) {
      throw uploadError;
    }

    logInfo(trace_id, "card_art_stored", { path, bytes: bytes.length });
    return publicUrl;
  } catch (error) {
    // Art is decoration, never a reason to fail a briefing. Fall back to the
    // legacy on-demand URL the app can fetch itself.
    logError(trace_id, "card_art_generation_failed", error, { path });
    return imageURLForBullet(bullet);
  }
}

// Provider chain, free-first: Cloudflare Workers AI's forever-free tier
// (10,000 neurons/day, far above the ~30 images a day of briefings needs),
// then Pollinations if a key with pollen balance is configured. The caller
// falls back to the legacy on-demand URL if every provider misses.
async function generateImage(prompt: string, seed: number): Promise<Uint8Array> {
  const cfAccount = Deno.env.get("CF_ACCOUNT_ID");
  const cfToken = Deno.env.get("CF_API_TOKEN");
  if (cfAccount && cfToken) {
    try {
      return await generateWithCloudflare(prompt, seed, cfAccount, cfToken);
    } catch {
      // Fall through to Pollinations.
    }
  }
  const pollinationsKey = Deno.env.get("POLLINATIONS_API_KEY");
  if (pollinationsKey) {
    return await generateWithPollinations(prompt, seed, pollinationsKey);
  }
  throw new Error("No image provider configured or available");
}

/** FLUX.1 schnell on Workers AI. Returns base64 JSON; square 1024px output. */
async function generateWithCloudflare(
  prompt: string,
  seed: number,
  accountId: string,
  token: string,
): Promise<Uint8Array> {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/@cf/black-forest-labs/flux-1-schnell`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ prompt, seed, steps: 8 }),
    },
  );
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Cloudflare Workers AI returned ${response.status}`);
  }
  const payload = await response.json();
  const b64 = payload?.result?.image;
  if (typeof b64 !== "string" || !b64) {
    throw new Error("Cloudflare Workers AI returned no image");
  }
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/// Bursts of generations can trip the gateway's rate limit (402/429); those
/// are worth a short backoff. Anything else fails fast to the legacy URL.
async function generateWithPollinations(prompt: string, seed: number, apiKey: string): Promise<Uint8Array> {
  let status = 0;
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await new Promise((resolve) => setTimeout(resolve, 5000 * attempt));
    }
    const response = await fetch(
      `https://gen.pollinations.ai/image/${encodePromptPath(prompt)}` +
        `?width=768&height=960&seed=${seed}&safe=true`,
      { headers: { Authorization: `Bearer ${apiKey}` } },
    );
    if (response.ok) {
      return new Uint8Array(await response.arrayBuffer());
    }
    status = response.status;
    await response.body?.cancel();
    if (status !== 402 && status !== 429) {
      break;
    }
  }
  throw new Error(`gen.pollinations.ai returned ${status}`);
}

function contentType(bytes: Uint8Array): string {
  return bytes[0] === 0x89 && bytes[1] === 0x50 ? "image/png" : "image/jpeg";
}

// The house style. Every card runs through this identical wrapper so the deck
// reads as one illustrated set, whether the scene is a stadium at night or a
// cartoon great dane in a quarterback jersey. Gemini supplies only the scene
// (the WHAT); this supplies the entire look (the HOW).
const STYLE_PREFIX = "Retro editorial sports poster illustration:";
const STYLE = "Flat bold graphic shapes, screen print risograph texture, " +
  "limited palette of deep navy, warm cream, forest green and antique gold, " +
  "dramatic side lighting, grainy shadows, 1960s sports magazine poster aesthetic. " +
  "No real people's likenesses, no readable faces, no text, no words, no letters, " +
  "no numbers, no logos, no watermark, no signature, no caption.";

const FALLBACK_SCENE = "packed sports stadium at night under floodlights, " +
  "crowd in silhouette, confetti in the air";

export function imageURLForBullet(bullet: GeneratedBullet): string {
  return pollinationsURL(promptFor(bullet), fnv1a32(bullet.source_url));
}

function promptFor(bullet: GeneratedBullet): string {
  // Gemini's scene captures the story's actual hook (mashups included);
  // the sport/mood scene is the fallback when it didn't provide one.
  const scene = bullet.image_prompt?.trim() ||
    `${sceneFor(bullet)}, ${moodFor(bullet.tag ?? null)}`;
  return `${STYLE_PREFIX} ${scene}. ${STYLE}`;
}

function encodePromptPath(prompt: string): string {
  return encodeURIComponent(prompt).replace(/%2C/g, ",");
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
  return `https://image.pollinations.ai/prompt/${encodePromptPath(prompt)}` +
    `?width=768&height=960&nologo=true&safe=true&seed=${seed}`;
}

/// FNV-1a, masked to 31 bits — identical to CardArt.stableSeed in the app.
/// gen.pollinations.ai rejects seeds above int32 max, so the top bit goes.
function fnv1a32(text: string): number {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(text)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash & 0x7fffffff;
}
