# CRUDS Universe frontend

Responsive React/Vite implementation for CRUDS-E09. The build preserves the live CRUDS wordmark, magenta editorial identity, Wall of Creatives artwork and six canonical archetypes while exposing the E01–E08 operating loop.

## Local development

```sh
npm ci --no-audit --no-fund
npm run dev -- --host 0.0.0.0 --port 4173 --strictPort
```

Without `VITE_CRUDS_API_URL`, the app uses a clearly labelled preview dataset. Configure the variable with the approved CRUDS gateway base URL to load `GET /universe`; direct browser access to Supabase is intentionally unsupported.

## Verification

```sh
npm test
npm run build
npm run test:sites
```

See [API_CONTRACT.md](API_CONTRACT.md) for the E01–E08 table mapping and authority-safe command boundaries.
