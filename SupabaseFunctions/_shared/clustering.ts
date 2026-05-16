import { logInfo } from "./logger.ts";
import type { SourceItemRow } from "./types.ts";

interface ClusterInput extends SourceItemRow {
  dedupe_key: string | null;
  is_pop_culture: boolean;
}

export async function rebuildRecentClusters(
  supabase: any,
  trace_id: string,
  hoursBack = 36,
): Promise<{ clusters: number; linked_items: number }> {
  const since = new Date(Date.now() - hoursBack * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("source_items")
    .select("id,source_name,source_url,headline,summary,published_at,categories,dedupe_key,is_pop_culture")
    .gte("fetched_at", since)
    .order("published_at", { ascending: false, nullsFirst: false })
    .limit(300);

  if (error) {
    throw error;
  }

  const grouped = new Map<string, ClusterInput[]>();
  for (const item of (data ?? []) as ClusterInput[]) {
    const key = item.dedupe_key || fallbackKey(item.headline);
    const bucket = grouped.get(key) ?? [];
    bucket.push(item);
    grouped.set(key, bucket);
  }

  let clusterCount = 0;
  let linkedItems = 0;

  for (const [clusterKey, items] of grouped.entries()) {
    if (items.length === 0) {
      continue;
    }

    const representative = items[0];
    const categories = [...new Set(items.flatMap((item) => item.categories ?? []))];
    const score = scoreCluster(items);

    const { data: cluster, error: upsertError } = await supabase
      .from("story_clusters")
      .upsert({
        cluster_key: clusterKey,
        representative_headline: representative.headline,
        categories,
        source_count: items.length,
        last_seen_at: new Date().toISOString(),
        score,
        updated_at: new Date().toISOString(),
      }, { onConflict: "cluster_key" })
      .select("id")
      .single();

    if (upsertError) {
      throw upsertError;
    }

    clusterCount += 1;

    const links = items.map((item) => ({
      cluster_id: cluster.id,
      source_item_id: item.id,
    }));

    const { error: linkError } = await supabase
      .from("story_cluster_items")
      .upsert(links, { onConflict: "cluster_id,source_item_id", ignoreDuplicates: true });

    if (linkError) {
      throw linkError;
    }

    linkedItems += links.length;
  }

  logInfo(trace_id, "recent_clusters_rebuilt", {
    since,
    source_items: data?.length ?? 0,
    clusters: clusterCount,
    linked_items: linkedItems,
  });

  return { clusters: clusterCount, linked_items: linkedItems };
}

function scoreCluster(items: ClusterInput[]): number {
  const sourceDiversity = new Set(items.map((item) => item.source_name)).size;
  const popCultureBoost = items.some((item) => item.is_pop_culture) ? 4 : 0;
  const recencyBoost = items.some((item) => {
    if (!item.published_at) {
      return false;
    }
    return Date.now() - new Date(item.published_at).getTime() < 12 * 60 * 60 * 1000;
  }) ? 2 : 0;

  return items.length * 2 + sourceDiversity * 3 + popCultureBoost + recencyBoost;
}

function fallbackKey(headline: string): string {
  return headline
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .split(" ")
    .filter((part) => part.length > 3)
    .slice(0, 8)
    .join("-");
}
