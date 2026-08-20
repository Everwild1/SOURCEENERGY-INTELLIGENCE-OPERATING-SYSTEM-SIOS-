# WITC Taxonomy Verification Record

**Source:** https://wimexchange.com/the-west-indies-trading-company/  
**Verification date:** 2026-08-20  
**Program:** WIM-E02 / GitHub #91

## Verified source structure

The live West Indies Trading Company page enumerates:

- 51 traded clusters, source numbers 1 through 51.
- 16 local clusters, source numbers 101 through 116.
- subcluster headings under the cluster registry that must be loaded only through source-backed extraction and validation.

## Correction to provisional seed

The initial WIM seed contained 50 traded + 16 local records and locally renumbered the local clusters 1..16. That seed was explicitly provisional and non-canonical. On source reconciliation it was replaced before any organization memberships, offerings, opportunities, or research assets referenced those rows.

The verified registry now preserves WITC source numbering: traded 1..51 and local 101..116. Canonical WIM codes remain namespace-safe (`WIM-T01`..`WIM-T51`, `WIM-L01`..`WIM-L16`) while `source_cluster_number` preserves the source's numbering.

## Duplicate / alias disposition

The provisional duplicate labels and shifted mappings were extraction artifacts, not canonical aliases. They are not retained as production synonyms. Future aliases require an explicit source/evidence record and must resolve to one canonical WIM cluster.

## Provenance controls

1. Source URL and verification date are recorded.
2. Registry range/count invariants are executable in `taxonomy.py` and CI tests.
3. Evidence captures may be hashed using SHA-256 to detect later source drift.
4. A future source change must not silently overwrite canonical meaning; it requires a versioned reconciliation/migration.
5. Subclusters remain a separate verification tranche and must not be invented from cluster names.

## Database reconciliation

The authoritative SourceEnergy command backend has been reconciled to 67 verified top-level clusters: 51 traded and 16 local. The correction was safe because no downstream WIM membership, offering, opportunity, or research records existed at migration time.
