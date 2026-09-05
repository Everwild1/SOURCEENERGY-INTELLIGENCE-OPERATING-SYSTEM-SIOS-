-- V36: promote SourceEnergy One Genesis package creation from Spirit-Gate-only
-- enforcement to the composite AGB-7D/L constitutional gate.

create or replace function sourceenergy_one.enforce_spirit_gate_on_genesis_insert()
returns trigger
language plpgsql
set search_path to 'sourceenergy_one','pg_temp'
as $$
begin
  perform sourceenergy_one.require_genesis_constitutional_gate('impact_report',new.impact_report_id);
  perform sourceenergy_one.require_genesis_constitutional_gate('genesis_approval',new.approval_id);
  return new;
end;
$$;

comment on function sourceenergy_one.enforce_spirit_gate_on_genesis_insert() is
'V36 canonical SourceEnergy One Genesis package gate. Requires both the human-confirmed Spirit Gate v3 and the separate human-confirmed Love/Selfless invariant for the linked impact report and Genesis approval before package insertion.';
