create or replace function pqc.guard_protected_object_reference()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_metadata_text text;
begin
  if new.content_reference is null or btrim(new.content_reference)='' then
    raise exception 'A controlled content reference is required';
  end if;

  if length(new.content_reference) > 2048
     or new.content_reference ~ E'[\r\n]'
     or lower(new.content_reference) like 'data:%' then
    raise exception 'content_reference must be a bounded opaque reference, not an embedded payload';
  end if;

  v_metadata_text := coalesce(new.metadata,'{}'::jsonb)::text;

  if v_metadata_text ~* '"(raw_personal_data|personal_data|ssn|social_security_number|passport_number|national_id|date_of_birth|bank_account|account_number|routing_number|credential|password|private_key|secret_key|seed|mnemonic|service_role_key)"[[:space:]]*:' then
    raise exception 'Sensitive payload or secret material is prohibited in protected-object metadata';
  end if;

  if new.object_type in ('ORGANIZATION_DD_REPORT','INDIVIDUAL_DD_REPORT') then
    if new.content_reference !~ '^(supabase|drive|vault|document|evidence|case|github)://[^[:space:]]+$' then
      raise exception 'Due-diligence objects require an approved opaque reference scheme';
    end if;

    if lower(coalesce(new.metadata->>'payload_copied','false'))='true' then
      raise exception 'Raw due-diligence payloads cannot be copied into the PQC registry';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists protected_object_reference_guard on evidence.protected_objects;
create trigger protected_object_reference_guard
before insert or update on evidence.protected_objects
for each row execute function pqc.guard_protected_object_reference();

revoke all on function pqc.guard_protected_object_reference() from public, anon, authenticated;

comment on function pqc.guard_protected_object_reference() is 'Enforces hash-and-reference-only protection records and rejects embedded due-diligence, personal, financial, credential, or private-key payload indicators.';