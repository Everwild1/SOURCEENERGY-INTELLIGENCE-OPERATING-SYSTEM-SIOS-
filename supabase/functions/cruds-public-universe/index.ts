import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "postgres";

const CONTRACT_VERSION = "cruds-e09.v1";
const PUBLICATION_POLICY_VERSION = "cruds-publication.v1";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const databaseUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";
const sql = postgres(databaseUrl, {
  max: 1,
  idle_timeout: 5,
  connect_timeout: 10,
  prepare: false,
  ssl: "require",
});

function response(body: unknown, status = 200, cacheControl = "no-store") {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": cacheControl,
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function configuredPublishableKeys() {
  const keys = new Set<string>();
  const manifest = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");

  if (manifest) {
    try {
      const parsed = JSON.parse(manifest);
      for (const value of Object.values(parsed)) {
        if (typeof value !== "string") continue;
        keys.add(Deno.env.get(value) ?? value);
      }
    } catch {
      // A malformed platform manifest must fail closed.
    }
  }

  const legacyAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacyAnonKey) keys.add(legacyAnonKey);
  return keys;
}

function isAuthorized(req: Request) {
  const supplied = req.headers.get("apikey");
  return Boolean(supplied && configuredPublishableKeys().has(supplied));
}

function titleCase(value: string | null) {
  if (!value) return "Unclassified";
  return value.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function monthLabel(value: string | Date | null) {
  if (!value) return "Publication date pending";
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(value));
}

function dateLabel(value: string | Date | null) {
  if (!value) return "Open until filled";
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "2-digit", year: "numeric", timeZone: "UTC" }).format(new Date(value));
}

function metricContext(row: Record<string, unknown>) {
  if (row.confidence_score !== null && row.confidence_score !== undefined) {
    return `${Math.round(Number(row.confidence_score) * 100)}% confidence`;
  }
  if (row.measurement_period_start || row.measurement_period_end) {
    return `${row.measurement_period_start ?? "Start open"} – ${row.measurement_period_end ?? "Current"}`;
  }
  return "Current published measurement";
}

