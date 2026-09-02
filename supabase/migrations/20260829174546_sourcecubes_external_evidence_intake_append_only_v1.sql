create table if not exists sourcecubes.external_evidence_intake(
 intake_id uuid primary key default gen_random_uuid(),
 anchor_candidate_id uuid not null references ecology.ssr_anchor_candidate_registry(id) on delete cascade,
 provider_code text not null,
 evidence_type text not null,
 request_payload jsonb not null default '{}'::jsonb,
 response_payload jsonb,
 provider_status integer,
 evidence_hash text,
 acquisition_state text not null default 'QUEUED',
 requested_at timestamptz not null default now(),
 received_at timestamptz,
 source_endpoint text,
 notes text
);

create table if not exists sourcecubes.external_evidence_validation(
 validation_id uuid primary key default gen_random_uuid(),
 intake_id uuid not null references sourcecubes.external_evidence_intake(intake_id) on delete cascade,
 validation_rule text not null,
 validation_state text not null,
 canonicalization_eligible boolean not null default false,
 observed_value jsonb,
 evidence_reference text,
 validated_at timestamptz not null default now()
);

create or replace function sourcecubes.queue_external_evidence(p_candidate_id uuid,p_provider_code text,p_evidence_type text)
returns uuid language plpgsql set search_path='pg_catalog','sourcecubes','ecology' as $$
declare c ecology.ssr_anchor_candidate_registry%rowtype; rid uuid; payload jsonb;
begin
 select * into c from ecology.ssr_anchor_candidate_registry where id=p_candidate_id;
 if not found then raise exception 'Unknown anchor candidate'; end if;
 if p_provider_code='W3W' then payload:=jsonb_build_object('mode','coordinates','latitude',c.latitude,'longitude',c.longitude,'language','en');
 elsif p_provider_code='OT-POINT' then payload:=jsonb_build_object('latitude',c.latitude,'longitude',c.longitude,'dataset','SRTM_GL1');
 elsif p_provider_code='OT-SRTM15PLUS' then payload:=jsonb_build_object('latitude',c.latitude,'longitude',c.longitude,'dataset','SRTM15Plus');
 else raise exception 'Unsupported queued provider: %',p_provider_code; end if;
 insert into sourcecubes.external_evidence_intake(anchor_candidate_id,provider_code,evidence_type,request_payload,acquisition_state)
 values(p_candidate_id,p_provider_code,p_evidence_type,payload,'QUEUED') returning intake_id into rid;
 return rid;
end $$;

create or replace function sourcecubes.record_external_evidence_response(p_intake_id uuid,p_provider_status integer,p_source_endpoint text,p_response_payload jsonb,p_notes text default null)
returns uuid language plpgsql set search_path='pg_catalog','sourcecubes','extensions' as $$
declare h text;
begin
 if not exists(select 1 from sourcecubes.external_evidence_intake where intake_id=p_intake_id) then raise exception 'Evidence intake not found'; end if;
 h:=encode(extensions.digest(convert_to(coalesce(p_response_payload,'{}'::jsonb)::text,'UTF8'),'sha256'::text),'hex');
 update sourcecubes.external_evidence_intake set response_payload=p_response_payload,provider_status=p_provider_status,evidence_hash=h,received_at=now(),source_endpoint=p_source_endpoint,notes=p_notes,acquisition_state=case when p_provider_status between 200 and 299 then 'RECEIVED' else 'PROVIDER_ERROR' end where intake_id=p_intake_id;
 return p_intake_id;
end $$;

create or replace function sourcecubes.record_external_evidence_validation(p_intake_id uuid,p_validation_rule text,p_validation_state text,p_canonicalization_eligible boolean,p_observed_value jsonb,p_evidence_reference text)
returns uuid language plpgsql set search_path='pg_catalog','sourcecubes' as $$
declare rid uuid;
begin
 if not exists(select 1 from sourcecubes.external_evidence_intake where intake_id=p_intake_id and acquisition_state='RECEIVED') then raise exception 'Received evidence required before validation'; end if;
 insert into sourcecubes.external_evidence_validation(intake_id,validation_rule,validation_state,canonicalization_eligible,observed_value,evidence_reference)
 values(p_intake_id,p_validation_rule,p_validation_state,p_canonicalization_eligible,p_observed_value,p_evidence_reference) returning validation_id into rid;
 return rid;
end $$;

create or replace view sourcecubes.external_evidence_pipeline as
select i.intake_id,i.anchor_candidate_id,c.infrastructure_name,i.provider_code,i.evidence_type,i.acquisition_state,i.provider_status,i.evidence_hash,i.requested_at,i.received_at,i.source_endpoint,
 v.validation_id,v.validation_rule,v.validation_state,v.canonicalization_eligible,v.observed_value,v.evidence_reference,v.validated_at
from sourcecubes.external_evidence_intake i
join ecology.ssr_anchor_candidate_registry c on c.id=i.anchor_candidate_id
left join lateral (select * from sourcecubes.external_evidence_validation v where v.intake_id=i.intake_id order by v.validated_at desc limit 1) v on true;

comment on table sourcecubes.external_evidence_intake is 'External-provider evidence acquisition ledger. Provider responses are recorded here without mutating canonical SSR candidate or registry state.';
comment on table sourcecubes.external_evidence_validation is 'Independent validation decisions for acquired provider evidence. This table does not itself mutate canonical SSR state.';
