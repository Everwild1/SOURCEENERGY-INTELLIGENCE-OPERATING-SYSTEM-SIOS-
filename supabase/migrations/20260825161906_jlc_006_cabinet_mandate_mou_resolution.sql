create table if not exists jlc.authority_resolution_requirements (
  requirement_code text primary key,
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  subject_reference text not null,
  requirement_type text not null check (requirement_type in ('CABINET_APPROVAL','MINISTERIAL_MANDATE','JRC_BOARD_AUTHORIZATION','EXECUTED_MOU','PPP_UNIT_ACKNOWLEDGEMENT','LEGAL_OPINION','OTHER')),
  description text not null,
  resolution_state text not null default 'MISSING' check (resolution_state in ('MISSING','LOCATED_UNVERIFIED','VERIFIED','NOT_REQUIRED','REJECTED','SUPERSEDED')),
  source_system text,
  source_reference text,
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table jlc.authority_resolution_requirements enable row level security;
grant select,insert,update,delete on jlc.authority_resolution_requirements to service_role;
revoke all on jlc.authority_resolution_requirements from anon,authenticated;
create policy service_role_all on jlc.authority_resolution_requirements for all to service_role using(true) with check(true);

insert into jlc.authority_resolution_requirements(requirement_code,corridor_code,subject_reference,requirement_type,description,resolution_state,source_system,source_reference,notes) values
('JLC-AUTH-CABINET-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','CABINET_APPROVAL','Cabinet approval, minute, decision, memorandum endorsement, or equivalent evidence authorizing the Phase I freight rail PPP mandate.','MISSING','GOOGLE_DRIVE',null,'Targeted Drive search on 2026-08-25 found the Cabinet briefing note seeking approval but no subsequent Cabinet approval/minute/decision artifact.'),
('JLC-AUTH-JRC-BOARD-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','JRC_BOARD_AUTHORIZATION','JRC board resolution, board minute, chairman/authorized officer approval, or equivalent authority approving negotiations/PPP structuring with RGL.','MISSING','GOOGLE_DRIVE',null,'Targeted Drive search on 2026-08-25 found no JRC board resolution or board authorization artifact.'),
('JLC-AUTH-MOU-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','EXECUTED_MOU','Executed memorandum of understanding between Jamaica Railway Corporation and Robert Global Logistics LLC, or equivalent signed instrument establishing the agreed feasibility/PPP structuring relationship.','MISSING','GOOGLE_DRIVE',null,'Drive search found only prospective references stating that an MOU would be executed after approval; no executed/signed MOU surfaced.'),
('JLC-AUTH-MINISTRY-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','MINISTERIAL_MANDATE','Ministerial mandate, letter, instruction, or approved communication authorizing JRC/Ministry participation in the Phase I freight rail PPP process.','MISSING','GOOGLE_DRIVE',null,'No separate ministerial mandate surfaced in targeted Drive searches.'),
('JLC-AUTH-PPPUNIT-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','PPP_UNIT_ACKNOWLEDGEMENT','PPP Unit acknowledgement, screening, transaction-development authorization, or equivalent process evidence.','MISSING','GOOGLE_DRIVE',null,'No PPP Unit acknowledgement or transaction authorization surfaced in targeted Drive searches.')
on conflict(requirement_code) do nothing;

update jlc.activation_gates
set gate_state='PENDING_VERIFICATION',
    notes='JLC-006 resolution search completed against the accessible Drive corpus. The 2026-02-26 Cabinet briefing note remains the strongest process artifact, but no Cabinet approval/minute, JRC board authorization, executed RGL-JRC MOU, ministerial mandate, or PPP Unit acknowledgement was located. Gate remains PENDING_VERIFICATION until one or more authoritative execution instruments are produced and validated.',
    updated_at=now()
where gate_code='JLC-GATE-JRC-001';
