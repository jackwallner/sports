import { logInfo } from "./logger.ts";
import type { GeneratedBriefing, GenerationTarget, SourceItemRow } from "./types.ts";

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
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

  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const prompt = buildPrompt(target, sourceItems);
  const requestPayload = {
    contents: [
      {
        role: "user",
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      temperature: 0.7,
      topP: 0.9,
      responseMimeType: "application/json",
    },
  };

  logInfo(trace_id, "gemini_request_prepared", {
    model,
    persona: target.persona,
    scope: target.scope,
    refresh_window: target.refreshWindow,
    source_count: sourceItems.length,
    prompt_chars: prompt.length,
  });

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(requestPayload),
    },
  );

  const responseText = await response.text();
  let responsePayload: GeminiResponse;
  try {
    responsePayload = JSON.parse(responseText);
  } catch {
    responsePayload = { candidates: [{ content: { parts: [{ text: responseText }] } }] };
  }

  if (!response.ok) {
    throw new Error(`Gemini request failed ${response.status}: ${responseText}`);
  }

  const generatedText = responsePayload.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("\n") ?? "";
  const briefing = parseJSON(generatedText) as GeneratedBriefing;

  return { briefing, requestPayload, responsePayload };
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
    "Identity tags: the first time any field mentions a person or team, attach a short plain-words tag that tells an outsider who that is and why the name carries weight. Examples: 'Victor Wembanyama, the Spurs' 7-foot-4 French phenom', 'the Chiefs, the team that has owned football lately', 'Caitlin Clark, the rookie who made everyone start watching the WNBA'. Each card is read on its own, so tag per field, not per briefing. Never write a name bare and assume it means something.",
    "Translate stakes, never cite them: explain why a story matters by mapping it onto things an outsider already understands, like jobs, salaries, office politics, celebrity drama, or TV shows. 'He signed through 2033' means nothing; 'he is guaranteed paychecks until his kids are in high school, which never happens in a league this brutal' lands. One sharp translation beats two more facts.",
    "Do not write like ESPN. Write like a real person texting a friend, not like an AI or a press release.",
    "Never use em dashes (—). Use periods or commas. Avoid AI tells: no 'not just X but Y', no 'in a world where', no 'it's important to note', no 'buckle up', no rhetorical questions as filler, no overuse of colons. Keep sentences varied and human.",
    "Do not reproduce article bodies. Use the provided headlines/summaries only and link to the original source URL.",
    "Every bullet must cite exactly one provided source URL.",
    "Each bullet's subject is a 1-3 word label for the team, league, or athlete it is about (for example: 'Cowboys', 'NBA', 'Serena Williams'). Use the most specific one that fits.",
    "Each bullet's backstory is the reader's cover for the moment someone replies 'wait, what happened?'. Write 2-3 short sentences for a total outsider, in order: what actually happened in plain words, who the key people are (with identity tags), and why everyone cares, translated into everyday terms. Hard limit 55 words; it has to fit on the back of a card. Stick to facts in the source. It must add real information beyond the talking_point, never restate it, and never lean on context the reader does not have.",
    "The briefing's lead_backstory is the same kind of cover for the tl_dr: 2-3 sentences that set up the day's main story for someone who knows nothing, with identity tags and a translated reason it matters. Hard limit 70 words.",
    "Each bullet's tie_in is one full sentence that hooks the story to something a non-fan already knows or has an opinion on (a show, a celebrity, money, workplace life), so the reader can steer the conversation somewhere comfortable. Never a bare label like 'Taylor Swift' or 'Internet culture'. Use null if there is no genuine angle.",
    "Each bullet's image_prompt is the literal visual scene for that story's card art. Describe only WHAT is in the picture: concrete objects, setting, action, mascots, and pop-culture imagery (a cartoon great dane in a quarterback jersey, a torn jersey on a locker room floor, a phone glowing with angry posts). Lean into the story's hook, including silly comparisons. Never name or depict a real person, never describe an art style, and never include words, numbers, or signs to render.",
    "The briefing's lead_image_prompt is the visual scene for the deck's cover card: one image that captures the day's biggest story or overall mood. Same rules as image_prompt, and it must be a clearly different scene from every bullet's image_prompt.",
    "Return strict JSON only. No markdown. No code fences.",
    "Schema:",
    JSON.stringify({
      headline: "string, <= 120 chars",
      tl_dr: "string, one sentence the reader can say out loud",
      lead_backstory: "2-3 sentences: the setup behind the tl_dr for a total outsider, with identity tags",
      lead_image_prompt: "1-2 sentence literal visual scene for the deck's cover card, distinct from every bullet's",
      bullets: [
        {
          talking_point: "plain-language point, 1-2 sentences",
          subject: "1-3 word sport/team/athlete label, e.g. 'Cowboys' or 'NBA'",
          backstory: "2-3 sentences: what actually happened and why people care, beyond the talking_point",
          tie_in: "one full sentence pop-culture/social angle to keep talking, or null",
          tag: "nice_guy | jerk | redemption | drama | neutral | null",
          tag_reason: "optional short reason or null",
          image_prompt: "1-2 sentence literal visual scene for this story's card art",
          source_headline: "headline from one source below",
          source_url: "source URL from one source below",
        },
      ],
      suggested_question: "open question to ask a fan",
      source_count: "number of distinct source URLs used",
    }),
    "Use 3 to 6 bullets. Prefer 3 or 4 unless there are multiple genuinely conversation-worthy stories.",
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
