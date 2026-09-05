create table if not exists ecology.ssr_anchor_candidate_registry (
  id uuid primary key default gen_random_uuid(),
  source_schema text not null,
  source_object text not null,
  source_record_id text not null,
  entity_id text,
  infrastructure_name text,
  infrastructure_type text,
  jurisdiction_code text,
  latitude double precision,
  longitude double precision,
  source_reference text,
  source_verification_status text,
  source_reconciliation_status text,
  authority_code text not null references ecology.ssr_authority_registry(authority_code),
  w3w_address text,
  z_index integer,
  canonical_address text,
  cube_uid text,
  canonicalization_status text not null default 'awaiting_w3w' check (canonicalization_status in ('awaiting_w3w','awaiting_z_assignment','ready_for_hash','hash_generated','evidence_review','promotion_ready','promoted','rejected')),
  promotion_eligible boolean not null default false,
  blocker_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_schema,source_object,source_record_id),
  check (z_index is null or (z_index between -1000 and 1000)),
  check (w3w_address is null or w3w_address ~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+$'),
  check (canonical_address is null or canonical_address ~ '^///[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9-]+@Z[+-][0-9]{4}$'),
  check (cube_uid is null or cube_uid ~ '^[0-9a-f]{64}$')
);
alter table ecology.ssr_anchor_candidate_registry enable row level security;
create policy ssr_anchor_candidate_registry_service_role_all on ecology.ssr_anchor_candidate_registry for all to service_role using (true) with check (true);

create table if not exists ecology.ssr_canonicalization_requirements (
  requirement_code text primary key,
  sequence_no integer not null unique,
  requirement_name text not null,
  requirement_description text not null,
  evidence_rule text not null,
  blocking boolean not null default true,
  created_at timestamptz not null default now()
);
alter table ecology.ssr_canonicalization_requirements enable row level security;
create policy ssr_canonicalization_requirements_service_role_all on ecology.ssr_canonicalization_requirements for all to service_role using (true) with check (true);

insert into ecology.ssr_canonicalization_requirements(requirement_code,sequence_no,requirement_name,requirement_description,evidence_rule,blocking) values
('SSR-CAN-01',1,'Source Location Evidence','Source record identifies the physical infrastructure candidate and coordinates with traceable evidence.','Candidate status alone does not prove authoritative SSR registration; evidence must remain traceable to the source record.',true),
('SSR-CAN-02',2,'Canonical Surface Address','Resolve the exact What3Words-style canonical surface address used by the SSR AnchorTile contract.','Do not infer or fabricate ///three.words from latitude/longitude. Exact canonical value must come from an authorized resolver or authoritative source evidence.',true),
('SSR-CAN-03',3,'Z Index Assignment','Assign an SSR Z-index in the permitted -1000..1000 range.','The vertical assignment must reflect the governed use case and must not be invented solely to complete registration.',true),
('SSR-CAN-04',4,'Canonical String Validation','Construct and validate ///three.words@Z±NNNN exactly against the SSR canonical addressing contract.','Canonical representation must pass the database format contract before hashing.',true),
('SSR-CAN-05',5,'Deterministic Cube UID','Generate SHA-256 of the exact canonical address string.','Hash generation is deterministic only after the canonical string is authoritative; never hash a placeholder.',true),
('SSR-CAN-06',6,'Authority and Evidence Review','Confirm source authority, jurisdiction metadata, evidence lineage, and any conflicts or restrictions.','Internal Codex authority does not create external title, jurisdiction, permit, regulatory, sovereign, or operating authority.',true),
('SSR-CAN-07',7,'Registry Promotion','Promote only an approved candidate into AnchorTile, Cube, and SSR registry records under controlled service-role execution.','Promotion requires all blocking requirements complete and a documented authoritative-match decision.',true)
on conflict(requirement_code) do update set requirement_name=excluded.requirement_name,requirement_description=excluded.requirement_description,evidence_rule=excluded.evidence_rule,blocking=excluded.blocking;

insert into ecology.ssr_anchor_candidate_registry(
  source_schema,source_object,source_record_id,entity_id,infrastructure_name,infrastructure_type,jurisdiction_code,latitude,longitude,
  source_reference,source_verification_status,source_reconciliation_status,authority_code,canonicalization_status,promotion_eligible,blocker_reason
)
select 'rgl','spatial_registry_links',l.id::text,l.entity_id::text,n.name,n.node_type,l.jurisdiction_code,l.latitude,l.longitude,
       l.source_reference,l.verification_status,l.reconciliation_status,'SSR-411','awaiting_w3w',false,
       'Exact canonical ///three.words value is not present in the reviewed SourceEnergy evidence. Do not fabricate or derive a W3W address from coordinates without an authorized resolver/source.'
