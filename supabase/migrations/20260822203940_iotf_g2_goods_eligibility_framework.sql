create table if not exists iotf.eligibility_rules (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id) on delete cascade,
  rule_code text not null,
  rule_type text not null check (rule_type in ('PURPOSE','GOODS_CLASS','TENOR','AMOUNT','DOCUMENT','COUNTERPARTY','LOGISTICS','PROHIBITION','OTHER')),
  rule_description text not null,
  rule_status text not null default 'ACTIVE' check (rule_status in ('ACTIVE','INACTIVE','SUPERSEDED')),
  decision_effect text not null check (decision_effect in ('REQUIRED','SUPPORTING','BLOCKING','INFORMATIONAL')),
  source_basis text not null default 'INSTRUMENT_TEXT',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (instrument_id, rule_code)
);
alter table iotf.eligibility_rules enable row level security;
revoke all on iotf.eligibility_rules from public, anon, authenticated;
grant select, insert, update, delete on iotf.eligibility_rules to service_role;
create index if not exists iotf_eligibility_rules_instrument_idx on iotf.eligibility_rules(instrument_id, rule_type, rule_status);

create table if not exists iotf.instrument_commodity_candidates (
  id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references iotf.instruments(id) on delete cascade,
  commodity_id uuid not null references gsc.commodities(id) on delete restrict,
  candidate_status text not null default 'CANDIDATE' check (candidate_status in ('CANDIDATE','ELIGIBLE','INELIGIBLE','SUSPENDED')),
  rationale text not null,
  source_basis text not null default 'GOODS_PURCHASE_SCOPE',
  requires_g4_confirmation boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (instrument_id, commodity_id)
);
alter table iotf.instrument_commodity_candidates enable row level security;
revoke all on iotf.instrument_commodity_candidates from public, anon, authenticated;
grant select, insert, update, delete on iotf.instrument_commodity_candidates to service_role;
create index if not exists iotf_instrument_commodity_candidates_instrument_idx on iotf.instrument_commodity_candidates(instrument_id, candidate_status);
create index if not exists iotf_instrument_commodity_candidates_commodity_idx on iotf.instrument_commodity_candidates(commodity_id);

create table if not exists iotf.transaction_eligibility_assessments (
  id uuid primary key default gen_random_uuid(),
  transaction_request_id uuid not null references iotf.transaction_requests(id) on delete cascade,
  instrument_id uuid not null references iotf.instruments(id) on delete cascade,
  assessment_status text not null default 'PENDING' check (assessment_status in ('PENDING','IN_REVIEW','ELIGIBLE','INELIGIBLE','CONDITIONAL')),
  purpose_match boolean,
  commodity_match boolean,
  amount_within_face_capacity boolean,
  tenor_fit boolean,
  counterparty_ready boolean,
  logistics_ready boolean,
  blocking_reasons text[] not null default '{}',
  conditions text[] not null default '{}',
  eligibility_score numeric(5,2),
  decision_reference text,
  metadata jsonb not null default '{}'::jsonb,
  assessed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (transaction_request_id)
);
alter table iotf.transaction_eligibility_assessments enable row level security;
revoke all on iotf.transaction_eligibility_assessments from public, anon, authenticated;
grant select, insert, update, delete on iotf.transaction_eligibility_assessments to service_role;
create index if not exists iotf_tx_eligibility_instrument_idx on iotf.transaction_eligibility_assessments(instrument_id, assessment_status);

create trigger iotf_commodity_candidates_updated_at
before update on iotf.instrument_commodity_candidates
for each row execute function iotf.set_updated_at();
create trigger iotf_transaction_eligibility_updated_at
before update on iotf.transaction_eligibility_assessments
for each row execute function iotf.set_updated_at();