async function loadUniverse() {
  const [archetypeRows, creatorRows, workRows, opportunityRows, researchRows, metricRows] = await Promise.all([
    sql`select code, name, description, sort_order from cruds.creator_archetypes where active order by sort_order limit 6`,
    sql`select
          c.id::text,
          c.identity_reference,
          c.display_name,
          c.headline,
          c.biography,
          c.created_at,
          coalesce((select array_agg(m.archetype_code order by m.is_primary desc, m.archetype_code)
                    from cruds.creator_archetype_memberships m where m.creator_id = c.id), '{}'::text[]) as archetypes,
          coalesce((select m.archetype_code from cruds.creator_archetype_memberships m
                    where m.creator_id = c.id order by m.is_primary desc, m.archetype_code limit 1), 'unclassified') as primary_archetype,
          (select count(*)::int from cruds.works w where w.creator_id = c.id and w.publication_status = 'published') as work_count
        from cruds.creators c
        where c.published
        order by c.created_at, c.id
        limit 250`,
    sql`select
          w.id::text,
          w.creator_id::text,
          w.title,
          w.work_type,
          w.summary,
          coalesce((select v.verification_status from cruds.witness_verifications v
                    where v.work_id = w.id order by v.verified_at desc nulls last, v.created_at desc limit 1), 'unverified') as verification_status
        from cruds.works w
        where w.publication_status = 'published'
        order by w.published_at desc nulls last, w.created_at desc
        limit 500`,
    sql`select
          o.id::text,
          o.opportunity_type,
          o.title,
          o.description,
          o.status,
          o.closes_at,
          w.title as work_title
        from cruds.opportunities o
        left join cruds.works w on w.id = o.work_id and w.publication_status = 'published'
        where o.status in ('open', 'under_review')
          and (o.opens_at is null or o.opens_at <= now())
          and (o.closes_at is null or o.closes_at >= now())
        order by o.closes_at nulls last, o.created_at desc
        limit 100`,
    sql`select id::text, title, source_url, source_block_reference, publication_date
        from cruds.research_assets
        where publication_date is not null and publication_date <= current_date
        order by publication_date desc, created_at desc
        limit 50`,
    sql`select
          m.id::text,
          m.metric_code,
          r.metric_name,
          m.metric_value,
          coalesce(m.metric_unit, r.default_unit) as metric_unit,
          m.measurement_kind,
          m.methodology_version,
          m.measurement_period_start,
          m.measurement_period_end,
          m.confidence_score
        from cruds.impact_metrics m
        join cruds.impact_metric_registry r on r.metric_code = m.metric_code and r.active
        where m.status = 'active'
        order by m.created_at desc
        limit 100`,
  ]);

  const archetypes = archetypeRows.map((row) => ({
    code: row.code,
    name: row.name,
    shortDescription: row.description,
  }));
  const creators = creatorRows.map((row, index) => ({
    id: row.id,
    wallOrder: index + 1,
    displayName: row.display_name,
    identityReference: row.identity_reference,
    primaryArchetype: titleCase(row.primary_archetype),
    archetypes: row.archetypes,
    location: "Published registry",
    headline: row.headline ?? "Published CRUDS Universe creator",
    biography: row.biography ?? "Biography pending publication.",
    workCount: row.work_count,
  }));
  const works = workRows.map((row) => ({
    id: row.id,
    creatorId: row.creator_id,
    title: row.title,
    workType: titleCase(row.work_type),
    verificationStatus: row.verification_status,
    summary: row.summary ?? "Summary pending publication.",
  }));
  const opportunities = opportunityRows.map((row) => ({
    id: row.id,
    type: titleCase(row.opportunity_type),
    title: row.title,
    description: row.description ?? "Published opportunity details are available through the originating authority.",
    archetype: "Open creative brief",
    workTitle: row.work_title ?? "No published work linked",
    status: titleCase(row.status),
    closesLabel: dateLabel(row.closes_at),
  }));
  const research = researchRows.map((row) => ({
    id: row.id,
    dateLabel: monthLabel(row.publication_date),
    title: row.title,
    source: row.source_block_reference ?? row.source_url ?? "Published CRUDS research record",
  }));
  const intelligence = metricRows.map((row) => ({
    code: `${row.metric_code}:${row.id}`,
    label: row.metric_name,
    value: `${row.metric_value ?? "—"}${row.metric_unit ? ` ${row.metric_unit}` : ""}`,
    context: metricContext(row),
    methodologyVersion: row.methodology_version,
    measurementKind: titleCase(row.measurement_kind),
  }));

  return {
    contractVersion: CONTRACT_VERSION,
    publicationPolicyVersion: PUBLICATION_POLICY_VERSION,
    dataMode: "live",
    generatedAt: new Date().toISOString(),
    contractCoverage: {
      e01: ["creator_archetypes", "creators", "creator_archetype_memberships"],
      e02: ["creators", "creator_archetype_memberships"],
      e03: ["works", "work_contributors", "work_media"],
      e04: ["provenance_records", "provenance_corrections", "witness_verification_requests", "witness_verifications"],
      e05: ["opportunities", "opportunity_responses"],
      e06: ["commercialization_projects", "market_access_requests"],
      e07: ["settlement_requests", "settlement_references"],
      e08: ["research_assets", "impact_metric_registry", "impact_metrics", "impact_metric_corrections", "intelligence_projections"],
    },
    stats: { creators: creators.length, works: works.length },
    archetypes,
    creators,
    works,
    opportunities,
    research,
    intelligence,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return response({ error: "method_not_allowed" }, 405);
  if (!new URL(req.url).pathname.endsWith("/universe")) return response({ error: "not_found" }, 404);
  if (!isAuthorized(req)) return response({ error: "unauthorized" }, 401);
  if (!databaseUrl) return response({ error: "gateway_unavailable" }, 503);

  try {
    return response(await loadUniverse(), 200, "public, max-age=60, stale-while-revalidate=300");
  } catch (error) {
    console.error("cruds-public-universe failed", error instanceof Error ? error.message : "unknown error");
    return response({ error: "gateway_unavailable" }, 503);
  }
});
