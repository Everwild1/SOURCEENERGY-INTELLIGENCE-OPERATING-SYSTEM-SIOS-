# Epic 37 — SETC Organizations Integration, Regression & Release Closure

## Purpose

Epic 37 closes the SETC Organizations delivery stream after Epics 1–36 by establishing an integration and regression release gate over the governance stack already represented on `main`.

## Production lineage

The release baseline is the current `main` lineage through Epic 36. Epic 37 does not introduce a new institutional power domain. It validates that the accumulated organization, authority, policy, risk, compliance, adjudication, execution, audit, and assurance surfaces remain importable and coherently exported as one package.

## Release controls

1. The implementation branch must originate from current `main`.
2. Representative governance modules must import successfully as an integrated stack.
3. Representative public symbols must resolve through `setc.organizations`.
4. The package public export registry must contain no duplicate names.
5. SETC Organizations release-closure work must not modify or couple to the existing `ssr/` subsystem.
6. The implementation PR remains Draft until SETC Core CI is green.
7. Promotion requires successful CI evidence and review; final integration should use the repository's established squash-merge control path.

## Stale branch governance

Historical SETC branches whose unique changes are already represented on `main` are classified as **superseded / retained for history** and must not be promoted as new architecture. A branch with a genuine delta must be reviewed against the current production lineage before any new PR is created.

## Closure evidence

Epic 37 adds root-level integration regression coverage so the SETC Core CI gate exercises package-level integration in addition to domain-local tests. Completion of this Epic is the release-readiness checkpoint for the Epics 1–36 Organizations stack.

## Boundary

This record makes no representation of legal authority, accreditation, credential status, financial entitlement, or institutional endorsement. It is a software governance and release-control artifact.