create or replace function iotf.assess_transaction_eligibility(p_request_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = iotf, gsc, pg_temp
as $$
declare
  r iotf.transaction_requests;
  i iotf.instruments;
  commodity_is_candidate boolean := false;
  purpose_ok boolean := false;
  amount_ok boolean := false;
  tenor_ok boolean := false;
  cp_ok boolean := false;
  logistics_ok boolean := false;
  blockers text[] := '{}';
  conds text[] := '{}';
  score numeric(5,2) := 0;
  result_status text := 'CONDITIONAL';
  assessment_id uuid;
begin
  select * into r from iotf.transaction_requests where id=p_request_id;
  if not found then raise exception 'transaction request not found'; end if;
  select * into i from iotf.instruments where id=r.instrument_id;

  purpose_ok := upper(coalesce(i.stated_purpose,'')) = 'GOODS PURCHASE' and length(trim(coalesce(r.goods_description,''))) > 0;
  amount_ok := r.requested_amount <= i.face_amount and r.currency=i.face_currency;
  tenor_ok := r.expected_settlement_date is null or i.issued_at is null or r.expected_settlement_date <= (i.issued_at::date + coalesce(i.tenor_days,365));

  if r.commodity_id is not null then
    select exists(
      select 1 from iotf.instrument_commodity_candidates c
      where c.instrument_id=r.instrument_id and c.commodity_id=r.commodity_id and c.candidate_status in ('CANDIDATE','ELIGIBLE')
    ) into commodity_is_candidate;
  end if;

  cp_ok := (r.buyer_organization_id is not null and r.seller_organization_id is not null);
  logistics_ok := (r.logistics_reference is not null and length(trim(r.logistics_reference))>0);

  if not purpose_ok then blockers := array_append(blockers,'PURPOSE_MISMATCH'); end if;
  if not commodity_is_candidate then blockers := array_append(blockers,'COMMODITY_NOT_MAPPED'); end if;
  if not amount_ok then blockers := array_append(blockers,'AMOUNT_OR_CURRENCY_OUTSIDE_INSTRUMENT'); end if;
  if not tenor_ok then blockers := array_append(blockers,'SETTLEMENT_OUTSIDE_STATED_TENOR'); end if;
  if not cp_ok then conds := array_append(conds,'BUYER_AND_SELLER_REQUIRED'); end if;
  if not logistics_ok then conds := array_append(conds,'LOGISTICS_REFERENCE_REQUIRED_BEFORE_COMMERCIAL_APPROVAL'); end if;
  conds := array_append(conds,'G4_BANKING_LEGAL_CONFIRMATION_REQUIRED');

  score := (case when purpose_ok then 30 else 0 end)
         + (case when commodity_is_candidate then 25 else 0 end)
         + (case when amount_ok then 20 else 0 end)
         + (case when tenor_ok then 10 else 0 end)
         + (case when cp_ok then 10 else 0 end)
         + (case when logistics_ok then 5 else 0 end);

  if cardinality(blockers)>0 then result_status := 'INELIGIBLE';
  elsif cp_ok and logistics_ok then result_status := 'CONDITIONAL';
  else result_status := 'CONDITIONAL';
  end if;

  insert into iotf.transaction_eligibility_assessments(
    transaction_request_id,instrument_id,assessment_status,purpose_match,commodity_match,
    amount_within_face_capacity,tenor_fit,counterparty_ready,logistics_ready,
    blocking_reasons,conditions,eligibility_score,assessed_at,
    metadata
  ) values (
    r.id,r.instrument_id,result_status,purpose_ok,commodity_is_candidate,amount_ok,tenor_ok,cp_ok,logistics_ok,
    blockers,conds,score,now(),jsonb_build_object('scope','G2 eligibility only','g4_required',true)
  )
  on conflict (transaction_request_id) do update set
    assessment_status=excluded.assessment_status,
    purpose_match=excluded.purpose_match,
    commodity_match=excluded.commodity_match,
    amount_within_face_capacity=excluded.amount_within_face_capacity,
    tenor_fit=excluded.tenor_fit,
    counterparty_ready=excluded.counterparty_ready,
    logistics_ready=excluded.logistics_ready,
    blocking_reasons=excluded.blocking_reasons,
    conditions=excluded.conditions,
    eligibility_score=excluded.eligibility_score,
    assessed_at=excluded.assessed_at,
    metadata=excluded.metadata,
    updated_at=now()
  returning id into assessment_id;

  update iotf.transaction_requests set eligibility_score=score where id=r.id;
  return assessment_id;
end;
$$;
revoke all on function iotf.assess_transaction_eligibility(uuid) from public, anon, authenticated;
grant execute on function iotf.assess_transaction_eligibility(uuid) to service_role;

create or replace view iotf.g2_eligibility_catalog
with (security_invoker=true)
as
select
  c.instrument_id,
  i.instrument_code,
  g.commodity_code,
  g.category,
  g.name as commodity_name,
  g.status as commodity_catalog_status,
  c.candidate_status,
  c.rationale,
  c.requires_g4_confirmation
from iotf.instrument_commodity_candidates c
join iotf.instruments i on i.id=c.instrument_id
join gsc.commodities g on g.id=c.commodity_id;

insert into iotf.eligibility_rules(instrument_id,rule_code,rule_type,rule_description,decision_effect,source_basis,metadata)
select i.id, x.rule_code, x.rule_type, x.rule_description, x.decision_effect, x.source_basis, x.metadata
from iotf.instruments i
cross join (values
 ('G2-PURPOSE-GOODS','PURPOSE','Transaction must be a purchase of physical goods consistent with the stated instrument purpose GOODS PURCHASE.','REQUIRED','INSTRUMENT_TEXT',jsonb_build_object('source_field','PURPOSE')),
 ('G2-AMOUNT-FACE','AMOUNT','Requested transaction amount must not exceed remaining governed instrument capacity and must use the instrument currency unless separately approved.','REQUIRED','CONTROL_FRAMEWORK',jsonb_build_object('currency','USD')),
 ('G2-TENOR-365','TENOR','Expected settlement must fit within the stated 365-day tenor unless later authoritative evidence changes the controlling dates.','REQUIRED','INSTRUMENT_TEXT',jsonb_build_object('tenor_days',365)),
 ('G2-COMMODITY-MAPPED','GOODS_CLASS','Commodity must be mapped to the governed SourceEnergy goods catalog before eligibility can be assessed.','REQUIRED','CONTROL_FRAMEWORK',jsonb_build_object('catalog','gsc.commodities')),
 ('G2-G4-BOUNDARY','OTHER','G2 eligibility never substitutes for G4 banking/legal confirmation of actual instrument usability for a proposed transaction.','BLOCKING','CONTROL_FRAMEWORK',jsonb_build_object('required_gate','G4_BANKING_LEGAL'))
) as x(rule_code,rule_type,rule_description,decision_effect,source_basis,metadata)
where i.external_reference='SBLC-20260820-0001-14'
on conflict (instrument_id,rule_code) do nothing;

insert into iotf.instrument_commodity_candidates(instrument_id,commodity_id,candidate_status,rationale,source_basis,requires_g4_confirmation,metadata)
select i.id,g.id,'CANDIDATE',
       'Physical-goods commodity class within the SourceEnergy supply-chain catalog; candidate under the instrument stated GOODS PURCHASE purpose. This is not bank confirmation of eligibility.',
       'GOODS_PURCHASE_SCOPE',true,
       jsonb_build_object('catalog_status',g.status,'category',g.category)
from iotf.instruments i
join gsc.commodities g on true
where i.external_reference='SBLC-20260820-0001-14'
on conflict (instrument_id,commodity_id) do nothing;

update iotf.governance_gates
set gate_status='IN_REVIEW',
    decision_reference='G2-FRAMEWORK-INITIALIZED',
    decision_metadata=jsonb_build_object('framework','goods purchase eligibility','commodity_candidates','gsc.commodities','approval_effect',false),
    decided_at=now()
where instrument_id=(select id from iotf.instruments where external_reference='SBLC-20260820-0001-14')
  and allocation_id is null and gate_code='G2_ELIGIBILITY' and gate_status='PENDING';
