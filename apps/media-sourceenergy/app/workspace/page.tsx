import { redirect } from 'next/navigation';
import { createMediaServerClient } from '@/lib/supabase/server';
import { getMyMediaCapabilities, hasCapability } from '@/lib/media/capabilities';

const operations = [
  ['Assignments','media.draft'],['Content & Versions','media.draft'],['Evidence & Claims','media.fact_validate'],
  ['Reviews','media.review'],['Approvals','media.approve'],['Assets & Rights','media.rights_manage'],
  ['Channels','media.channel_manage'],['Distribution','media.publish'],['Incidents','media.incident_manage'],['Analytics','media.analytics']
] as const;

export default async function WorkspacePage() {
  const supabase = await createMediaServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/');
  const capabilities = await getMyMediaCapabilities();
  const organizations = [...new Set(capabilities.map((item) => item.organization_oid))];

  return <div className="shell page-stack">
    <section className="hero"><p className="eyebrow">Authenticated workspace</p><h1>Media command center</h1><p className="lede">Role-aware editorial operations across {organizations.length} authorized organization{organizations.length===1?'':'s'}. Interface visibility does not grant authority; RLS and governed commands remain authoritative.</p></section>
    <section aria-labelledby="capabilities-heading"><h2 id="capabilities-heading">Authorized operations</h2><div className="route-grid">
      {operations.filter(([,permission]) => hasCapability(capabilities,permission)).map(([label,permission]) => <div className="route-card" key={label}><strong>{label}</strong><p>{permission}</p></div>)}
    </div>{capabilities.length===0 && <p>No Media authority has been assigned to this authenticated principal.</p>}</section>
    <section className="boundary"><h2>Authority scope</h2>{organizations.length>0 ? <ul>{organizations.map((org)=><li key={org}>{org}</li>)}</ul> : <p>No organization scope.</p>}</section>
  </div>;
}
