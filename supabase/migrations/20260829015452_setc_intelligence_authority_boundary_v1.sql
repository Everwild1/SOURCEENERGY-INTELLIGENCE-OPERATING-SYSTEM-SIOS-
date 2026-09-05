create schema if not exists intelligence_authority;

create table if not exists intelligence_authority.authority_classes (
  authority_class text primary key,
  rank smallint not null unique,
  may_directly_authorize_mutation boolean not null default false,
  description text not null
);
insert into intelligence_authority.authority_classes(authority_class,rank,may_directly_authorize_mutation,description) values
('SOURCE',10,false,'Raw or externally sourced evidence; not itself an authorization to mutate authoritative state.'),
('LEDGER_VERIFIED',20,false,'Evidence verified against a governed ledger or authoritative source; verification is not mutation authority.'),
('DERIVED',30,false,'Analytic or transformed output derived from source evidence.'),
('MODEL_INFERRED',40,false,'Output produced by a statistical, AI, ML or agent inference.'),
('HUMAN_REVIEWED',50,false,'Artifact reviewed by an authorized human; review alone is not final mutation authority.'),
('GOVERNANCE_APPROVED',60,true,'Artifact explicitly approved under a governed authority process and eligible to support an authorized mutation.')
on conflict (authority_class) do update set rank=excluded.rank,may_directly_authorize_mutation=excluded.may_directly_authorize_mutation,description=excluded.description;

create table if not exists intelligence_authority.protected_resources (
  resource_code text primary key,
  schema_name text not null,
  table_name text not null,
  resource_domain text not null,
  protection_status text not null default 'ACTIVE',
  authority_reference text,
  unique(schema_name,table_name)
);

create table if not exists intelligence_authority.artifacts (
  artifact_id uuid primary key default gen_random_uuid(),
  artifact_type text not null,
  artifact_reference text not null,
  authority_class text not null references intelligence_authority.authority_classes(authority_class),
  source_artifact_id uuid references intelligence_authority.artifacts(artifact_id),
  model_reference text,
  provenance jsonb not null default '{}'::jsonb,
  integrity_hash text,
  created_by_reference text,
  created_at timestamptz not null default now(),
  unique(artifact_type,artifact_reference)
);

create table if not exists intelligence_authority.promotion_events (
  promotion_id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null references intelligence_authority.artifacts(artifact_id),
  from_authority_class text not null references intelligence_authority.authority_classes(authority_class),
  to_authority_class text not null references intelligence_authority.authority_classes(authority_class),
  decision text not null check (decision in ('APPROVE','REJECT')),
  authority_reference text not null,
  approver_reference text not null,
  rationale text not null,
  evidence jsonb not null default '{}'::jsonb,
  decided_at timestamptz not null default now()
);

create table if not exists intelligence_authority.mutation_authorizations (
  authorization_id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null references intelligence_authority.artifacts(artifact_id),
  promotion_id uuid not null references intelligence_authority.promotion_events(promotion_id),
  resource_code text not null references intelligence_authority.protected_resources(resource_code),
  operation text not null check (operation in ('INSERT','UPDATE','DELETE','EXECUTE')),
  target_reference text,
  authorization_status text not null default 'ACTIVE' check (authorization_status in ('ACTIVE','USED','REVOKED','EXPIRED')),
  expires_at timestamptz not null default (now() + interval '1 hour'),
  created_at timestamptz not null default now()
);

create table if not exists intelligence_authority.enforcement_events (
  enforcement_event_id uuid primary key default gen_random_uuid(),
  artifact_id uuid references intelligence_authority.artifacts(artifact_id),
  resource_code text references intelligence_authority.protected_resources(resource_code),
  operation text not null,
  outcome text not null check (outcome in ('ALLOWED','DENIED')),
  reason text not null,
  authorization_id uuid references intelligence_authority.mutation_authorizations(authorization_id),
  occurred_at timestamptz not null default now()
);

create or replace function intelligence_authority.promote_artifact(
  p_artifact_id uuid,
  p_to_authority_class text,
  p_decision text,
  p_authority_reference text,
  p_approver_reference text,
  p_rationale text,
  p_evidence jsonb default '{}'::jsonb
) returns uuid language plpgsql set search_path='' as $$
declare v_from text; v_from_rank smallint; v_to_rank smallint; v_promotion uuid;
begin
  select a.authority_class,c.rank into v_from,v_from_rank from intelligence_authority.artifacts a join intelligence_authority.authority_classes c on c.authority_class=a.authority_class where a.artifact_id=p_artifact_id for update;
  if not found then raise exception 'Authority promotion denied: artifact not found'; end if;
  select rank into v_to_rank from intelligence_authority.authority_classes where authority_class=p_to_authority_class;
  if v_to_rank is null then raise exception 'Authority promotion denied: unknown authority class'; end if;
  if p_decision not in ('APPROVE','REJECT') then raise exception 'Authority promotion denied: invalid decision'; end if;
  if p_decision='APPROVE' and v_to_rank <= v_from_rank then raise exception 'Authority promotion denied: target class must be higher than current class'; end if;
  insert into intelligence_authority.promotion_events(artifact_id,from_authority_class,to_authority_class,decision,authority_reference,approver_reference,rationale,evidence)
  values(p_artifact_id,v_from,p_to_authority_class,p_decision,p_authority_reference,p_approver_reference,p_rationale,coalesce(p_evidence,'{}'::jsonb)) returning promotion_id into v_promotion;
  if p_decision='APPROVE' then update intelligence_authority.artifacts set authority_class=p_to_authority_class where artifact_id=p_artifact_id; end if;
  return v_promotion;
