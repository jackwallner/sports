import { logInfo } from "./logger.ts";
import type { GeneratedBriefing, GenerationTarget, SourceItemRow } from "./types.ts";

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string; thought?: boolean }>;
    };
  }>;
}

export async function generateBriefingWithGemini(
  trace_id: string,
  target: GenerationTarget,
  sourceItems: SourceItemRow[],
): Promise<{ briefing: GeneratedBriefing; requestPayload: Record<string, unknown>; responsePayload: GeminiResponse }> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new Error("Missing GEMINI_API_KEY");
  }

  const models = geminiModels();
  const fullPayload = payloadFor(buildPrompt(target, sourceItems));
  // Gemma's free tier allows 16k input tokens a minute and the full 40-source
  // prompt is about 8k, so it gets the top half: room for a second try within
  // the minute, and a shorter read for a slower model.
  const gemmaPayload = payloadFor(buildPrompt(target, sourceItems.slice(0, GEMMA_SOURCE_LIMIT)), GEMMA_THINKING);
  let requestPayload = fullPayload;

  let response: Response | undefined;
  let responseText = "";
  const attempts: string[] = [];
  const started = Date.now();
  for (const model of models) {
    const remainingMs = MODEL_CHAIN_BUDGET_MS - (Date.now() - started);
    if (remainingMs <= 0) {
      logInfo(trace_id, "gemini_model_chain_budget_spent", { elapsed_ms: Date.now() - started });
      break;
    }
    requestPayload = model.startsWith("gemma-") ? gemmaPayload : fullPayload;
    logInfo(trace_id, "gemini_request_prepared", {
      model,
      persona: target.persona,
      scope: target.scope,
      refresh_window: target.refreshWindow,
      prompt_chars: requestPayload.contents[0].parts[0].text.length,
    });
    const requestStarted = Date.now();
    try {
      response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(requestPayload),
          signal: AbortSignal.timeout(remainingMs),
        },
      );
      responseText = await response.text();
    } catch (error) {
      response = undefined;
      responseText = "";
      attempts.push(`${model}: ${error instanceof Error ? error.message : String(error)} after ${Date.now() - requestStarted}ms`);
      logInfo(trace_id, "gemini_model_request_failed", {
        model,
        error_name: error instanceof Error ? error.name : "UnknownError",
      });
      continue;
    }
    if (response.ok || !FALLBACK_STATUSES.has(response.status)) {
      break;
    }
    attempts.push(`${model}: ${response.status} after ${Date.now() - requestStarted}ms`);
    logInfo(trace_id, "gemini_model_unavailable", { model, status: response.status });
  }

  let responsePayload: GeminiResponse;
  try {
    responsePayload = JSON.parse(responseText);
  } catch {
    responsePayload = { candidates: [{ content: { parts: [{ text: responseText }] } }] };
  }

  if (!response?.ok) {
    const tried = `Models tried: ${attempts.join("; ")}`;
    if (response) {
      throw new Error(`Gemini request failed ${response.status}: ${responseText}\n${tried}`);
    }
    throw new Error(`Gemini requests failed before receiving a response. ${tried}`);
  }

  // Gemma returns its reasoning as text parts flagged `thought`; only the
  // answer parts are the JSON.
  const generatedText = responsePayload.candidates?.[0]?.content?.parts
    ?.filter((part) => !part.thought)
    .map((part) => part.text ?? "")
    .join("\n") ?? "";
  // Gemma sometimes wraps the briefing in a one-item array.
  const parsed = parseJSON(generatedText);
  const briefing = (Array.isArray(parsed) && parsed.length === 1 ? parsed[0] : parsed) as GeneratedBriefing;

  return { briefing, requestPayload, responsePayload };
}

// Free-tier quota is per model per day, and every Gemini Flash model answers
// 503 under load, sometimes all at once. Falling through the chain (ending on
// Gemma, which is slower but on separate capacity) keeps a window's briefings
// alive at no cost. Busy or exhausted models answer within a second or two,
// while a working Flash call takes 20-60s, so each request gets whatever is
// left of one shared budget rather than its own short cap (a 15s cap cut off
// every healthy response). The budget keeps the whole call, art included,
// inside the edge function's wall-clock limit; the pg_cron retry pass picks
// up anything left missing.
const FALLBACK_STATUSES = new Set([404, 429, 500, 503]);
const MODEL_CHAIN_BUDGET_MS = 90_000;
const GEMMA_SOURCE_LIMIT = 20;

