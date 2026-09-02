select cron.unschedule(jobid)
from cron.job
where jobname='ssr-air-event-routing-maintenance-v1';

select cron.schedule(
  'ssr-air-event-routing-maintenance-v1',
  '*/5 * * * *',
  $$select public.ssr_air_routing_maintenance();$$
);
