alter table wim.economic_clusters add column if not exists verification_status text not null default 'pending_source_verification' check (verification_status in ('pending_source_verification','verified','superseded'));
update wim.economic_clusters set verification_status='pending_source_verification';
comment on column wim.economic_clusters.verification_status is 'Prevents imported website taxonomy from being treated as canonical until independently reconciled to the source page/export.';
