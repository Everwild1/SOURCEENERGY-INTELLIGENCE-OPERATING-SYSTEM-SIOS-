alter table wealth_ecology.decision_love_evaluations drop constraint if exists decision_love_evaluations_decision_id_key;
alter table wealth_ecology.decision_love_evaluations add column if not exists invariant_version text not null default 'love-invariant-v1';
alter table wealth_ecology.decision_love_evaluations add column if not exists assessment_hash text;
alter table wealth_ecology.decision_love_evaluations add column if not exists supersedes_evaluation_id uuid references wealth_ecology.decision_love_evaluations(id) on delete restrict;
alter table wealth_ecology.decision_love_evaluations add constraint decision_love_evaluations_hash_check check (assessment_hash is null or assessment_hash ~ '^[0-9a-f]{64}$');
create unique index if not exists decision_love_one_human_confirmed_pass_idx on wealth_ecology.decision_love_evaluations(decision_id,invariant_version) where status='PASS' and human_reviewed_by is not null and human_reviewed_at is not null;

create or replace function wealth_ecology.evaluate_decision_readiness_v2(p_decision_id uuid)
returns jsonb language plpgsql set search_path to '' as $$
declare d7_total int; d7_done int; p4_done int; seci_done int; love_done int; firewall_bad int; failures int; result jsonb;
begin
 select count(*) into d7_total from wnf7.dimension_registry;
 select count(*) into d7_done from wealth_ecology.decision_7d_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
 select count(*) into p4_done from wealth_ecology.decision_4p_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
 select count(*) into seci_done from wealth_ecology.decision_seci_evaluations where decision_id=p_decision_id and status in ('PASS','WARN','NOT_APPLICABLE');
 select count(*) into love_done from wealth_ecology.decision_love_evaluations l where l.decision_id=p_decision_id and l.invariant_version='love-invariant-v1' and l.status='PASS' and l.human_reviewed_by is not null and l.human_reviewed_at is not null and not exists(select 1 from wealth_ecology.decision_love_evaluations n where n.supersedes_evaluation_id=l.id);
 select count(*) into firewall_bad from wealth_ecology.cross_domain_mappings m join wealth_ecology.decisions d on d.id=p_decision_id where m.target_wealth_ecology_object in (select purpose_ref from wealth_ecology.decisions where id=p_decision_id) and (m.mechanism_equivalence_status='NOT_ESTABLISHED' or m.review_status<>'APPROVED');
 select count(*) into failures from wealth_ecology.decision_7d_evaluations where decision_id=p_decision_id and status='FAIL';
 result:=jsonb_build_object('seven_d_complete',d7_total>0 and d7_done=d7_total,'love_invariant_complete',love_done=1,'four_p_complete',p4_done=4,'seci_complete',seci_done=4,'scientific_firewall_passed',firewall_bad=0,'authorization_ready',d7_total>0 and d7_done=d7_total and love_done=1 and p4_done=4 and seci_done=4 and firewall_bad=0 and failures=0);
 return result;
end; $$;

comment on table wealth_ecology.decision_love_evaluations is 'V37 append-oriented Love/Selfless assessment history. L is invariant; rows represent corrigible time-dependent assessments L-hat. New assessments supersede prior rows rather than destructively replacing history.';
comment on column wealth_ecology.decision_love_evaluations.supersedes_evaluation_id is 'Prior Love assessment superseded by this assessment. Readiness uses only a currently unsuperseded, human-reviewed PASS.';
