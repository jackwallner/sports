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
  const document = new DOMParser().parseFromString(xml, "application/xml");
  if (!document) {
    throw new Error(`Failed to parse XML for ${feed.name}`);
  }

  const parseErrors = document.querySelectorAll("parsererror");
  if (parseErrors.length > 0) {
    throw new Error(`RSS parser error for ${feed.name}: ${parseErrors[0].textContent ?? "unknown error"}`);
  }

  const nodes = [...document.querySelectorAll("item")];
  const atomNodes = nodes.length > 0 ? [] : [...document.querySelectorAll("entry")];
  const allNodes = nodes.length > 0 ? nodes : atomNodes;

  const items: SourceItemInput[] = [];
  for (const node of allNodes) {
    const headline = text(node, "title");
    const sourceUrl = link(node);

    if (!headline || !sourceUrl) {
      continue;
    }

    const summary = text(node, "description") ?? text(node, "summary") ?? text(node, "content");
    const published = text(node, "pubDate") ?? text(node, "published") ?? text(node, "updated");
    const author = text(node, "author") ?? text(node, "dc\\:creator");
    const categories = [...new Set([...feed.categories, ...nodeCategories(node)])];
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

function text(node: Element, selector: string): string | null {
  return node.querySelector(selector)?.textContent?.trim() || null;
}

function link(node: Element): string | null {
  const rssLink = text(node, "link");
  if (rssLink && isHTTPURL(rssLink)) {
    return rssLink;
  }

  const atomLink = node.querySelector("link[href]")?.getAttribute("href");
  return atomLink && isHTTPURL(atomLink) ? atomLink : null;
}

function nodeCategories(node: Element): string[] {
  return [...node.querySelectorAll("category")]
    .map((category) => category.textContent?.trim().toLowerCase())
    .filter((value): value is string => Boolean(value));
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
