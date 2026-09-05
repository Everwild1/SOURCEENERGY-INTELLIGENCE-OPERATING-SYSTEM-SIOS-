-- AGB-7D-L-v1 constitutional contract smoke assertions.
-- These assertions are read-only and expect the V28/V30 migrations to be installed.

do $$
declare
  v_default text;
  v_dims int;
  v_love_table regclass;
  v_eval_table regclass;
begin
  select column_default into v_default
  from information_schema.columns
  where table_schema='wealth_ecology'
    and table_name='execution_authorizations'
    and column_name='constitutional_gate_version';

  if v_default is null or position('AGB-7D-L-v1' in v_default)=0 then
    raise exception 'AGB-7D-L-v1 must be the default constitutional gate';
  end if;

  select count(*) into v_dims from wnf7.dimension_registry;
  if v_dims <> 7 then
    raise exception 'Genesis dimension registry must contain exactly seven dimensions; Love is not D8';
  end if;

  v_love_table := to_regclass('sourceenergy_one.love_invariant_assessments');
  if v_love_table is null then raise exception 'Love invariant assessment table missing'; end if;

  v_eval_table := to_regclass('wealth_ecology.decision_love_evaluations');
  if v_eval_table is null then raise exception 'Decision Love evaluation table missing'; end if;

  if to_regprocedure('wealth_ecology.evaluate_decision_readiness_v2(uuid)') is null then
    raise exception 'Constitutional readiness v2 function missing';
  end if;

  if to_regprocedure('sourceenergy_one.require_genesis_constitutional_gate(text,uuid)') is null then
    raise exception 'Composite Genesis constitutional gate missing';
  end if;
end $$;
