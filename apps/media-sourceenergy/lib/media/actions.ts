'use server';

import { revalidatePath } from 'next/cache';
import { createMediaServerClient } from '@/lib/supabase/server';

async function command(name: string, args: Record<string, unknown>, paths: string[]) {
  const supabase = await createMediaServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('AUTHENTICATION_REQUIRED');
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(error.message);
  paths.forEach((path) => revalidatePath(path));
  return data;
}

export async function validateClaimAction(formData: FormData) {
  return command('setc_media_validate_claim', {
    p_claim_id: String(formData.get('claim_id')),
    p_state: String(formData.get('state')),
    p_reason: String(formData.get('reason') ?? '') || null
  }, ['/workspace/evidence']);
}

export async function reviewDecisionAction(formData: FormData) {
  return command('setc_media_review_decide', {
    p_review_id: String(formData.get('review_id')),
    p_decision: String(formData.get('decision')),
    p_notes: String(formData.get('notes') ?? '') || null
  }, ['/workspace/reviews','/workspace/approvals']);
}

export async function approvalDecisionAction(formData: FormData) {
  return command('setc_media_approval_decide', {
    p_content_id: String(formData.get('content_id')),
    p_decision: String(formData.get('decision')),
    p_scope: String(formData.get('scope') ?? 'INSTITUTIONAL'),
    p_authority_basis: String(formData.get('authority_basis') ?? '') || null
  }, ['/workspace/approvals','/workspace/editorial']);
}

export async function publishAction(formData: FormData) {
  return command('setc_media_publish', {
    p_content_id: String(formData.get('content_id')),
    p_channel_code: String(formData.get('channel_code')),
    p_destination_key: String(formData.get('destination_key')),
    p_idempotency_key: String(formData.get('idempotency_key'))
  }, ['/workspace/approvals','/workspace/distribution','/']);
}

export async function retryOutboxAction(formData: FormData) {
  return command('setc_media_retry_outbox', { p_outbox_id: String(formData.get('outbox_id')) }, ['/workspace/distribution']);
}
