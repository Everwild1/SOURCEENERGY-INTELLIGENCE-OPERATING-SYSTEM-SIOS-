create or replace function sourceenergy_one.validate_4p_typed_evidence(p_subject_id text,p_profile jsonb) returns boolean language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare dim_name text; dim jsonb; ref text; eid uuid; begin if p_profile is null or jsonb_typeof(p_profile)<>'object' then raise exception '4P profile required'; end if; foreach dim_name in array array['purpose','product','people','profit'] loop dim:=p_profile->dim_name; if dim is null or jsonb_typeof(dim)<>'object' then raise exception '4P dimension % required',dim_name; end if; if jsonb_typeof(dim->'evidence_refs')<>'array' or jsonb_array_length(dim->'evidence_refs')=0 then raise exception '4P dimension % typed evidence required',dim_name; end if; for ref in select jsonb_array_elements_text(dim->'evidence_refs') loop begin eid:=ref::uuid; exception when invalid_text_representation then raise exception '4P dimension % evidence reference must be typed evidence UUID',dim_name; end; perform sourceenergy_one.require_evidence_provenance(eid,p_subject_id); end loop; end loop; return true; end $$;

create or replace function sourceenergy_one.enforce_genesis_4p_typed_evidence() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin perform sourceenergy_one.validate_4p_typed_evidence(new.subject_id,new.package->'economic_4p_profile'); return new; end $$;
drop trigger if exists genesis_4p_typed_evidence_trg on sourceenergy_one.genesis_packages;
create trigger genesis_4p_typed_evidence_trg before insert on sourceenergy_one.genesis_packages for each row execute function sourceenergy_one.enforce_genesis_4p_typed_evidence();

create or replace function sourceenergy_one.enforce_evolution_4p_typed_evidence() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin perform sourceenergy_one.validate_4p_typed_evidence(new.subject_id,new.proposed_4p_profile); return new; end $$;
drop trigger if exists evolution_4p_typed_evidence_trg on sourceenergy_one.genesis_evolution_nominations;
create trigger evolution_4p_typed_evidence_trg before insert on sourceenergy_one.genesis_evolution_nominations for each row execute function sourceenergy_one.enforce_evolution_4p_typed_evidence();

create table if not exists sourceenergy_one.reflection_evidence_links (
 reflection_id uuid not null references sourceenergy_one.purpose_reflection_syntheses(id),
 evidence_id uuid not null references sourceenergy_one.evidence_provenance(id),
 relationship text not null default 'source' check(relationship in ('source','corroborating','context','contradicting')),
 created_at timestamptz not null default now(),
 primary key(reflection_id,evidence_id,relationship)
);
alter table sourceenergy_one.reflection_evidence_links enable row level security;
revoke all on sourceenergy_one.reflection_evidence_links from public,anon,authenticated;
grant select,insert on sourceenergy_one.reflection_evidence_links to service_role;
create policy reflection_evidence_links_service_role on sourceenergy_one.reflection_evidence_links for all to service_role using(true) with check(true);

create or replace function sourceenergy_one.link_reflection_typed_evidence(p_reflection_id uuid,p_evidence_ids uuid[],p_relationship text default 'source') returns integer language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare r sourceenergy_one.purpose_reflection_syntheses%rowtype; eid uuid; n int:=0; begin if p_evidence_ids is null or cardinality(p_evidence_ids)=0 then raise exception 'typed evidence required'; end if; if p_relationship not in ('source','corroborating','context','contradicting') then raise exception 'invalid evidence relationship'; end if; select * into r from sourceenergy_one.purpose_reflection_syntheses where id=p_reflection_id; if not found then raise exception 'reflection not found'; end if; foreach eid in array p_evidence_ids loop perform sourceenergy_one.require_evidence_provenance(eid,r.subject_id); insert into sourceenergy_one.reflection_evidence_links(reflection_id,evidence_id,relationship) values(r.id,eid,p_relationship) on conflict do nothing; n:=n+1; end loop; return n; end $$;

create or replace function sourceenergy_one.enforce_reflection_typed_evidence_on_confirmation() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin if old.human_review_status='pending' and new.human_review_status='confirmed' then if not exists(select 1 from sourceenergy_one.reflection_evidence_links l join sourceenergy_one.evidence_provenance e on e.id=l.evidence_id where l.reflection_id=new.id and e.status='active' and e.subject_id=new.subject_id) then raise exception 'reflection requires active typed evidence before human confirmation'; end if; end if; return new; end $$;
drop trigger if exists purpose_reflection_typed_evidence_confirm_trg on sourceenergy_one.purpose_reflection_syntheses;
create trigger purpose_reflection_typed_evidence_confirm_trg before update on sourceenergy_one.purpose_reflection_syntheses for each row execute function sourceenergy_one.enforce_reflection_typed_evidence_on_confirmation();

revoke all on function sourceenergy_one.validate_4p_typed_evidence(text,jsonb) from public,anon,authenticated;
revoke all on function sourceenergy_one.link_reflection_typed_evidence(uuid,uuid[],text) from public,anon,authenticated;
grant execute on function sourceenergy_one.validate_4p_typed_evidence(text,jsonb) to service_role;
grant execute on function sourceenergy_one.link_reflection_typed_evidence(uuid,uuid[],text) to service_role;
comment on function sourceenergy_one.validate_4p_typed_evidence(text,jsonb) is 'Fail-closed 4P evidence gate. Every Purpose/Product/People/Profit evidence_refs item must be an active typed evidence_provenance UUID for the same subject.';