from rgl.spatial_registry_links l
left join rgl.infrastructure_nodes n on n.id=l.entity_id
on conflict(source_schema,source_object,source_record_id) do update set
  entity_id=excluded.entity_id,
  infrastructure_name=excluded.infrastructure_name,
  infrastructure_type=excluded.infrastructure_type,
  jurisdiction_code=excluded.jurisdiction_code,
  latitude=excluded.latitude,
  longitude=excluded.longitude,
  source_reference=excluded.source_reference,
  source_verification_status=excluded.source_verification_status,
  source_reconciliation_status=excluded.source_reconciliation_status,
  updated_at=now();

create table if not exists ecology.ssr_candidate_requirement_status (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references ecology.ssr_anchor_candidate_registry(id) on delete cascade,
  requirement_code text not null references ecology.ssr_canonicalization_requirements(requirement_code),
  status text not null default 'not_satisfied' check(status in ('not_satisfied','pending_review','satisfied_reference','blocked','not_applicable')),
  evidence_reference text,
  notes text,
  updated_at timestamptz not null default now(),
  unique(candidate_id,requirement_code)
);
alter table ecology.ssr_candidate_requirement_status enable row level security;
create policy ssr_candidate_requirement_status_service_role_all on ecology.ssr_candidate_requirement_status for all to service_role using (true) with check (true);

insert into ecology.ssr_candidate_requirement_status(candidate_id,requirement_code,status,evidence_reference,notes)
select c.id,r.requirement_code,
       case when r.requirement_code='SSR-CAN-01' then 'pending_review'
            when r.requirement_code='SSR-CAN-02' then 'blocked'
            else 'not_satisfied' end,
       case when r.requirement_code='SSR-CAN-01' then c.source_reference else null end,
       case when r.requirement_code='SSR-CAN-01' then 'Traceable source reference exists, but RGL source record remains pending/needs_review.'
            when r.requirement_code='SSR-CAN-02' then 'Blocked because exact canonical W3W-style surface address has not been found in reviewed SourceEnergy evidence.'
            else null end
from ecology.ssr_anchor_candidate_registry c cross join ecology.ssr_canonicalization_requirements r
on conflict(candidate_id,requirement_code) do update set status=excluded.status,evidence_reference=excluded.evidence_reference,notes=excluded.notes,updated_at=now();

create or replace view ecology.ssr_promotion_readiness as
with s as (
  select c.id,c.infrastructure_name,c.infrastructure_type,c.jurisdiction_code,c.latitude,c.longitude,c.canonicalization_status,c.promotion_eligible,
         count(*) filter(where r.blocking) as blocking_requirements,
         count(*) filter(where r.blocking and st.status='satisfied_reference') as satisfied_blocking_requirements,
         count(*) filter(where st.status='blocked') as blocked_requirements,
         string_agg(r.requirement_code || ':' || st.status, ', ' order by r.sequence_no) as requirement_state
  from ecology.ssr_anchor_candidate_registry c
  join ecology.ssr_candidate_requirement_status st on st.candidate_id=c.id
  join ecology.ssr_canonicalization_requirements r on r.requirement_code=st.requirement_code
  group by c.id,c.infrastructure_name,c.infrastructure_type,c.jurisdiction_code,c.latitude,c.longitude,c.canonicalization_status,c.promotion_eligible
)
select *, case when blocking_requirements=satisfied_blocking_requirements and blocked_requirements=0 and promotion_eligible then 'promotion_ready' else 'not_ready' end as readiness
from s;

insert into public.codex_registry(scroll_id,name,layer,dominion_cube,status,function,codex_group,priority)
values('411','SourceEnergy Spatial Registry','Spatial Governance',null,'ACTIVE','Internal SourceEnergy spatial registry governance authority and canonical addressing reference; does not confer external sovereign, regulatory, title, permit, or operating authority.','Book IX — Spatial Governance','HIGH')
on conflict(scroll_id) do update set name=excluded.name,layer=excluded.layer,status=excluded.status,function=excluded.function,codex_group=excluded.codex_group,priority=excluded.priority;

