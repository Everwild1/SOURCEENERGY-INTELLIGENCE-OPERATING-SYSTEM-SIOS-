# IBG-02 — Account & Custody Registry

Status: Draft implementation contract
Issue: #111

## Decision

IBG-02 extends `capitalization.treasury_accounts`; it does not introduce a second generic bank-account table. The existing Capitalization schema remains the authoritative internal account registry.

## Authority boundary

A registry row is reference metadata, not proof of account existence, ownership, custody, banking relationship, regulatory standing, payment authority, settlement authority, or external-bank finality.

Bank money, Source Coin, and SETC/SIOS records remain separate domains. IBG-02 does not initiate payments (IBG-03), orchestrate liquidity (IBG-04), execute trade finance (IBG-05), or establish settlement finality (IBG-06).

## Account activation gate

An account may become `ACTIVE` or `PRODUCTION_ELIGIBLE` only when all applicable controls are satisfied:

- custodian institution exists in the IBG institution registry;
- institution is `VERIFIED` and `APPROVED` or `ACTIVE`;
- an evidence-backed contracted/integrated institutional relationship exists;
- the account itself is `VERIFIED` with a verification timestamp;
- the external account identifier is opaque (`vault:`, `token:`, `masked:`, or `provider:` under the existing constraint);
- current verified `ACCOUNT_EXISTENCE` evidence exists;
- no current active account restriction exists.

`PRODUCTION_ELIGIBLE` is an internal eligibility classification only. It does not itself authorize a payment or prove settlement finality.

## Custody gate

A custody arrangement cannot become `CONTRACTED` or `ACTIVE` unless the custodian institution is verified and approved/active and an evidence-backed custody-capable institutional relationship exists. Contracted/active custody also requires an agreement reference and verification evidence.

## Sensitive-data policy

Raw account numbers, credentials, API keys, private banking credentials, PINs, signing material, and raw evidence documents are prohibited from public/read models. Application-facing projections may expose masked references only.

The authenticated `capitalization_api.account_registry` view contains no balances, credentials, evidence documents, or raw account numbers.

## GSF Banking

GSF Banking remains `TARGET / UNVERIFIED / NOT_CONNECTED` under IBG-01. Consequently, the parent-institution gate prevents any GSF-linked treasury account or custody arrangement from becoming active or production eligible until independent evidence supports institutional promotion.

## Fail-closed behavior

Restrictions, evidence expiry, institution demotion, or failed verification are intended to block promotion and downstream payment/settlement eligibility. Operational services must re-check eligibility at execution time rather than treating an earlier registry state as permanent authority.
