import { approvalDecisionAction, publishAction, retryOutboxAction, reviewDecisionAction, validateClaimAction } from '@/lib/media/actions';

export function ClaimControls({ claimId }: { claimId: string }) {
  return <form action={validateClaimAction} className="operator-controls">
    <input type="hidden" name="claim_id" value={claimId}/>
    <label>Validation decision<select name="state" required><option value="VERIFIED">Verified</option><option value="CONFLICT">Conflict</option><option value="REJECTED">Rejected</option><option value="PENDING">Pending</option></select></label>
    <label>Reason<input name="reason" maxLength={500}/></label><button type="submit">Record validation</button>
  </form>;
}

export function ReviewControls({ reviewId }: { reviewId: string }) {
  return <form action={reviewDecisionAction} className="operator-controls">
    <input type="hidden" name="review_id" value={reviewId}/>
    <label>Review decision<select name="decision" required><option value="APPROVED">Approve</option><option value="CHANGES_REQUIRED">Changes required</option><option value="REJECTED">Reject</option><option value="WAIVED">Waive</option></select></label>
    <label>Notes<input name="notes" maxLength={1000}/></label><button type="submit">Record review</button>
  </form>;
}

export function ApprovalControls({ contentId }: { contentId: string }) {
  return <form action={approvalDecisionAction} className="operator-controls">
    <input type="hidden" name="content_id" value={contentId}/><input type="hidden" name="scope" value="INSTITUTIONAL"/>
    <label>Authority basis<input name="authority_basis" required maxLength={500}/></label>
    <button name="decision" value="APPROVED" type="submit">Approve</button><button name="decision" value="REJECTED" type="submit">Reject</button>
  </form>;
}

export function PublishControls({ contentId }: { contentId: string }) {
  return <form action={publishAction} className="operator-controls">
    <input type="hidden" name="content_id" value={contentId}/>
    <label>Channel code<input name="channel_code" required/></label><label>Destination<input name="destination_key" required/></label><label>Idempotency key<input name="idempotency_key" required/></label>
    <button type="submit">Publish governed content</button>
  </form>;
}

export function RetryControls({ outboxId }: { outboxId: string }) {
  return <form action={retryOutboxAction} className="operator-controls"><input type="hidden" name="outbox_id" value={outboxId}/><button type="submit">Retry delivery</button></form>;
}
