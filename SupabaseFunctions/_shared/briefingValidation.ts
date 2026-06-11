import { ALLOWED_TAGS, type GeneratedBriefing } from "./types.ts";

export interface ValidationResult {
  ok: boolean;
  errors: string[];
}

export function validateBriefing(value: unknown): ValidationResult {
  const errors: string[] = [];

  if (!isRecord(value)) {
    return { ok: false, errors: ["Briefing is not an object"] };
  }

  requireString(value, "headline", 12, 120, errors);
  requireString(value, "tl_dr", 40, 280, errors);
  requireString(value, "suggested_question", 20, 180, errors);

  if (!Array.isArray(value.bullets)) {
    errors.push("bullets must be an array");
  } else {
    if (value.bullets.length < 3 || value.bullets.length > 6) {
      errors.push("bullets must contain 3 to 6 items");
    }

    value.bullets.forEach((bullet, index) => validateBullet(bullet, index, errors));
  }

  if (typeof value.source_count !== "number" || value.source_count < 1) {
    errors.push("source_count must be a positive number");
  }

  return { ok: errors.length === 0, errors };
}

export function normalizeBriefing(value: GeneratedBriefing): GeneratedBriefing {
  return {
    headline: value.headline.trim(),
    tl_dr: value.tl_dr.trim(),
    bullets: value.bullets.map((bullet) => ({
      id: bullet.id ?? crypto.randomUUID(),
      talking_point: bullet.talking_point.trim(),
      subject: bullet.subject?.trim() || null,
      tie_in: bullet.tie_in?.trim() || null,
      backstory: bullet.backstory?.trim() || null,
      tag: bullet.tag ?? null,
      tag_reason: bullet.tag_reason?.trim() || null,
      source_headline: bullet.source_headline.trim(),
      source_url: bullet.source_url.trim(),
      // Art is decoration: tolerate anything Gemini puts here (or omits)
      // rather than failing the briefing, hence no validation rule.
      image_prompt: typeof bullet.image_prompt === "string" && bullet.image_prompt.trim()
        ? bullet.image_prompt.trim().slice(0, 400)
        : null,
    })),
    suggested_question: value.suggested_question.trim(),
    source_count: value.source_count,
    lead_image_prompt: typeof value.lead_image_prompt === "string" && value.lead_image_prompt.trim()
      ? value.lead_image_prompt.trim().slice(0, 400)
      : null,
  };
}

function validateBullet(value: unknown, index: number, errors: string[]) {
  if (!isRecord(value)) {
    errors.push(`bullet ${index} is not an object`);
    return;
  }

  requireString(value, "talking_point", 30, 260, errors, `bullet ${index}`);
  optionalString(value, "subject", 0, 40, errors, `bullet ${index}`);
  optionalString(value, "tie_in", 0, 180, errors, `bullet ${index}`);
  // Optional so one missing field never burns a whole briefing's Gemini call;
  // the prompt demands it and the app falls back to tie_in when absent.
  optionalString(value, "backstory", 0, 700, errors, `bullet ${index}`);
  optionalString(value, "tag_reason", 0, 160, errors, `bullet ${index}`);
  requireString(value, "source_headline", 8, 180, errors, `bullet ${index}`);
  requireURL(value, "source_url", errors, `bullet ${index}`);

  if (value.tag !== null && value.tag !== undefined && !ALLOWED_TAGS.includes(value.tag as never)) {
    errors.push(`bullet ${index}.tag must be one of ${ALLOWED_TAGS.join(", ")}`);
  }
}

function requireString(
  value: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
  errors: string[],
  prefix = "briefing",
) {
  const field = value[key];
  if (typeof field !== "string") {
    errors.push(`${prefix}.${key} must be a string`);
    return;
  }

  const length = field.trim().length;
  if (length < min || length > max) {
    errors.push(`${prefix}.${key} length must be between ${min} and ${max}`);
  }
}

function optionalString(
  value: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
  errors: string[],
  prefix: string,
) {
  const field = value[key];
  if (field === null || field === undefined || field === "") {
    return;
  }

  if (typeof field !== "string") {
    errors.push(`${prefix}.${key} must be a string`);
    return;
  }

  const length = field.trim().length;
  if (length < min || length > max) {
    errors.push(`${prefix}.${key} length must be between ${min} and ${max}`);
  }
}

function requireURL(value: Record<string, unknown>, key: string, errors: string[], prefix: string) {
  const field = value[key];
  if (typeof field !== "string") {
    errors.push(`${prefix}.${key} must be a URL string`);
    return;
  }

  try {
    const url = new URL(field);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      errors.push(`${prefix}.${key} must be an HTTP URL`);
    }
  } catch {
    errors.push(`${prefix}.${key} must be a valid URL`);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
