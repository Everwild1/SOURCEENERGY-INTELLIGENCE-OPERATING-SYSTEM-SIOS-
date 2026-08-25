# SourceEnergy Wealth Advisors — Phase VI-D

Governed React/Vite experience layer for the Wealth Advisors data plane.

## Surfaces
- Executive Command Center → `wa_executive_command_summary`
- Client Portfolio → `wa_client_portal_overview`
- Advisor Workbench → `wa_advisor_crm_queue`
- Capital Pipeline → `wa_capital_pipeline`

All application reads execute as the authenticated Supabase user. The database security-invoker views and underlying RLS remain the authorization boundary.

## Local
```bash
cp .env.example .env
npm install
npm run dev
```

## Production
Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in the deployment environment, run `npm run build`, and serve `dist/` over HTTPS. The publishable key is intentionally client-safe; never place a service-role or secret key in this application.

## Gate VI-D
Before production release: validate role-specific test users, confirm auth redirect/domain configuration, run responsive/accessibility QA, and confirm executive/CRM views return only authorized rows.