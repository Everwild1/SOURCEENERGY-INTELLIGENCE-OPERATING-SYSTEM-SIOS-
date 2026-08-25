import { createMediaServerClient } from '@/lib/supabase/server';

export type PublicMediaItem = {
  content_id: string;
  organization_oid: string;
  title: string;
  slug: string | null;
  content_type: string;
  representation_class: string;
  summary: string | null;
  language_code: string;
  current_version: number;
  published_at: string;
  has_correction: boolean;
};

export async function listPublishedMedia(limit = 12): Promise<PublicMediaItem[]> {
  const supabase = await createMediaServerClient();
  const { data, error } = await supabase
    .from('setc_media_public_content')
    .select('content_id,organization_oid,title,slug,content_type,representation_class,summary,language_code,current_version,published_at,has_correction')
    .order('published_at', { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as PublicMediaItem[];
}
