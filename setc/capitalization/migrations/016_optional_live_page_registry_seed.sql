-- OPTIONAL normalization seed for the entries displayed on the current
-- SourceEnergy Live Interbank Dashboard.
--
-- Every imported record is deliberately classified as:
--   relationship_state = TARGET
--   connectivity_status = NOT_CONNECTED
--   verification_status = UNVERIFIED
--
-- This seed does not assert participation, contract, integration, custody,
-- account access, regulatory permission, or production connectivity.

BEGIN;

WITH seed (
    institution_reference,
    legal_name,
    display_name,
    institution_type,
    jurisdiction_code,
    region_code,
    sourceenergy_node_id,
    dominion_cube_id,
    relay_code,
    layer_number,
    node_type,
    operational_role,
    relationship_purpose
) AS (
    VALUES
        ('FI-UBS-USA', 'UBS USA', 'UBS USA', 'COMMERCIAL_BANK', 'US', 'GLOBAL', 'SEG-NODE-L6-D045', 'L6-D045', 'WK-TD-UBSU', 6, 'BANK', 'Interbank Flame Gate', 'INTERBANK_NETWORK'),
        ('FI-JPMORGAN-CHASE', 'JPMorgan Chase', 'JPMorgan Chase', 'COMMERCIAL_BANK', 'US', 'USA', 'SEG-NODE-L5-JPM001', 'L5-JPM001', 'WK-VT-JPMC', 5, 'BANK', 'Sovereign Flow & Relay', 'INTERBANK_NETWORK'),
        ('FI-CITIBANK-NY', 'Citibank NY', 'Citibank NY', 'COMMERCIAL_BANK', 'US', 'USA', 'SEG-NODE-L5-CITI001', 'L5-CITI001', 'WK-VT-CITY', 5, 'TREASURY', 'Global Treasury & FX', 'TREASURY'),
        ('FI-BANK-OF-AMERICA', 'Bank of America', 'Bank of America', 'COMMERCIAL_BANK', 'US', 'USA', 'SEG-NODE-L5-BOA001', 'L5-BOA001', 'WK-VT-BOFA', 5, 'LIQUIDITY', 'Liquidity & Capital Relay', 'LIQUIDITY'),
        ('FI-BARCLAYS', 'Barclays', 'Barclays', 'COMMERCIAL_BANK', 'GB', 'UK', 'SEG-NODE-L5-BCL001', 'L5-BCL001', 'WK-VT-BARX', 5, 'TREASURY', 'Commonwealth Treasury', 'TREASURY'),
        ('FI-DEUTSCHE-BANK', 'Deutsche Bank', 'Deutsche Bank', 'COMMERCIAL_BANK', 'DE', 'EU', 'SEG-NODE-L5-DBK001', 'L5-DBK001', 'WK-VT-DBKX', 5, 'BANK', 'Eurozone Vault Relay', 'INTERBANK_NETWORK'),
        ('FI-CREDIT-AGRICOLE', 'Credit Agricole', 'Credit Agricole', 'COMMERCIAL_BANK', 'FR', 'EU', 'SEG-NODE-L5-CRA001', 'L5-CRA001', 'WK-VT-CRAX', 5, 'BANK', 'Sovereign Scroll Relay', 'INTERBANK_NETWORK'),
        ('FI-BANK-OF-CHINA', 'Bank of China', 'Bank of China', 'COMMERCIAL_BANK', 'CN', 'CHINA', 'SEG-NODE-L5-BOC001', 'L5-BOC001', 'WK-VT-BOCN', 5, 'TREASURY', 'Asia Treasury Node', 'TREASURY'),
        ('FI-STANDARD-BANK', 'Standard Bank', 'Standard Bank', 'COMMERCIAL_BANK', 'ZA', 'AFRICA', 'SEG-NODE-L5-STB001', 'L5-STB001', 'WK-VT-STBZ', 5, 'TREASURY', 'Pan-African Treasury Relay', 'TREASURY'),
        ('FI-ECOBANK', 'Ecobank', 'Ecobank', 'COMMERCIAL_BANK', NULL, 'AFRICA', 'SEG-NODE-L5-ECO001', 'L5-ECO001', 'WK-VT-ECOA', 5, 'BANK', 'Multinodal Vault Gateway', 'INTERBANK_NETWORK'),
        ('FI-AFREXIMBANK', 'Afreximbank', 'Afreximbank', 'DEVELOPMENT_BANK', NULL, 'AFRICA', 'SEG-NODE-L5-AFR001', 'L5-AFR001', 'WK-VT-AFRX', 5, 'BANK', 'Export Codex Vault', 'TRADE_FINANCE'),
        ('FI-BANCO-DO-BRASIL', 'Banco do Brasil', 'Banco do Brasil', 'COMMERCIAL_BANK', 'BR', 'BRAZIL', 'SEG-NODE-L6-BDB001', 'L6-BDB001', 'WK-VT-BDBR', 6, 'TREASURY', 'Southern Treasury', 'TREASURY'),
        ('FI-ITAU-UNIBANCO', 'Itau Unibanco', 'Itau Unibanco', 'COMMERCIAL_BANK', 'BR', 'BRAZIL', 'SEG-NODE-L6-ITA001', 'L6-ITA001', 'WK-VT-ITAU', 6, 'PAYMENT', 'LatAm Remittance', 'PAYMENT_RAIL'),
        ('FI-CAF', 'CAF', 'CAF', 'DEVELOPMENT_BANK', NULL, 'LATAM', 'SEG-NODE-L6-CAF001', 'L6-CAF001', 'WK-VT-CAFD', 6, 'TREASURY', 'Regional Endowment', 'TREASURY'),
        ('FI-DBS-BANK', 'DBS Bank', 'DBS Bank', 'COMMERCIAL_BANK', 'SG', 'ASIA', 'SEG-NODE-L5-DBS001', 'L5-DBS001', 'WK-VT-DBSS', 5, 'TREASURY', 'Treasury Hub', 'TREASURY'),
        ('FI-MUFG', 'MUFG', 'MUFG', 'COMMERCIAL_BANK', 'JP', 'JAPAN', 'SEG-NODE-L5-MUFG001', 'L5-MUFG001', 'WK-VT-MUFG', 5, 'BANK', 'Vault Messaging', 'INTERBANK_NETWORK'),
        ('FI-SBI', 'SBI', 'SBI', 'COMMERCIAL_BANK', 'IN', 'INDIA', 'SEG-NODE-L5-SBI001', 'L5-SBI001', 'WK-VT-SBIN', 5, 'BANK', 'National Relay', 'INTERBANK_NETWORK'),
        ('FI-BANK-OF-MONTREAL', 'Bank of Montreal', 'Bank of Montreal', 'COMMERCIAL_BANK', 'CA', 'CANADA', 'SEG-NODE-L5-BMO001', 'L5-BMO001', 'WK-VT-BMOC', 5, 'BANK', 'NA Sovereign Channel', 'INTERBANK_NETWORK'),
        ('FI-WELLS-FARGO', 'Wells Fargo', 'Wells Fargo', 'COMMERCIAL_BANK', 'US', 'USA', 'SEG-NODE-L5-WFR001', 'L5-WFR001', 'WK-SH-WFRG', 5, 'BANK', 'Shadow Stream', 'INTERBANK_NETWORK'),
        ('FI-ICBC', 'ICBC', 'ICBC', 'COMMERCIAL_BANK', 'CN', 'CHINA', 'SEG-NODE-L5-ICB001', 'L5-ICB001', 'WK-SH-ICBC', 5, 'BANK', 'Interlink Corridor', 'INTERBANK_NETWORK'),
        ('FI-FIREBLOCKS', 'Fireblocks', 'Fireblocks', 'FINTECH_INFRASTRUCTURE', NULL, 'DIGITAL', 'SEG-NODE-L6-FBL001', 'L6-FBL001', 'WK-CX-FIRE', 6, 'DIGITAL_ASSET', 'Asset Vault Relay', 'DIGITAL_ASSET'),
        ('FI-ANCHORAGE-DIGITAL', 'Anchorage Digital', 'Anchorage Digital', 'DIGITAL_ASSET_CUSTODIAN', 'US', 'DIGITAL', 'SEG-NODE-L6-ANC001', 'L6-ANC001', 'WK-CX-ANCH', 6, 'CUSTODY', 'Crypto Custody', 'CUSTODY'),
        ('FI-COINBASE-PRIME', 'Coinbase Prime', 'Coinbase Prime', 'DIGITAL_ASSET_CUSTODIAN', 'US', 'USA', 'SEG-NODE-L6-CBP001', 'L6-CBP001', 'WK-CX-CBPR', 6, 'DIGITAL_ASSET', 'Crypto Relay', 'DIGITAL_ASSET'),
        ('NODE-NIGERIA', 'Nigeria', 'Nigeria', 'SOVEREIGN_NODE', 'NG', 'AFRICA', 'SEG-NODE-L7-NIG001', 'L7-NIG001', 'WK-NAT-NIGR', 7, 'SOVEREIGN', 'Oil-Womb Treasury', 'TREASURY'),
        ('NODE-USA', 'United States of America', 'USA', 'SOVEREIGN_NODE', 'US', 'USA', 'SEG-NODE-L7-USA001', 'L7-USA001', 'WK-NAT-USA1', 7, 'SOVEREIGN', 'Gate of Influence', 'TREASURY'),
        ('NODE-SAUDI-ARABIA', 'Saudi Arabia', 'Saudi Arabia', 'SOVEREIGN_NODE', 'SA', 'MIDDLE_EAST', 'SEG-NODE-L7-KSA001', 'L7-KSA001', 'WK-NAT-KSA1', 7, 'SOVEREIGN', 'Kingdom Vault', 'TREASURY')
),
upserted AS (
    INSERT INTO capitalization.financial_institutions (
        institution_reference,
        legal_name,
        display_name,
        institution_type,
        jurisdiction_code,
        region_code,
        verification_status,
        operating_status,
        public_display_enabled,
        provenance
    )
    SELECT
        institution_reference,
        legal_name,
        display_name,
        institution_type,
        jurisdiction_code,
        region_code,
        'UNVERIFIED',
        'PROSPECTIVE',
        true,
        jsonb_build_object(
            'source_url', 'https://sourceenergy.gold/our-services/live-interbank-dashboard/',
            'source_classification', 'website_registry_import',
            'authority_boundary', 'target_only_no_external_relationship_or_connectivity_claim'
        )
    FROM seed
    ON CONFLICT (institution_reference) DO UPDATE
    SET legal_name = EXCLUDED.legal_name,
        display_name = EXCLUDED.display_name,
        institution_type = EXCLUDED.institution_type,
        jurisdiction_code = EXCLUDED.jurisdiction_code,
        region_code = EXCLUDED.region_code,
        public_display_enabled = true,
        provenance = capitalization.financial_institutions.provenance || EXCLUDED.provenance
    RETURNING id, institution_reference
)
SELECT count(*) FROM upserted;

