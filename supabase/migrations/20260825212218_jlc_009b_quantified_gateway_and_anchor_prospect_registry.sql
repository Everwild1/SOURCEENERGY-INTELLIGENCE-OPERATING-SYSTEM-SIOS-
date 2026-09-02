create table if not exists jlc.anchor_customer_prospects (
  prospect_code text primary key,
  corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
  segment_code text references jlc.commercial_demand_segments(segment_code) on delete set null,
  organization_name text not null,
  prospect_role text not null,
  prospect_status text not null default 'IDENTIFIED' check (prospect_status in ('IDENTIFIED','RESEARCHED','OUTREACH_READY','CONTACTED','QUALIFIED','LOI','CONTRACTED','DECLINED','ARCHIVED')),
  evidence_reference text,
  rationale text not null,
  next_validation_step text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table jlc.anchor_customer_prospects enable row level security;
grant select,insert,update,delete on jlc.anchor_customer_prospects to service_role;
revoke all on jlc.anchor_customer_prospects from anon,authenticated;
create policy service_role_all on jlc.anchor_customer_prospects for all to service_role using(true) with check(true);

insert into jlc.market_evidence(evidence_code,corridor_code,segment_code,source_agency,source_title,source_url,observation_period,metric_name,metric_value,metric_unit,evidence_class,validation_status,notes) values
('JLC-ME-KFTL-CAP-001','JLC-001','JLC-CDS-CONTAINER-001','Kingston Freeport Terminal Limited','Port Development','Current published terminal profile','CURRENT PROFILE','Rated container terminal capacity',3.6,'million TEU','PORT_STATISTIC','VERIFIED','Published terminal capacity. This is infrastructure capacity, not actual annual throughput or RGL-addressable demand.'),
('JLC-ME-NMIA-AIR-001','JLC-001','JLC-CDS-AIR-001','Norman Manley International Airport','Airport Profile','https://nmia.aero/about/airport-profile/','CURRENT PROFILE','Airfreight handled',17.0,'million kg','AVIATION_STATISTIC','VERIFIED','NMIA states it handles over 70% of Jamaica airfreight, approximately 17 million kg. Treat as airport-level market indicator, not customer commitment.'),
('JLC-ME-WISYNCO-WH-001','JLC-001','JLC-CDS-CONSUMER-001','Wisynco Group Limited','2025 Annual Report','https://wisynco.com/wp-content/uploads/2025/11/Wisynco-Annual-Report-2025.pdf','FY2025','Primary warehouse footprint',500000,'square feet','MARKET_STUDY','VERIFIED','Company-reported logistics footprint in St. Catherine; useful for prospect qualification, not evidence of outsourced logistics demand.'),
('JLC-ME-WISYNCO-FLEET-001','JLC-001','JLC-CDS-CONSUMER-001','Wisynco Group Limited','2025 Annual Report','https://wisynco.com/wp-content/uploads/2025/11/Wisynco-Annual-Report-2025.pdf','FY2025','Distribution truck fleet',600,'trucks','MARKET_STUDY','VERIFIED','Company-reported fleet scale indicates a major national distribution footprint; no inference of willingness to outsource logistics.')
on conflict(evidence_code) do nothing;

insert into jlc.anchor_customer_prospects(prospect_code,corridor_code,segment_code,organization_name,prospect_role,prospect_status,evidence_reference,rationale,next_validation_step) values
('JLC-PROS-WISYNCO-001','JLC-001','JLC-CDS-CONSUMER-001','Wisynco Group Limited','NATIONAL_DISTRIBUTOR_AND_MANUFACTURER','RESEARCHED','WISYNCO:AR2025','Large national distribution footprint with approximately 500,000 square feet of warehouse capacity, over 600 trucks, and more than 12,000 direct customers. Relevant to intermodal, warehousing and western-island distribution economics.','Establish logistics/procurement decision-maker contact, confirm current lane economics, outsourced-carrier usage, container volumes, western distribution requirements and rail/intermodal interest.'),
('JLC-PROS-GK-001','JLC-001','JLC-CDS-MFG-001','GraceKennedy Limited / GK Foods Jamaica','FOOD_MANUFACTURER_DISTRIBUTOR_EXPORTER','RESEARCHED','GRACEKENNEDY:AR2023','Operates multiple Jamaica food manufacturing facilities plus sales/distribution businesses and international food channels, making it relevant to container, cold-chain, manufacturing-input and export logistics.','Validate plant-level inbound/outbound tonnage, container flows, export destinations, cold-chain needs, current logistics providers and appetite for multimodal consolidation.'),
('JLC-PROS-CARIBCEM-001','JLC-001','JLC-CDS-BUILD-001','Caribbean Cement Company Limited','BULK_INDUSTRIAL_SHIPPER','RESEARCHED','CARIBCEMENT:AR2025','Major Jamaica cement producer with an industrial bulk-freight profile and regional export relevance; candidate for heavy-haul and industrial-spur economics.','Confirm annual inbound raw-material and outbound cement/clinker tonnage, origin-destination lanes, current road/port movement costs, siding feasibility and decision-maker interest.'),
('JLC-PROS-RAINFOREST-001','JLC-001','JLC-CDS-AGRI-001','Rainforest Seafoods','COLD_CHAIN_FOOD_DISTRIBUTOR','IDENTIFIED','MBJ:CORPORATE-PARTICIPATION-2025','Visible large corporate participant in western Jamaica and strategically aligned with seafood/refrigerated logistics; no current evidence of RGL commercial engagement.','Validate cold-storage footprint, inbound seafood/import volumes, hotel/retail distribution lanes, reefer requirements and openness to consolidated multimodal service.')
on conflict(prospect_code) do nothing;

update jlc.transaction_readiness set readiness_state='IN_PROGRESS',evidence_reference='STATIN:IMTS-2026-JAN-APR;KFTL:PORT-DEVELOPMENT;NMIA:AIRPORT-PROFILE;WISYNCO:AR2025;DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO',notes='JLC-009 quantified layer now includes verified gateway capacity/airfreight indicators and an evidence-backed anchor-customer prospect registry. No prospect is treated as an engaged customer, LOI, or contract absent direct evidence.',updated_at=now() where readiness_code='JLC-TR-COMM-001';
