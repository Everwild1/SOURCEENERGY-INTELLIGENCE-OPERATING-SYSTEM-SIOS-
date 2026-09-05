create table if not exists sourcecubes.vertical_evidence_observations (
 observation_id uuid primary key default gen_random_uuid(),
 anchor_candidate_id uuid references ecology.ssr_anchor_candidate_registry(id),
 anchor_tile_id text references public.anchor_tiles(anchor_tile_id),
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 provider_code text not null references ecology.ssr_scientific_data_providers(provider_code),
 dataset_name text,
 observed_value_m numeric not null,
 source_vertical_datum text,
 source_reference_surface text,
 source_resolution_m numeric,
 source_timestamp timestamptz,
 evidence_reference text not null,
 evidence_payload jsonb not null default '{}'::jsonb,
 canonicalization_eligible boolean not null default false,
 created_at timestamptz not null default now(),
 check ((anchor_candidate_id is not null)::int + (anchor_tile_id is not null)::int <= 1)
);

create table if not exists sourcecubes.vertical_evidence_reconciliation (
 reconciliation_id uuid primary key default gen_random_uuid(),
 subject_key text not null,
 primary_observation_id uuid references sourcecubes.vertical_evidence_observations(observation_id),
 crosscheck_observation_id uuid references sourcecubes.vertical_evidence_observations(observation_id),
 primary_value_m numeric,
 crosscheck_value_m numeric,
 variance_m numeric,
 tolerance_m numeric not null default 6,
 reconciliation_status text not null,
 canonical_z_index integer,
 canonical_altitude_m integer,
 decision_reference text,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create or replace function sourcecubes.compute_ssr_z(p_elevation_m_egm96 numeric)
returns table(z_index integer, altitude_m integer, in_envelope boolean)
language sql immutable set search_path='' as $$
 select round(p_elevation_m_egm96 / 3.0)::integer,
        (round(p_elevation_m_egm96 / 3.0)::integer * 3)::integer,
        round(p_elevation_m_egm96 / 3.0)::integer between -4000 and 7000;
$$;

create or replace function sourcecubes.reconcile_vertical_evidence(p_primary uuid,p_crosscheck uuid,p_tolerance_m numeric default 6)
returns uuid language plpgsql set search_path='' as $$
declare a sourcecubes.vertical_evidence_observations%rowtype; b sourcecubes.vertical_evidence_observations%rowtype; rid uuid; vvar numeric; zi integer; za integer; ok boolean;
begin
 select * into a from sourcecubes.vertical_evidence_observations where observation_id=p_primary;
 select * into b from sourcecubes.vertical_evidence_observations where observation_id=p_crosscheck;
 if a.observation_id is null or b.observation_id is null then raise exception 'Observation not found'; end if;
 if a.provider_code not in ('OT-POINT','OT-BATHY') then raise exception 'Primary observation must be controlled OpenTopography land/bathymetry evidence'; end if;
 if b.provider_code <> 'GOOGLE-ELEV' then raise exception 'Cross-check observation must be GOOGLE-ELEV'; end if;
 vvar:=abs(a.observed_value_m-b.observed_value_m);
 if a.canonicalization_eligible and coalesce(a.source_vertical_datum,'')='EGM96' then select * into zi,za,ok from sourcecubes.compute_ssr_z(a.observed_value_m); end if;
 insert into sourcecubes.vertical_evidence_reconciliation(subject_key,primary_observation_id,crosscheck_observation_id,primary_value_m,crosscheck_value_m,variance_m,tolerance_m,reconciliation_status,canonical_z_index,canonical_altitude_m,decision_reference,notes)
 values(coalesce(a.anchor_tile_id,a.anchor_candidate_id::text,a.latitude||','||a.longitude),a.observation_id,b.observation_id,a.observed_value_m,b.observed_value_m,vvar,p_tolerance_m,case when not a.canonicalization_eligible or coalesce(a.source_vertical_datum,'')<>'EGM96' then 'PRIMARY_DATUM_NOT_CANONICALIZED' when vvar<=p_tolerance_m then 'CROSSCHECK_WITHIN_TOLERANCE' else 'VARIANCE_REQUIRES_REVIEW' end,zi,za,'SSR-Z-EGM96-3M-V1','Google Elevation is secondary only; variance never overwrites primary/canonical SSR Z.') returning reconciliation_id into rid;
 return rid;
end $$;

comment on table sourcecubes.vertical_evidence_observations is 'Raw vertical evidence ledger preserving provider, dataset, datum/reference surface and payload before canonicalization.';
comment on table sourcecubes.vertical_evidence_reconciliation is 'Primary-vs-secondary vertical evidence reconciliation. Google Elevation is cross-check only; Mapbox visualization values must not be inserted as canonical evidence.';
