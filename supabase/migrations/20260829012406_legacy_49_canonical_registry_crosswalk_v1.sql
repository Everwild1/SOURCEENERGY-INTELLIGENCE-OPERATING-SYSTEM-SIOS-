alter table sourcecubes.legacy_49_reconciliation
  add column if not exists canonical_ip_id text,
  add column if not exists canonical_source_url text,
  add column if not exists canonical_registry_state text,
  add column if not exists authority_owner text;

with crosswalk(slot_no, canonical_ip_id, reconciled_asset, canonical_source_url, canonical_registry_state, authority_owner) as (
  values
  (1,'WEM-IP-120','Wealth Ecology Electron-Shell / 120 Composite Architecture','https://docs.google.com/document/d/1jVdpskFU8WiGawHDXwctjDysWNwzNPSrNU8vkCy4o3o/edit','REGISTERED','Dr. Oliver E. Jones / WEM IP governance'),
  (2,'WEM-IP-120J-120O','Purpose, Daily Bread, Weekly Cycle & Technology Translation Addendum','https://docs.google.com/document/d/13Ip6MSoe7gXOPEB0pVmpl2FPaWHsj4wrxDbFAmx1E9g/edit','REGISTERED','Dr. Oliver E. Jones / WEM IP governance'),
  (3,'SEG-IP-QIP-001','Quantum Intellectual Property Blockchain Model & Congruency Matrix','https://docs.google.com/document/d/16wzqUcR_uGl-DXpDKjUom1heHy8hgG8JTzN6i8_f_wU/edit','REGISTERED','Dr. Oliver E. Jones / SourceEnergy IP governance'),
  (4,'SEG-IP-SC-001','Source Coin Protocol & Gold-Backed Digital Currency Architecture','https://docs.google.com/document/d/17jFzR84Usorn79eafJngj87TAGCQ0LGF6ru4tWX3OCA/edit','REGISTERED','Dr. Oliver E. Jones / SourceEnergy IP governance'),
  (5,'SEG-IP-WIM-COLOR-001','IP Blockchain Color/Saturation Encoding Matrix','https://docs.google.com/document/d/14QXCMPnbzsWJ0vBuWlFW_zIJTkJwYLMg6IbZqvNbh08/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy IP governance'),
  (6,'SEG-IP-HBID-001','Dual Cardiac Biometric Blockchain Authentication Integration','https://docs.google.com/document/d/1r2SNpXqvaXNdDiZ9y9Ahst0t6UN4lWWUMvQ2zu6LfY4/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy IP governance'),
  (7,'SEG-IP-WEEKLY-001','SourceEnergy Weekly Cycle Spiritual-Economic Alignment Framework','https://docs.google.com/document/d/1CJybQd4OI0OUu046nPzqp1GD4E2YVi14eaCQd_4aqrA/edit','REGISTERED','Dr. Oliver E. Jones / SourceEnergy IP governance'),
  (8,'SEG-IP-TECHTRANS-001','NASA T2U-to-Startup Technology Translation & Commercialization Matrix','https://docs.google.com/document/d/13XyKBfrZ3D96TKPpbIKQ7ChlOIfYFaQZVqcZH9A1VVo/edit','EVIDENCE-PENDING','SourceEnergy technology-commercialization governance'),
  (9,'RGL-IP-100','RobertLogix Logistics Platform Architecture','https://docs.google.com/document/d/1NL8Dq8D5TEiBMvhtAtd6M48tY8fV7BEi-zJeB9fzkvY/edit','REGISTERED','RobertLogix Holdings Trust / authorized operating entities'),
  (10,'SEG-IP-SK-001','Scrollkeeper Codex Governance & Transaction Protocol','https://docs.google.com/document/d/1BDVLBQTY-Cyya6R4qIPZVOWl05k6BHzflvOFBM-uxrg/edit','REGISTERED','Dr. Oliver E. Jones / SourceEnergy Codex IP governance'),
  (11,'SEG-IP-M1-001','M1 Accelerator Curriculum & Transformation Operating System','https://docs.google.com/document/d/1ZQUosruT8mW2z6RZEA5gYN1HAXhyGv3ZtjtN5v6_RZ0/edit','REGISTERED','Dr. Oliver E. Jones / WEM and M1 IP governance'),
  (12,'SEG-IP-CODEX-026','Oracle Command Console & Codex AI Orchestration Architecture','https://docs.google.com/document/d/1UKeyY0V3ZmdHns9pUYNMNvmEnpNwRiug7RmTXaFpn-0/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy software IP governance'),
  (13,'SEG-IP-FIN-DCB-001','Dual-Central-Bank Anchored Account Management and Cross-Border Settlement Architecture','https://docs.google.com/document/d/1_Uv3J_BwFCRch4B4FP4hPYP_1CwSnCcubEW6nceXhoQ/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy FinTech IP governance'),
  (14,'WEM-IP-MUSIC-001','WEM Music Industry 4.0 Operating Architecture and Cultural IP Protocol','https://docs.google.com/document/d/1Yt29JnwrX53Bva7m6hfnSm0vRMmXOzMjbs-3cOfiO1U/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / WEM and authorized M1 IP governance'),
  (15,'SEG-IP-SMG-001','Smart Management Grid Innovation Orchestration Platform','https://docs.google.com/document/d/1-CVS7XbU8kDGHu4Joa2MPsp2v1ghc252rx0PrnnPqz4/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy software IP governance'),
  (16,'SIOS-IP-001','SourceEnergy Intelligence Operating System','https://docs.google.com/document/d/1OmZrMb9obfkh0JLlT3ONE8eC5SIfY_WGaJbf7fgFwD8/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy software and IP governance'),
  (17,'SETC-IP-001','Institutional Identity, Governance & Lifecycle Control Architecture','https://docs.google.com/document/d/1EJRGMlA6Ew6JfiW6pDs2NpAi_iFRWJh4d9XZJgDedGg/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy Trust Chain and IP governance'),
  (18,'SETC-IP-CAP-001','Capitalization & Empire Block Capital Lineage Control Plane','https://docs.google.com/document/d/1iUJ_OfIsMmnQbPbobncy6svEguK5Yj-FRpjNP8x36CM/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy Capitalization and IP governance'),
  (19,'DHN-IP-001','Diaspora Health Consent-Governed Identity, Biometric, Telemetry & Attestation Architecture','https://docs.google.com/document/d/1Ht7whrrKr2qBMvgoLIPQ2BndNOEuEd6xDW4Mfum8Msk/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / Diaspora Health and SourceEnergy IP governance'),
  (20,'HEI-IP-001','Higher Education Consortium, Endowment, Research & Commercialization Operating Architecture','https://docs.google.com/document/d/1X-X3ecInP4J3sQE0nbM3O7ZtTTZiLfxb1GVChVS63Rc/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy and Oliver E. Jones Center IP governance'),
  (21,'SEI-IP-001','SourceEnergy Insurance Risk, Underwriting, Policy, Claims & Reinsurance Control Plane','https://docs.google.com/document/d/1oY92Y0PvUcAFEun0RceXpD0u05a0cxcTH_T5B-5FQb8/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy Insurance and IP governance'),
  (22,'SEG-IP-TST-001','Tithe Stewardship Trust Fiduciary Ledger & Assurance Operating System','https://docs.google.com/document/d/1yXrxaTKgMkn-Dd_L-0jzFwSi6Z9PKBr5yzixLtuWvWE/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy stewardship and IP governance'),
  (23,'WIM-IP-001','WIM Exchange Market Access, Trade & Settlement Orchestration Architecture','https://docs.google.com/document/d/1NrIWEm9TBQmyyUSkLDmpaBtjpo0vOc-mpoXsHPjGcGo/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / WIM and SourceEnergy IP governance'),
  (24,'RW-IP-001','Revolution Wealth Enterprise Development, Capital Readiness, Commercialization & Wealth Yield Operating System','https://docs.google.com/document/d/1D2IXsgnQGX8p9_cjh1AniiqCQZhKn4KWX3Vt_2D5-Wo/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / Revolution Wealth and WEM IP governance'),
  (25,'CRUDS-IP-001','CRUDS Universe Creative Identity, Work Provenance, Commercialization & Ecosystem Intelligence Architecture','https://docs.google.com/document/d/14GKdPXtt2ZDymm0YWkJPf6QGZnIoNQL4EkTbmkBfjlo/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / CRUDS Universe and SourceEnergy IP governance'),
  (26,'SEG-IP-ENERGY-001','Energy Infrastructure, Market, Environmental Attribute & Project Intelligence Operating Architecture','https://docs.google.com/document/d/16MQR7LzSSwwIAfvlfn_UcnBkedVrN336YsrDXg5z7bc/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy energy and IP governance'),
  (27,'SEG-IP-IOTF-001','IOTF Instrument Eligibility, Capacity Allocation & Settlement Governance Architecture','https://docs.google.com/document/d/1AOShrYfRrBD4Xtw8uIRTDGERMUbVbJ7QhmB69y3Spzs/edit','EVIDENCE-PENDING','Dr. Oliver E. Jones / SourceEnergy capital, trade and IP governance')
)
update sourcecubes.legacy_49_reconciliation l
set canonical_ip_id = c.canonical_ip_id,
    reconciled_asset = c.reconciled_asset,
    canonical_source_url = c.canonical_source_url,
    canonical_registry_state = c.canonical_registry_state,
    authority_owner = c.authority_owner,
    reconciliation_status = 'MATCHED_TO_CANONICAL_MASTER_REGISTER',
    legal_status = 'INTERNAL_REGISTRY_STATUS_ONLY',
    notes = 'Matched to the live Master Governance Register by canonical IP record. This slot is a portfolio reconciliation position, not a patent-office application or grant number.',
    updated_at = now()
from crosswalk c
where l.slot_no = c.slot_no;

comment on column sourcecubes.legacy_49_reconciliation.canonical_ip_id is 'Canonical SourceEnergy IP family identifier from the live Master Governance Register; not a patent-office identifier.';
