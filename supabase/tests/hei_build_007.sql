BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-56565656565656565656565656565656','HEI Seven','hei seven','UNIVERSITY','VERIFIED'),
       ('SETC-OID-78787878787878787878787878787878','Supplier Seven','supplier seven','CORPORATION','VERIFIED');

INSERT INTO public.hei_procurement_programs(organization_oid,program_reference,name,procurement_type,status)
VALUES('SETC-OID-56565656565656565656565656565656','PP-007','Institutional Procurement','GOODS','ACTIVE');
INSERT INTO public.hei_suppliers(supplier_organization_oid,supplier_reference,qualification_state)
VALUES('SETC-OID-78787878787878787878787878787878','SUP-007','QUALIFIED');
INSERT INTO public.hei_procurement_opportunities(procurement_program_id,opportunity_reference,title,sourcing_method,status,authority_reference)
SELECT id,'PROC-007','Procurement Opportunity','RFP','EVALUATION','AUTH-OPP' FROM public.hei_procurement_programs WHERE program_reference='PP-007';

DO $$ DECLARE oid bigint; sid bigint; blocked boolean:=false; BEGIN
 SELECT id INTO oid FROM public.hei_procurement_opportunities WHERE opportunity_reference='PROC-007';
 SELECT id INTO sid FROM public.hei_suppliers WHERE supplier_reference='SUP-007';
 BEGIN
  INSERT INTO public.hei_procurement_awards(procurement_opportunity_id,supplier_id,award_reference,status,authority_reference)
  VALUES(oid,sid,'PA-BLOCK','APPROVED','AUTH-007');
 EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'award to non-approved supplier was not blocked'; END IF;
END $$;

DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname = ANY(ARRAY['hei_procurement_programs','hei_suppliers','hei_supplier_qualifications','hei_economic_clusters','hei_economic_cluster_members','hei_procurement_opportunities','hei_procurement_bids','hei_procurement_awards','hei_procurement_external_links']) AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'Wave 7 table without RLS'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_007_contract_passed' AS result;
