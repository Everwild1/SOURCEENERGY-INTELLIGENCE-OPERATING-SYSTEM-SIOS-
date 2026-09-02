create table if not exists sourceenergy_one.actor_identities (
 id uuid primary key default gen_random_uuid(),
 actor_ref text not null unique,
 subject_id text,
 auth_user_id uuid,
 assurance_level text not null check(assurance_level in ('declared','verified','strong_verified')),
 verification_method text not null,
 verification_evidence jsonb not null default '{}'::jsonb,
 heartbeat_enrollment_ref uuid,
 status text not null default 'active' check(status in ('active','suspended','revoked')),
 verified_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint actor_verified_time_ck check((assurance_level='declared') or verified_at is not null)
);

create table if not exists sourceenergy_one.consent_receipts (
 id uuid primary key default gen_random_uuid(),
 consent_ref text not null unique,
 subject_id text not null,
 actor_identity_id uuid not null references sourceenergy_one.actor_identities(id),
 scope text not null,
 purpose text not null,
 terms_hash text not null check(terms_hash ~ '^[0-9a-f]{64}$'),
 evidence jsonb not null default '{}'::jsonb,
 status text not null default 'active' check(status in ('active','revoked','expired','superseded')),
 effective_at timestamptz not null default now(),
 expires_at timestamptz,
 revoked_at timestamptz,
 supersedes_consent_id uuid references sourceenergy_one.consent_receipts(id),
 created_at timestamptz not null default now(),
 constraint consent_expiry_ck check(expires_at is null or expires_at>effective_at)
);

alter table sourceenergy_one.actor_identities enable row level security;
alter table sourceenergy_one.consent_receipts enable row level security;
revoke all on sourceenergy_one.actor_identities,sourceenergy_one.consent_receipts from public,anon,authenticated;
grant select,insert,update on sourceenergy_one.actor_identities,sourceenergy_one.consent_receipts to service_role;
create policy actor_identities_service_role on sourceenergy_one.actor_identities for all to service_role using(true) with check(true);
create policy consent_receipts_service_role on sourceenergy_one.consent_receipts for all to service_role using(true) with check(true);

create or replace function sourceenergy_one.register_actor_identity(p_actor_ref text,p_subject_id text,p_assurance_level text,p_verification_method text,p_verification_evidence jsonb,p_auth_user_id uuid default null,p_heartbeat_enrollment_ref uuid default null) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare aid uuid; begin
 if nullif(btrim(p_actor_ref),'') is null then raise exception 'actor_ref required'; end if;
 if p_assurance_level not in ('declared','verified','strong_verified') then raise exception 'invalid assurance level'; end if;
 if nullif(btrim(p_verification_method),'') is null then raise exception 'verification method required'; end if;
 insert into sourceenergy_one.actor_identities(actor_ref,subject_id,auth_user_id,assurance_level,verification_method,verification_evidence,heartbeat_enrollment_ref,verified_at)
 values(btrim(p_actor_ref),nullif(btrim(p_subject_id),''),p_auth_user_id,p_assurance_level,btrim(p_verification_method),coalesce(p_verification_evidence,'{}'::jsonb),p_heartbeat_enrollment_ref,case when p_assurance_level='declared' then null else now() end)
 returning id into aid;
 return aid;
end $$;

create or replace function sourceenergy_one.issue_consent_receipt(p_consent_ref text,p_subject_id text,p_actor_ref text,p_scope text,p_purpose text,p_terms_hash text,p_evidence jsonb,p_expires_at timestamptz default null,p_supersedes_consent_id uuid default null) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare aid uuid; cid uuid; begin
 if nullif(btrim(p_consent_ref),'') is null or nullif(btrim(p_subject_id),'') is null or nullif(btrim(p_scope),'') is null or nullif(btrim(p_purpose),'') is null then raise exception 'consent reference, subject, scope and purpose required'; end if;
 if p_terms_hash !~ '^[0-9a-f]{64}$' then raise exception 'terms_hash must be 64 lowercase hex characters'; end if;
 select id into aid from sourceenergy_one.actor_identities where actor_ref=btrim(p_actor_ref) and status='active' and assurance_level in ('verified','strong_verified');
 if aid is null then raise exception 'verified active actor identity required for consent'; end if;
 insert into sourceenergy_one.consent_receipts(consent_ref,subject_id,actor_identity_id,scope,purpose,terms_hash,evidence,expires_at,supersedes_consent_id)
 values(btrim(p_consent_ref),btrim(p_subject_id),aid,btrim(p_scope),btrim(p_purpose),p_terms_hash,coalesce(p_evidence,'{}'::jsonb),p_expires_at,p_supersedes_consent_id) returning id into cid;
 return cid;
end $$;

