# ECO-PH-03 — Production Gateway Security & Observability

## Purpose

Harden the ECO-E07 transport contract for production-facing adapters while preserving source-domain authority boundaries.

## Enforcement model

Every request is evaluated against an authenticated `GatewayPrincipal`, the canonical ECO-E07 target/action allowlist, a stateful idempotency store, and a deterministic per-principal rate policy. Failure is closed.

Accepted requests are **accepted for review only**. A gateway receipt never proves execution, settlement finality, ledger mutation, treasury action, fiduciary approval, compliance approval, ownership, or source-domain authority.

## Audit posture

Each decision emits a `GatewayAuditRecord` containing request ID, principal ID, target domain, action, correlation ID, decision, rejection reason and timestamp. The audit record deliberately excludes credentials, tokens and secrets.

## Source Coin boundary

`REQUEST_SETTLEMENT` is transport intent only. Ecology cannot bypass the Source Coin release gate, create ledger effects, or manufacture settlement finality. Production Source Coin economic effects remain independently gated.

## Rate and replay controls

The reference implementation provides deterministic in-memory enforcement for contract testing and adapter development. Production adapters MUST bind the same semantics to durable/shared replay and rate-limit state before horizontal or multi-process deployment. In-memory state is not itself production persistence.

## Acceptance evidence

The Ecology test suite covers authenticated/authorized acceptance, unauthenticated rejection, unauthorized rejection, stateful replay rejection, rate-limit rejection, allowlist non-expansion, and non-escalation of execution/finality authority.
