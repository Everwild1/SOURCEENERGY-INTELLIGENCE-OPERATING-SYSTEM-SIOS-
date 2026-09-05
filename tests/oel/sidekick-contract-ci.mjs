import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const vectors = JSON.parse(fs.readFileSync(new URL('./sidekick-gateway-test-vectors.json', import.meta.url), 'utf8'));

const expectedOrder = [
  'client_code','command_id','idempotency_key','nonce','request_timestamp','correlation_id','trace_id','setc_org_oid','action','resource_type','resource_id','requested_control_level','actor_external_ref','channel_identity','payload_hash'
];
assert.deepEqual(vectors.canonical_order, expectedOrder, 'canonical signing field order drifted');

const testSecret = 'NON_PRODUCTION_TEST_SECRET_32_BYTES_MINIMUM_ONLY';
const payload = { evidence_type: 'DOCUMENT', object_ref: 'fixture://evidence/001', content_hash: 'abc123' };
const payloadHash = crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
const envelope = {
  client_code: 'sidekick-oel',
  command_id: '11111111-1111-4111-8111-111111111111',
  idempotency_key: 'fixture-idempotency-001',
  nonce: 'fixture-nonce-001',
  request_timestamp: '2026-08-30T10:00:00.000Z',
  correlation_id: '22222222-2222-4222-8222-222222222222',
  trace_id: '33333333-3333-4333-8333-333333333333',
  setc_org_oid: 'SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d',
  action: 'evidence.submit',
  resource_type: 'work_item',
  resource_id: '44444444-4444-4444-8444-444444444444',
  requested_control_level: 'C2',
  actor_external_ref: 'fixture-actor-001',
  channel_identity: '+15555550100',
  payload_hash: payloadHash,
};

const canonical = expectedOrder.map((field) => envelope[field] ?? '').join('\n');
const sign = (secret, text) => crypto.createHmac('sha256', secret).update(text).digest('hex');
const sig1 = sign(testSecret, canonical);
const sig2 = sign(testSecret, canonical);
assert.equal(sig1, sig2, 'HMAC must be deterministic');
assert.match(sig1, /^[0-9a-f]{64}$/);

const mutatedPayload = { ...payload, object_ref: 'fixture://evidence/TAMPERED' };
const mutatedHash = crypto.createHash('sha256').update(JSON.stringify(mutatedPayload)).digest('hex');
assert.notEqual(mutatedHash, payloadHash, 'payload mutation must change SHA-256 hash');
const mutatedCanonical = expectedOrder.map((field) => field === 'payload_hash' ? mutatedHash : (envelope[field] ?? '')).join('\n');
assert.notEqual(sign(testSecret, mutatedCanonical), sig1, 'payload mutation must invalidate signature');

const negativeIds = new Set(vectors.negative_tests.map((t) => t.id));
const positiveIds = new Set(vectors.positive_tests.map((t) => t.id));
for (let i = 1; i <= 13; i++) assert(negativeIds.has(`C${String(i).padStart(3, '0')}`), `missing negative commissioning vector C${String(i).padStart(3, '0')}`);
for (let i = 14; i <= 16; i++) assert(positiveIds.has(`C${String(i).padStart(3, '0')}`), `missing positive commissioning vector C${String(i).padStart(3, '0')}`);

const c011 = vectors.negative_tests.find((t) => t.id === 'C011');
assert.equal(c011?.mutation, 'requested_control_level=C3', 'C3 ceiling test missing or altered');
const c016 = vectors.positive_tests.find((t) => t.id === 'C016');
assert.equal(c016?.target_control_level, 'C3', 'human escalation vector must target C3');
assert.match(c016?.expected ?? '', /HUMAN_AUTHORIZATION_REQUIRED/, 'C3 escalation must require human authorization');

const forbidden = ['OEL_SIDEKICK_SHARED_SECRET=', 'sb_secret_', 'service_role'];
const fixtureText = fs.readFileSync(new URL('./sidekick-gateway-test-vectors.json', import.meta.url), 'utf8');
for (const token of forbidden) assert(!fixtureText.includes(token), `forbidden secret-like material found: ${token}`);

console.log('OEL Sidekick contract CI: PASS');
console.log(`canonical_fields=${expectedOrder.length} vectors=${negativeIds.size + positiveIds.size} signature_length=${sig1.length}`);
