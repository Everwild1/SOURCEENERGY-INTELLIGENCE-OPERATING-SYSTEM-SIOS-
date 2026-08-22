# SSR Legacy Source Recovery Runbook

**Control:** Issue #133  
**Downstream ingestion gate:** Issue #2  
**Scope:** March-April 2026 SourceEnergy Spatial Registry (SSR / Scroll #411) activation evidence recovery.

## 1. Purpose
Recover the original machine-level SSR source artifact or machine-verifiable ledger trail without reconstructing canonical AnchorTile identities from narrative or downstream material.

## 2. Fail-closed rule
Until an authoritative source artifact passes provenance and integrity validation:
- do not populate canonical AnchorTile identities from inferred data;
- do not generate What3Words addresses;
- do not treat placeholder `Cube-###` values as canonical identities;
- do not promote review candidates to canonical Cube UIDs;
- preserve the production activation state as blocked.

## 3. Priority recovery targets
1. March 2026 SSR architecture-review deliverable and attachments.
2. March 3 activation registry export / registration batch.
3. April 5 Bernard Lodge 729-unit activation source file.
4. Fire-Pulse execution or reconciliation logs.
5. Codex 1038 synchronization logs/endpoints.
6. Digital Witness (#222) attestation records.
7. Blockchain Covenant (#311) wallet/contract/transaction evidence.
8. Legacy datastore/API/object-store/backup predating 2026-04-28.
9. Operator-local archives and exported communications attachments.

## 4. Expected provenance fingerprint
Preserve any available values for:
- anchor_tile_id
- source-supplied w3w_address
- WGS84 latitude / longitude
- projected CRS
- scroll/domain assignment
- activation timestamp
- authority signature
- SHA-256 metadata hash
- source system and environment
- source record / registration batch identifier
- source export timestamp
- audit/event UID
- previous state hash
- new state hash
- Digital Witness attestation reference
- blockchain network, wallet, contract, transaction hash, block number and receipt

Missing fields do not authorize reconstruction. They trigger governance review.

## 5. Acquisition chain of custody
For every candidate artifact:
1. Preserve original bytes unchanged.
2. Record original filename, path/URL, account/device/system and custodian.
3. Record acquisition timestamp in UTC.
4. Compute SHA-256 before transformation.
5. Store raw artifact separately from normalized derivatives.
6. Never edit, deduplicate, geocode, infer, regenerate or repair source identities in the raw copy.
7. Record every transformation applied to a derivative.
8. Validate row count, uniqueness, coordinates, timestamps, signatures and hashes.
9. Route discrepancies to human governance review.
10. Only Issue #2 may authorize canonical staging/loading after acceptance.

## 6. Recovery sequence
Search in this order unless a new machine identifier provides a stronger lead:
1. Organizational Microsoft 365 / licensed Teams tenant.
2. Organizational SharePoint / OneDrive or direct legacy file URLs.
3. Other SourceEnergy mailboxes/workspaces.
4. Other GitHub accounts/orgs and repository backups.
5. Operator-local workstation/archive.
6. Historical cloud/object-storage backup.
7. Fire-Pulse / Codex 1038 runtime estate.
8. Digital Witness archive.
9. Blockchain deployment/account history.

Do not repeat an exhausted broad search unless new identifiers emerge.

## 7. Candidate artifact intake record
For each recovered item create an evidence record containing:

| Field | Required |
|---|---|
| Evidence ID | Yes |
| Original filename | Yes |
| Source system/account | Yes |
| Source path/URL | When available |
| Custodian/operator | Yes |
| Acquisition UTC | Yes |
| SHA-256 | Yes |
| Original byte size | Yes |
| MIME/file type | Yes |
| Activation linkage | Yes |
| Raw/derivative status | Yes |
| Reviewer | Before promotion |
| Governance disposition | Before promotion |

## 8. Acceptance gates
A recovered 729-row roster may advance to Issue #2 only when:
- provenance links it to the March-April 2026 SSR activation or authoritative registry source;
- original bytes are preserved and checksummed;
- expected row count and uniqueness controls pass;
- coordinates and activation timestamps are valid;
- source-supplied identity fields are distinguishable from later derived fields;
- discrepancies are documented;
- governance reviewer explicitly accepts the artifact for staging.

Machine-verifiable ledger evidence may be accepted as a provenance bridge even if it is not itself the roster, but it does not authorize synthesizing missing roster values.

## 9. Downstream restart protocol
After Issue #2 accepts the source artifact:
1. preserve raw evidence;
2. load only to controlled ingestion staging;
3. run exact-count/uniqueness/provenance validation;
4. load accepted AnchorTiles to canonical storage;
5. generate review-only RGL spatial candidates;
6. perform human/governance approval;
7. resolve deterministic Cube identities;
8. audit and publish activation-state transition.

## 10. Current boundary
Connected production systems are the reconstruction/production target, not proof of the historical March-April activation datastore. Canonicalization remains fail-closed until authoritative provenance is recovered.