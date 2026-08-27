BEGIN;

INSERT INTO public.setc_organizations(oid,legal_name,normalized_name,organization_type,verification_state)
VALUES ('SETC-OID-80808080808080808080808080808080','HEI Wave Eight','hei wave eight','UNIVERSITY','VERIFIED')
ON CONFLICT (oid) DO NOTHING;

INSERT INTO public.hei_capital_projects(organization_oid,project_reference,name,project_type,status)
VALUES('SETC-OID-80808080808080808080808080808080','CP-008','Wave 8 Project','ENERGY','PLANNING');

DO $$ DECLARE pid bigint; blocked boolean:=false; BEGIN
 SELECT id INTO pid FROM public.hei_capital_projects WHERE project_reference='CP-008';
 BEGIN
  INSERT INTO public.hei_project_financing_sources(capital_project_id,source_reference,source_type,commitment_state,authority_reference,evidence_reference)
  VALUES(pid,'FIN-BLOCK-008','GRANT','COMMITTED','AUTH-008','EVID-008');
 EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'financing gate failed'; END IF;

 blocked:=false;
 BEGIN
  UPDATE public.hei_capital_projects SET status='OPERATING' WHERE id=pid;
 EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'operating gate failed'; END IF;
END $$;

DO $$ BEGIN
 IF EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public'
    AND c.relname = ANY(ARRAY['hei_capital_projects','hei_project_assets','hei_project_budgets','hei_project_financing_sources','hei_project_milestones','hei_project_participants','hei_project_external_links'])
    AND NOT c.relrowsecurity
 ) THEN RAISE EXCEPTION 'Wave 8 table without RLS'; END IF;
END $$;

ROLLBACK;
SELECT 'hei_build_008_contract_passed' AS result;
