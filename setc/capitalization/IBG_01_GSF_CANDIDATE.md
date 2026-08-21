# IBG-01 — GSF Banking Candidate Registry Record

## Purpose

This record reconciles Issue #109 with the canonical Capitalization Block control plane. It is a governance/control-plane record only and does not establish a banking relationship, regulatory status, custody authority, payment capability, settlement finality, or production connectivity.

## Candidate

- Display name: GSF Banking
- Public website supplied for diligence: https://www.gsfbanking.com
- Relationship state: `DUE_DILIGENCE`
- Verification status: `UNVERIFIED`
- Connectivity status: `NOT_CONNECTED`
- Settlement authority: `NONE`
- Custody authority: `NONE`
- Production eligibility: `NO-GO`
- Public live-network claim: `PROHIBITED`

The relationship state is advanced only to `DUE_DILIGENCE` because first-party website screenshots now provide specific claims suitable for verification. They are not independent evidence and do not satisfy the `VERIFIED`, `CONTRACTED`, `INTEGRATED`, or `LIVE` gates.

## First-party claims captured for verification

The supplied GSF website screenshots state or advertise the following. Every item remains `CLAIMED / UNVERIFIED` until corroborated by authoritative third-party evidence and, where relevant, contractual evidence.

### Operator and regulatory profile

- Claimed operator: `MAEZ INTERNATIONAL GROUP SDN BHD`.
- Claimed company number: `202001042881 (1399202-X)`.
- Claimed jurisdiction/registry: Malaysia / Suruhanjaya Syarikat Malaysia (SSM).
- The site expressly states that GSF does **not** hold its own banking licence and describes the service as a fintech/payment-services platform rather than a deposit-taking institution.
- The site states deposits are not covered by PIDM or FSCS.
- Claimed contact location: Level 25, Menara GSF, KLCC, 50088 Kuala Lumpur, Malaysia.

### Settlement and payment rails

- Claimed settlement bank: `CIMB Bank Berhad`.
- Claimed CIMB BIC: `CIBBMYKL`.
- Claimed rails/services include SWIFT/MT103, DuitNow, FPX, SEPA, ACH and PACS.008.
- The site states payment settlement occurs through regulated/sponsor infrastructure and does not present GSF as holding its own BIC or banking licence.
- Other named sponsor/rail providers shown in site copy include Stripe, NIUM, Xendit, Brankas, GlobalPayments, Airwallex and HitPay.

These claims do not establish that GSF has an active correspondent, sponsor, settlement, API, account, or contractual relationship with any named institution/provider.

### Technology and licensing claims

- Claimed core-banking licence/provider: `iGCB Intellect`.
- Claimed edge-security / PCI DSS dependency: `Akamai`.
- Claimed database and enterprise infrastructure: `Oracle`.
- Site copy references `OBIE Open Licence v2.0` and an MIT/open-source licence notice.

No vendor logo, attribution, licence statement, or website copy is accepted as proof of a current commercial contract, certification, production deployment, or provider endorsement.

### Compliance/readiness claims

- EU DGA: site references Regulation (EU) 2022/868.
- ISO 27001:2022: site status shown as `In Progress`.
- ISO 9362 (BIC): site status shown as `Internally Identified`.
- ISO 20022: site status shown as `Live`.
- LEI registration/renewal is described as via RapidLEI / an accredited LOU.
- ISO 27001 / SOC 2 readiness is described as via Sprinto.
- eIDAS QWAC / QSealC is described as via a partner QTSP.
- PCI DSS readiness is described using an Akamai responsibility matrix and PCI DSS 4.0.1 alignment.
- KYC/AML is described as tiered eKYC plus real-time screening.
- The site describes append-only/sealed ledger controls and AES-256-GCM document seals.

Readiness, alignment, internal identification, and self-described live status are not equivalent to certification, registration, accreditation, regulatory authorization, or independently verified operational capability.

### Commercial/product claims

The site markets personal, business and enterprise tiers and advertises multi-currency accounts/wallets, Visa cards, domestic/international transfers, treasury, trade finance/SBLC, wealth/markets, and business transfer limits. These are product claims only. They must not be modeled as available SETC capabilities until the underlying regulated provider, contract, eligibility, limits, custody/settlement structure, and production integration are independently established.

## Evidence classification

- Evidence class: `FIRST_PARTY_WEBSITE_SCREENSHOT`
- Evidence strength: `LOW / ASSERTIONAL`
- Suitable use: identify diligence questions and candidate/provider names.
- Unsuitable use: verify licence, BIC ownership, bank relationship, certification, account availability, custody, payment execution, settlement finality, or production readiness.

Unknown or unverified legal, regulatory, ownership, SWIFT/BIC, correspondent, deposit-protection, currency, custody, treasury, trade-finance, API, digital-asset, cybersecurity, and business-continuity attributes must remain null/unknown unless supported by independently retained evidence.

## Promotion gate

GSF may not advance beyond `DUE_DILIGENCE` merely because it appears in this repository or because claims appear on its website. Promotion to `QUALIFIED`, `CONTRACTED`, `INTEGRATED`, or `LIVE` requires the evidence and governance controls defined by the Capitalization Block architecture and Issue #109.

`LIVE` additionally requires `PRODUCTION` connectivity, `VERIFIED` status, an evidence reference, and a verification timestamp under `InstitutionStatus`.

## IBG boundary

The Institutional Banking Gateway is the governed boundary between SourceEnergy capital orchestration and external financial institutions. External institutions remain replaceable execution rails. Bank money, Source Coin settlement, and SETC/SIOS records are distinct domains and must not be conflated.

## Due-diligence minimum

Before approval, independently verify as applicable:

1. Exact legal entity and jurisdiction through SSM or equivalent authoritative registry.
2. Regulator, licence status, and authorized activities; confirm the site's explicit non-bank status.
3. Deposit-taking authority and deposit-protection status.
4. Whether `CIBBMYKL` belongs to CIMB and whether GSF has an actual authorized settlement/correspondent relationship with CIMB.
5. Ownership and beneficial ownership.
6. Audited financial/capital information.
7. AML/KYC/sanctions controls and accountable regulated parties.
8. Supported jurisdictions and currencies.
9. Treasury and cash-management capabilities and responsible licensed provider.
10. Custody capabilities and legal account/custody structure.
11. Trade-finance/SBLC capabilities and issuing/confirming institution.
12. API/open-banking capabilities and production contracts.
13. Digital-asset policy.
14. Institutional eligibility and settlement limits.
15. Cybersecurity and business-continuity controls.
16. Current contracts/attestations for iGCB/Intellect, Akamai, Oracle and any named payment/sponsor provider.
17. ISO 27001 certificate only after issuance by an accredited certification body; do not treat `In Progress` as certified.
18. ISO 20022 production scope and endpoints; do not treat website `Live` wording as network connectivity evidence.
19. LEI from the GLEIF authoritative record and exact legal-entity mapping.
20. PCI DSS scope/attestation and responsibility matrix applicable to GSF's actual card-data environment.

## IBG-02 / IBG-03 implications

No GSF account may become `ACTIVE / PRODUCTION_ELIGIBLE` under IBG-02 based on these screenshots. IBG-03 must reject GSF as an executable payment route while `UNVERIFIED` or `NOT_CONNECTED`, regardless of advertised rails, transfer limits, product pricing, or settlement-bank claims.

## Implementation sequence

This record satisfies the IBG-01 candidate-classification layer and now captures first-party diligence assertions. Follow-on implementation remains sequenced as account/custody registry, payment orchestration, treasury/liquidity, trade finance, and settlement reconciliation. None of those lanes may infer production authority from this candidate record.
