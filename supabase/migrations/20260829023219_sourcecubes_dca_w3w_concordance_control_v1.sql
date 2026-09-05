create table if not exists sourcecubes.spatial_concordance (
  concordance_id uuid primary key default gen_random_uuid(),
  dca_sequence_no integer not null references ecology.ssr_dca_729_registry(sequence_no),
  dca_address text not null,
  latitude double precision,
  longitude double precision,
  w3w_reference_id uuid references ecology.ssr_reference_addresses(id),
  w3w_surface_anchor text,
  concordance_status text not null default 'PENDING_EVIDENCE',
  evidence_reference text,
  evidence_payload jsonb not null default '{}'::jsonb,
  authority_reference text,
  validated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(dca_sequence_no),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180),
  check ((latitude is null and longitude is null) or (latitude is not null and longitude is not null))
);

insert into sourcecubes.spatial_concordance(dca_sequence_no,dca_address,concordance_status,evidence_reference,authority_reference)
select sequence_no,dca_address,'PENDING_EVIDENCE','No canonical DCA-to-coordinate evidence presently recorded','SC-CAC-001'
from ecology.ssr_dca_729_registry
on conflict(dca_sequence_no) do nothing;

create table if not exists sourcecubes.concordance_control_status (
  control_id text primary key,
  dca_total integer not null,
  dca_with_coordinates integer not null,
  dca_with_w3w integer not null,
  dca_fully_validated integer not null,
  reference_w3w_total integer not null,
  reference_w3w_verified integer not null,
  global_binding_status text not null,
  blocking_reason text not null,
  assessed_at timestamptz not null default now()
);

insert into sourcecubes.concordance_control_status(control_id,dca_total,dca_with_coordinates,dca_with_w3w,dca_fully_validated,reference_w3w_total,reference_w3w_verified,global_binding_status,blocking_reason)
select 'SC-CONCORDANCE-001',
       (select count(*) from ecology.ssr_dca_729_registry),
       (select count(*) from sourcecubes.spatial_concordance where latitude is not null and longitude is not null),
       (select count(*) from sourcecubes.spatial_concordance where w3w_reference_id is not null),
       (select count(*) from sourcecubes.spatial_concordance where concordance_status='VALIDATED'),
       (select count(*) from ecology.ssr_reference_addresses),
       (select count(*) from ecology.ssr_reference_addresses where w3w_validation_status in ('VALIDATED','verified','VERIFIED')),
       'BLOCKED_PENDING_AUTHORITATIVE_CONCORDANCE',
       'All 729 DCA records are presently unmapped to latitude/longitude and canonical W3W anchors. Existing SSR reference W3W records are historical_reference_unverified and must not be used to fabricate DCA concordance.'
on conflict(control_id) do update set dca_total=excluded.dca_total,dca_with_coordinates=excluded.dca_with_coordinates,dca_with_w3w=excluded.dca_with_w3w,dca_fully_validated=excluded.dca_fully_validated,reference_w3w_total=excluded.reference_w3w_total,reference_w3w_verified=excluded.reference_w3w_verified,global_binding_status=excluded.global_binding_status,blocking_reason=excluded.blocking_reason,assessed_at=now();

create or replace function sourcecubes.promote_spatial_concordance(
 p_dca_sequence_no integer,
 p_latitude double precision,
 p_longitude double precision,
 p_w3w_reference_id uuid,
 p_evidence_reference text,
 p_evidence_payload jsonb,
 p_authority_reference text
) returns uuid language plpgsql set search_path='' as $$
declare v_id uuid; v_w3w_status text; v_anchor text;
begin
 if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'Invalid coordinate range'; end if;
 if coalesce(btrim(p_evidence_reference),'')='' or coalesce(btrim(p_authority_reference),'')='' then raise exception 'Evidence and authority references are required'; end if;
 select w3w_validation_status,surface_anchor into v_w3w_status,v_anchor from ecology.ssr_reference_addresses where id=p_w3w_reference_id;
 if not found then raise exception 'W3W reference not found'; end if;
 if coalesce(v_w3w_status,'') not in ('VALIDATED','verified','VERIFIED') then raise exception 'W3W reference is not validated'; end if;
 update sourcecubes.spatial_concordance set latitude=p_latitude,longitude=p_longitude,w3w_reference_id=p_w3w_reference_id,w3w_surface_anchor=v_anchor,concordance_status='VALIDATED',evidence_reference=p_evidence_reference,evidence_payload=coalesce(p_evidence_payload,'{}'::jsonb),authority_reference=p_authority_reference,validated_at=now(),updated_at=now() where dca_sequence_no=p_dca_sequence_no returning concordance_id into v_id;
 if v_id is null then raise exception 'DCA sequence not found in concordance control'; end if;
 return v_id;
end $$;

comment on table sourcecubes.spatial_concordance is 'Evidence-controlled DCA 729 to latitude/longitude and What3Words concordance. Nulls are intentional until authoritative evidence is available.';
comment on function sourcecubes.promote_spatial_concordance(integer,double precision,double precision,uuid,text,jsonb,text) is 'Promotes a DCA spatial concordance only when coordinates, validated W3W reference, evidence and authority are supplied.';
