import { logError, logInfo } from "./logger.ts";
import type { BriefingTag, GeneratedBriefing, GeneratedBullet } from "./types.ts";

// Card art for the briefing deck.
//
// Preferred path (a provider is configured): generate each image once, upload
// it to the public `card-art` storage bucket, and stamp the storage URL on the
// bullet. Every phone then downloads the same image from our own storage, with
// no third-party rate limits at runtime. Bullet art is keyed by the story's
// source URL alone, so a story covered by several personas or refresh windows
// is drawn once and reused, which keeps the daily free quota in reach.
//
// Fallback path (no provider, or generation/upload fails): stamp the legacy
// pollinations.ai on-demand URL. The app can still fetch that from a
// residential IP, and its own gradient is the floor below that. The FNV-1a
// seed matches `Sideline/Utilities/CardArt.swift`; the app's derived fallback
// still uses the older poster style, which is fine since it is a fallback.
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
  const stamped: GeneratedBullet[] = [];
  for (const bullet of bullets) {
    stamped.push({
      ...bullet,
      image_url: hasProvider()
        ? await storedImageURL(
          supabase,
          trace_id,
          promptFor(bullet),
          `story-${fnv1a32(bullet.source_url)}.jpg`,
          imageURLForBullet(bullet),
        )
        : imageURLForBullet(bullet),
    });
  }
  return stamped;
}

/// The deck's cover card gets its OWN image. It used to borrow the first
/// bullet's art on-device, which put the identical picture on two adjacent
/// cards in every deck. Seeded on tl_dr — byte-identical with the app's
/// legacy fallback in `CardArt.leadImageURL`, so old builds and new rows
/// agree on which image a briefing's cover wants.
export async function stampLeadArt(
  supabase: any,
  trace_id: string,
  briefing: GeneratedBriefing,
): Promise<string | null> {
  const scene = briefing.lead_image_prompt?.trim() ||
    `${sceneFor(briefing.bullets[0] ?? fallbackBullet())}, grand cinematic atmosphere`;
  const prompt = `${STYLE_PREFIX} ${scene}. ${STYLE}`;
  const seed = fnv1a32(briefing.tl_dr);
  const fallback = pollinationsURL(prompt, seed);
  if (!hasProvider()) {
    return fallback;
  }
  return await storedImageURL(supabase, trace_id, prompt, `lead-${seed}-${fnv1a32(prompt)}.jpg`, fallback);
}

function fallbackBullet(): GeneratedBullet {
  return { talking_point: "", source_headline: "", source_url: "" };
}

function hasProvider(): boolean {
  return Boolean(
    (Deno.env.get("CF_ACCOUNT_ID") && Deno.env.get("CF_API_TOKEN")) ||
      Deno.env.get("POLLINATIONS_API_KEY"),
  );
}

async function storedImageURL(
  supabase: any,
  trace_id: string,
  prompt: string,
  path: string,
  fallback: string,
): Promise<string> {
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  const publicUrl: string = data.publicUrl;

  try {
    // Same story already rendered (other persona, earlier window)? Reuse it.
    const head = await fetch(publicUrl, { method: "HEAD" });
    if (head.ok) {
      return publicUrl;
    }

    const bytes = await generateImage(trace_id, prompt);

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
    return fallback;
  }
}

// Provider chain, all free: Cloudflare Workers AI FLUX.1 schnell (best look,
// ~173 neurons an image against a 10,000 neuron/day free allocation), then
// Workers AI SDXL Lightning (0 neurons, so it still works once the FLUX
// allocation runs out), then Pollinations if a key with pollen balance is
// configured. The caller falls back to the legacy on-demand URL if all miss.
async function generateImage(trace_id: string, prompt: string): Promise<Uint8Array> {
  const cfAccount = Deno.env.get("CF_ACCOUNT_ID");
  const cfToken = Deno.env.get("CF_API_TOKEN");
  if (cfAccount && cfToken) {
    try {
      return await generateWithFlux(prompt, cfAccount, cfToken);
    } catch (error) {
      logError(trace_id, "card_art_flux_failed", error);
    }
    try {
      return await generateWithSDXL(prompt, cfAccount, cfToken);
    } catch (error) {
      logError(trace_id, "card_art_sdxl_failed", error);
    }
  }
  const pollinationsKey = Deno.env.get("POLLINATIONS_API_KEY");
  if (pollinationsKey) {
    return await generateWithPollinations(prompt, fnv1a32(prompt), pollinationsKey);
  }
  throw new Error("No image provider configured or available");
}

function workersAIURL(accountId: string, model: string): string {
  return `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`;
}

/// FLUX.1 schnell on Workers AI. Returns base64 JSON; square 1024px output.
/// The model now rejects any field besides prompt and steps with a 400, which
/// is why every card fell back to the legacy URL after a `seed` was sent.
/// Four steps is the model's default
/// and costs about half of eight with no visible loss at card size.
async function generateWithFlux(prompt: string, accountId: string, token: string): Promise<Uint8Array> {
  const response = await fetch(workersAIURL(accountId, "@cf/black-forest-labs/flux-1-schnell"), {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ prompt, steps: 4 }),
  });
  if (!response.ok) {
    throw new Error(`Workers AI flux returned ${response.status}: ${(await response.text()).slice(0, 200)}`);
  }
  const payload = await response.json();
  const b64 = payload?.result?.image;
  if (typeof b64 !== "string" || !b64) {
    throw new Error("Workers AI flux returned no image");
  }
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/// SDXL Lightning on Workers AI. Returns raw image bytes in the card's
/// portrait shape. Unlike FLUX it honours a negative prompt, which is where
/// the no-text rule does the most good.
async function generateWithSDXL(prompt: string, accountId: string, token: string): Promise<Uint8Array> {
  const response = await fetch(workersAIURL(accountId, "@cf/bytedance/stable-diffusion-xl-lightning"), {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ prompt, negative_prompt: NEGATIVE, width: 768, height: 960 }),
  });
  if (!response.ok) {
    throw new Error(`Workers AI sdxl returned ${response.status}: ${(await response.text()).slice(0, 200)}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length < 1024) {
    throw new Error("Workers AI sdxl returned no image");
  }
  return bytes;
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
//
// "Poster" and "magazine" in the prompt make FLUX paint headlines, mastheads
// and artist signatures, so the style names neither and describes the image
// as wordless with blank surfaces instead of listing banned text.
const STYLE_PREFIX = "Wordless mid-century editorial illustration:";
const STYLE = "Flat bold graphic shapes, screen print risograph grain, " +
  "limited palette of deep navy, warm cream, forest green and antique gold, " +
  "dramatic side lighting, soft grainy shadows, generous empty space. " +
  "A pure picture with blank surfaces: no lettering, no headline, no banner, " +
  "no signage, plain unmarked clothing and gear, no logos, no people's faces.";
const NEGATIVE = "text, letters, words, typography, headline, caption, signature, " +
  "watermark, logo, numbers, realistic face, photo";

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
