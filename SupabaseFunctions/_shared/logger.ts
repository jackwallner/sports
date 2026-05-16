export function traceId(prefix = "sideline"): string {
  return `${prefix}_${crypto.randomUUID()}`;
}

export function logInfo(trace_id: string, message: string, fields: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", trace_id, message, ...fields }));
}

export function logWarn(trace_id: string, message: string, fields: Record<string, unknown> = {}) {
  console.warn(JSON.stringify({ level: "warn", trace_id, message, ...fields }));
}

export function logError(trace_id: string, message: string, error: unknown, fields: Record<string, unknown> = {}) {
  const normalized = normalizeError(error);
  console.error(JSON.stringify({ level: "error", trace_id, message, error: normalized, ...fields }));
  console.error(error);
}

export function normalizeError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack,
      cause: error.cause,
    };
  }

  if (typeof error === "object" && error !== null) {
    return error as Record<string, unknown>;
  }

  return { message: String(error) };
}

export function requireCronSecret(request: Request) {
  const configured = Deno.env.get("CRON_SECRET");
  if (!configured) {
    return;
  }

  const provided = request.headers.get("x-cron-secret") ?? request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (provided !== configured) {
    throw new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }
}
