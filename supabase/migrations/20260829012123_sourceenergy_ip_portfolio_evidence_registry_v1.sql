create table if not exists sourcecubes.portfolio_evidence_registry (
  evidence_id text primary key,
  portfolio_class text not null,
  asset_or_family text not null,
  source_system text not null,
  source_reference text not null,
  evidence_status text not null,
  ownership_status text not null,
  filing_or_rights_status text not null,
  counts_toward_legacy_49 boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into sourcecubes.portfolio_evidence_registry(evidence_id,portfolio_class,asset_or_family,source_system,source_reference,evidence_status,ownership_status,filing_or_rights_status,counts_toward_legacy_49,notes) values
('IP-EV-001','INTERNAL_INVENTION_REGISTRY','IP Blockchain Matrix — 45 registered invention elements / 12 patent families','Google Drive','IP_Blockchain_Matrix_IP_Filing_Readiness_Registry_v2.xlsx','DOCUMENTED','OWNERSHIP_REVIEW_OPEN','FIRST_FILING_NOT_YET_FILED',false,'Authoritative planning artifact identifies 45 invention elements, 12 families, 24 claim concepts; do not treat as 45 filed patents.'),
('IP-EV-002','WEM_ORIGINATED_IP','Wealth Ecology Model','Dropbox','SEC UNITED STATES PATENT AND TRADEMARK OFFICE.pdf','DOCUMENTED_DOSSIER','CHAIN_OF_TITLE_TO_VALIDATE','DOCUMENT_LABELS_ITSELF_PATENT_APPLICATION_2023',false,'Dossier supports a separate WEM invention/application evidence stream; official filing evidence remains to be reconciled.'),
('IP-EV-003','AFFILIATE_OR_THIRD_PARTY_ISSUED_PATENTS','Larry Williams historical patent schedule','Dropbox','Larry Williams Patents.docx','DOCUMENTED_SCHEDULE','NOT_ESTABLISHED_AS_SOURCEENERGY_OWNED','ISSUED_PATENT_NUMBERS_LISTED_IN_SOURCE',false,'Historical schedule contains issued patents but assignment/license/affiliate rights to SourceEnergy Technologies are not established by this source alone.'),
('IP-EV-004','THIRD_PARTY_TECHNOLOGY_TRANSFER','VoltX / NASA MSC-TOPS-35 and MSC-TOPS-40','Dropbox','VoltXNASA Patents.pdf','DOCUMENTED_COMMERCIALIZATION_PLAN','NASA_OR_THIRD_PARTY_RIGHTS','LICENSE_OR_TECH_TRANSFER_REQUIRED',false,'Treat as technology-rights candidates, not SourceEnergy-owned patents absent executed NASA license/transfer evidence.'),
('IP-EV-005','SOURCECUBES_CANDIDATE','SourceCubes™','Google Drive / Supabase','SourceEnergy Technologies — SourceCubes IP Assignment & Patent Pipeline Update — v1.0; SC-PAT-050','CONTROLLED','GOVERNANCE_ASSIGNED_TO_SOURCEENERGY_TECHNOLOGIES_PENDING_PERFECTION','CANDIDATE_PENDING_FORMAL_ASSESSMENT_AND_EVIDENCE',false,'Pipeline position 50 is controlled separately from the unresolved composition of the legacy 49.')
on conflict (evidence_id) do update set
 portfolio_class=excluded.portfolio_class,
 asset_or_family=excluded.asset_or_family,
 source_system=excluded.source_system,
 source_reference=excluded.source_reference,
 evidence_status=excluded.evidence_status,
 ownership_status=excluded.ownership_status,
 filing_or_rights_status=excluded.filing_or_rights_status,
 counts_toward_legacy_49=excluded.counts_toward_legacy_49,
 notes=excluded.notes,
 updated_at=now();

create table if not exists sourcecubes.legacy_49_reconciliation (
  slot_no integer primary key check (slot_no between 1 and 49),
  slot_id text generated always as ('SC-PAT-' || lpad(slot_no::text,3,'0')) stored,
  reconciled_asset text,
  evidence_id text references sourcecubes.portfolio_evidence_registry(evidence_id),
  reconciliation_status text not null default 'UNRESOLVED',
  legal_status text not null default 'NOT_ESTABLISHED',
  notes text,
  updated_at timestamptz not null default now()
);

insert into sourcecubes.legacy_49_reconciliation(slot_no)
select g from generate_series(1,49) g
on conflict (slot_no) do nothing;

comment on table sourcecubes.legacy_49_reconciliation is 'Controlled 49-slot legacy patent-pipeline reconciliation. Slots remain unresolved until evidence supports identity, ownership/rights basis, and filing/legal status.';
