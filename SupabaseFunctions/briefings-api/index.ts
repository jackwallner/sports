import { logError, logInfo, normalizeError, traceId } from "../_shared/logger.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { PERSONAS, type BriefingScope, type Persona } from "../_shared/types.ts";

Deno.serve(async (request) => {
  const trace_id = traceId("briefing");

  try {
    const url = new URL(request.url);
    const persona = (url.searchParams.get("persona") ?? "cocktail_party") as Persona;
    const scope = (url.searchParams.get("scope") ?? "national") as BriefingScope;
    const team = url.searchParams.get("team");

    if (!PERSONAS.includes(persona)) {
      return json({ trace_id, error: `Unsupported persona: ${persona}` }, 400);
    }

    const supabase = serviceClient();
    logInfo(trace_id, "latest_briefing_requested", { persona, scope, team });

    let query = supabase
      .from("briefings")
      .select("*")
      .eq("persona", persona)
      .eq("scope", scope);

    if (scope === "local" && team) {
      query = query.eq("team", team);
    }

    const { data, error } = await query
      .order("generated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return json({ trace_id, error: "No briefing cached yet" }, 404);
    }

    return json({ trace_id, briefing: data });
  } catch (error) {
    logError(trace_id, "latest_briefing_failed", error);
    return json({ trace_id, error: normalizeError(error) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
