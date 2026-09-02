create or replace function sourcecubes.promote_anchor_candidate(
  p_candidate_id uuid,
  p_approval_reference text
) returns sourcecubes.cube_bindings
language plpgsql
set search_path='pg_catalog','sourcecubes','ecology','public','rgl','extensions'
as $$
declare
  c ecology.ssr_anchor_candidate_registry%rowtype;
  s rgl.spatial_registry_links%rowtype;
  n rgl.infrastructure_nodes%rowtype;
  v_anchor_id text;
  v_surface text;
  v_expected_address text;
  v_expected_uid text;
  v_metadata_hash text;
  v_authority_signature text;
  v_binding sourcecubes.cube_bindings%rowtype;
begin
  if coalesce(btrim(p_approval_reference),'')='' then raise exception 'Approval reference is required'; end if;
  select * into c from ecology.ssr_anchor_candidate_registry where id=p_candidate_id for update;
  if not found then raise exception 'Anchor candidate not found'; end if;
  if c.source_schema<>'rgl' or c.source_object<>'spatial_registry_links' then raise exception 'Unsupported source lineage for controlled promotion'; end if;
  select * into s from rgl.spatial_registry_links where id=c.source_record_id::uuid for update;
  if not found then raise exception 'RGL spatial source record not found'; end if;
  select * into n from rgl.infrastructure_nodes where id=s.entity_id for update;
  if not found then raise exception 'RGL infrastructure node not found'; end if;
  if lower(coalesce(n.verification_status,''))<>'verified' then raise exception 'Infrastructure source node is not verified'; end if;
  if abs(n.latitude::double precision-c.latitude)>0.000001 or abs(n.longitude::double precision-c.longitude)>0.000001 then raise exception 'Candidate/source coordinate mismatch'; end if;
  if not exists(select 1 from ecology.ssr_w3w_validation_log w where w.subject_id=p_candidate_id::text and lower(w.validation_status)='validated' and lower(w.resolved_words)=lower(c.w3w_address)) then raise exception 'Validated What3Words evidence missing or mismatched'; end if;
  if c.elevation_m_egm96 is null or c.z_index is null or c.z_assignment_standard<>'SSR-Z-EGM96-3M-V1' then raise exception 'Canonical EGM96/Z evidence incomplete'; end if;
  if not exists(select 1 from ecology.ssr_vertical_11001_layers z where z.z_index=c.z_index) then raise exception 'Candidate Z is outside canonical 11,001-layer registry'; end if;
  v_surface:=lower(c.w3w_address); if left(v_surface,3)<>'///' then v_surface:='///'||ltrim(v_surface,'/'); end if;
  v_expected_address:=v_surface||'@Z'||case when c.z_index>=0 then '+' else '-' end||lpad(abs(c.z_index)::text,4,'0');
  v_expected_uid:=encode(extensions.digest(convert_to(v_expected_address,'UTF8'),'sha256'::text),'hex');
  if c.canonical_address is distinct from v_expected_address or c.cube_uid is distinct from v_expected_uid then raise exception 'Candidate canonical address/UID fails deterministic validation'; end if;
  v_anchor_id:='SSR-'||coalesce(substring(s.ssr_registry_designation from '([0-9]+\.[A-Za-z]+-[0-9]+)'),replace(p_candidate_id::text,'-',''));
  v_metadata_hash:=encode(extensions.digest(convert_to(v_anchor_id||'|'||v_surface||'|'||c.latitude::text||'|'||c.longitude::text||'|'||coalesce(n.source_reference,'')||'|'||coalesce(s.ssr_registry_designation,'')||'|'||p_candidate_id::text,'UTF8'),'sha256'::text),'hex');
  v_authority_signature:=encode(extensions.digest(convert_to('SOURCEENERGY_SSR_APPROVAL|'||p_approval_reference||'|'||v_metadata_hash,'UTF8'),'sha256'::text),'hex');

  update rgl.spatial_registry_links set verification_status='verified',reconciliation_status='matched_verified',reconciliation_confidence=1.0,ssr_anchor_address=v_surface,ssr_cube_uid=v_expected_uid,updated_at=now() where id=s.id;
  update ecology.ssr_anchor_candidate_registry set source_verification_status='verified',source_reconciliation_status='matched_verified',canonicalization_status='authority_review_approved',promotion_eligible=true,blocker_reason=null,updated_at=now() where id=p_candidate_id;
  update ecology.ssr_candidate_requirement_status set status='satisfied_reference',evidence_reference=coalesce(evidence_reference,n.source_reference||' | verified RGL node '||n.id::text),notes=coalesce(notes,'Source node verified by recorded authority and exact coordinate reconciliation.'),updated_at=now() where candidate_id=p_candidate_id and requirement_code='SSR-CAN-01';
  update ecology.ssr_candidate_requirement_status set status='satisfied_authority_review',evidence_reference=p_approval_reference||' | verified RGL source node '||n.id::text||' | validated W3W + EGM96 + deterministic UID',notes='SourceEnergy SSR authority/evidence review approved after all blocking technical and provenance checks passed.',updated_at=now() where candidate_id=p_candidate_id and requirement_code='SSR-CAN-06';

  insert into public.anchor_tiles(anchor_tile_id,w3w_address,latitude,longitude,activation_date,status,surface_crs,vertical_datum,source_system,source_record_id,source_exported_at,authority_signature,metadata_hash)
  values(v_anchor_id,v_surface,c.latitude,c.longitude,now(),'active','EPSG:4326','EGM96','SOURCEENERGY-SSR-CANONICAL-PROMOTION',c.source_record_id,now(),v_authority_signature,v_metadata_hash)
  on conflict(w3w_address) do update set latitude=excluded.latitude,longitude=excluded.longitude,status='active',surface_crs='EPSG:4326',vertical_datum='EGM96',source_system=excluded.source_system,source_record_id=excluded.source_record_id,source_exported_at=excluded.source_exported_at,authority_signature=excluded.authority_signature,metadata_hash=excluded.metadata_hash;

  select * into v_binding from sourcecubes.resolve_authoritative_cube((select anchor_tile_id from public.anchor_tiles where w3w_address=v_surface),c.z_index);

  update ecology.ssr_candidate_requirement_status set status='satisfied_promoted',evidence_reference='public.anchor_tiles:'||v_binding.anchor_tile_id||' | public.spatial_cubes:'||v_binding.spatial_cube_id::text,notes='Candidate promoted to authoritative AnchorTile and SourceCube registry.',updated_at=now() where candidate_id=p_candidate_id and requirement_code='SSR-CAN-07';
  update sourcecubes.anchor_promotion_gate set source_location_gate='SATISFIED_VERIFIED_SOURCE',authority_review_gate='SATISFIED',registry_promotion_gate='SATISFIED',overall_status='PROMOTED_AUTHORITATIVE',evidence_summary=evidence_summary||jsonb_build_object('approval_reference',p_approval_reference,'anchor_tile_id',v_binding.anchor_tile_id,'spatial_cube_id',v_binding.spatial_cube_id,'promoted_at',now()),updated_at=now() where anchor_candidate_id=p_candidate_id;
  update sourcecubes.canonicalization_gate set authority_review_state='SATISFIED',registry_promotion_state='SATISFIED',overall_state='AUTHORITATIVE_ACTIVE',blocker_reason=null,evidence_reference=evidence_reference||'; public.anchor_tiles:'||v_binding.anchor_tile_id||'; public.spatial_cubes:'||v_binding.spatial_cube_id::text,updated_at=now() where anchor_candidate_id=p_candidate_id;
  update sourcecubes.anchor_tile_bindings set anchor_tile_id=v_binding.anchor_tile_id,anchor_candidate_id=null,authority_state='SSR_CANONICAL',binding_status='AUTHORITATIVE_ACTIVE',canonical_address=v_binding.canonical_address,cube_uid=v_binding.cube_uid,z_index=v_binding.z_index,updated_at=now() where anchor_candidate_id=p_candidate_id;
  return v_binding;
end $$;
comment on function sourcecubes.promote_anchor_candidate(uuid,text) is 'Fail-closed SourceEnergy SSR candidate promotion. Requires verified source node, exact coordinate concordance, validated W3W, EGM96/Z evidence, 11,001-layer membership, deterministic canonical address/UID, and explicit approval reference before creating authoritative AnchorTile and SourceCube records.';
