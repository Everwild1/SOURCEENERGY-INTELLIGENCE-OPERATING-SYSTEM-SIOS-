BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-11111111111111111111111111111111','HEI Five','hei five','UNIVERSITY','VERIFIED');

INSERT INTO public.hei_funding_programs(organization_oid,program_reference,program_type,name,status)
VALUES('SETC-OID-11111111111111111111111111111111','FP-005','PHILANTHROPY','Institutional Advancement','ACTIVE');
INSERT INTO public.hei_funding_sources(source_reference,source_type,name) VALUES('SRC-005','FOUNDATION','Test Foundation');
INSERT INTO public.hei_funding_awards(funding_program_id,funding_source_id,award_reference,award_type,awarded_amount,currency_code,status,restricted,authority_reference)
SELECT p.id,s.id,'AWD-005','GIFT',100000,'USD','ACCEPTED',true,'AUTH-AWARD' FROM public.hei_funding_programs p, public.hei_funding_sources s WHERE p.program_reference='FP-005' AND s.source_reference='SRC-005';

DO $$ DECLARE aid bigint; blocked boolean:=false; BEGIN
 SELECT id INTO aid FROM public.hei_funding_awards WHERE award_reference='AWD-005';
 BEGIN INSERT INTO public.hei_funding_allocations(funding_award_id,allocation_reference,destination_type,destination_reference,allocated_amount,currency_code,restriction_compatible,authority_reference,status)
 VALUES(aid,'ALLOC-BLOCK','OPERATING_PROGRAM','PROGRAM-X',1000,'USD',false,'AUTH-ALLOC','APPROVED'); EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'restricted incompatible allocation was not blocked'; END IF;
END $$;

DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname = ANY(ARRAY['hei_funding_programs','hei_funding_sources','hei_funding_awards','hei_funding_restrictions','hei_funding_receipts','hei_funding_allocations','hei_stewardship_obligations']) AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'Wave 5 table without RLS'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_005_contract_passed' AS result;
