import { getReviewQueue } from '@/lib/media/workspace';
import { reviewDecisionAction } from '@/lib/media/actions';

export default async function ReviewsPage(){
 const items=await getReviewQueue();
 return <div className="shell page-stack">
  <section><p className="eyebrow">Governed review</p><h1>Review queue</h1><p>Review authority is resolved from review type and organization scope by the database command.</p></section>
  <section className="route-grid">{items.map(i=><article className="route-card" key={i.review_id}>
   <p className="eyebrow">{i.review_type} · {i.organization_oid}</p><h2>{i.title}</h2>
   <form action={reviewDecisionAction}><input type="hidden" name="review_id" value={i.review_id}/><label>Notes<textarea name="notes"/></label><div><button name="decision" value="APPROVED">Approve review</button> <button name="decision" value="CHANGES_REQUIRED">Changes required</button> <button name="decision" value="REJECTED">Reject</button></div></form>
  </article>)}</section>
 </div>
}
