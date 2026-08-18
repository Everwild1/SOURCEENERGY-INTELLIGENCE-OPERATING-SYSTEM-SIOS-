# SETC Phase II-D — Security & Release Assurance

## Purpose

This control record establishes engineering release criteria for the SETC Phase II production baseline. It records software assurance evidence only; it is not an external certification, accreditation, legal opinion, financial guarantee, or service-level commitment.

## Production lineage

Phase II-D begins after successful production integration of:

- Phase II-A — Production Hardening & Quality Gates
- Phase II-B — Observability & Operational Diagnostics
- Phase II-C — Ecosystem Integration Contracts

## Required release evidence

A Phase II release candidate must have evidence for:

1. SETC Core CI success.
2. Integration regression coverage.
3. Public API stability checks.
4. Observability contract regression coverage.
5. Ecosystem integration contract regression coverage.
6. Dependency/security review.

Missing required evidence fails the release closed.

## Dependency and security checklist

- Review dependency additions and version changes before release.
- Do not introduce secrets, credentials, tokens, private keys, or environment-specific access material into source control.
- Keep integration consumers behind explicit versioned contracts.
- Treat malformed or unsupported contract/version input as a closed failure.
- Preserve bounded contexts; no hidden imports into external consumer internals.
- Record remediation before release for known high-severity dependency or code-security findings.
- Preserve the `ssr/` boundary unless separately authorized and reviewed.

## Performance baseline

The Phase II-D regression suite includes a lightweight deterministic engineering threshold for canonical SETC identifier mint/parse round trips. This threshold exists to detect severe performance regression in CI and is not an SLA, throughput commitment, or production capacity representation.

## Release decision

Phase II-D may be promoted only when SETC Core CI is green and the required release evidence is complete. Final integration follows the established review and squash-merge control path.