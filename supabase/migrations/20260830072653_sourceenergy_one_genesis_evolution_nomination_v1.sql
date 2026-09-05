create table if not exists sourceenergy_one.genesis_evolution_nominations (
 id uuid primary key default gen_random_uuid(),
 subject_id text not null,
 prior_genesis_id uuid not null references sourceenergy_one.genesis_packages(id),
 reflection_id uuid not null unique references sourceenergy_one.purpose_reflection_syntheses(id),
 proposed_4p_profile jsonb not null,
 proposed_4p_hash text not null check (proposed_4p_hash ~ '^[0-9a-f]{64}$'),
 consent_scope_id text not null,
 nominated_by_actor_ref text not null,
 nomination_attestation text not null,
 status text not null default 'nominated' check (status in ('nominated','approval_required','rejected','consumed')),
 genesis_approval_id uuid references sourceenergy_one.genesis_approvals(id),
 superseding_genesis_id uuid unique references sourceenergy_one.genesis_packages(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table sourceenergy_one.genesis_evolution_nominations enable row level security;
revoke all on sourceenergy_one.genesis_evolution_nominations from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.genesis_evolution_nominations to service_role;
create policy genesis_evolution_nomination_service_role on sourceenergy_one.genesis_evolution_nominations for all to service_role using(true) with check(true);
create index if not exists genesis_evolution_subject_idx on sourceenergy_one.genesis_evolution_nominations(subject_id,created_at desc);

create or replace function sourceenergy_one.nominate_genesis_evolution(
 p_reflection_id uuid,p_prior_genesis_id uuid,p_proposed_4p_profile jsonb,p_actor_ref text,p_attestation text
) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare r sourceenergy_one.purpose_reflection_syntheses%rowtype; g sourceenergy_one.genesis_packages%rowtype; nomination_id uuid; h text; dim_name text; dim jsonb;
begin
 if p_actor_ref is null or btrim(p_actor_ref)='' then raise exception 'actor_ref required'; end if;
 if p_attestation is null or btrim(p_attestation)='' then raise exception 'nomination attestation required'; end if;
 select * into r from sourceenergy_one.purpose_reflection_syntheses where id=p_reflection_id for update; if not found then raise exception 'reflection synthesis not found'; end if;
 if r.human_review_status<>'confirmed' then raise exception 'reflection must be human-confirmed'; end if;
 if r.materiality<>'material' then raise exception 'only material reflection may nominate Genesis evolution'; end if;
 select * into g from sourceenergy_one.genesis_packages where id=p_prior_genesis_id; if not found then raise exception 'prior Genesis not found'; end if;
 if g.subject_id<>r.subject_id then raise exception 'reflection subject does not match prior Genesis'; end if;
 if exists(select 1 from sourceenergy_one.genesis_packages x where x.package->>'prior_genesis_id'=p_prior_genesis_id::text) then raise exception 'prior Genesis already has a superseding Genesis'; end if;
 if p_proposed_4p_profile is null or jsonb_typeof(p_proposed_4p_profile)<>'object' then raise exception 'proposed_4p_profile required'; end if;
 if nullif(btrim(p_proposed_4p_profile->>'version'),'') is null then raise exception '4P profile version required'; end if;
 if nullif(btrim(p_proposed_4p_profile->>'approved_by'),'') is null then raise exception '4P profile approved_by required'; end if;
 if nullif(btrim(p_proposed_4p_profile->>'approval_attestation'),'') is null then raise exception '4P approval attestation required'; end if;
 foreach dim_name in array array['purpose','product','people','profit'] loop
   dim:=p_proposed_4p_profile->dim_name;
   if dim is null or jsonb_typeof(dim)<>'object' then raise exception '4P dimension % required',dim_name; end if;
   if nullif(btrim(dim->>'statement'),'') is null or nullif(btrim(dim->>'source_hash'),'') is null or nullif(btrim(dim->>'version'),'') is null then raise exception '4P dimension % incomplete',dim_name; end if;
   if jsonb_typeof(dim->'evidence_refs')<>'array' or jsonb_array_length(dim->'evidence_refs')=0 then raise exception '4P dimension % evidence required',dim_name; end if;
 end loop;
 h:=encode(extensions.digest(convert_to(p_proposed_4p_profile::text,'UTF8'),'sha256'::text),'hex');
 insert into sourceenergy_one.genesis_evolution_nominations(subject_id,prior_genesis_id,reflection_id,proposed_4p_profile,proposed_4p_hash,consent_scope_id,nominated_by_actor_ref,nomination_attestation,status)
 values(r.subject_id,g.id,r.id,p_proposed_4p_profile,h,r.consent_scope_id,btrim(p_actor_ref),btrim(p_attestation),'approval_required') returning id into nomination_id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),r.subject_id,auth.uid(),'genesis_evolution_nominated','genesis_evolution_nomination',nomination_id::text,jsonb_build_object('prior_genesis_id',g.id,'reflection_id',r.id,'proposed_4p_hash',h,'actor_ref',btrim(p_actor_ref),'status','approval_required'));
 return nomination_id;
end; $$;

create or replace function sourceenergy_one.bind_genesis_evolution_approval(p_nomination_id uuid,p_genesis_approval_id uuid,p_actor_ref text) returns void language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$
declare n sourceenergy_one.genesis_evolution_nominations%rowtype; a sourceenergy_one.genesis_approvals%rowtype;
begin
 if p_actor_ref is null or btrim(p_actor_ref)='' then raise exception 'actor_ref required'; end if;
 select * into n from sourceenergy_one.genesis_evolution_nominations where id=p_nomination_id for update; if not found then raise exception 'nomination not found'; end if;
 if n.status<>'approval_required' then raise exception 'nomination is not awaiting approval'; end if;
 select * into a from sourceenergy_one.genesis_approvals where id=p_genesis_approval_id; if not found then raise exception 'Genesis approval not found'; end if;
 if a.decision<>'approve' then raise exception 'Genesis approval decision is not approve'; end if;
 if coalesce(nullif(btrim(a.actor_ref),''),a.actor_id::text) is null then raise exception 'human Genesis approver required'; end if;
 if a.consent_receipt_id is null or btrim(a.consent_receipt_id)='' then raise exception 'Genesis approval consent required'; end if;
 if a.decided_at <= n.created_at then raise exception 'Genesis approval must occur after evolution nomination'; end if;
 update sourceenergy_one.genesis_evolution_nominations set genesis_approval_id=a.id,updated_at=now() where id=n.id;
 insert into sourceenergy_one.audit_events(correlation_id,subject_id,actor_id,event_type,object_type,object_ref,payload) values(gen_random_uuid(),n.subject_id,auth.uid(),'genesis_evolution_approval_bound','genesis_evolution_nomination',n.id::text,jsonb_build_object('genesis_approval_id',a.id,'actor_ref',btrim(p_actor_ref)));
end; $$;

revoke all on function sourceenergy_one.nominate_genesis_evolution(uuid,uuid,jsonb,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.bind_genesis_evolution_approval(uuid,uuid,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.nominate_genesis_evolution(uuid,uuid,jsonb,text,text) to service_role;
grant execute on function sourceenergy_one.bind_genesis_evolution_approval(uuid,uuid,text) to service_role;
