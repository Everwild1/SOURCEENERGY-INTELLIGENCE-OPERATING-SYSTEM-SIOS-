create table if not exists jlc.transaction_readiness (
 readiness_code text primary key,
 corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
 subject_reference text not null,
 workstream text not null check(workstream in ('AUTHORITY','LEGAL','TECHNICAL','COMMERCIAL','FINANCIAL','ESG','PROCUREMENT','OPERATIONS')),
 deliverable text not null,
 readiness_state text not null default 'NOT_STARTED' check(readiness_state in ('NOT_STARTED','IN_PROGRESS','EVIDENCE_READY','VERIFIED','BLOCKED','NOT_REQUIRED')),
 dependency_reference text,
 evidence_reference text,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table jlc.transaction_readiness enable row level security;
grant select,insert,update,delete on jlc.transaction_readiness to service_role;
revoke all on jlc.transaction_readiness from anon,authenticated;
create policy service_role_all on jlc.transaction_readiness for all to service_role using(true) with check(true);
insert into jlc.transaction_readiness(readiness_code,corridor_code,subject_reference,workstream,deliverable,readiness_state,dependency_reference,notes) values
('JLC-TR-AUTH-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','AUTHORITY','Cabinet/ministerial/JRC authority package','BLOCKED','JLC-GATE-JRC-001','Blocked pending authoritative execution evidence tracked in JLC-006.'),
('JLC-TR-LEGAL-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','LEGAL','PPP/MOU/concession legal structure and Jamaican counsel validation','NOT_STARTED','JLC-TR-AUTH-001','Prepare structure without representing execution authority; finalization depends on verified mandate.'),
('JLC-TR-TECH-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','TECHNICAL','Phase I rail asset condition, route, terminal, capacity and rehabilitation baseline','NOT_STARTED','JLC-GATE-RAIL-ASSETS-001','Requires authoritative rail asset and spatial evidence.'),
('JLC-TR-COMM-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','COMMERCIAL','Anchor cargo, shipper/offtaker pipeline and volume assumptions','NOT_STARTED',null,'Can progress during diligence without implying government authorization.'),
('JLC-TR-FIN-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','FINANCIAL','Bankable base-case model, capex/opex, tariff, DSCR and sensitivity framework','NOT_STARTED','JLC-TR-TECH-001','Model may begin with assumptions but bankability requires technical baseline.'),
('JLC-TR-ESG-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','ESG','Environmental, social, land/right-of-way and stakeholder diligence framework','NOT_STARTED',null,'Establish diligence framework before project activation.'),
('JLC-TR-PROC-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','PROCUREMENT','Jamaica PPP/procurement pathway and approvals matrix','IN_PROGRESS','JLC-TR-AUTH-001','Cabinet briefing identifies a contemplated PPP mandate; authoritative pathway still requires verification.'),
('JLC-TR-OPS-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','OPERATIONS','RGL operating concept, multimodal interfaces, staffing, safety and service-level framework','IN_PROGRESS',null,'Existing Drive master plan supports concept development; operational authority remains gated.')
on conflict(readiness_code) do nothing;
