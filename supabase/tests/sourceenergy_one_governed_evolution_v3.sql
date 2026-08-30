-- SourceEnergy One Governed Evolution V3 release assertions
-- Intended for CI against a database containing the canonical SourceEnergy One migrations.

begin;

do $$
begin
  if to_regclass('sourceenergy_one.spirit_gate_assessments') is null then raise exception 'missing spirit_gate_assessments'; end if;
  if to_regclass('sourceenergy_one.evidence_provenance') is null then raise exception 'missing evidence_provenance'; end if;
  if to_regclass('sourceenergy_one.actor_identities') is null then raise exception 'missing actor_identities'; end if;
  if to_regclass('sourceenergy_one.consent_receipts') is null then raise exception 'missing consent_receipts'; end if;
  if to_regclass('sourceenergy_one.model_provenance_registry') is null then raise exception 'missing model_provenance_registry'; end if;
  if to_regclass('sourceenergy_one.ai_inference_records') is null then raise exception 'missing ai_inference_records'; end if;
  if to_regprocedure('sourceenergy_one.assess_spirit_gate_v3(text,text,uuid,jsonb,text,text)') is null then raise exception 'missing assess_spirit_gate_v3'; end if;
  if to_regprocedure('sourceenergy_one.review_spirit_gate_v3(uuid,text,text,text)') is null then raise exception 'missing review_spirit_gate_v3'; end if;
  if to_regprocedure('sourceenergy_one.require_spirit_gate(text,uuid)') is null then raise exception 'missing require_spirit_gate'; end if;
  if to_regprocedure('sourceenergy_one.require_verified_actor(text,text,text)') is null then raise exception 'missing require_verified_actor'; end if;
  if to_regprocedure('sourceenergy_one.require_active_consent(text,text,text)') is null then raise exception 'missing require_active_consent'; end if;
  if to_regprocedure('sourceenergy_one.require_ai_inference_provenance(text,uuid,text)') is null then raise exception 'missing require_ai_inference_provenance'; end if;
  if to_regprocedure('sourceenergy_one.verify_audit_chain()') is null then raise exception 'missing verify_audit_chain'; end if;
  if exists(select 1 from sourceenergy_one.verify_audit_chain() where not valid) then raise exception 'audit chain invalid'; end if;
end $$;

-- No operational path may treat exempted as satisfying current Spirit Gate V3.
do $$ declare f text; begin
 select pg_get_functiondef('sourceenergy_one.require_spirit_gate(text,uuid)'::regprocedure) into f;
 if f ilike '%exempted%' then raise exception 'require_spirit_gate must not accept exempted'; end if;
 if f not ilike '%spirit-gate-v3%' then raise exception 'require_spirit_gate must require spirit-gate-v3'; end if;
end $$;

-- Promotion may never manufacture a pre-confirmed reflection.
do $$ declare f text; begin
 select pg_get_functiondef('sourceenergy_one.promote_confirmed_knowledge_to_reflection(uuid,text,jsonb)'::regprocedure) into f;
 if f ilike '%''confirmed''%k.reviewed_by_actor_ref%' then raise exception 'reflection promotion contains legacy pre-confirmed insertion'; end if;
 if f not ilike '%''pending''%' then raise exception 'reflection promotion must create pending state'; end if;
end $$;

rollback;
