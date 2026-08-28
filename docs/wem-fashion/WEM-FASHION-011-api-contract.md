# WEM-FASHION-011 — WF-DB-002 Governed API Contract

Status: implementation baseline

## Purpose

WF-DB-002 exposes the promoted `fashion` bounded context without creating a second authority for identity, rights, market execution, logistics, capitalization, settlement, certification, or title.

## Trust boundary

Client applications MUST NOT receive direct table mutation privileges. The Fashion schema remains service-mediated. API implementations use server-side credentials and enforce application authorization before database access.

Authoritative domains remain:
- SETC: organization identity
- CRUDS/SEAE: creator/work, rights, licenses, consent, production evidence
- WIM: market organization, offering, opportunity and transaction execution
- GSC: commodities and supply nodes
- RGL: orders and shipments
- capitalization domains: financing and capital decisions
- settlement domains: payment/finality

Fashion owns only fashion-specific brand projections, designs, collections, materials, product models, SKUs, production planning/batches, serialized product instances, RefleX evidence links and circular lifecycle evidence.

## Service contract

Base path: `/api/v1/fashion`

### Registry reads
- `GET /brands`
- `GET /brands/{id}`
- `GET /designs`
- `GET /designs/{id}`
- `GET /collections`
- `GET /collections/{id}`
- `GET /materials`
- `GET /materials/{id}`
- `GET /products`
- `GET /products/{id}`
- `GET /skus/{id}`
- `GET /instances/{id}`
- `GET /instances/{id}/lifecycle`

### Governed writes
- `POST /brands`
- `PATCH /brands/{id}`
- `POST /designs`
- `PATCH /designs/{id}`
- `POST /collections`
- `PATCH /collections/{id}`
- `POST /materials`
- `PATCH /materials/{id}`
- `POST /products`
- `PATCH /products/{id}`
- `POST /skus`
- `PATCH /skus/{id}`
- `POST /production-orders`
- `PATCH /production-orders/{id}`
- `POST /production-batches`
- `PATCH /production-batches/{id}`
- `POST /instances`
- `PATCH /instances/{id}` only for current projection fields; never historical event mutation
- `POST /instances/{id}/lifecycle-events`
- `POST /reflex-evidence-links`

There is deliberately no UPDATE or DELETE lifecycle-event endpoint.

## Mutation rules

1. All external authority references must resolve before a Fashion record is committed.
2. Rights/licensing/consent fields are references to SEAE authority and must never be converted into Fashion ownership assertions.
3. WIM references may establish market projections but Fashion endpoints must not execute settlement.
4. RGL references may bind logistics records but Fashion endpoints must not create shipment finality outside RGL.
5. Lifecycle events are append-only evidence. Corrections are represented by a later event or governed supersession evidence, never by rewriting history.
6. `verification_state=verified` requires an authorized evidence-verification workflow; ordinary registry writers cannot self-verify.
7. Certification metadata is descriptive evidence only unless backed by an authoritative certification record.

## Response envelope

Successful object responses use:

```json
{
  "data": {},
  "meta": {
    "domain": "fashion",
    "authority": "projection",
    "request_id": "uuid"
  }
}
```

Errors use:

```json
{
  "error": {
    "code": "FASHION_CONTRACT_ERROR",
    "message": "Human-readable description",
    "request_id": "uuid"
  }
}
```

## Required application roles

- `fashion_reader`: governed registry reads
- `fashion_editor`: mutable Fashion projection writes
- `fashion_production_operator`: production-order and batch operations
- `fashion_lifecycle_recorder`: append lifecycle evidence
- `fashion_evidence_submitter`: submit RefleX/evidence links
- `fashion_evidence_verifier`: controlled evidence verification
- `fashion_admin`: administrative projection controls; does not supersede external authorities

Role names are application-level contracts and do not grant database access by themselves.

## Acceptance tests

WF-DB-002 must prove:
- anonymous/authenticated clients cannot mutate `fashion` tables directly;
- service-mediated registry reads and permitted writes succeed;
- invalid external authority references fail closed;
- lifecycle history cannot be updated or deleted through the API;
- ordinary evidence submitters cannot mark evidence verified;
- no Fashion endpoint performs settlement mutation;
- no Fashion endpoint creates legal-rights assertions from registry metadata;
- request IDs and audit context are emitted for governed writes.

## Promotion gate

WF-DB-002 is promotable only when the executable service adapter, authorization middleware, contract tests and CI gate implement this contract without weakening WF-DB-001 RLS or append-only controls.
