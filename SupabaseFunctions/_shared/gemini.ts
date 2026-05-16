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
  const personaVoice = personaInstruction(target.persona);
  const sources = sourceItems.map((item, index) => ({
    n: index + 1,
    source_name: item.source_name,
    headline: item.headline,
    summary: item.summary,
    url: item.source_url,
    published_at: item.published_at,
    categories: item.categories,
  }));

  return [
    "You write The Sideline: sports pop-culture talking points for people who do not follow sports.",
    "Audience: non-sports people who want to sound informed and not excluded from sports conversations.",
    `Persona: ${target.persona}. ${personaVoice}`,
    "Coverage: national US major sports and broad sports-pop-culture stories likely to come up outside sports media.",
    "Do not write like ESPN. Use plain language, warm wit, and zero stats jargon.",
    "Do not reproduce article bodies. Use the provided headlines/summaries only and link to the original source URL.",
    "Every bullet must cite exactly one provided source URL.",
    "Return strict JSON only. No markdown. No code fences.",
    "Schema:",
    JSON.stringify({
      headline: "string, <= 120 chars",
      tl_dr: "string, one sentence the reader can say out loud",
      bullets: [
        {
          talking_point: "plain-language point, 1-2 sentences",
          tie_in: "optional pop-culture/social angle or null",
          tag: "nice_guy | jerk | redemption | drama | neutral | null",
          tag_reason: "optional short reason or null",
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

function personaInstruction(persona: string): string {
  switch (persona) {
    case "sports_talk_for_moms":
      return "Warm, zero jargon, framed as something to ask your kid about.";
    case "office_watercooler":
      return "Safe, current, mildly opinionated takes for coworkers.";
    case "date_night":
      return "One charming story plus a follow-up question to seem interested.";
    case "local_team":
      return "Bias toward city/team relevance, but keep it useful to a non-fan.";
    default:
      return "Broad, witty, cross-sport, light gossip that can work in any room.";
  }
}

function parseJSON(text: string): unknown {
  const trimmed = text.trim().replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/```$/i, "").trim();
  return JSON.parse(trimmed);
}
