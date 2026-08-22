# IBG-08 — SBLC Monetization & Private Placement Control Plane

## Purpose
IBG-08 governs the financing, monetization, collateralization, platform due-diligence, encumbrance, funding-facility, and approval lifecycle for an externally evidenced trade-finance instrument. It extends the existing Capitalization and IBG-05 domains; it does not create a bank undertaking, authenticate an instrument, confer regulatory authority, or represent projected platform returns as realized liquidity.

## Current transaction anchor
The current SourceEnergy transaction was submitted/requested at USD 170,000,000. The instrument evidence record received for reference `SBLC-20260820-0001-14` states a face amount of USD 153,000,000. The USD 17,000,000 difference is not classified as a fee, haircut, reserve, discount, or loss unless authoritative transaction documentation establishes that characterization.

The current IOTF record is `SE-IOTF-SBLC-20260820-0001-14`, with recognition status `EVIDENCE_RECEIVED`, evidence status `PARTIAL`, deployable cash `0`, realized liquidity `0`, and independent bank authentication recorded as false. IBG-08 must preserve those distinctions until evidence-backed promotion occurs.

## Authority boundaries
1. IOTF remains authoritative for the instrument evidence record and recognition state.
2. IBG-05 remains authoritative for governed trade-finance lifecycle records inside Capitalization.
3. IBG-08 is authoritative for monetization case state, platform/counterparty qualification, instrument encumbrance, funding economics, and monetization approvals.
4. IBG-03/IBG-06 remain authoritative for payment orchestration and external settlement/finality boundaries.
5. WIM remains authoritative for downstream trade/commercial deployment.
6. Source Coin remains authoritative only for its own ledger and finality.
7. A platform registration, dashboard record, PDF, SWIFT-formatted text, UETR, internal approval, database row, or counterparty representation cannot by itself prove bank authentication, enforceability, funding, custody, or settlement finality.

## Case lifecycle
`P0_UNSCREENED -> P1_INTAKE_RECEIVED -> P2_VERIFIED_CANDIDATE -> P3_TRANSACTION_QUALIFIED -> P4_AUTHORIZED`

Any state may transition to `PX_SUSPENDED_REJECTED` when a critical verification, sanctions, fraud, authority, banking, legal, custody, economic-substance, or double-encumbrance control fails.

### P0 — Unscreened
No operative instrument submission to a platform. No monetization authority.

### P1 — Intake received
Legal identity, ownership, transaction role, proposed economics, fees, bank/custody coordinates, and transaction documentation have been received for review.

### P2 — Verified candidate
Material corporate, beneficial-ownership, regulatory, banking, and capacity diligence has been independently verified. P2 does not authorize instrument transmission.

### P3 — Transaction qualified
Legal, compliance, custody, collateral, economics, funding-source, receiving-bank, and exit/release mechanics are cleared for final governance authorization.

### P4 — Authorized
Transaction-specific governance approval has been recorded. P4 authorizes only the specific approved transaction and does not establish settlement finality.

## Mandatory P4 gates
A monetization case cannot become P4 unless all applicable controls are true:

- instrument evidence is linked and remains eligible for the proposed use;
- independent bank authentication is recorded;
- funding source is identified and independently verified;
- receiving/custody institution is identified and independently verified where applicable;
- platform/counterparty due diligence is cleared;
- beneficial ownership is resolved;
- sanctions/AML/KYB status is cleared;
- legal review is cleared;
- economics and fee waterfall are approved;
- instrument encumbrance status is known and no conflicting active encumbrance exists;
- transaction-specific governance authorization is recorded.

## Economics boundary
IBG-08 stores submitted/requested amount, received instrument face amount, proposed financing amount, verified financing amount, transaction costs, reserves, and net deployable capital as distinct values.

`instrument face value != deployable cash`

`projected trading return != realized liquidity`

Only externally evidenced settled proceeds may be promoted into realized liquidity or deployable capital.

## Platform due diligence
Every platform, monetizer, funder, trader, mandate, intermediary, custodian, escrow provider, and material fee recipient must be represented by a legal identity and role record. Diligence includes jurisdiction, registration, UBOs, regulatory basis where applicable, banking/custody relationship, sanctions/AML status, transaction capacity, independently verifiable track record, fee schedule, and definitive agreements.

Enhanced review is mandatory for guaranteed returns, extraordinary fixed weekly returns, risk-free trading, secret interbank programs, purported central-bank/Federal Reserve private programs, guaranteed monetization percentages, unexplained blocking of funds, material advance fees, refusal to identify UBOs/funding institutions, prevention of independent verification, or requests for banking credentials/private authentication material.

## Encumbrance control
IBG-08 maintains a centralized instrument encumbrance register. An instrument subject to an active pledge, assignment, lien, collateral use, custody control, or other material encumbrance may not be represented as freely available for another transaction unless the prior encumbrance is evidenced as released.

## Security
IBG-08 tables are internal, RLS-enabled, and default-deny to public, anon, and authenticated roles. Application-facing projections, if later introduced, must omit raw account numbers, credentials, evidence-document bodies, private authentication material, and unrestricted bank instructions.

## Current status
For `SBLC-20260820-0001-14`:

- submitted/requested amount: USD 170,000,000;
- received instrument face amount: USD 153,000,000;
- IOTF recognition: `EVIDENCE_RECEIVED`;
- IOTF evidence: `PARTIAL`;
- independent bank authentication: not yet evidenced in the current system record;
- deployable cash: USD 0;
- realized liquidity: USD 0;
- IBG-08 case state: P0 until a named platform/monetizer/funding counterparty package is registered and screened.

## Non-authority statement
IBG-08 is a control and evidence architecture. It does not itself establish that UBS, Truist, GSF, a private-placement platform, a trader, or any other external entity has authenticated, accepted, funded, monetized, confirmed, advised, settled, or otherwise committed to a transaction. Those claims require independent authoritative evidence.