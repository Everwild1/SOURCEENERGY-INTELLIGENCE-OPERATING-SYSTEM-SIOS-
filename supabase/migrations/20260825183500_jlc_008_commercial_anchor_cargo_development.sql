-- JLC-008: Commercial & Anchor Cargo Development
create table if not exists jlc.commercial_demand_segments (
 segment_code text primary key,
 corridor_code text not null references jlc.corridors(corridor_code) on delete cascade,
 subject_reference text not null,
 cargo_segment text not null,
 logistics_requirement text not null,
 candidate_corridor text,
 evidence_status text not null check(evidence_status in ('PLANNING_EVIDENCE','MARKET_EVIDENCE','CUSTOMER_ENGAGEMENT','LOI','CONTRACTED','REJECTED')),
 evidence_reference text,
 validation_requirement text not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table jlc.commercial_demand_segments enable row level security;
grant select,insert,update,delete on jlc.commercial_demand_segments to service_role;
revoke all on jlc.commercial_demand_segments from anon,authenticated;
create policy service_role_all on jlc.commercial_demand_segments for all to service_role using(true) with check(true);
insert into jlc.commercial_demand_segments(segment_code,corridor_code,subject_reference,cargo_segment,logistics_requirement,candidate_corridor,evidence_status,evidence_reference,validation_requirement) values
('JLC-CDS-CONTAINER-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Containerized freight','Port-rail transfer, inland distribution, container storage and customs integration','Kingston-Port / National Freight Spine','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate TEU origin-destination volumes, current trucking economics, shipper commitments and modal-conversion potential.'),
('JLC-CDS-AGRI-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Agricultural products','Cold chain, food processing, export consolidation and time-sensitive distribution','Central / May Pen / Eastern corridors','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate producer/exporter volumes, seasonality, commodity mix, spoilage losses and destination markets.'),
('JLC-CDS-PHARMA-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Pharmaceutical and healthcare logistics','Temperature-controlled warehousing and distribution with airport/port interfaces','Kingston / airport-linked logistics','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate healthcare/pharma import-export volumes, temperature bands, service levels and regulated handling requirements.'),
('JLC-CDS-BUILD-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Building materials and cement','Bulk/heavy freight movement and industrial spurs','Clarendon / industrial freight spurs','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate plant locations, annual tonnage, current road cost, siding feasibility and customer interest.'),
('JLC-CDS-MINERAL-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Minerals and bauxite-related freight','Heavy-haul industrial rail and port interface','Industrial freight spurs / Clarendon','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate active production flows, tonnage, ownership, port routing and rail-access feasibility.'),
('JLC-CDS-CONSUMER-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Consumer goods and regional distribution','Warehousing, national distribution and intermodal transfer','Kingston / Spanish Town / Montego Bay','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate distributor/retailer volumes, pallet/container flows, service frequencies and warehouse demand.'),
('JLC-CDS-MFG-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Manufacturing inputs and export production','Industrial parks, export logistics and regional warehousing','Kingston / Clarendon / SEZ-linked corridors','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate manufacturer input/output tonnage, supplier origins, export destinations and logistics cost base.'),
('JLC-CDS-HOSP-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Hospitality and tourism supply chains','Regional distribution, refrigerated supply and airport/port interfaces','Montego Bay Western Gateway','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate hotel/resort procurement volumes, supplier origins, frequency, perishables share and consolidation potential.'),
('JLC-CDS-AIR-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Air cargo and high-value/time-sensitive freight','Airport cargo handling, cold chain and intermodal transfer','KIN / MBJ gateway interfaces','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate airfreight tonnage, commodities, route economics, carrier capacity and shipper demand.'),
('JLC-CDS-AFRICA-001','JLC-001','JLC-PROG-JRC-MULTIMODAL','Caribbean-North America-Africa trade flows','Port/airport consolidation, regional distribution and trans-Atlantic market development','Kingston gateway / national logistics network','PLANNING_EVIDENCE','DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO','Validate actual bilateral commodity flows, counterparties, shipping/air routes, volumes and commercial commitments; do not treat strategic positioning as contracted demand.')
on conflict(segment_code) do nothing;
update jlc.transaction_readiness set readiness_state='IN_PROGRESS',evidence_reference='DRIVE:JAMAICA-NATIONAL-TRANSFORMATION-PORTFOLIO',notes='JLC-008 commercial segmentation established from internal planning evidence. Freight categories and logistics requirements are now structured, but demand remains unvalidated until external market data and customer engagement produce quantified volumes and commitments.',updated_at=now() where readiness_code='JLC-TR-COMM-001';
