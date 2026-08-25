import { createMediaServerClient } from '@/lib/supabase/server';

async function rpc<T>(name: string): Promise<T[]> {
  const supabase = await createMediaServerClient();
  const { data, error } = await supabase.rpc(name);
  if (error) throw error;
  return (data ?? []) as T[];
}

export type EditorialQueueItem = { content_id:string; organization_oid:string; title:string; content_type:string; representation