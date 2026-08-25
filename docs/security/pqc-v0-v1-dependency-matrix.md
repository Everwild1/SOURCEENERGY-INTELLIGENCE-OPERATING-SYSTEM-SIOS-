# PQC V0/V1 — Supabase Dependency & Migration Matrix

Status: V0 REPOSITORY SWEEP COMPLETE / OPERATIONAL INVENTORY PENDING
Date: 2026-08-25

## Repository sweep
Indexed SIOS source was searched for committed references to:
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `createClient(`
- `supabase.co`
- `net.http_post`
- `Authorization`
- `secrets.`

No indexed committed matches were returned for these patterns.

This is evidence of no detected committed dependency in the indexed repository; it is not evidence that deployment platforms, GitHub Actions secret stores, external applications, mobile clients, webhooks, cron jobs, workers, or third-party integrations have no dependency.

## V1 migration matrix
| Surface | Legacy dependency | Target | State | Retirement authority |
|---|---|---|---|---|
| Browser/public client | anon JWT key | `sb_publishable_*` | No committed dependency detected; runtime inventory pending | V9 human gate |
| Mobile/desktop public client | anon JWT key | `sb_publishable_*` | External inventory pending | V9 human gate |
| Server/backend | service_role JWT key | `sb_secret_*` | No committed dependency detected; runtime inventory pending | V9 human gate |
| GitHub Actions | anon/service_role secret | publishable or secret according to privilege | Secret-store inventory pending | V9 human gate |
| Edge Functions | legacy JWT/API-key behavior | reviewed per function | Platform inventory pending | V9 human gate |
| Database webhooks / pg_net | legacy JWT/API key | new secret key in `apikey` header where required | Database inventory pending | V9 human gate |
| Cron/workers | legacy API key | publishable/secret according to privilege | Runtime inventory pending | V9 human gate |
| External integrations | legacy API key | scoped modern key | Counterparty inventory pending | V9 human gate |

## Rules
1. Do not deactivate a legacy key because repository search returns zero matches.
2. Secret-store values must never be copied into this document or the PQC database inventory.
3. Record only key type, owner, runtime, purpose, rotation state, and verification evidence.
4. `sb_secret_*` keys are privileged backend credentials and must never be exposed to public clients.
5. API-key modernization and JWT-signing-key modernization remain separate workstreams.
6. Modern RSA/ECC JWT signing does not constitute PQC completion.
7. V3 requires evidence of zero remaining legacy dependencies across every operational surface before V9 retirement authorization can be requested.

## Next evidence requirements
- Supabase project API-key inventory: key types/status only, no key values.
- Supabase Auth signing-key inventory: algorithm/status only.
- Edge Function inventory and auth mode.
- Database webhook/pg_net/cron inventory.
- GitHub Actions workflow references and secret-name inventory where accessible without revealing secret values.
- External deployment/runtime inventory.

## Gate state
V0 repository committed-code sweep: PASSED.
V0 operational dependency inventory: PENDING.
V1 public-client migration: NOT YET REQUIRED BY REPOSITORY EVIDENCE / RUNTIME VERIFICATION PENDING.
V2 backend migration: RUNTIME VERIFICATION PENDING.
V3 legacy zero-dependency evidence: NOT ESTABLISHED.
V9 legacy retirement: PROHIBITED UNTIL V3/V8 PASS AND HUMAN AUTHORIZATION.