end $$;

create or replace function intelligence_authority.authorize_mutation(
  p_artifact_id uuid,
  p_promotion_id uuid,
  p_resource_code text,
  p_operation text,
  p_target_reference text default null,
  p_ttl interval default interval '1 hour'
) returns uuid language plpgsql set search_path='' as $$
declare v_class text; v_allowed boolean; v_promo intelligence_authority.promotion_events%rowtype; v_auth uuid;
begin
  select a.authority_class,c.may_directly_authorize_mutation into v_class,v_allowed from intelligence_authority.artifacts a join intelligence_authority.authority_classes c on c.authority_class=a.authority_class where a.artifact_id=p_artifact_id;
  if not found then raise exception 'Mutation authorization denied: artifact not found'; end if;
  if not v_allowed or v_class <> 'GOVERNANCE_APPROVED' then raise exception 'Mutation authorization denied: artifact is not GOVERNANCE_APPROVED'; end if;
  select * into v_promo from intelligence_authority.promotion_events where promotion_id=p_promotion_id and artifact_id=p_artifact_id and decision='APPROVE' and to_authority_class='GOVERNANCE_APPROVED';
  if not found then raise exception 'Mutation authorization denied: valid governance promotion not found'; end if;
  if p_operation not in ('INSERT','UPDATE','DELETE','EXECUTE') then raise exception 'Mutation authorization denied: invalid operation'; end if;
  if p_ttl <= interval '0 seconds' or p_ttl > interval '1 hour' then raise exception 'Mutation authorization denied: TTL must be greater than zero and no more than one hour'; end if;
  perform 1 from intelligence_authority.protected_resources where resource_code=p_resource_code and protection_status='ACTIVE';
  if not found then raise exception 'Mutation authorization denied: protected resource not active'; end if;
  insert into intelligence_authority.mutation_authorizations(artifact_id,promotion_id,resource_code,operation,target_reference,expires_at)
  values(p_artifact_id,p_promotion_id,p_resource_code,p_operation,p_target_reference,now()+p_ttl) returning authorization_id into v_auth;
  return v_auth;
end $$;

create or replace function intelligence_authority.enforce_mutation(
  p_artifact_id uuid,
  p_resource_code text,
  p_operation text,
  p_target_reference text default null,
  p_authorization_id uuid default null
) returns boolean language plpgsql set search_path='' as $$
declare v_class text; v_auth intelligence_authority.mutation_authorizations%rowtype;
begin
  select authority_class into v_class from intelligence_authority.artifacts where artifact_id=p_artifact_id;
  if not found then raise exception 'Authority boundary denied: artifact not found'; end if;
  if v_class in ('DERIVED','MODEL_INFERRED','SOURCE','LEDGER_VERIFIED','HUMAN_REVIEWED') then
    insert into intelligence_authority.enforcement_events(artifact_id,resource_code,operation,outcome,reason,authorization_id) values(p_artifact_id,p_resource_code,p_operation,'DENIED','Artifact authority class cannot directly mutate authoritative state',p_authorization_id);
    return false;
  end if;
  select * into v_auth from intelligence_authority.mutation_authorizations where authorization_id=p_authorization_id and artifact_id=p_artifact_id and resource_code=p_resource_code and operation=p_operation and authorization_status='ACTIVE' and expires_at>now() for update;
  if not found then
    insert into intelligence_authority.enforcement_events(artifact_id,resource_code,operation,outcome,reason,authorization_id) values(p_artifact_id,p_resource_code,p_operation,'DENIED','No active mutation authorization matches artifact, resource and operation',p_authorization_id);
    return false;
  end if;
  if v_auth.target_reference is not null and v_auth.target_reference is distinct from p_target_reference then
    insert into intelligence_authority.enforcement_events(artifact_id,resource_code,operation,outcome,reason,authorization_id) values(p_artifact_id,p_resource_code,p_operation,'DENIED','Target reference mismatch',p_authorization_id);
    return false;
  end if;
  update intelligence_authority.mutation_authorizations set authorization_status='USED' where authorization_id=p_authorization_id;
  insert into intelligence_authority.enforcement_events(artifact_id,resource_code,operation,outcome,reason,authorization_id) values(p_artifact_id,p_resource_code,p_operation,'ALLOWED','Governance-approved artifact and active mutation authorization verified',p_authorization_id);
  return true;
end $$;

insert into intelligence_authority.protected_resources(resource_code,schema_name,table_name,resource_domain,authority_reference) values
('SETC_ORGANIZATIONS','public','setc_organizations','IDENTITY_ORGANIZATION','SETC authority boundary v1'),
('ENERGY_EXECUTIVE_DECISIONS','energy','executive_decision_cases','EXECUTIVE_DECISION','SETC authority boundary v1'),
('AI_EXECUTION_GRANTS','ai_governance','execution_grants','AI_EXECUTION','SETC authority boundary v1')
on conflict(resource_code) do update set protection_status='ACTIVE',authority_reference=excluded.authority_reference;

comment on schema intelligence_authority is 'SETC Intelligence Authority Boundary: separates derived/model-inferred intelligence from authoritative state mutation through governed promotion and scoped mutation authorization.';
comment on function intelligence_authority.enforce_mutation(uuid,text,text,text,uuid) is 'Control-plane enforcement function. Domain writers must invoke this gate or a bound trigger before protected mutations; registration alone does not retrofit existing tables.';
