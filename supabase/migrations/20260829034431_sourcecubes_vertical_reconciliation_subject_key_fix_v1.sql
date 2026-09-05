create or replace function sourcecubes.reconcile_vertical_evidence(p_primary uuid,p_crosscheck uuid default null,p_tolerance_m numeric default 6)
returns uuid language plpgsql security invoker as $$
declare a sourcecubes.vertical_evidence_observations%rowtype; b sourcecubes.vertical_evidence_observations%rowtype; rid uuid; v numeric; st text; zi integer; za numeric; sk text;
begin
 select * into a from sourcecubes.vertical_evidence_observations where observation_id=p_primary;
 if not found then raise exception 'Primary observation not found'; end if;
 if a.provider_code not in ('OT-POINT','OT-SRTM15PLUS','OT-GEBCO','OT-BATHY','GEBCO-SOURCE') then raise exception 'Provider % is not permitted as primary vertical evidence',a.provider_code; end if;
 sk:=coalesce('anchor_candidate:'||a.anchor_candidate_id::text,'anchor_tile:'||a.anchor_tile_id::text,'coordinate:'||a.latitude::text||','||a.longitude::text);
 if p_crosscheck is not null then select * into b from sourcecubes.vertical_evidence_observations where observation_id=p_crosscheck; if not found then raise exception 'Crosscheck observation not found'; end if; if b.provider_code <> 'GOOGLE-ELEV' then raise exception 'Crosscheck provider must be GOOGLE-ELEV'; end if; v:=abs(a.observed_value_m-b.observed_value_m); end if;
 if a.provider_code in ('OT-POINT','OT-SRTM15PLUS') and a.canonicalization_eligible and upper(a.source_vertical_datum)='EGM96' then select z_index,altitude_m into zi,za from sourcecubes.compute_ssr_z(a.observed_value_m); st:=case when p_crosscheck is null then 'PRIMARY_EGM96_CANONICALIZABLE' when v<=p_tolerance_m then 'CROSSCHECK_WITHIN_TOLERANCE' else 'VARIANCE_REQUIRES_REVIEW' end;
 elsif a.provider_code in ('OT-GEBCO','OT-BATHY','GEBCO-SOURCE') then st:='PRIMARY_DATUM_RECONCILIATION_REQUIRED'; zi:=null; za:=null;
 else st:='PRIMARY_DATUM_NOT_CANONICALIZED'; zi:=null; za:=null; end if;
 insert into sourcecubes.vertical_evidence_reconciliation(subject_key,primary_observation_id,crosscheck_observation_id,primary_value_m,crosscheck_value_m,variance_m,tolerance_m,reconciliation_status,canonical_z_index,canonical_altitude_m,decision_reference,notes)
 values(sk,a.observation_id,case when p_crosscheck is null then null else b.observation_id end,a.observed_value_m,case when p_crosscheck is null then null else b.observed_value_m end,v,p_tolerance_m,st,zi,za,'SSR-Z-EGM96-3M-V1','Dataset-specific provider rules v2. GEBCO-family evidence never directly establishes canonical SSR Z; Google Elevation is crosscheck only.') returning reconciliation_id into rid;
 return rid;
end $$;