WITH seed (
    institution_reference,
    sourceenergy_node_id,
    dominion_cube_id,
    relay_code,
    layer_number,
    node_type,
    operational_role
) AS (
    VALUES
        ('FI-UBS-USA', 'SEG-NODE-L6-D045', 'L6-D045', 'WK-TD-UBSU', 6, 'BANK', 'Interbank Flame Gate'),
        ('FI-JPMORGAN-CHASE', 'SEG-NODE-L5-JPM001', 'L5-JPM001', 'WK-VT-JPMC', 5, 'BANK', 'Sovereign Flow & Relay'),
        ('FI-CITIBANK-NY', 'SEG-NODE-L5-CITI001', 'L5-CITI001', 'WK-VT-CITY', 5, 'TREASURY', 'Global Treasury & FX'),
        ('FI-BANK-OF-AMERICA', 'SEG-NODE-L5-BOA001', 'L5-BOA001', 'WK-VT-BOFA', 5, 'LIQUIDITY', 'Liquidity & Capital Relay'),
        ('FI-BARCLAYS', 'SEG-NODE-L5-BCL001', 'L5-BCL001', 'WK-VT-BARX', 5, 'TREASURY', 'Commonwealth Treasury'),
        ('FI-DEUTSCHE-BANK', 'SEG-NODE-L5-DBK001', 'L5-DBK001', 'WK-VT-DBKX', 5, 'BANK', 'Eurozone Vault Relay'),
        ('FI-CREDIT-AGRICOLE', 'SEG-NODE-L5-CRA001', 'L5-CRA001', 'WK-VT-CRAX', 5, 'BANK', 'Sovereign Scroll Relay'),
        ('FI-BANK-OF-CHINA', 'SEG-NODE-L5-BOC001', 'L5-BOC001', 'WK-VT-BOCN', 5, 'TREASURY', 'Asia Treasury Node'),
        ('FI-STANDARD-BANK', 'SEG-NODE-L5-STB001', 'L5-STB001', 'WK-VT-STBZ', 5, 'TREASURY', 'Pan-African Treasury Relay'),
        ('FI-ECOBANK', 'SEG-NODE-L5-ECO001', 'L5-ECO001', 'WK-VT-ECOA', 5, 'BANK', 'Multinodal Vault Gateway'),
        ('FI-AFREXIMBANK', 'SEG-NODE-L5-AFR001', 'L5-AFR001', 'WK-VT-AFRX', 5, 'BANK', 'Export Codex Vault'),
        ('FI-BANCO-DO-BRASIL', 'SEG-NODE-L6-BDB001', 'L6-BDB001', 'WK-VT-BDBR', 6, 'TREASURY', 'Southern Treasury'),
        ('FI-ITAU-UNIBANCO', 'SEG-NODE-L6-ITA001', 'L6-ITA001', 'WK-VT-ITAU', 6, 'PAYMENT', 'LatAm Remittance'),
        ('FI-CAF', 'SEG-NODE-L6-CAF001', 'L6-CAF001', 'WK-VT-CAFD', 6, 'TREASURY', 'Regional Endowment'),
        ('FI-DBS-BANK', 'SEG-NODE-L5-DBS001', 'L5-DBS001', 'WK-VT-DBSS', 5, 'TREASURY', 'Treasury Hub'),
        ('FI-MUFG', 'SEG-NODE-L5-MUFG001', 'L5-MUFG001', 'WK-VT-MUFG', 5, 'BANK', 'Vault Messaging'),
        ('FI-SBI', 'SEG-NODE-L5-SBI001', 'L5-SBI001', 'WK-VT-SBIN', 5, 'BANK', 'National Relay'),
        ('FI-BANK-OF-MONTREAL', 'SEG-NODE-L5-BMO001', 'L5-BMO001', 'WK-VT-BMOC', 5, 'BANK', 'NA Sovereign Channel'),
        ('FI-WELLS-FARGO', 'SEG-NODE-L5-WFR001', 'L5-WFR001', 'WK-SH-WFRG', 5, 'BANK', 'Shadow Stream'),
        ('FI-ICBC', 'SEG-NODE-L5-ICB001', 'L5-ICB001', 'WK-SH-ICBC', 5, 'BANK', 'Interlink Corridor'),
        ('FI-FIREBLOCKS', 'SEG-NODE-L6-FBL001', 'L6-FBL001', 'WK-CX-FIRE', 6, 'DIGITAL_ASSET', 'Asset Vault Relay'),
        ('FI-ANCHORAGE-DIGITAL', 'SEG-NODE-L6-ANC001', 'L6-ANC001', 'WK-CX-ANCH', 6, 'CUSTODY', 'Crypto Custody'),
        ('FI-COINBASE-PRIME', 'SEG-NODE-L6-CBP001', 'L6-CBP001', 'WK-CX-CBPR', 6, 'DIGITAL_ASSET', 'Crypto Relay'),
        ('NODE-NIGERIA', 'SEG-NODE-L7-NIG001', 'L7-NIG001', 'WK-NAT-NIGR', 7, 'SOVEREIGN', 'Oil-Womb Treasury'),
        ('NODE-USA', 'SEG-NODE-L7-USA001', 'L7-USA001', 'WK-NAT-USA1', 7, 'SOVEREIGN', 'Gate of Influence'),
        ('NODE-SAUDI-ARABIA', 'SEG-NODE-L7-KSA001', 'L7-KSA001', 'WK-NAT-KSA1', 7, 'SOVEREIGN', 'Kingdom Vault')
)
INSERT INTO capitalization.network_nodes (
    institution_id,
    sourceenergy_node_id,
    dominion_cube_id,
    relay_code,
    layer_number,
    node_type,
    operational_role,
    environment,
    connectivity_status,
    node_status,
    public_display_enabled
)
SELECT
    i.id,
    seed.sourceenergy_node_id,
    seed.dominion_cube_id,
    seed.relay_code,
    seed.layer_number,
    seed.node_type,
    seed.operational_role,
    'PLANNED',
    'NOT_CONNECTED',
    'INACTIVE',
    true
