-- HEI-SEC-001 — Validation Function Search-Path Hardening
-- Pin HEI trigger functions to a deterministic trusted schema path.
-- These functions remain SECURITY INVOKER; no privilege elevation is introduced.

ALTER FUNCTION public.hei_validate_commercialization_case() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_funding_allocation() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_funding_receipt() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_institution_opportunity_review() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_investment_commitment() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_investment_decision() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_procurement_award() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_project_financing() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_project_operating_state() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_talent_award() SET search_path = public, pg_temp;
ALTER FUNCTION public.hei_validate_talent_disbursement() SET search_path = public, pg_temp;
