# Media.SourceEnergy — Application Contract v0.1

Parent: #214
Control dependency: #207 / PR #213

## Purpose
Media.SourceEnergy is the governed presentation and orchestration layer for SourceEnergy Media & Communications. It does not become the authoritative system of record for underlying institutional claims.

## Runtime decision
This repository currently has no conventional production frontend scaffold. Do not select a framework implicitly. Framework/runtime selection is a separate architecture decision after visual/product design and deployment-target review.

## Route contract

### Public
- `/` — Media Network home
- `/news` — newsroom feed
- `/intelligence` — intelligence products
- `/research` — research/publications
- `/business`
- `/trade`
- `/capital`
- `/technology`
- `/energy`
- `/infrastructure`
- `/health`
- `/education`
- `/diaspora`
- `/climate`
- `/government`
- `/video`
- `/podcasts`
- `/publications`
- `/press`
- `/organizations/:organizationSlug`
- `/content/:slug` — canonical published content detail
- `/content/:slug/corrections` — correction/supersession history

### Authenticated workspace
- `/workspace` — role-aware command center
- `/workspace/assignments`
- `/workspace/content`
- `/workspace/content/:contentId`
- `/workspace/content/:contentId/evidence`
- `/workspace/content/:contentId/reviews`
- `/workspace/content/:contentId/approvals`
- `/workspace/assets`
- `/workspace/channels`
- `/workspace/distribution`
- `/workspace/incidents`
- `/workspace/analytics`

## Public read boundary
Public clients may receive only content whose governed state is publishable/published for the requested version. Drafts, internal reviews, private evidence, role assignments and outbox internals are never public read models.

Required public content projection:
- content ID / slug
- title / summary / rendered body
- organization identity
- content type / representation class
- published version
- published timestamp
- authors/contributors where approved for disclosure
- source/provenance indicators safe for public disclosure
- correction/supersession state
- public rights/license metadata where applicable

## Authenticated command boundary
Browser clients must never receive service-role credentials. Mutations are authorized by Supabase Auth + RLS and governed RPC/command boundaries.

Required commands:
- transition lifecycle: `setc_media_transition`
- publish: `setc_media_publish`
- emit controlled event: `setc_media_emit_event`
- enqueue governed delivery: `setc_media_enqueue_outbox`

The UI MUST NOT implement publication by directly updating `lifecycle_status='PUBLISHED'`.

## Workspace capability mapping
- Contributor: assignments, drafts, sources
- Fact Validator: claims/evidence validation
- Editor: editorial review/version coordination
- Domain Reviewer: specialized review queues
- Approver: institutional approval queue
- Publisher: publication command + official-channel distribution
- Rights Manager: asset rights/licensing
- Incident Manager: corrections/crisis/reputation operations
- Analyst: governed metrics/read-only intelligence
- Administrator: authorization administration subject to delegated authority

UI affordances are not authorization. The database permission model remains authoritative.

## Application states
Every command surface must render explicit states for loading, unauthorized, insufficient authority, blocked by evidence, blocked by review, ready, command submitted, success, conflict/stale version and system failure.

## Publication UX invariant
The Publish action is enabled only when the user has publish authority and the backend readiness guard returns true. The client may explain blockers but must not reproduce or override the authoritative readiness decision.

## Evidence UX invariant
Material claims display verification state and authoritative-source requirement. Financial, regulatory, governmental, partnership, scientific and corporate claims receive heightened review treatment. Media roles cannot self-create underlying authority.

## Corrections
Corrections and supersessions remain visible in publication history. Never silently overwrite a materially published version.

## Distribution
External delivery is driven from governed event/outbox state. A DELIVERED transport result means only that transport succeeded; it does not validate the content's underlying claim.

## Security
- no service-role secret in browser bundles
- no direct client writes that bypass governed commands for protected transitions
- organization scope carried through authenticated session/RLS
- deny by default on missing authority
- sanitize rendered rich content
- CSP and secure headers required at deployment layer
- audit/correlation IDs propagated for governed commands

## Accessibility / responsive contract
- WCAG-oriented semantic structure and keyboard operation
- visible focus state
- accessible status/error announcements
- mobile/tablet/desktop layouts
- editorial tables/queues must have responsive alternatives

## Design gate
This file defines behavior and information architecture only. Production visual styling/component selection should follow an approved product-design target; implementation must preserve the control boundaries above regardless of visual system.
