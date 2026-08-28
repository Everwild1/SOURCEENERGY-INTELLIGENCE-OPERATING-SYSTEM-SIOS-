from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "wem-fashion" / "WEM-FASHION-011-api-contract.md"
FOUNDATION = ROOT / "supabase" / "migrations" / "20260827185837_wem_fashion_wf_db_001_foundation.sql"
HARDENING = ROOT / "supabase" / "migrations" / "20260827190352_wem_fashion_wf_db_001_append_only_hardening.sql"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_contract_declares_service_mediated_trust_boundary():
    text = read(CONTRACT)
    assert "Client applications MUST NOT receive direct table mutation privileges" in text
    assert "server-side credentials" in text


def test_contract_preserves_external_authorities():
    text = read(CONTRACT)
    for authority in ("SETC", "CRUDS/SEAE", "WIM", "GSC", "RGL", "settlement"):
        assert authority in text


def test_contract_has_no_lifecycle_update_or_delete_endpoint():
    text = read(CONTRACT)
    assert "POST /instances/{id}/lifecycle-events" in text
    assert "no UPDATE or DELETE lifecycle-event endpoint" in text


def test_contract_requires_separate_evidence_verifier_role():
    text = read(CONTRACT)
    assert "fashion_evidence_submitter" in text
    assert "fashion_evidence_verifier" in text
    assert "ordinary evidence submitters cannot mark evidence verified" in text


def test_foundation_keeps_client_roles_revoked():
    text = read(FOUNDATION)
    assert "revoke all on schema fashion from anon, authenticated" in text
    assert "revoke all on all tables in schema fashion from anon, authenticated" in text


def test_lifecycle_database_hardening_is_append_only():
    text = read(HARDENING)
    assert "circular_lifecycle_events" in text
    assert "grant select, insert" in text.lower()
    assert "update" in text.lower() and "delete" in text.lower()
