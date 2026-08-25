import { redirect } from 'next/navigation';
import { createMediaServerClient } from '@/lib/supabase/server';

const capabilities = ['Assignments','Content & Versions','Evidence & Claims','Reviews','Approvals','Assets & Rights','Channels','Distribution','Incidents','Analytics'];

export default async function WorkspacePage() {
  const supabase = await createMediaServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/');

  return (
    <div className="shell page-stack">
      <section className="hero">
        <p className="eyebrow">Authenticated workspace</p>
        <h1>Media command center</h1>
        <p className="lede">Role-aware editorial operations. Interface visibility does not grant authority; Supabase RLS and governed commands remain authoritative.</p>
      </section>
      <section aria-labelledby="capabilities-heading">
        <h2 id="capabilities-heading">Operations</h2>
        <div className="route-grid">
          {capabilities.map((item) => <div className="route-card" key={item}>{item}</div>)}
        </div>
      </section>
    </div>
  );
}
