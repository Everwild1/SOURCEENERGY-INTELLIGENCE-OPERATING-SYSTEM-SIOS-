-- JLC-005: Government & Counterparty Evidence Registry
create table if not exists jlc.counterparty_evidence_registry (
 evidence_code text primary key,
 corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
 counterparty_name text not null,
 counterparty_type text not null,
 subject_reference text not null,
 artifact_title text not null,
 artifact_date date,
 source_system text not null,
 source_reference text not null,
 evidence_status text not null check(evidence_status in ('DRAFT','PROPOSAL','SUBMITTED','COORDINATED_DRAFT','COUNTERPARTY_ACKNOWLEDGED','APPROVED','EXECUTED','REJECTED','SUPERSEDED')),
 authority_effect text not null,
 activation_effect text not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table jlc.counterparty_evidence_registry enable row level security;
grant select,insert,update,delete on jlc.counterparty_evidence_registry to service_role;
revoke all on jlc.counterparty_evidence_registry from anon,authenticated;
create policy service_role_all on jlc.counterparty_evidence_registry for all to service_role using(true) with check(true);
insert into jlc.counterparty_evidence_registry(evidence_code,corridor_code,counterparty_name,counterparty_type,subject_reference,artifact_title,artifact_date,source_system,source_reference,evidence_status,authority_effect,activation_effect) values
('JLC-CP-JRC-001','JLC-001','Jamaica Railway Corporation','GOVERNMENT_ENTERPRISE','JLC-PROG-JRC-MULTIMODAL','RGL JAMAICA RAILWAY CORPORATION (JRC): Gov Brief',null,'GOOGLE_DRIVE','1x9p8ahD81_zNVxKfZJfbiMVtalWwlRNxQbbiK3ZmPuk','PROPOSAL','Supports a structured RGL/JRC PPP concept and identifies concession, JV SPV, and operating lease options; it is not itself an executed authority instrument.','Retain DILIGENCE; strengthens counterparty architecture but does not satisfy execution gate.'),
('JLC-CP-JRC-002','JLC-001','Jamaica Railway Corporation','GOVERNMENT_ENTERPRISE','JLC-PROG-JRC-MULTIMODAL','JRC Freight Rail Activation - Cabinet Briefing Note','2026-02-26','GOOGLE_DRIVE','1KGwYOVRavCZXXC0JPidW_Sc5hSnLRm5X','COORDINATED_DRAFT','Document states it was prepared by RGL in coordination with JRC and seeks Cabinet approval for a mandate; it calls for an RGL/JRC MOU after approval. This is stronger process evidence but still prospective, not proof that Cabinet approval or MOU execution occurred.','Advance JRC authority gate from EVIDENCE_IDENTIFIED to PENDING_VERIFICATION; require Cabinet approval/minute/mandate and executed MOU before SATISFIED.')
on conflict(evidence_code) do nothing;
update jlc.activation_gates set gate_state='PENDING_VERIFICATION',source_reference='DRIVE:JRC-CABINET-BRIEFING-2026-02-26',notes='Cabinet briefing note dated 2026-02-26 states it was prepared by Robert Global Logistics LLC in coordination with JRC, seeks Cabinet approval for a formal PPP mandate, and provides that upon approval JRC would execute an MOU with RGL within 30 days. This materially strengthens process/counterparty evidence but remains prospective. Gate requires evidence that Cabinet approval/mandate actually occurred and that the MOU was executed.',updated_at=now() where gate_code='JLC-GATE-JRC-001';
