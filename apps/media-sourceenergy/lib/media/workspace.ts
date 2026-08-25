import { createMediaServerClient } from '@/lib/supabase/server';

async function rpc<T>(name: string): Promise<T[]> {
  const supabase = await createMediaServerClient();
  const { data, error } = await supabase.rpc(name);
  if (error) throw error;
  return (data ?? []) as T[];
}

export type EditorialQueueItem = {
  content_id: string;
  organization_oid: string;
  title: string;
  content_type: string;
  representation_class: string;
  lifecycle_status: string;
  current_version: number;
  updated_at: string;
};

export type EvidenceQueueItem = {
  claim_id: string;
  content_id: string;
  organization_oid: string;
  title: string;
  claim_text: string;
  claim_category: string;
  materiality: string;
  verification_state: string;
  authoritative_source_required: boolean;
  created_at: string;
};

export type ReviewQueueItem = {
  review_id: string;
  content_id: string;
  organization_oid: string;
  title: string;
  review_type: string;
  decision: string;
  reviewer_user_id: string | null;
  notes: string | null;
  created_at: string;
};

export type ApprovalQueueItem = {
  content_id: string;
  organization_oid: string;
  title: string;
  representation_class: string;
  lifecycle_status: string;
  current_version: number;
  unresolved_claims: number;
  pending_reviews: number;
  updated_at: string;
};

export type DistributionQueueItem = {
  outbox_id: string;
  event_id: string;
  organization_oid: string;
  content_id: string;
  event_type: string;
  destination_type: string;
  destination_key: string;
  delivery_status: string;
  attempt_count: number;
  available_at: string;
  created_at: string;
};

export const getEditorialQueue = () => rpc<EditorialQueueItem>('setc_media_editorial_queue');
export const getEvidenceQueue = () => rpc<EvidenceQueueItem>('setc_media_evidence_queue');
export const getReviewQueue = () => rpc<ReviewQueueItem>('setc_media_review_queue');
export const getApprovalQueue = () => rpc<ApprovalQueueItem>('setc_media_approval_queue');
export const getDistributionQueue = () => rpc<DistributionQueueItem>('setc_media_distribution_queue');
