import { normalizeBriefing, validateBriefing } from "../_shared/briefingValidation.ts";
import { imageURLForBullet } from "../_shared/cardArt.ts";
import { generateBriefingWithGemini, paceGeminiCalls } from "../_shared/gemini.ts";
import { logError, logInfo, normalizeError, requireCronSecret, traceId } from "../_shared/logger.ts";
import { serviceClient } from "../_shared/supabase.ts";
import {
  PERSONAS,
  PROMPT_VERSION,
  type BriefingScope,
  type GenerationTarget,
  type Persona,
  type RefreshWindow,
  type SourceItemRow,
} from "../_shared/types.ts";

Deno.serve(async (request) => {
  const trace_id = traceId("gemini");

  try {
    requireCronSecret(request);
    const body = request.method === "POST" ? await safeJSON(request) : {};
    const supabase = serviceClient();
    const targets = resolveTargets(body);

    logInfo(trace_id, "generation_started", {
      targets,
      request_body: body,
    });

    const sourceItems = await loadSourceItems(supabase, trace_id);
    if (sourceItems.length < 3) {
      throw new Error(`Not enough source items to generate a briefing. Count=${sourceItems.length}`);
    }

    const results = [];
    for (const target of targets) {
      const result = await generateOne(supabase, trace_id, target, sourceItems);
      results.push(result);
      await paceGeminiCalls(trace_id);
    }

    logInfo(trace_id, "generation_finished", { generated: results.length, results });
    return json({ trace_id, results });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    logError(trace_id, "generation_unhandled_error", error);
    return json({ trace_id, error: normalizeError(error) }, 500);
  }
});

async function generateOne(
  supabase: any,
  trace_id: string,
  target: GenerationTarget,
  sourceItems: SourceItemRow[],
) {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const run = await createRun(supabase, trace_id, target, sourceItems, model);

  try {
    logInfo(trace_id, "target_generation_started", {
      run_id: run.id,
      persona: target.persona,
      scope: target.scope,
      refresh_window: target.refreshWindow,
      input_count: sourceItems.length,
    });

    const { briefing, requestPayload, responsePayload } = await generateBriefingWithGemini(trace_id, target, sourceItems);
    const validation = validateBriefing(briefing);
    if (!validation.ok) {
      throw new Error(`Generated briefing failed validation: ${validation.errors.join("; ")}`);
    }

    const normalized = normalizeBriefing(briefing);
    // Stamp deterministic card art on each bullet. Gemini never sees or
    // produces this; it's derived from the bullet's own source/tag so the
    // same story keeps the same art across personas and refresh windows.
    normalized.bullets = normalized.bullets.map((bullet) => ({
      ...bullet,
      image_url: imageURLForBullet(bullet),
    }));
    const { error: insertError } = await supabase.from("briefings").insert({
      persona: target.persona,
      scope: target.scope,
      team: target.team ?? null,
      refresh_window: target.refreshWindow,
      headline: normalized.headline,
      tl_dr: normalized.tl_dr,
      bullets: normalized.bullets,
      suggested_question: normalized.suggested_question,
      source_count: normalized.source_count,
      generated_at: new Date().toISOString(),
      expires_at: expirationFor(target.refreshWindow),
      model,
      prompt_version: PROMPT_VERSION,
      run_id: run.id,
    });

    if (insertError) {
      throw insertError;
    }

    await updateRun(supabase, run.id, {
      status: "succeeded",
      finished_at: new Date().toISOString(),
      request_payload: requestPayload,
      response_payload: responsePayload,
    });

    logInfo(trace_id, "target_generation_succeeded", {
      run_id: run.id,
      persona: target.persona,
      bullets: normalized.bullets.length,
      source_count: normalized.source_count,
    });

    return {
      run_id: run.id,
      target,
      status: "succeeded",
      // Surfaced so the cron can warm these onto the image CDN right away.
      image_urls: normalized.bullets.map((bullet) => bullet.image_url).filter(Boolean),
    };
  } catch (error) {
    logError(trace_id, "target_generation_failed", error, {
      run_id: run.id,
      persona: target.persona,
      scope: target.scope,
      refresh_window: target.refreshWindow,
    });

    await updateRun(supabase, run.id, {
      status: "failed",
      finished_at: new Date().toISOString(),
      error: normalizeError(error),
    });

    return { run_id: run.id, target, status: "failed", error: normalizeError(error) };
  }
}

async function loadSourceItems(supabase: any, trace_id: string): Promise<SourceItemRow[]> {
  const since = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("source_items")
    .select("id,source_name,source_url,headline,summary,published_at,categories")
    .gte("fetched_at", since)
    .order("is_pop_culture", { ascending: false })
    .order("published_at", { ascending: false, nullsFirst: false })
    .limit(40);

  if (error) {
    throw error;
  }

  logInfo(trace_id, "source_items_loaded", { since, count: data?.length ?? 0 });
  return (data ?? []) as SourceItemRow[];
}

async function createRun(
  supabase: any,
  trace_id: string,
  target: GenerationTarget,
  sourceItems: SourceItemRow[],
  model: string,
) {
  const { data, error } = await supabase
    .from("generation_runs")
    .insert({
      trace_id,
      persona: target.persona,
      scope: target.scope,
      team: target.team ?? null,
      refresh_window: target.refreshWindow,
      status: "running",
      model,
      prompt_version: PROMPT_VERSION,
      input_count: sourceItems.length,
      source_item_ids: sourceItems.map((item) => item.id),
      started_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (error) {
    throw error;
  }

  return data;
}

async function updateRun(supabase: any, runId: string, fields: Record<string, unknown>) {
  const { error } = await supabase
    .from("generation_runs")
    .update(fields)
    .eq("id", runId);

  if (error) {
    throw error;
  }
}

function resolveTargets(body: Record<string, unknown>): GenerationTarget[] {
  const refreshWindow = (body.refresh_window as RefreshWindow | undefined) ?? currentRefreshWindow();
  const requestedPersonas = Array.isArray(body.personas) ? body.personas as Persona[] : null;
  const personas = requestedPersonas?.length ? requestedPersonas : defaultPersonas(refreshWindow);

  // local_team always covers a specific team and is stored under scope=local.
  const team = typeof body.team === "string" && body.team.trim() ? body.team.trim() : null;
  const requestedScope = body.scope as BriefingScope | undefined;

  return personas
    .filter((persona): persona is Persona => PERSONAS.includes(persona as Persona))
    .map((persona) => {
      if (persona === "local_team") {
        if (!team) {
          throw new Error(`local_team requires a "team" in the request body`);
        }
        return { persona, scope: "local" as BriefingScope, refreshWindow, team };
      }
      return { persona, scope: requestedScope ?? "national", refreshWindow, team: null };
    });
}

function defaultPersonas(refreshWindow: RefreshWindow): Persona[] {
  if (refreshWindow === "daily") {
    return ["cocktail_party"];
  }

  return PERSONAS;
}

function currentRefreshWindow(): RefreshWindow {
  const hour = new Date().getUTCHours();
  if (hour < 16) {
    return "morning";
  }
  if (hour < 22) {
    return "midday";
  }
  return "evening";
}

function expirationFor(refreshWindow: RefreshWindow): string {
  const hours = refreshWindow === "daily" ? 30 : 10;
  return new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
}

async function safeJSON(request: Request): Promise<Record<string, unknown>> {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
