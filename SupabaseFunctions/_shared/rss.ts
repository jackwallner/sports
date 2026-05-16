import { XMLParser } from "https://esm.sh/fast-xml-parser@4.5.0";
import type { SourceFeed, SourceItemInput } from "./types.ts";

const POP_CULTURE_TERMS = [
  "wife",
  "girlfriend",
  "boyfriend",
  "celebrity",
  "taylor",
  "swift",
  "podcast",
  "viral",
  "social media",
  "instagram",
  "tiktok",
  "controversy",
  "feud",
  "beef",
  "bench",
  "trade",
  "lawsuit",
  "apology",
  "suspended",
];

export async function parseFeed(feed: SourceFeed, xml: string): Promise<SourceItemInput[]> {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
    textNodeName: "#text",
    cdataPropName: "#cdata",
  });
  const parsed = parser.parse(xml);
  const rssItems = toArray(parsed?.rss?.channel?.item);
  const atomItems = rssItems.length > 0 ? [] : toArray(parsed?.feed?.entry);
  const allNodes = rssItems.length > 0 ? rssItems : atomItems;

  const items: SourceItemInput[] = [];
  for (const node of allNodes) {
    const headline = textValue(node.title);
    const sourceUrl = link(node);

    if (!headline || !sourceUrl) {
      continue;
    }

    const summary = textValue(node.description) ?? textValue(node.summary) ?? textValue(node.content);
    const published = textValue(node.pubDate) ?? textValue(node.published) ?? textValue(node.updated);
    const author = textValue(node.author) ?? textValue(node["dc:creator"]);
    const categories = [...new Set([...feed.categories, ...nodeCategories(node)].map((value) => value.toLowerCase()))];
    const dedupeKey = normalizeDedupeKey(headline);
    const urlHash = await sha256(sourceUrl);

    items.push({
      feed_id: feed.id,
      source_name: feed.source_name,
      source_url: sourceUrl,
      url_hash: urlHash,
      headline: cleanText(headline),
      summary: summary ? cleanText(stripHtml(summary)).slice(0, 600) : null,
      author: author ? cleanText(author) : null,
      published_at: published ? parseDate(published) : null,
      categories,
      raw_item: {
        feed: feed.name,
        title: headline,
        link: sourceUrl,
        published,
      },
      dedupe_key: dedupeKey,
      is_pop_culture: isPopCulture(`${headline} ${summary ?? ""}`),
    });
  }

  return items;
}

export function normalizeDedupeKey(value: string): string {
  return cleanText(value)
    .toLowerCase()
    .replace(/['"]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .split(" ")
    .filter((part) => part.length > 2 && !["the", "and", "for", "with", "from", "amid"].includes(part))
    .slice(0, 10)
    .join("-");
}

function link(node: Record<string, unknown>): string | null {
  const rssLink = textValue(node.link);
  if (rssLink && isHTTPURL(rssLink)) {
    return rssLink;
  }

  const atomLink = toArray(node.link)
    .map((value) => isRecord(value) ? textValue(value["@_href"]) : null)
    .find((value): value is string => Boolean(value));
  return atomLink && isHTTPURL(atomLink) ? atomLink : null;
}

function nodeCategories(node: Record<string, unknown>): string[] {
  return toArray(node.category)
    .map((category) => textValue(category) ?? (isRecord(category) ? textValue(category["@_term"]) : null))
    .filter((value): value is string => Boolean(value));
}

function textValue(value: unknown): string | null {
  if (typeof value === "string" || typeof value === "number") {
    return cleanText(String(value));
  }

  if (isRecord(value)) {
    return textValue(value["#text"]) ?? textValue(value["#cdata"]);
  }

  return null;
}

function toArray(value: unknown): Record<string, unknown>[] {
  if (!value) {
    return [];
  }

  if (Array.isArray(value)) {
    return value.filter(isRecord);
  }

  return isRecord(value) ? [value] : [];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cleanText(value: string): string {
  return value.replace(/\s+/g, " ").replace(/\u00a0/g, " ").trim();
}

function stripHtml(value: string): string {
  return value.replace(/<[^>]+>/g, " ");
}

function parseDate(value: string): string | null {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function isHTTPURL(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function isPopCulture(value: string): boolean {
  const haystack = value.toLowerCase();
  return POP_CULTURE_TERMS.some((term) => haystack.includes(term));
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
