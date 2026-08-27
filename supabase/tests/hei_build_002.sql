BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','HEI Test University','hei test university','UNIVERSITY','VERIFIED');
INSERT INTO public.hei_institution_profiles(organization_oid,qualification_state)
VALUES ('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','VERIFIED');

INSERT INTO public.hei_fiduciary_authorities(organization_oid,authority_type,authority_scope,status,effective_at)
VALUES ('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','BOARD','ENDOWMENT','ACTIVE',now());

INSERT INTO public.hei_endowment_pools(organization_oid,legal_owner_organization_oid,pool_reference,pool_type,currency_code,status)
VALUES ('SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','CORE','CORE_ENDOWMENT','USD','ACTIVE');

INSERT INTO public.hei_investment_policy_statements(organization_oid,policy_reference,version,status,effective_at,approved_by_authority_id)
SELECT 'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','IPS',1,'APPROVED',now(),id
FROM public.hei_fiduciary_authorities WHERE organization_oid='SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

INSERT INTO public.hei_fund_restrictions(endowment_pool_id,restriction_type,restriction_source,purpose,status)
SELECT id,'DONOR','GIFT_INSTRUMENT','SCHOLARSHIPS','ACTIVE' FROM public.hei_endowment_pools WHERE pool_reference='CORE';

INSERT INTO public.hei_spending_policies(organization_oid,endowment_pool_id,calculation_method,spending_rate,restriction_override_prohibited,status,approved_by_authority_id)
SELECT 'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',p.id,'TRAILING_AVERAGE',0.05,true,'ACTIVE',a.id
FROM public.hei_endowment_pools p CROSS JOIN public.hei_fiduciary_authorities a
WHERE p.pool_reference='CORE' AND a.organization_oid='SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

INSERT INTO public.hei_strategic_allocations(endowment_pool_id,ips_id,asset_class,target_weight,minimum_weight,maximum_weight)
SELECT p.id,i.id,'PUBLIC_EQUITY',0.50,0.30,0.70 FROM public.hei_endowment_pools p CROSS JOIN public.hei_investment_policy_statements i
WHERE p.pool_reference='CORE' AND i.policy_reference='IPS';

INSERT INTO public.hei_investment_decisions(organization_oid,endowment_pool_id,ips_id,decision_authority_id,lifecycle_state,ips_compatible,conflict_review_state)
SELECT 'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',p.id,i.id,a.id,'APPROVED',true,'CLEARED'
FROM public.hei_endowment_pools p CROSS JOIN public.hei_investment_policy_statements i CROSS JOIN public.hei_fiduciary_authorities a
WHERE p.pool_reference='CORE' AND i.policy_reference='IPS' AND a.organization_oid='SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.hei_endowment_pools WHERE endowment_cross_collateralization) THEN RAISE EXCEPTION 'endowment firewall default failed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.hei_spending_policies WHERE restriction_override_prohibited) THEN RAISE EXCEPTION 'restriction override firewall failed'; END IF;
  BEGIN
    INSERT INTO public.hei_strategic_allocations(endowment_pool_id,ips_id,asset_class,target_weight,minimum_weight,maximum_weight)
    SELECT p.id,i.id,'INVALID',0.20,0.30,0.10 FROM public.hei_endowment_pools p CROSS JOIN public.hei_investment_policy_statements i
    WHERE p.pool_reference='CORE' AND i.policy_reference='IPS';
    RAISE EXCEPTION 'invalid allocation range accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.hei_investment_decisions(organization_oid,endowment_pool_id,ips_id,decision_authority_id,lifecycle_state,ips_compatible,conflict_review_state)
    SELECT 'SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',p.id,i.id,a.id,'APPROVED',false,'CLEARED'
    FROM public.hei_endowment_pools p CROSS JOIN public.hei_investment_policy_statements i CROSS JOIN public.hei_fiduciary_authorities a
    WHERE p.pool_reference='CORE' AND i.policy_reference='IPS' AND a.organization_oid='SETC-OID-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    RAISE EXCEPTION 'IPS-incompatible approval accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM = 'IPS-incompatible approval accepted' THEN RAISE; END IF;
  END;
  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname LIKE 'hei_%'
      AND c.relname IN ('hei_fiduciary_authorities','hei_endowment_pools','hei_investment_policy_statements','hei_fund_restrictions','hei_spending_policies','hei_investment_mandates','hei_strategic_allocations','hei_investment_decisions','hei_endowment_account_links')
      AND NOT c.relrowsecurity
  ) THEN RAISE EXCEPTION 'Wave 2 protected table without RLS'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_002_contract_passed' AS validation_result;
