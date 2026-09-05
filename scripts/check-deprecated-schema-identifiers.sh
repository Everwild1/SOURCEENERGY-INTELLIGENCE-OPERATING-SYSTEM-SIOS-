#!/usr/bin/env bash
set -euo pipefail

# SourceEnergy schema-contract guard.
# Deprecated identifiers must not be reintroduced into application code or migrations.
DEPRECATED_REGEX='\badapter_code\b'

# Search tracked source/config/migration files while excluding this guard itself and governance documentation.
if git grep -n -E "$DEPRECATED_REGEX" -- \
  ':!scripts/check-deprecated-schema-identifiers.sh' \
  ':!docs/governance/deprecated-schema-identifiers.md'; then
  echo "ERROR: deprecated SourceEnergy schema identifier detected."
  echo "adapter_code is noncanonical. Use the governed subsystem contract (for example adapter_key, adapter_command_id, or insurance_adapter_system_id) only where that contract applies."
  exit 1
fi

echo "Schema identifier governance check passed."
