create table if not exists jlc.market_evidence (
 evidence_code text primary key,
 corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
 segment_code text references jlc.commercial_demand_segments(segment_code) on delete set null,
 source_agency text not null,
 source_title text not null,
 source_url text not null,
 observation_period text not null,
 metric_name text not null,
 metric_value numeric,
 metric_unit text,
 evidence_class text not null check(evidence_class in ('OFFICIAL_STATISTIC','PORT_STATISTIC','AVIATION_STATISTIC','MARKET_STUDY','CUSTOMER_DISCOVERY','LOI','CONTRACT')),
 validation_status text not null check(validation_status in ('VERIFIED','PARTIAL','PENDING','REJECTED')),
 notes text,
 captured_at timestamptz not null default now()
);
alter table jlc.market_evidence enable row level security;
grant select,insert,update,delete on jlc.market_evidence to service_role;
revoke all on jlc.market_evidence from anon,authenticated;
create policy service_role_all on jlc.market_evidence for all to service_role using(true) with check(true);
insert into jlc.market_evidence(evidence_code,corridor_code,segment_code,source_agency,source_title,source_url,observation_period,metric_name,metric_value,metric_unit,evidence_class,validation_status,notes) values
('JLC-ME-STATIN-2026-IM-APR','JLC-001',null,'Statistical Institute of Jamaica (STATIN)','International Merchandise Trade Jan-Apr 2026','https://statinja.gov.jm/PressReleases.aspx?field1=trade','2026-01 through 2026-04','Total imports',2502.4,'USD million','OFFICIAL_STATISTIC','VERIFIED','Official national trade aggregate. Establishes macro freight-market scale but does not establish rail-addressable tonnage or customer commitment.'),
('JLC-ME-STATIN-2026-IM-APR-EXP','JLC-001',null,'Statistical Institute of Jamaica (STATIN)','International Merchandise Trade Jan-Apr 2026','https://statinja.gov.jm/','2026-04','Monthly exports',159.5,'USD million','OFFICIAL_STATISTIC','VERIFIED','STATIN key indicator for April 2026. Do not interpret as segment-level or contracted logistics demand.'),
('JLC-ME-STATIN-2026-IM-APR-IMP','JLC-001',null,'Statistical Institute of Jamaica (STATIN)','International Merchandise Trade Jan-Apr 2026','https://statinja.gov.jm/','2026-04','Monthly imports',632.5,'USD million','OFFICIAL_STATISTIC','VERIFIED','STATIN key indicator for April 2026. Do not interpret as segment-level or contracted logistics demand.')
on conflict(evidence_code) do nothing;
update jlc.transaction_readiness set evidence_reference='STATIN:IMTS-2026-JAN-APR;DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO',notes='JLC-009 external validation initiated. Official STATIN trade aggregates now establish macro merchandise-flow scale. Segment-level tonnage, origin-destination flows, modal economics and anchor-customer commitments remain pending.',updated_at=now() where readiness_code='JLC-TR-COMM-001';
