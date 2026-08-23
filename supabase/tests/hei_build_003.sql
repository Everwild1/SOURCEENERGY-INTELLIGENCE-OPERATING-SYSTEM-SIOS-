BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES
('SETC-OID-cccccccccccccccccccccccccccccccc','Research University','research university','UNIVERSITY','VERIFIED'),
('SETC-OID-dddddddddddddddddddddddddddddddd','Commercial Partner','commercial partner','CORPORATION','VERIFIED');

INSERT INTO public.hei_research_projects(lead_organization_oid,project_reference,title,status)
VALUES ('SETC-OID-cccccccccccccccccccccccccccccccc','RP-001','Research Project','ACTIVE');

INSERT INTO public.hei_ip_assets(research_project_id,asset_reference,asset_type,title)
SELECT id,'IP-001','PATENT_APPLICATION','Test IP' FROM public.hei_research_projects WHERE project_reference='RP-001';

DO $$ DECLARE ipid bigint; blocked boolean := false; BEGIN
 SELECT id INTO ipid FROM public.hei_ip_assets WHERE asset_reference='IP-001';
 BEGIN
  INSERT INTO public.hei_commercialization_cases(ip_asset_id,commercialization_reference,route,status,authority_reference,conflict_review_state)
  VALUES(ipid,'CC-BLOCK','LICENSE','APPROVED','AUTH-1','CLEARED');
 EXCEPTION WHEN OTHERS THEN blocked := true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'commercialization without ownership was not blocked'; END IF;
END $$;

INSERT INTO public.hei_ip_ownership(ip_asset_id,owner_organization_oid,ownership_share,ownership_basis,authority_reference)
SELECT id,'SETC-OID-cccccccccccccccccccccccccccccccc',1.0,'institutional policy','AUTH-IP' FROM public.hei_ip_assets WHERE asset_reference='IP-001';

INSERT INTO public.hei_commercialization_cases(ip_asset_id,commercialization_reference,route,status,authority_reference,conflict_review_state)
SELECT id,'CC-001','LICENSE','APPROVED','AUTH-COMM','CLEARED' FROM public.hei_ip_assets WHERE asset_reference='IP-001';

DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname = ANY(ARRAY['hei_research_projects','hei_research_participants','hei_ip_assets','hei_ip_ownership','hei_commercialization_cases','hei_commercialization_counterparties','hei_revenue_waterfalls','hei_revenue_waterfall_lines']) AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'Wave 3 table without RLS'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.hei_ip_ownership o JOIN public.hei_ip_assets a ON a.id=o.ip_asset_id WHERE a.asset_reference='IP-001' AND o.ownership_share=1.0) THEN RAISE EXCEPTION 'ownership contract failed'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_003_contract_passed' AS result;
