# IBG-07 — Production Connectivity & Institutional Certification

## Mission
IBG-07 governs the transition from completed control-plane architecture to independently evidenced institutional connectivity. It is a certification layer, not a declaration that any bank, account, rail, provider, custody arrangement, trade-finance capability or settlement path is live.

## Governing principle
`ARCHITECTURE_COMPLETE` is categorically different from `PRODUCTION_CERTIFIED`.

No institution, account, route or environment may be represented as production/live because software exists, a dashboard displays a logo, a relationship has been introduced, credentials have been discussed, or an internal test succeeds.

## Certification domains
Every production candidate must independently satisfy applicable domains:

1. **Legal entity** — exact legal name, registration identity, jurisdiction and authoritative evidence.
2. **Regulatory scope** — regulator, licence/authorization identifier, current status and permitted activities.
3. **Commercial relationship** — executed contract or other authoritative evidence identifying parties and service scope.
4. **Account/custody** — IBG-02 account evidence, ownership/beneficial-interest classification and operational eligibility.
5. **Technical endpoint** — endpoint ownership, environment, authentication method, network restrictions and provider attestation. Secret values are prohibited from repository/control-plane evidence.
6. **Payment route** — IBG-03 route certification, idempotency, maker-checker, compliance, failure and return tests.
7. **Treasury/liquidity** — IBG-04 source-balance provenance, funding reservation and applicable limits.
8. **Trade finance** — IBG-05 regulated institution-role evidence where issuing/advising/confirming/guarantee capabilities are claimed.
9. **Settlement/finality** — IBG-06 external observations, deterministic reconciliation, exception handling and finality evidence.
10. **Operations** — incident response, rollback, business continuity, credential/key rotation and named operational ownership.

## Environment ladder
`DISCOVERY -> DUE_DILIGENCE -> SANDBOX -> UAT -> PRODUCTION_CANDIDATE -> PRODUCTION_CERTIFIED`

Promotion is fail-closed. A downstream environment cannot compensate for a missing upstream evidence domain.

## Evidence standard
Evidence records should identify evidence type, authoritative issuer/source, immutable reference or controlled storage locator, observation/issue date, expiry where applicable, reviewer and verification status. Repository records must not contain passwords, private keys, API secrets, access tokens, PINs, seed phrases or full credential payloads.

## Production approval
Production certification requires:

- all mandatory domains `VERIFIED` and current;
- no unresolved critical certification exceptions;
- successful UAT using non-production credentials/endpoints;
- exercised payment failure, retry/idempotency and return paths where applicable;
- exercised IBG-06 reconciliation against authoritative external evidence;
- independent maker/checker approval;
- explicit governance approval identifying the exact institution, account, route and environment being certified.

Certification is scoped. Approval of one legal entity, account, rail, currency, endpoint or environment never implicitly certifies another.

## GSF boundary
GSF may be recorded as a strategic institutional enabler where evidence supports that relationship contribution. That designation does not itself certify GSF as a regulated bank, correspondent, custodian, settlement institution, issuing/advising/confirming bank, guarantor, payment processor or production network node.

Until the applicable due-diligence and certification evidence is independently verified, GSF remains fail-closed for executable production routing.

## Revocation
Certification must be suspendable or revocable when evidence expires, regulatory status changes, contracts terminate, endpoint ownership changes, credentials are compromised, reconciliation fails materially, or a critical control exception is opened. Revocation does not delete historical certification evidence.

## Non-authority statement
IBG-07 records certification governance. It cannot grant a banking licence, create a correspondent relationship, open a bank account, create funds, authenticate an external instrument, establish legal title, or manufacture settlement finality.