create table if not exists sourcecubes.provider_runtime_validation (
  validation_id uuid primary key default gen_random_uuid(),
  provider_code text not null references ecology.ssr_scientific_data_providers(provider_code),
  validation_mode text not null,
  endpoint_reference text not null,
  http_status integer,
  content_type text,
  response_bytes integer,
  validation_status text not null,
  evidence_note text not null,
  validated_at timestamptz not null default now()
);

insert into sourcecubes.provider_runtime_validation(provider_code,validation_mode,endpoint_reference,http_status,content_type,response_bytes,validation_status,evidence_note)
values('GEBCO-SOURCE','POSTGRES_HTTP_PUBLIC_ENDPOINT','https://www.gebco.net/data-products-gridded-bathymetry-data/gebco2026-grid',200,'text/html; charset=UTF-8',69443,'PUBLIC_SOURCE_ENDPOINT_VALIDATED','Direct database HTTP GET returned 200 after increasing the temporary HTTP timeout. This validates public GEBCO source reachability only; it does not validate point extraction, NetCDF/OPeNDAP parsing, or canonical Z transformation.') ;

update ecology.ssr_scientific_data_providers
set integration_status='public_source_endpoint_validated_point_extraction_pending',updated_at=now()
where provider_code='GEBCO-SOURCE';

comment on table sourcecubes.provider_runtime_validation is 'Runtime/provider validation evidence. A successful public endpoint reachability check is not equivalent to dataset extraction, credential validation, or canonical datum authority.';
