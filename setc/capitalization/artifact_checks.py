"""Static governance checks for the Capitalization Block repository overlay."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MIGRATIONS = ROOT / "migrations"
REQUIRED_MIGRATIONS = (
    "012_capitalization_foundation.sql",
    "013_capitalization_treasury_interbank.sql",
    "014_capitalization_settlement_governance.sql",
    "015_capitalization_api_projection_security.sql",
    "016_optional_live_page_registry_seed.sql",
)


def _sql_without_comments_and_strings(sql: str) -> str:
    sql = re.sub(r"--[^\n]*", "", sql)
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    sql = re.sub(r"'(?:''|[^'])*'", "''", sql, flags=re.DOTALL)
    return sql


def _check_balanced_sql(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count("$$") % 2:
        errors.append(f"{path.name}: unbalanced dollar-quoted block")

    scrubbed = _sql_without_comments_and_strings(text)
    depth = 0
    for char in scrubbed:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth < 0:
                errors.append(f"{path.name}: closing parenthesis precedes opening parenthesis")
                return
    if depth:
        errors.append(f"{path.name}: unbalanced parentheses ({depth})")

    if "BEGIN;" not in text or "COMMIT;" not in text:
        errors.append(f"{path.name}: migration must be transaction-wrapped")


def _check_authority_boundaries(text: str, path: Path, errors: list[str]) -> None:
    forbidden_dml = re.compile(
        r"\b(?:insert\s+into|update|delete\s+from)\s+(?:wim|source_coin)\.",
        re.IGNORECASE,
    )
    if forbidden_dml.search(_sql_without_comments_and_strings(text)):
        errors.append(f"{path.name}: direct WIM or Source Coin mutation is prohibited")

    if re.search(
        r"\bgrant\s+(?:all|select|insert|update|delete)[^;]*"
        r"\bon\s+(?:table\s+)?capitalization\.[^;]*\bto\s+(?:anon|authenticated)\b",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        errors.append(f"{path.name}: internal capitalization tables must not be client-granted")

    dangerous_secret_patterns = (
        r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
        r"\bservice_role_key\s*=",
        r"\bdatabase_password\s*=",
    )
    for pattern in dangerous_secret_patterns:
        if re.search(pattern, text, flags=re.IGNORECASE):
            errors.append(f"{path.name}: embedded secret or private key pattern detected")


def _check_required_controls(files: dict[str, str], errors: list[str]) -> None:
    foundation = files["012_capitalization_foundation.sql"]
    settlement = files["014_capitalization_settlement_governance.sql"]
    api = files["015_capitalization_api_projection_security.sql"]
    seed = files["016_optional_live_page_registry_seed.sql"]

    required_foundation = (
        "PRODUCTION_SETTLEMENT",
        "PUBLIC_LIVE_NETWORK_CLAIMS",
        "false, 'NO-GO",
        "ENABLE ROW LEVEL SECURITY",
        "ECID-",
    )
    for token in required_foundation:
        if token not in foundation:
            errors.append(f"foundation migration missing required control: {token}")

    required_settlement = (
        "Capitalization Block cannot self-confer settlement finality",
        "requester cannot approve or reject their own request",
        "production settlement gate is disabled",
        "SOURCE_COIN_DOMAIN",
        "idempotency_key text NOT NULL UNIQUE",
    )
    for token in required_settlement:
        if token not in settlement:
            errors.append(f"settlement migration missing required invariant: {token}")

    required_api = (
        "REGISTRY_TARGET",
        "EVIDENCE_BACKED_NON_LIVE",
        "VERIFIED_LIVE",
        "PUBLIC_LIVE_NETWORK_CLAIMS",
        "No external banking relationship",
    )
    for token in required_api:
        if token not in api:
            errors.append(f"public API migration missing required disclosure control: {token}")

    for token in ("'TARGET'", "'NOT_CONNECTED'", "'UNVERIFIED'"):
        if token not in seed:
            errors.append(f"optional registry seed missing safe default: {token}")

    if "'LIVE'" in seed or "'PRODUCTION'" in seed:
        errors.append("optional registry seed must not seed LIVE or PRODUCTION state")

    first_seed_match = re.search(
        r"WITH seed \(.*?\) AS \(\s*VALUES(?P<values>.*?)\),\s*upserted AS",
        seed,
        flags=re.DOTALL,
    )
    if not first_seed_match:
        errors.append("optional registry seed first institution values block was not found")
    else:
        seeded_entries = re.findall(
            r"\(\s*'(?:FI|NODE)-[A-Z0-9-]+'\s*,",
            first_seed_match.group("values"),
        )
        if len(seeded_entries) != 26:
            errors.append(
                f"optional registry seed expected 26 target entries, found {len(seeded_entries)}"
            )

    directory_match = re.search(
        r"CREATE TABLE IF NOT EXISTS capitalization_api\.network_directory \((?P<body>.*?)\n\);",
        api,
        flags=re.DOTALL | re.IGNORECASE,
    )
    if not directory_match:
        errors.append("public network_directory table definition was not found")
    else:
        unsafe_public_columns = (
            "account_reference",
            "balance",
            "committed_amount",
            "settlement_instruction",
            "credential_reference",
            "evidence_reference",
        )
        body = directory_match.group("body").lower()
        for column in unsafe_public_columns:
            if column in body:
                errors.append(
                    f"public network_directory includes prohibited financial/internal field: {column}"
                )


def _check_openapi(errors: list[str]) -> None:
    path = ROOT / "openapi.yaml"
    if not path.exists():
        errors.append("openapi.yaml is missing")
        return

    text = path.read_text(encoding="utf-8")
    for token in (
        "openapi: 3.1.0",
        "/v1/public/network-directory:",
        "/v1/capitalization/settlement-instructions:",
        "/v1/integrations/source-coin/confirmations:",
        "mutualTLS:",
    ):
        if token not in text:
            errors.append(f"openapi.yaml missing required contract token: {token}")

    try:
        import yaml  # type: ignore
    except ImportError:
        return

    try:
        document = yaml.safe_load(text)
    except Exception as exc:  # pragma: no cover - environment-dependent dependency
        errors.append(f"openapi.yaml is not valid YAML: {exc}")
        return

    if not isinstance(document, dict) or document.get("openapi") != "3.1.0":
        errors.append("openapi.yaml did not parse as an OpenAPI 3.1 document")


def main() -> int:
    errors: list[str] = []
    files: dict[str, str] = {}

    for name in REQUIRED_MIGRATIONS:
        path = MIGRATIONS / name
        if not path.exists():
            errors.append(f"missing migration: {name}")
            continue
        files[name] = path.read_text(encoding="utf-8")
        _check_balanced_sql(path, errors)
        _check_authority_boundaries(files[name], path, errors)

    if len(files) == len(REQUIRED_MIGRATIONS):
        _check_required_controls(files, errors)

    _check_openapi(errors)

    if errors:
        print("Capitalization artifact checks failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Capitalization artifact checks passed.")
    print(f"Validated {len(files)} ordered migrations and the OpenAPI contract.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
