insert into public.codex_registry (scroll_id,name,layer,dominion_cube,status,function,codex_group,priority)
select '#024','Human Consciousness / Organic Intelligence','SourceEnergy One / Genesis',null,'EMERGING','Candidate interpretation of Purpose Discovery testimony for human-reviewed Mission, Vision, Purpose and long-horizon impact synthesis. Not authoritative without explicit human confirmation.','Human Intelligence','HIGH'
where not exists (select 1 from public.codex_registry where scroll_id in ('#024','024','24'));