create or replace function sourceenergy_one.require_verified_actor(p_actor_ref text,p_subject_id text default null,p_min_assurance text default 'verified') returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare a sourceenergy_one.actor_identities%rowtype; minrank int; arank int; begin
 select * into a from sourceenergy_one.actor_identities where actor_ref=btrim(p_actor_ref) and status='active'; if not found then raise exception 'verified actor identity required'; end if;
 minrank:=case p_min_assurance when 'declared' then 1 when 'verified' then 2 when 'strong_verified' then 3 else 99 end;
 arank:=case a.assurance_level when 'declared' then 1 when 'verified' then 2 when 'strong_verified' then 3 else 0 end;
 if arank<minrank then raise exception 'actor assurance insufficient'; end if;
 if p_subject_id is not null and a.subject_id is not null and a.subject_id<>p_subject_id then raise exception 'actor subject mismatch'; end if;
 return a.id;
end $$;

create or replace function sourceenergy_one.require_active_consent(p_consent_ref text,p_subject_id text,p_required_scope text default null) returns uuid language plpgsql security definer set search_path=sourceenergy_one,pg_temp as $$ declare c sourceenergy_one.consent_receipts%rowtype; begin
 select * into c from sourceenergy_one.consent_receipts where consent_ref=btrim(p_consent_ref); if not found then raise exception 'governed consent receipt required'; end if;
 if c.subject_id<>p_subject_id then raise exception 'consent subject mismatch'; end if;
 if c.status<>'active' then raise exception 'consent receipt not active'; end if;
 if c.expires_at is not null and c.expires_at<=now() then raise exception 'consent receipt expired'; end if;
 if p_required_scope is not null and c.scope<>p_required_scope then raise exception 'consent scope mismatch'; end if;
 perform sourceenergy_one.require_verified_actor((select actor_ref from sourceenergy_one.actor_identities where id=c.actor_identity_id),p_subject_id,'verified');
 return c.id;
end $$;

create or replace function sourceenergy_one.enforce_genesis_approval_identity_consent() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ declare s text; begin
 select subject_id into s from sourceenergy_one.impact_reports where id=new.impact_report_id;
 if s is null then raise exception 'impact report required'; end if;
 perform sourceenergy_one.require_verified_actor(new.actor_ref,s,'verified');
 perform sourceenergy_one.require_active_consent(new.consent_receipt_id,s,null);
 return new;
end $$;
drop trigger if exists genesis_approval_identity_consent_trg on sourceenergy_one.genesis_approvals;
create trigger genesis_approval_identity_consent_trg before insert or update of decision,actor_ref,consent_receipt_id on sourceenergy_one.genesis_approvals for each row when (new.decision='approve') execute function sourceenergy_one.enforce_genesis_approval_identity_consent();

create or replace function sourceenergy_one.enforce_spirit_gate_review_identity() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin
 if old.status='assessed' and new.status='human_confirmed' then perform sourceenergy_one.require_verified_actor(new.human_reviewed_by_actor_ref,new.subject_id,'verified'); perform sourceenergy_one.require_active_consent(new.consent_scope_id,new.subject_id,null); end if; return new;
end $$;
drop trigger if exists spirit_gate_review_identity_trg on sourceenergy_one.spirit_gate_assessments;
create trigger spirit_gate_review_identity_trg before update on sourceenergy_one.spirit_gate_assessments for each row execute function sourceenergy_one.enforce_spirit_gate_review_identity();

create or replace function sourceenergy_one.enforce_reflection_review_identity() returns trigger language plpgsql set search_path=sourceenergy_one,pg_temp as $$ begin
 if old.human_review_status='pending' and new.human_review_status='confirmed' then perform sourceenergy_one.require_verified_actor(new.reviewed_by_actor_ref,new.subject_id,'verified'); perform sourceenergy_one.require_active_consent(new.consent_scope_id,new.subject_id,null); end if; return new;
end $$;
drop trigger if exists purpose_reflection_review_identity_trg on sourceenergy_one.purpose_reflection_syntheses;
create trigger purpose_reflection_review_identity_trg before update on sourceenergy_one.purpose_reflection_syntheses for each row execute function sourceenergy_one.enforce_reflection_review_identity();

revoke all on function sourceenergy_one.register_actor_identity(text,text,text,text,jsonb,uuid,uuid) from public,anon,authenticated;
revoke all on function sourceenergy_one.issue_consent_receipt(text,text,text,text,text,text,jsonb,timestamptz,uuid) from public,anon,authenticated;
revoke all on function sourceenergy_one.require_verified_actor(text,text,text) from public,anon,authenticated;
revoke all on function sourceenergy_one.require_active_consent(text,text,text) from public,anon,authenticated;
grant execute on function sourceenergy_one.register_actor_identity(text,text,text,text,jsonb,uuid,uuid) to service_role;
grant execute on function sourceenergy_one.issue_consent_receipt(text,text,text,text,text,text,jsonb,timestamptz,uuid) to service_role;
grant execute on function sourceenergy_one.require_verified_actor(text,text,text) to service_role;
grant execute on function sourceenergy_one.require_active_consent(text,text,text) to service_role;
comment on table sourceenergy_one.actor_identities is 'Governed actor identity registry. Consequential human confirmations require verified or strong_verified assurance.';
comment on table sourceenergy_one.consent_receipts is 'Governed consent receipt registry with subject, verified actor, scope, terms hash, status, expiry and supersession.';
