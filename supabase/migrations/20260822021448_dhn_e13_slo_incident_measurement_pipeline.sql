create table if not exists dhn_ops.slo_measurements (
  slo_measurement_id uuid primary key default gen_random_uuid(),
  slo_code text not null references dhn_ops.slo_definitions(slo_code),
  measured_value numeric not null,
  window_started_at timestamptz not null,
  window_ended_at timestamptz not null,
  source text not null,
  status text not null check (status in ('within_target','breach','insufficient_data')),
  evidence jsonb not null default '{}'::jsonb,
  measured_at timestamptz not null default now(),
  check (window_ended_at >= window_started_at),
  check (evidence::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);

create table if not exists dhn_ops.incidents (
  incident_id uuid primary key default gen_random_uuid(),
  incident_code text not null unique,
  incident_class text not null check (incident_class in ('slo_breach','security','privacy','integrity','availability','settlement','deployment','other')),
  severity text not null check (severity in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','investigating','mitigated','resolved','closed')),
  component text not null,
  correlation_id text,
  summary text not null,
  evidence jsonb not null default '{}'::jsonb,
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (evidence::text !~* '"(patient_id|actor_id|principal_ref|health_credential_id|cardiac_credential_id|clinical_resource_ref_id|storage_object_ref|payload_location_ref|diagnosis|medication|ecg|waveform|samples|raw_payload|biometric_template|phi)"[[:space:]]*:')
);

create index if not exists idx_dhn_slo_measurements_code_time on dhn_ops.slo_measurements(slo_code, measured_at desc);
create index if not exists idx_dhn_incidents_status_severity on dhn_ops.incidents(status,severity,opened_at desc);

alter table dhn_ops.slo_measurements enable row level security;
alter table dhn_ops.incidents enable row level security;
revoke all privileges on dhn_ops.slo_measurements,dhn_ops.incidents from public,anon,authenticated;
grant all privileges on dhn_ops.slo_measurements,dhn_ops.incidents to service_role;
create policy slo_measurements_service_role on dhn_ops.slo_measurements for all to service_role using (true) with check (true);
create policy incidents_service_role on dhn_ops.incidents for all to service_role using (true) with check (true);

create or replace function dhn_ops.evaluate_slo(p_slo_code text,p_measured_value numeric,p_window_started_at timestamptz,p_window_ended_at timestamptz,p_source text,p_evidence jsonb default '{}'::jsonb)
returns uuid language plpgsql security invoker set search_path=pg_catalog,dhn_ops as $$
declare d dhn_ops.slo_definitions%rowtype; s text; mid uuid;
begin
 select * into d from dhn_ops.slo_definitions where slo_code=p_slo_code and status='active';
 if not found then raise exception 'active_slo_not_found'; end if;
 s:=case d.target_operator when 'gte' then case when p_measured_value>=d.target_value then 'within_target' else 'breach' end when 'lte' then case when p_measured_value<=d.target_value then 'within_target' else 'breach' end when 'eq' then case when p_measured_value=d.target_value then 'within_target' else 'breach' end end;
 insert into dhn_ops.slo_measurements(slo_code,measured_value,window_started_at,window_ended_at,source,status,evidence) values(p_slo_code,p_measured_value,p_window_started_at,p_window_ended_at,p_source,s,p_evidence) returning slo_measurement_id into mid;
 if s='breach' then insert into dhn_ops.incidents(incident_code,incident_class,severity,component,summary,evidence) values('SLO-'||mid::text,'slo_breach',d.severity_on_breach,d.component,'SLO breach: '||p_slo_code,jsonb_build_object('slo_code',p_slo_code,'measurement_id',mid,'measured_value',p_measured_value,'target_value',d.target_value,'target_operator',d.target_operator)); end if;
 return mid;
end $$;
revoke all on function dhn_ops.evaluate_slo(text,numeric,timestamptz,timestamptz,text,jsonb) from public,anon,authenticated;
grant execute on function dhn_ops.evaluate_slo(text,numeric,timestamptz,timestamptz,text,jsonb) to service_role;
