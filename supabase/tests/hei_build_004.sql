BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee','HEI Four','hei four','UNIVERSITY','VERIFIED'),
       ('SETC-OID-ffffffffffffffffffffffffffffffff','Opportunity Sponsor','opportunity sponsor','CORPORATION','VERIFIED');

INSERT INTO public.hei_investment_opportunities(opportunity_reference,sponsor_organization_oid,opportunity_type,title,status)
VALUES('OPP-004','SETC-OID-ffffffffffffffffffffffffffffffff','PROJECT','Infrastructure Opportunity','OPEN');

DO $$ DECLARE oid bigint; blocked boolean:=false; BEGIN
 SELECT id INTO oid FROM public.hei_investment_opportunities WHERE opportunity_reference='OPP-004';
 BEGIN
   INSERT INTO public.hei_institution_opportunity_reviews(organization_oid,opportunity_id,review_status,ips_compatible,restriction_compatible,liquidity_compatible,conflict_review_state,authority_reference)
   VALUES('SETC-OID-eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',oid,'APPROVED',true,true,true,'CLEARED','AUTH-004');
 EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'review without fiduciary controls was not blocked'; END IF;
END $$;

DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname = ANY(ARRAY['hei_investment_opportunities','hei_opportunity_eligibility_rules','hei_opportunity_diligence','hei_institution_opportunity_reviews','hei_investment_indications','hei_investment_commitments','hei_opportunity_wim_links']) AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'Wave 4 table without RLS'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_004_contract_passed' AS result;
