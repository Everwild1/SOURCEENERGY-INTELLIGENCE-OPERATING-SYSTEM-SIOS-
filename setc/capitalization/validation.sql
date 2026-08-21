-- Capitalization Block post-deployment validation.
-- Run after migrations 012-015, and again after optional seed 016.
-- This script is read-only except for temporary execution state inside DO blocks.

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*)
      INTO v_count
      FROM capitalization.release_gates
     WHERE gate_code IN ('PRODUCTION_SETTLEMENT', 'PUBLIC_LIVE_NETWORK_CLAIMS');

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'expected 2 canonical release gates, found %', v_count;
    END IF;
END;
$$;

DO $$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, c.relname), ', ' ORDER BY n.nspname, c.relname)
      INTO v_missing
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname IN ('capitalization', 'capitalization_api')
       AND c.relkind IN ('r', 'p')
       AND c.relrowsecurity = false;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'RLS is disabled on: %', v_missing;
    END IF;
END;
$$;

DO $$
DECLARE
    v_exposed text;
BEGIN
    SELECT string_agg(format('%I.%I', table_schema, table_name), ', ' ORDER BY table_name)
      INTO v_exposed
      FROM information_schema.tables
     WHERE table_schema = 'capitalization'
       AND table_type = 'BASE TABLE'
       AND (
            has_table_privilege('anon', format('%I.%I', table_schema, table_name), 'SELECT')
            OR has_table_privilege('anon', format('%I.%I', table_schema, table_name), 'INSERT')
            OR has_table_privilege('anon', format('%I.%I', table_schema, table_name), 'UPDATE')
            OR has_table_privilege('anon', format('%I.%I', table_schema, table_name), 'DELETE')
            OR has_table_privilege('authenticated', format('%I.%I', table_schema, table_name), 'SELECT')
            OR has_table_privilege('authenticated', format('%I.%I', table_schema, table_name), 'INSERT')
            OR has_table_privilege('authenticated', format('%I.%I', table_schema, table_name), 'UPDATE')
            OR has_table_privilege('authenticated', format('%I.%I', table_schema, table_name), 'DELETE')
       );

    IF v_exposed IS NOT NULL THEN
        RAISE EXCEPTION 'internal Capitalization tables have client grants: %', v_exposed;
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM capitalization.institution_relationships r
          JOIN capitalization.financial_institutions i ON i.id = r.institution_id
         WHERE r.relationship_state = 'LIVE'
           AND (
                i.verification_status <> 'VERIFIED'
                OR r.evidence_reference IS NULL
                OR r.last_verified_at IS NULL
                OR NOT EXISTS (
                    SELECT 1
                      FROM capitalization.network_nodes n
                     WHERE n.institution_id = r.institution_id
                       AND n.environment = 'PRODUCTION'
                       AND n.connectivity_status = 'PRODUCTION'
                       AND n.node_status = 'ACTIVE'
                       AND n.evidence_reference IS NOT NULL
                       AND n.last_verified_at IS NOT NULL
                )
           )
    ) THEN
        RAISE EXCEPTION 'one or more LIVE relationships fail verification or production-connectivity invariants';
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM capitalization.network_nodes
         WHERE connectivity_status = 'PRODUCTION'
           AND (
                environment <> 'PRODUCTION'
                OR node_status <> 'ACTIVE'
                OR endpoint_reference IS NULL
                OR evidence_reference IS NULL
                OR last_verified_at IS NULL
           )
    ) THEN
        RAISE EXCEPTION 'one or more PRODUCTION nodes fail evidence requirements';
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT capitalization.release_gate_enabled('PUBLIC_LIVE_NETWORK_CLAIMS')
       AND EXISTS (
            SELECT 1
              FROM capitalization_api.network_directory
             WHERE public_claim_status = 'VERIFIED_LIVE'
       ) THEN
        RAISE EXCEPTION 'public VERIFIED_LIVE claim exists while public claim gate is disabled';
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM capitalization.treasury_accounts
         WHERE external_account_reference IS NOT NULL
           AND external_account_reference !~ '^(vault|token|masked|provider):[A-Za-z0-9._:/-]+$'
    ) THEN
        RAISE EXCEPTION 'raw or non-opaque external treasury account reference detected';
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM capitalization.settlement_instructions
         WHERE settlement_status = 'SETTLED'
           AND (
                finality_authority IS NULL
                OR finality_authority = 'CAPITALIZATION_BLOCK'
                OR authoritative_confirmation_reference IS NULL
                OR settled_at IS NULL
                OR evidence_reference IS NULL
                OR (rail_type = 'SOURCE_COIN' AND finality_authority <> 'SOURCE_COIN_DOMAIN')
           )
    ) THEN
        RAISE EXCEPTION 'settled instruction lacks authoritative finality evidence';
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT capitalization.release_gate_enabled('PRODUCTION_SETTLEMENT')
       AND EXISTS (
            SELECT 1
              FROM capitalization.settlement_instructions
             WHERE environment = 'PRODUCTION'
               AND settlement_status IN ('SUBMITTED', 'ACCEPTED', 'SETTLED')
       ) THEN
        RAISE EXCEPTION 'production settlement exists beyond APPROVED while production gate is disabled';
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT idempotency_key
          FROM capitalization.settlement_instructions
         GROUP BY idempotency_key
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'duplicate settlement idempotency key detected';
    END IF;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM capitalization.approval_actions a
          JOIN capitalization.approval_requests r ON r.id = a.approval_request_id
         WHERE a.actioned_by_actor = r.requested_by_actor
           AND a.decision IN ('APPROVE', 'REJECT')
    ) THEN
        RAISE EXCEPTION 'self-approval or self-rejection record detected';
    END IF;
END;
$$;

DO $$
DECLARE
    v_unsafe text;
BEGIN
    SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text)
      INTO v_unsafe
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'capitalization'
       AND p.prosecdef = true
       AND NOT EXISTS (
            SELECT 1
              FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) setting
             WHERE setting LIKE 'search_path=%'
       );

    IF v_unsafe IS NOT NULL THEN
        RAISE EXCEPTION 'SECURITY DEFINER function without fixed search_path: %', v_unsafe;
    END IF;
END;
$$;

SELECT
    gate_code,
    enabled,
    authorization_reference,
    evidence_reference,
    authorized_by_actor,
    authorized_at,
    version
FROM capitalization.release_gates
ORDER BY gate_code;

SELECT
    count(*) FILTER (WHERE relationship_state = 'TARGET') AS registry_targets,
    count(*) FILTER (WHERE relationship_state IN ('CONTRACTED', 'INTEGRATION_PENDING', 'INTEGRATED')) AS evidence_backed_non_live,
    count(*) FILTER (WHERE relationship_state = 'LIVE') AS live_relationships
FROM capitalization.institution_relationships;

SELECT
    connectivity_status,
    count(*) AS node_count
FROM capitalization.network_nodes
GROUP BY connectivity_status
ORDER BY connectivity_status;

SELECT
    public_claim_status,
    count(*) AS published_count
FROM capitalization_api.network_directory
WHERE is_published = true
GROUP BY public_claim_status
ORDER BY public_claim_status;

SELECT
    metric_code,
    numeric_value,
    text_value,
    unit,
    as_of,
    disclosure
FROM capitalization_api.dashboard_metrics
WHERE is_published = true
ORDER BY metric_code;
