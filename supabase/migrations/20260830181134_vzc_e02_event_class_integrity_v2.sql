-- VZC-E02 trust-class hardening.
-- Applied to SourceEnergy-command-backend as migration 20260830181134.

alter table vzc.safety_events
  add column if not exists event_class text not null default 'observation'
  check (event_class in ('observation','derived_intelligence','prediction','recommendation','authorization','execution','outcome'));

alter table vzc.safety_events
  add constraint vzc_safety_events_authority_for_consequential_class_ck
  check (event_class not in ('authorization','execution') or authority_reference is not null);

create index vzc_safety_events_class_time_idx on vzc.safety_events(event_class, first_observed_at desc);

comment on column vzc.safety_events.event_class is 'Trust class preserving separation among observation, derived intelligence, prediction, recommendation, authorization, execution and outcome.';
