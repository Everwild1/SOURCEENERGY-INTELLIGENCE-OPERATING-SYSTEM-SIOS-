# IBG-06 — Settlement Reconciliation & Finality Control Plane

## Purpose
IBG-06 is the final control layer in the initial Institutional Banking Gateway sequence. It classifies settlement only after retained external evidence is matched and reconciled to an IBG-03 payment instruction under governed approval.

## Core distinction
IBG-03 `COMPLETED` means the payment orchestration layer has recorded provider completion under its own controls. It is not settlement finality. IBG-06 `FINAL` requires authoritative external evidence, deterministic amount/asset consistency, successful reconciliation, no unresolved exceptions, and checker approvals.

## External evidence
Settlement observations are append-only and require an external reference plus retained evidence. Permitted source classifications include bank statements, bank APIs, payment providers, correspondents, custodians, clearing rails and manually verified external evidence. Classification of a source does not itself authenticate the source; evidence governance remains required.

## Matching and reconciliation
An observation is matched to an IBG-03 payment instruction. Reconciled/finality states require amount and asset equality across the external observation, match and payment instruction. Value date and counterparty comparisons are retained as independent matching dimensions and may generate exceptions.

Duplicate external observations are constrained by a deterministic uniqueness key and conflicting evidence must be routed to exception review rather than overwritten.

## Finality gate
`FINAL` requires:
1. IBG-03 payment state `COMPLETED`;
2. a `MATCHED` settlement match;
3. amount and asset equality;
4. external evidence/reference;
5. reconciliation and finality checker approvals;
6. zero unresolved exceptions;
7. an observation that has not been returned, reversed or rejected.

This is a governed internal classification of evidence. It does not create money, change an external bank ledger, manufacture a provider acknowledgement, or replace the legal effect of the underlying payment rail.

## Returns and reversals
Returns and reversals never rewrite the original observation or finality event. They transition the reconciliation into an exception state and append a new provenance event, preserving the prior evidence chain.

## Trade-finance linkage
A settlement observation may reference an IBG-05 trade-finance claim. That relationship permits reconciliation of a claim-driven payment while preserving the IBG-05 → IBG-03 → IBG-06 authority chain.

## Source Coin boundary
Source Coin and external bank-money settlement remain distinct settlement domains. A Source Coin ledger event, token transaction hash or internal ecosystem state cannot be used as proof of external bank-money finality unless a separately governed bridge defines the legal, operational and reconciliation relationship.

## Institutional boundary
GSF or any other institution's strategic role, dashboard representation, logo, introduction, correspondence or credibility contribution does not make that institution the settlement-finality authority. Institution-specific settlement evidence must be independently retained and governed.

## Non-authority statement
Screenshots, PDFs, SWIFT-formatted text, transaction hashes, internal ledgers, website claims, dashboard states, provider messages, instrument identifiers and relationship statements do not independently establish external settlement or finality.

## Sequence completion
With IBG-06 merged, IBG-01 through IBG-06 provide the initial institutional-banking governance control plane: institution registry, accounts/custody, payment orchestration, treasury/liquidity, trade finance, and settlement reconciliation/finality. Production connectivity remains a separate evidence-gated deployment concern.