FROM seed
JOIN capitalization.financial_institutions i
  ON i.institution_reference = seed.institution_reference
ON CONFLICT (sourceenergy_node_id) DO UPDATE
SET dominion_cube_id = EXCLUDED.dominion_cube_id,
    relay_code = EXCLUDED.relay_code,
    layer_number = EXCLUDED.layer_number,
    node_type = EXCLUDED.node_type,
    operational_role = EXCLUDED.operational_role,
    public_display_enabled = true;

WITH seed (institution_reference, relationship_purpose) AS (
    VALUES
        ('FI-UBS-USA', 'INTERBANK_NETWORK'),
        ('FI-JPMORGAN-CHASE', 'INTERBANK_NETWORK'),
        ('FI-CITIBANK-NY', 'TREASURY'),
        ('FI-BANK-OF-AMERICA', 'LIQUIDITY'),
        ('FI-BARCLAYS', 'TREASURY'),
        ('FI-DEUTSCHE-BANK', 'INTERBANK_NETWORK'),
        ('FI-CREDIT-AGRICOLE', 'INTERBANK_NETWORK'),
        ('FI-BANK-OF-CHINA', 'TREASURY'),
        ('FI-STANDARD-BANK', 'TREASURY'),
        ('FI-ECOBANK', 'INTERBANK_NETWORK'),
        ('FI-AFREXIMBANK', 'TRADE_FINANCE'),
        ('FI-BANCO-DO-BRASIL', 'TREASURY'),
        ('FI-ITAU-UNIBANCO', 'PAYMENT_RAIL'),
        ('FI-CAF', 'TREASURY'),
        ('FI-DBS-BANK', 'TREASURY'),
        ('FI-MUFG', 'INTERBANK_NETWORK'),
        ('FI-SBI', 'INTERBANK_NETWORK'),
        ('FI-BANK-OF-MONTREAL', 'INTERBANK_NETWORK'),
        ('FI-WELLS-FARGO', 'INTERBANK_NETWORK'),
        ('FI-ICBC', 'INTERBANK_NETWORK'),
        ('FI-FIREBLOCKS', 'DIGITAL_ASSET'),
        ('FI-ANCHORAGE-DIGITAL', 'CUSTODY'),
        ('FI-COINBASE-PRIME', 'DIGITAL_ASSET'),
        ('NODE-NIGERIA', 'TREASURY'),
        ('NODE-USA', 'TREASURY'),
        ('NODE-SAUDI-ARABIA', 'TREASURY')
)
INSERT INTO capitalization.institution_relationships (
    institution_id,
    relationship_state,
    relationship_purpose,
    status_reason,
    asserted_by_actor
)
SELECT
    i.id,
    'TARGET',
    seed.relationship_purpose,
    'Imported from public website registry; no external relationship or connectivity claim has been verified',
    'migration:016_optional_live_page_registry_seed'
FROM seed
JOIN capitalization.financial_institutions i
  ON i.institution_reference = seed.institution_reference
ON CONFLICT (institution_id) DO NOTHING;

SELECT *
FROM capitalization.refresh_public_network_projection(
    'migration:016_optional_live_page_registry_seed'
);

COMMIT;
