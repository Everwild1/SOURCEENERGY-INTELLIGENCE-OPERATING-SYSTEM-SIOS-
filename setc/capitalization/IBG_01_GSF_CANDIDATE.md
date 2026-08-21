# IBG-01 — GSF Banking Candidate Registry Record

## Purpose

This record reconciles Issue #109 with the canonical Capitalization Block control plane. It is a governance/control-plane record only and does not establish a banking relationship, regulatory status, custody authority, payment capability, settlement finality, or production connectivity.

## Candidate

- Display name: GSF Banking
- Public website supplied for diligence: https://www.gsfbanking.com
- Relationship state: `TARGET`
- Verification status: `UNVERIFIED`
- Connectivity status: `NOT_CONNECTED`
- Settlement authority: `NONE`
- Custody authority: `NONE`
- Production eligibility: `NO-GO`
- Public live-network claim: `PROHIBITED`

Unknown or unverified legal, regulatory, ownership, SWIFT/BIC, correspondent, deposit-protection, currency, custody, treasury, trade-finance, API, digital-asset, cybersecurity, and business-continuity attributes must remain null/unknown until supported by independently retained evidence.

## Promotion gate

GSF may not advance beyond a registry target merely because it appears in this repository. Promotion to `DUE_DILIGENCE`, `QUALIFIED`, `CONTRACTED`, `INTEGRATED`, or `LIVE` requires the evidence and governance controls defined by the Capitalization Block architecture and Issue #109.

`LIVE` additionally requires `PRODUCTION` connectivity, `VERIFIED` status, an evidence reference, and a verification timestamp under `InstitutionStatus`.

## IBG boundary

The Institutional Banking Gateway is the governed boundary between SourceEnergy capital orchestration and external financial institutions. External institutions remain replaceable execution rails. Bank money, Source Coin settlement, and SETC/SIOS records are distinct domains and must not be conflated.

## Due-diligence minimum

Before approval, independently verify as applicable:

1. Exact legal entity and jurisdiction.
2. Regulator, license, and authorized activities.
3. Deposit-taking authority and deposit-protection status.
4. SWIFT/BIC and correspondent relationships.
5. Ownership and beneficial ownership.
6. Audited financial/capital information.
7. AML/KYC/sanctions controls.
8. Supported jurisdictions and currencies.
9. Treasury and cash-management capabilities.
10. Custody capabilities.
11. Trade-finance capabilities.
12. API/open-banking capabilities.
13. Digital-asset policy.
14. Institutional eligibility and settlement limits.
15. Cybersecurity and business-continuity controls.

## Implementation sequence

This record satisfies the IBG-01 candidate-classification layer. Follow-on implementation remains sequenced as account/custody registry, payment orchestration, treasury/liquidity, trade finance, and settlement reconciliation. None of those lanes may infer production authority from this candidate record.
