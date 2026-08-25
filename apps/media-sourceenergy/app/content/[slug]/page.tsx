import { notFound } from 'next/navigation';
import { createMediaServerClient } from '@/lib/supabase/server';

export default async function ContentPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const supabase = await createMediaServerClient();
  const { data: item } = await supabase.from('setc_media_public_content').select('*').eq('slug', slug).maybeSingle();
  if (!item) notFound();
  const { data: corrections } = await supabase.from('setc_media_public_corrections').select('*').eq('content_id', item.content_id).order('published_at', { ascending: true });

  return <article className="shell page-stack">
    <header className="hero"><p className="eyebrow">{item.content_type} · Version {item.current_version}</p><h1>{item.title}</h1>{item.summary && <p className="lede">{item.summary}</p>}<p>Published {new Date(item.published_at).toLocaleDateString()}</p></header>
    <section aria-label="Publication body"><div style={{whiteSpace:'pre-wrap'}}>{item.body_markdown}</div></section>
    {(corrections?.length ?? 0) > 0 && <section className="boundary" aria-labelledby="corrections-heading"><h2 id="corrections-heading">Corrections & updates</h2>{corrections!.map((c) => <article key={c.correction_id}><h3>{c.materiality} correction</h3><p>{c.error_summary}</p><p><strong>Corrected:</strong> {c.corrected_fact}</p></article>)}</section>}
    <section className="boundary"><h2>Provenance</h2><p>Organization: {item.organization_oid} · Version {item.current_version}</p><p>This publication communicates an approved Media record. Authoritative institutional facts remain governed by their underlying source systems.</p></section>
  </article>;
}
