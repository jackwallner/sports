import { logError, logInfo, logWarn, normalizeError, requireCronSecret, traceId } from "../_shared/logger.ts";
import { rebuildRecentClusters } from "../_shared/clustering.ts";
import { parseFeed } from "../_shared/rss.ts";
import { serviceClient } from "../_shared/supabase.ts";
import type { SourceFeed } from "../_shared/types.ts";

Deno.serve(async (request) => {
  const trace_id = traceId("rss");
  const startedAt = Date.now();

  try {
    requireCronSecret(request);
    const supabase = serviceClient();
    logInfo(trace_id, "rss_ingest_started", { method: request.method });

    const { data: feeds, error: feedsError } = await supabase
      .from("source_feeds")
      .select("id,name,url,source_name,categories,trust_weight")
      .eq("is_active", true)
      .order("trust_weight", { ascending: false });

    if (feedsError) {
      throw feedsError;
    }

    let fetchedFeeds = 0;
    let failedFeeds = 0;
    let parsedItems = 0;
    let upsertedItems = 0;

    for (const feed of (feeds ?? []) as SourceFeed[]) {
      try {
        logInfo(trace_id, "fetching_feed", {
          feed_id: feed.id,
          feed_name: feed.name,
          feed_url: feed.url,
          categories: feed.categories,
        });

        const response = await fetch(feed.url, {
          headers: {
            "accept": "application/rss+xml, application/xml, text/xml, */*",
            "user-agent": "The Sideline RSS bot (+https://sideline.app)",
          },
        });

        const body = await response.text();
        if (!response.ok) {
          throw new Error(`Feed fetch failed ${response.status}: ${body.slice(0, 500)}`);
        }

        const items = await parseFeed(feed, body);
        parsedItems += items.length;
        fetchedFeeds += 1;

        logInfo(trace_id, "feed_parsed", {
          feed_id: feed.id,
          feed_name: feed.name,
          item_count: items.length,
          status: response.status,
        });

        if (items.length > 0) {
          const { error: upsertError, count } = await supabase
            .from("source_items")
            .upsert(items, { onConflict: "url_hash", ignoreDuplicates: false })
            .select("id");

          if (upsertError) {
            throw upsertError;
          }

          upsertedItems += count ?? items.length;
        }

        await supabase
          .from("source_feeds")
          .update({ last_fetched_at: new Date().toISOString(), last_error: null, updated_at: new Date().toISOString() })
          .eq("id", feed.id);
      } catch (error) {
        failedFeeds += 1;
        logError(trace_id, "feed_failed", error, {
          feed_id: feed.id,
          feed_name: feed.name,
          feed_url: feed.url,
        });

        await supabase
          .from("source_feeds")
          .update({
            last_error: normalizeError(error),
            updated_at: new Date().toISOString(),
          })
          .eq("id", feed.id);
      }
    }

    if (fetchedFeeds === 0) {
      logWarn(trace_id, "no_feeds_fetched", { configured_feed_count: feeds?.length ?? 0 });
    }

    const clusters = await rebuildRecentClusters(supabase, trace_id);
    const durationMs = Date.now() - startedAt;
    logInfo(trace_id, "rss_ingest_finished", {
      fetched_feeds: fetchedFeeds,
      failed_feeds: failedFeeds,
      parsed_items: parsedItems,
      upserted_items: upsertedItems,
      clusters,
      duration_ms: durationMs,
    });

    return json({
      trace_id,
      fetched_feeds: fetchedFeeds,
      failed_feeds: failedFeeds,
      parsed_items: parsedItems,
      upserted_items: upsertedItems,
      clusters,
      duration_ms: durationMs,
    });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    logError(trace_id, "rss_ingest_unhandled_error", error);
    return json({ trace_id, error: normalizeError(error) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
