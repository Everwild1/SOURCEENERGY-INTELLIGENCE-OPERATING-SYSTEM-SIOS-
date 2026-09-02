create table if not exists sourcecubes.patent_pipeline_control (
  pipeline_record_id text primary key,
  ip_record_id uuid references sourcecubes.ip_governance(ip_record_id) on delete restrict,
  asset_name text not null,
  preexisting_pipeline_count integer not null check (preexisting_pipeline_count >= 0),
  pipeline_position integer not null check (pipeline_position > 0),
  working_pipeline_count integer not null check (working_pipeline_count >= preexisting_pipeline_count),
  pipeline_status text not null,
  legal_status_boundary text not null,
  governance_reference text,
  drive_document_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into sourcecubes.patent_pipeline_control (
 pipeline_record_id, ip_record_id, asset_name, preexisting_pipeline_count,
 pipeline_position, working_pipeline_count, pipeline_status,
 legal_status_boundary, governance_reference, drive_document_id
)
select
 'SC-PAT-050', ip_record_id, 'SourceCubes™', 49, 50, 50,
 'CANDIDATE_PENDING_FORMAL_ASSESSMENT_AND_EVIDENCE',
 'Pipeline position does not establish a patent application, publication, allowance, grant, inventorship, patentability, or legal ownership.',
 'SETC-091; SC-SSR-001; SC-IP governance record',
 '1QZzcFZg4J9gUGrCWEo0qIeowR9WRh6D9dBFk4eSFDog'
from sourcecubes.ip_governance
where asset_name = 'SourceCubes™'
order by created_at desc
limit 1
on conflict (pipeline_record_id) do update set
 preexisting_pipeline_count=excluded.preexisting_pipeline_count,
 pipeline_position=excluded.pipeline_position,
 working_pipeline_count=excluded.working_pipeline_count,
 pipeline_status=excluded.pipeline_status,
 legal_status_boundary=excluded.legal_status_boundary,
 governance_reference=excluded.governance_reference,
 drive_document_id=excluded.drive_document_id,
 updated_at=now();

comment on table sourcecubes.patent_pipeline_control is 'Governed patent-development pipeline positioning. Counts are portfolio workflow metrics, not counts of granted patents.';
