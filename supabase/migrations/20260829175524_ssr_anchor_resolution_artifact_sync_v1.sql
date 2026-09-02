create or replace function ecology.sync_ssr_anchor_resolution_artifacts()
returns trigger
language plpgsql
security definer
set search_path=ecology,sourcecubes,public,pg_temp
as $$
declare
  c ecology.ssr_anchor_candidate_registry%rowtype;
  v_gate_id text;
  v_overall text;
  v_blocker text;
begin
  if new.status<>'completed' then return new; end if;
  select * into c from ecology.ssr_anchor_candidate_registry where id=new.candidate_id;
  if not found then return new; end if;

  insert into ecology.ssr_w3w_validation_log(
    subject_type,subject_id,request_mode,input_latitude,input_longitude,input_words,
    resolved_words,resolved_latitude,resolved_longitude,provider,provider_endpoint,
    validation_status,response_metadata,validated_at
  ) values (
    'coordinate_candidate',c.id::text,'coordinates',c.latitude,c.longitude,null,
    new.result_summary->>'w3w_address',
    nullif(new.result_summary->'w3w_metadata'->'coordinates'->>'lat','')::double precision,
    nullif(new.result_summary->'w3w_metadata'->'coordinates'->>'lng','')::double precision,
    'what3words','v3/convert-to-3wa','validated',
    coalesce(new.result_summary->'w3w_metadata','{}'::jsonb)||jsonb_build_object('resolution_job_id',new.id,'worker_id',new.worker_id),
    coalesce(new.completed_at,now())
  ) on conflict(subject_type,subject_id,request_mode) do update set
    input_latitude=excluded.input_latitude,input_longitude=excluded.input_longitude,
    resolved_words=excluded.resolved_words,resolved_latitude=excluded.resolved_latitude,
    resolved_longitude=excluded.resolved_longitude,provider=excluded.provider,
    provider_endpoint=excluded.provider_endpoint,validation_status='validated',
    response_metadata=excluded.response_metadata,validated_at=excluded.validated_at;

  v_gate_id:='SC-ANCHOR-'||upper(substr(replace(c.id::text,'-',''),1,12));
  v_overall:=case when lower(coalesce(c.infrastructure_type,'')) in ('seaport','port','harbor','marine_terminal')
                  then 'BLOCKED_CROSS_DOMAIN_RECONCILIATION' else 'READY_FOR_AUTHORITY_REVIEW' end;
  v_blocker:=case when v_overall='BLOCKED_CROSS_DOMAIN_RECONCILIATION'
                  then 'Coastline/grid/datum reconciliation and governance approval remain required before promotion.'
                  else 'Authority/evidence review and governed registry promotion remain required.' end;

  insert into sourcecubes.anchor_promotion_gate(
    gate_id,anchor_candidate_id,source_location_gate,w3w_gate,vertical_gate,
    canonical_string_gate,cube_uid_gate,authority_review_gate,registry_promotion_gate,
    overall_status,evidence_summary,updated_at
  ) values (
    v_gate_id,c.id,
    case when lower(coalesce(c.source_verification_status,''))='verified' then 'SATISFIED_VERIFIED_SOURCE' else 'SOURCE_REVIEW_PENDING' end,
    'SATISFIED_API_VALIDATED','SATISFIED_EGM96','SATISFIED','SATISFIED_SHA256',
    'PENDING','PENDING',v_overall,
    jsonb_build_object(
      'source_reference',c.source_reference,'canonical_address',c.canonical_address,
      'w3w_provider','what3words','vertical_standard',c.z_assignment_standard,
      'resolution_job_id',new.id,'remaining_blocker',v_blocker
    ),now()
  ) on conflict(gate_id) do update set
    source_location_gate=excluded.source_location_gate,w3w_gate=excluded.w3w_gate,
    vertical_gate=excluded.vertical_gate,canonical_string_gate=excluded.canonical_string_gate,
    cube_uid_gate=excluded.cube_uid_gate,overall_status=excluded.overall_status,
    evidence_summary=excluded.evidence_summary,updated_at=now();

  insert into sourcecubes.canonicalization_gate(
    subject_key,anchor_candidate_id,horizontal_address_state,vertical_evidence_state,
    vertical_datum_state,z_assignment_state,authority_review_state,
    registry_promotion_state,overall_state,blocker_reason,evidence_reference
  ) values (
    'ANCHOR_CANDIDATE:'||c.id::text,c.id,'W3W_VALIDATED_REFERENCE_PRESENT',
    'PRIMARY_EGM96_EVIDENCE_PRESENT','EGM96_ESTABLISHED','ASSIGNED_UNDER_SSR_STANDARD',
    'PENDING','PENDING',v_overall,v_blocker,
    'ecology.ssr_anchor_candidate_registry; ecology.ssr_candidate_requirement_status; sourcecubes.anchor_promotion_gate'
  ) on conflict(subject_key) do update set
    horizontal_address_state=excluded.horizontal_address_state,
    vertical_evidence_state=excluded.vertical_evidence_state,
    vertical_datum_state=excluded.vertical_datum_state,
    z_assignment_state=excluded.z_assignment_state,
    overall_state=excluded.overall_state,blocker_reason=excluded.blocker_reason,
    evidence_reference=excluded.evidence_reference,updated_at=now();

  if not exists(select 1 from sourcecubes.anchor_tile_bindings b where b.anchor_candidate_id=c.id) then
    insert into sourcecubes.anchor_tile_bindings(
      anchor_candidate_id,canonical_address,cube_uid,latitude,longitude,z_index,
      authority_state,binding_status,evidence_reference
    ) values (
      c.id,c.canonical_address,c.cube_uid,c.latitude,c.longitude,c.z_index,
      'CANDIDATE','PENDING_PROMOTION',c.source_reference
    );
  else
    update sourcecubes.anchor_tile_bindings
    set canonical_address=c.canonical_address,cube_uid=c.cube_uid,latitude=c.latitude,
        longitude=c.longitude,z_index=c.z_index,evidence_reference=c.source_reference,updated_at=now()
    where anchor_candidate_id=c.id;
  end if;

  return new;
end $$;

drop trigger if exists trg_sync_ssr_anchor_resolution_artifacts on ecology.ssr_anchor_resolution_jobs;
create trigger trg_sync_ssr_anchor_resolution_artifacts
after insert or update of status,result_summary on ecology.ssr_anchor_resolution_jobs
for each row execute function ecology.sync_ssr_anchor_resolution_artifacts();

-- Backfill artifacts for already completed resolution jobs.
update ecology.ssr_anchor_resolution_jobs
set updated_at=now()
where status='completed';
