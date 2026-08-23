from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "supabase/migrations/20260823032000_revolution_wealth_governed_registry.sql"
AUTH = ROOT / "supabase/migrations/20260823032100_revolution_wealth_registry_authorization_api.sql"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8").lower()


def test_registry_migration_uses_safe_enum_bootstrap():
    sql = text(REGISTRY)
    assert "create type if not exists" not in sql
    assert sql.count("exception when duplicate_object then null") >= 4


def test_registry_tables_enable_rls():
    sql = text(REGISTRY)
    for table in ("funds", "fund_vehicles", "investment_projects", "investment_assets", "capital_events", "registry_claims"):
        assert f"alter table rw.{table} enable row level security" in sql


def test_private_authorization_boundary_is_fail_closed():
    sql = text(AUTH)
    assert "create schema if not exists rw_private" in sql
    assert "revoke all on schema rw_private from public, anon, authenticated" in sql
    assert "registry_access_memberships" in sql
    assert "organization_participant" in sql


def test_role_binding_is_service_only():
    sql = text(AUTH)
    assert "registry access grants require service role" in sql
    assert "grant execute on function rw_private.grant_registry_access" in sql
    assert "to service_role" in sql
    assert "from public,anon,authenticated" in sql


def test_all_six_registry_tables_have_policies():
    sql = text(AUTH)
    expected = (
        "rw_funds_select", "rw_fund_vehicles_select", "rw_investment_projects_select",
        "rw_investment_assets_select", "rw_capital_events_select", "rw_registry_claims_select",
    )
    for policy in expected:
        assert f"create policy {policy}" in sql


def test_governed_views_are_security_invoker_and_not_anonymous():
    sql = text(AUTH)
    for view in ("registry_fund_overview", "registry_capital_activity", "registry_claim_overview"):
        assert f"view rw.{view} with(security_invoker=true)" in sql
    assert "revoke all on rw.registry_fund_overview,rw.registry_capital_activity,rw.registry_claim_overview from public,anon" in sql


def test_frontend_never_receives_service_role_access():
    sql = text(AUTH)
    # Service role is limited to controlled access binding and server-side reads;
    # authenticated users rely on RLS for the governed views.
    assert "grant select on rw.registry_fund_overview,rw.registry_capital_activity,rw.registry_claim_overview to authenticated,service_role" in sql
