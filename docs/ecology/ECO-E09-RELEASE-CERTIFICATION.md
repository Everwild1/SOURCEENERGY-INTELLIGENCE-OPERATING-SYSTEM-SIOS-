# ECO-E09 — Security, Release Assurance & Production Readiness

## Current disposition: CONDITIONAL-GO

The Ecology Block has passed its contract-level engineering sequence through ECO-E08 and may proceed as a bounded, non-economic orchestration/control plane. This disposition does **not** authorize real-value execution, Source Coin production economic effects, treasury mutation, ledger mutation, or settlement finality.

## Evidence established
- ECO-E01–E08 contracts merged through PR #245.
- Ecology Block CI and SETC Core CI passed for the corrected ECO-E08 synthetic closed-loop pilot.
- Authority non-escalation, gateway request-only semantics, deterministic intelligence and regenerative-allocation proposal controls are covered by the Ecology test suite.
- Synthetic loop closes through reinvestment into the next research cycle without production effects.

## Outstanding mandatory production evidence
1. Production gateway authentication/authorization, rate limiting, operational observability and audit policy.
2. Recovery, backup and rollback evidence for production Ecology services/projections.
3. Additive ECO-E04 correction/supersession persistence.
4. Database-enforced domain → source-authority mapping for Ecology references.
5. Independent Source Coin production release authorization; Ecology cannot bypass that gate.
6. Legally authoritative external settlement/counterparty evidence where real settlement is implicated.

## Shared-backend security finding
The known PostGIS-managed shared-backend findings (`public.spatial_ref_sys` RLS posture, PostGIS in `public`, and related SECURITY DEFINER exposure) remain a compatibility-reviewed security tranche. ECO-E09 does not silently modify PostGIS.

## Conditional operating constraints
Until the mandatory production evidence above is satisfied:
- non-economic control-plane/projection operation only;
- no settlement-finality assertion;
- no Source Coin production effects;
- no treasury or ledger mutation;
- no substitution of Ecology evidence for external legal/regulatory/institutional authority;
- no public production gateway without approved authentication and authorization controls.

## Promotion to GO
`GO` requires evidence for every mandatory production control and explicit authorization by the relevant authoritative domains/institutions. Engineering success alone cannot promote Ecology to GO.

## Rollback / incident posture
Any production candidate must have a tested rollback path, recovery point/recovery time objectives, audit-event preservation, idempotent replay handling and an incident owner before promotion from CONDITIONAL-GO.
