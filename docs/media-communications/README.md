# SourceEnergy Media & Communications — Integration Contract v1

Governing work: #207, #211, #212.

## Control hierarchy
SOL-024 -> SETC-089 -> M&C-01..12 -> SIOS/Supabase -> distribution endpoints.

## Authoritative boundary
Media records communicate approved information. They do not independently establish legal, financial, regulatory, governmental, scientific, partnership, ownership, or transaction truth. Material claims must trace to authoritative evidence and competent authority.

## Lifecycle
IDEA -> ASSIGNED -> DRAFT -> FACT_VALIDATION -> EDITORIAL_REVIEW -> DOMAIN_REVIEW -> APPROVAL_PENDING -> APPROVED -> SCHEDULED -> PUBLISHED.

Post-publication states: CORRECTED, SUPERSEDED, ARCHIVED, WITHDRAWN.

`PUBLISHED` must be reached through `setc_media_publish`, not the generic transition command.

## RPC commands
### setc_media_transition(content_id, target_status, reason)
Permission-gated lifecycle transition. Emits `media.content.status_changed`.

### setc_media_publish(content_id, external_url)
Requires `media.publish` and `setc_media_publication_ready(content_id)`. Emits `media.content.published`.

### setc_media_emit_event(event_type, content_id, payload, correlation_id, causation_id)
Emits a controlled Media event for an authorized organization context.

### setc_media_enqueue_outbox(event_id, destination_type, destination_key, idempotency_key)
Creates or resolves an idempotent delivery item. Requires publish authority.

## Event envelope
Every event supports: `event_id`, `event_type`, `event_version`, `aggregate_type`, `aggregate_id`, `organization_oid`, `content_id`, `actor_user_id`, `correlation_id`, `causation_id`, `payload`, `occurred_at`.

Initial event vocabulary:
- `media.content.status_changed`
- `media.content.published`

Consumers must ignore unknown additive payload fields. Breaking semantic changes require a new `event_version`.

## Outbox
`setc_media_outbox` is the transport queue. Unique `(destination_type, destination_key, idempotency_key)` prevents duplicate queue creation for the same delivery intent.

Delivery states: PENDING -> PROCESSING -> DELIVERED; failures may move through FAILED to DEAD_LETTER. Transport success is not evidence that an underlying institutional claim is true.

## Required CI controls
1. Anonymous access denied.
2. Authenticated user without Media role denied.
3. Cross-organization access denied.
4. Expired/revoked role denied.
5. Contributor cannot publish without publish permission.
6. Unverified required claim blocks publication.
7. Missing current-version approval blocks publication.
8. Generic transition cannot set PUBLISHED.
9. Duplicate outbox idempotency key does not create a second delivery intent.
10. Event correlation/causation survives the SIOS orchestration path.

## Current provisioning constraint
The connected Supabase environment had no Auth principals when the RBAC gate was established. Real-principal RLS integration tests therefore remain gated on identity provisioning; tests must not fabricate production authority assignments.