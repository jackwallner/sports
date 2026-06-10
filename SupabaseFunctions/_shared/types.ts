export type Persona =
  | "cocktail_party"
  | "sports_talk_for_moms"
  | "office_watercooler"
  | "date_night"
  | "local_team";

export type BriefingScope = "national" | "local";
export type RefreshWindow = "daily" | "morning" | "midday" | "evening";
export type BriefingTag = "nice_guy" | "jerk" | "redemption" | "drama" | "neutral";

export const PERSONAS: Persona[] = [
  "cocktail_party",
  "sports_talk_for_moms",
  "office_watercooler",
  "date_night",
  "local_team",
];

export const PRO_PERSONAS: Persona[] = [
  "sports_talk_for_moms",
  "office_watercooler",
  "date_night",
  "local_team",
];

export interface SourceFeed {
  id: string;
  name: string;
  url: string;
  source_name: string;
  categories: string[];
  trust_weight: number;
}

export interface SourceItemInput {
  feed_id: string;
  source_name: string;
  source_url: string;
  url_hash: string;
  headline: string;
  summary: string | null;
  author: string | null;
  published_at: string | null;
  categories: string[];
  raw_item: Record<string, unknown>;
  dedupe_key: string;
  is_pop_culture: boolean;
}

export interface SourceItemRow {
  id: string;
  source_name: string;
  source_url: string;
  headline: string;
  summary: string | null;
  published_at: string | null;
  categories: string[];
}

export interface GeneratedBullet {
  id?: string;
  talking_point: string;
  subject?: string | null;
  tie_in?: string | null;
  tag?: BriefingTag | null;
  tag_reason?: string | null;
  source_headline: string;
  source_url: string;
  /** Deck card art, stamped post-validation by generate-briefings. */
  image_url?: string;
}

export interface GeneratedBriefing {
  headline: string;
  tl_dr: string;
  bullets: GeneratedBullet[];
  suggested_question: string;
  source_count: number;
}

export interface GenerationTarget {
  persona: Persona;
  scope: BriefingScope;
  refreshWindow: RefreshWindow;
  team?: string | null;
}

export const ALLOWED_TAGS: BriefingTag[] = ["nice_guy", "jerk", "redemption", "drama", "neutral"];
export const PROMPT_VERSION = "sideline-v1-rss-gemini";