// Gemma thinks at length by default, which alone outruns the chain budget.
const GEMMA_THINKING = { thinkingConfig: { thinkingLevel: "MINIMAL" } };

function payloadFor(prompt: string, extraConfig: Record<string, unknown> = {}) {
  return {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.7,
      topP: 0.9,
      responseMimeType: "application/json",
      ...extraConfig,
    },
  };
}

function geminiModels(): string[] {
  const primary = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const fallbacks = (Deno.env.get("GEMINI_FALLBACK_MODELS") ?? "gemini-3.5-flash,gemini-3.8-flash,gemini-flash-latest,gemma-4-26b-a4b-it,gemma-4-31b-it")
    .split(",")
    .map((model) => model.trim())
    .filter(Boolean);
  return [...new Set([primary, ...fallbacks])];
}

export async function paceGeminiCalls(trace_id: string) {
  const interval = Number(Deno.env.get("GEMINI_MIN_INTERVAL_MS") ?? "4500");
  if (interval <= 0) {
    return;
  }

  logInfo(trace_id, "gemini_pacing_sleep", { interval_ms: interval });
  await new Promise((resolve) => setTimeout(resolve, interval));
}

function buildPrompt(target: GenerationTarget, sourceItems: SourceItemRow[]): string {
  const personaVoice = personaInstruction(target.persona, target.team);
  const sources = sourceItems.map((item, index) => ({
    n: index + 1,
    source_name: item.source_name,
    headline: item.headline,
    summary: item.summary,
    url: item.source_url,
    published_at: item.published_at,
    categories: item.categories,
  }));

  const coverage = target.persona === "local_team" && target.team
    ? `Coverage: prioritize stories about the ${target.team} and their league/city; if the sources have little on that team, pick the stories most relevant to their sport and frame them for a ${target.team} fan. Never invent facts not present in the sources.`
    : "Coverage: national US major sports and broad sports-pop-culture stories likely to come up outside sports media.";

  return [
    "You write The Sideline: sports talking points for smart people who do not follow sports at all.",
    "Audience: the reader cannot name a single current athlete, does not know team names or how any league works, and does not want to learn. They are about to walk into a room where sports will come up, and they want one good thing to say plus enough cover to survive a follow-up question.",
    `Persona: ${target.persona}. ${personaVoice}`,
    coverage,
    "Voice: you are a translator, not a commentator. Write like the one friend who follows sports AND remembers the reader does not. Plain language, warm wit, zero jargon, zero stats dumps.",
    "Identity tags: the first time any field mentions a sports person or team, attach a short plain-words tag that tells an outsider who that is and why the name carries weight. Examples: 'Victor Wembanyama, the Spurs' 7-foot-4 French phenom', 'the Chiefs, the team that has owned football lately', 'Caitlin Clark, the player who made everyone start watching the WNBA'. Each card is read on its own, so tag per field, not per briefing. Never write a sports name bare and assume it means something.",
    "Tag discipline: at most one tagged name per sentence, and never chain appositives into a pileup (BAD: 'Caitlin Clark, the star of the Indiana Fever, the team that just drafted her, wore custom shoes'). If a sentence would need two introductions, split it into two sentences. Never tag household names outside sports (Taylor Swift, Beyonce, presidents); the reader already knows exactly who they are, so 'Taylor Swift, the pop star' reads as condescending. Tags must hold up over time: no 'rookie', 'just drafted', 'newly signed' or any other time-anchored claim unless a source says it happened this week.",
    "Translate stakes, never cite them: explain why a story matters by mapping it onto things an outsider already understands, like jobs, salaries, office politics, celebrity drama, or TV shows. 'He signed through 2033' means nothing; 'he is guaranteed paychecks until his kids are in high school, which never happens in a league this brutal' lands. One sharp translation beats two more facts.",
    "Do not write like ESPN. Write like a real person texting a friend, not like an AI or a press release.",
    "Never use em dashes (—). Use periods or commas. Avoid AI tells: no 'not just X but Y', no 'in a world where', no 'it's important to note', no 'buckle up', no rhetorical questions as filler, no overuse of colons. Keep sentences varied and human.",
    "Do not reproduce article bodies. Use the provided headlines/summaries only and link to the original source URL.",
    "Every bullet must cite exactly one provided source URL.",
    "Each bullet's subject is an optional 1-3 word label for the team, league, or athlete it is about (for example: 'Cowboys', 'NBA', 'Serena Williams'). Use the most specific label that fits within 40 characters, or use null.",
    "Each bullet's backstory is the reader's cover for the moment someone replies 'wait, what happened?'. Write 2-3 short sentences for a total outsider, in order: what actually happened in plain words, who the key people are (with identity tags), and why everyone cares, translated into everyday terms. Hard limit 55 words; it has to fit on the back of a card. Stick to facts in the source. It must add real information beyond the talking_point, never restate it, and never lean on context the reader does not have. Every sentence must be specific to THIS story; no generic explainer filler like 'Athletes often use their gear to show personality'. Keep analogies and pop-culture comparisons out of the backstory; that is the tie_in's job, and the two must never make the same point twice.",
    "The briefing's lead_backstory is the same kind of cover for the tl_dr: 2-3 sentences that set up the day's main story for someone who knows nothing, with identity tags and a translated reason it matters. Hard limit 70 words.",
    "Each bullet's tie_in is one full sentence that hooks the story to something a non-fan already knows or has an opinion on (a show, a celebrity, money, workplace life), so the reader can steer the conversation somewhere comfortable. Never a bare label like 'Taylor Swift' or 'Internet culture'. It must bring a genuinely new angle the backstory has not already made; if the only angle available is one the backstory already lands, use null. Use null if there is no genuine angle.",
    "Each bullet's image_prompt is the literal visual scene for that story's card art, one sentence of 25 to 40 words. Build it like a movie still: one hero subject caught mid-action or at a moment of tension, a specific setting, and the light (floodlights, dusk, a single spotlight). Turn the story's hook into a visual joke or metaphor rather than a still life of objects on a table (BAD: 'a robot next to home plate'; GOOD: 'a boxy silver robot umpire crouched behind home plate under blazing stadium lights, one mechanical arm punching the air to call a strike as a baseball streaks toward it'). Describe only WHAT is in the picture: concrete objects, setting, action, mascots, and pop-culture imagery. Silly comparisons are welcome. Never name or depict a real person, never describe an art style, and never include words, numbers, or signs to render. Image models print gibberish on anything that usually carries lettering, so leave out jerseys, scoreboards, signs, stickers, trophies with plaques, newspapers and screens with content; show people only from behind or in silhouette.",
    "The briefing's lead_image_prompt is the visual scene for the deck's cover card: one image that captures the day's biggest story or overall mood. Same rules as image_prompt, and it must be a clearly different scene from every bullet's image_prompt.",
    "Return strict JSON only. No markdown. No code fences.",
    "Schema:",
    JSON.stringify({
      headline: "string, <= 120 chars",
      tl_dr: "string, one sentence the reader can say out loud",
      lead_backstory: "2-3 sentences: the setup behind the tl_dr for a total outsider, with identity tags",
      lead_image_prompt: "one 25-40 word movie-still scene for the deck's cover card, distinct from every bullet's",
      bullets: [
        {
          talking_point: "plain-language point, 1-2 sentences",
          subject: "1-3 word sport/team/athlete label, e.g. 'Cowboys' or 'NBA'",
          backstory: "2-3 sentences: what actually happened and why people care, beyond the talking_point",
          tie_in: "one full sentence pop-culture/social angle to keep talking, or null",
          tag: "nice_guy | jerk | redemption | drama | neutral | null",
          tag_reason: "optional short reason or null",
          image_prompt: "one 25-40 word movie-still scene for this story's card art",
          source_headline: "headline from one source below",
          source_url: "source URL from one source below",
        },
      ],
      suggested_question: "open question to ask a fan",
      source_count: 3,
    }),
    "Use 3 to 6 bullets. Prefer 3 or 4 unless there are multiple genuinely conversation-worthy stories.",
    "source_count must be a positive JSON integer equal to the number of distinct source_url values among the bullets; never return it as a string.",
    "Sources:",
    JSON.stringify(sources),
  ].join("\n\n");
}

function personaInstruction(persona: string, team?: string | null): string {
  switch (persona) {
    case "sports_talk_for_moms":
      return "Warm, zero jargon, framed as something to ask your kid about.";
    case "office_watercooler":
      return "Safe, current, mildly opinionated takes for coworkers.";
    case "date_night":
      return "One charming story plus a follow-up question to seem interested.";
    case "local_team":
      return team
        ? `Bias toward the ${team} and their city, but keep it useful to a non-fan.`
        : "Bias toward city/team relevance, but keep it useful to a non-fan.";
    default:
      return "Broad, witty, cross-sport, light gossip that can work in any room.";
  }
}

function parseJSON(text: string): unknown {
  const trimmed = text.trim().replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/```$/i, "").trim();
  return JSON.parse(trimmed);
}
