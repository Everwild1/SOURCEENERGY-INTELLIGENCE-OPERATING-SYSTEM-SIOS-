import { createMediaServerClient } from '@/lib/supabase/server';

export type MediaCapability = { organization_oid: string; permission_code: string };

export async function getMyMediaCapabilities(): Promise<MediaCapability[]> {
  const supabase = await createMediaServerClient();
  const { data, error } = await supabase.rpc('setc_media_my_capabilities');
  if (error) throw error;
  return (data ?? []) as MediaCapability[];
}

export function hasCapability(items: MediaCapability[], permission: string) {
  return items.some((item) => item.permission_code === permission);
}
