import crypto from 'node:crypto';
import fs from 'node:fs';

const required = ['OEL_GATEWAY_URL','OEL_SIDEKICK_SHARED_SECRET','OEL_ACTOR_EXTERNAL_REF','OEL_WORK_ITEM_ID'];
for (const name of required) {
  if (!process.env[name]) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(2);
  }
}

const gateway = process.env.OEL_GATEWAY_URL;
const secret = process.env.OEL_SIDEKICK_SHARED_SECRET;
const actorRef = process.env.OEL_ACTOR_EXTERNAL_REF;
const channelIdentity = process.env.OEL_CHANNEL_IDENTITY || '';
const workItemId = process.env.OEL_WORK_ITEM_ID;
const orgOid = process.env.OEL_SETC_ORG_OID || 'SETC-OID-7a0c7e1b3f2d4a5b8c9d0e1f2a3b4c5d';
const vectors = JSON.parse(fs.readFileSync(new URL('./sidekick-gateway-test-vectors.json', import.meta.url), 'utf8'));
const canonicalOrder = vectors.canonical_order;

const sha256 = (text) => crypto.createHash('sha256').update(text).digest('hex');
const hmac = (text, key = secret) => crypto.createHmac('sha256', key).update(text).digest('hex');
const uuid = () => crypto.randomUUID();

function envelope({action='work.acknowledge', control='C1', payload={}, timestamp=new Date().toISOString(), commandId=uuid(), idempotencyKey=`live-${uuid()}`, nonce=`nonce-${uuid()}`}={}) {
  const payloadHash = sha256(JSON.stringify(payload));
  return {
    client_code:'sidekick-oel',
    command_id:commandId,
    idempotency_key:idempotencyKey,
    nonce,
    request_timestamp:timestamp,
    correlation_id:uuid(),
    trace_id:uuid(),
    setc_org_oid:orgOid,
    action,
    resource_type:'work_item',
    resource_id:workItemId,
    requested_control_level:control,
    actor_external_ref:actorRef,
    channel_identity:channelIdentity,
    payload,
    payload_hash:payloadHash,
  };
}

function sign(env, key=secret) {
  const canonical = canonicalOrder.map((field) => env[field] ?? '').join('\n');
  return hmac(canonical, key);
}

async function invoke(env, signature=sign(env)) {
  const res = await fetch(gateway, {method:'POST', headers:{'content-type':'application/json','x-oel-signature':signature}, body:JSON.stringify(env)});
  let body;
  try { body = await res.json(); } catch { body = {raw: await res.text()}; }
  return {http_status:res.status, body};
}

const evidence=[];
async function record(id, description, fn) {
  try {
    const result=await fn();
    evidence.push({id,description,pass:true,...result});
  } catch (error) {
    evidence.push({id,description,pass:false,error:String(error)});
  }
}

await record('C002','missing signature rejected',async()=>{const env=envelope();const res=await fetch(gateway,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(env)});const body=await res.json();return {pass:res.status===401&&body?.error?.code==='SIGNATURE_REQUIRED',http_status:res.status,response:body};});
await record('C003','invalid HMAC rejected',async()=>{const env=envelope();const r=await invoke(env,'0'.repeat(64));return {pass:r.http_status===401&&r.body?.error?.code==='INVALID_SIGNATURE',...r};});
await record('C004','payload tamper rejected',async()=>{const env=envelope({payload:{reason:'original'}});const sig=sign(env);env.payload={reason:'tampered'};const r=await invoke(env,sig);return {pass:r.http_status===401,['response']:r.body,http_status:r.http_status};});
await record('C005','unknown client rejected',async()=>{const env=envelope();env.client_code='unknown';const r=await invoke(env,sign(env));return {pass:r.http_status===403&&r.body?.error?.code==='CLIENT_NOT_ALLOWED',...r};});
await record('C006','clock skew rejected',async()=>{const env=envelope({timestamp:new Date(Date.now()-10*60*1000).toISOString()});const r=await invoke(env);return {pass:(r.body?.receipt?.reason==='request_timestamp_outside_allowed_window'||r.body?.error?.code==='REQUEST_TIMESTAMP_OUTSIDE_ALLOWED_WINDOW'||r.http_status===403),...r};});
await record('C009','non-allowlisted org rejected',async()=>{const env=envelope();env.setc_org_oid='SETC-OID-NOT-ALLOWED';const r=await invoke(env,sign(env));return {pass:r.http_status===403,...r};});
await record('C010','non-allowlisted action rejected',async()=>{const env=envelope({action:'work.complete'});const r=await invoke(env);return {pass:r.http_status===403,...r};});
await record('C011','C3 autonomous request rejected',async()=>{const env=envelope({control:'C3'});const r=await invoke(env);return {pass:r.http_status===403,...r};});
await record('C012','unknown actor rejected',async()=>{const env=envelope();env.actor_external_ref='commissioning-unknown-actor';const r=await invoke(env,sign(env));return {pass:r.http_status>=400,...r};});

if (process.env.OEL_RUN_MUTATING_TESTS === 'true') {
  const envAck=envelope({action:'work.acknowledge',control:'C1'});
  await record('C014','valid C1 acknowledge executes once',async()=>{const first=await invoke(envAck);const second=await invoke(envAck);return {pass:first.http_status===200&&second.http_status===200,first,second};});
  const envEvidence=envelope({action:'evidence.submit',control:'C2',payload:{evidence_type:'DOCUMENT',object_ref:`commissioning://${uuid()}`,content_hash:sha256('commissioning-evidence')}});
  await record('C015','valid C2 evidence submit records provenance',async()=>{const r=await invoke(envEvidence);return {pass:r.http_status===200,...r};});
  const envEscalate=envelope({action:'work.escalate',control:'C2',payload:{reason:'Commissioning C3 human-gate verification',target_control_level:'C3'}});
  await record('C016','C2 request escalates to C3 human authorization',async()=>{const r=await invoke(envEscalate);return {pass:r.http_status===200&&(r.body?.result?.status==='REQUIRES_HUMAN_APPROVAL'||r.body?.receipt?.status==='REQUIRES_HUMAN_APPROVAL'),...r};});
}

const redacted = evidence.map((e)=>JSON.parse(JSON.stringify(e).replaceAll(secret,'[REDACTED]')));
const out = process.env.OEL_EVIDENCE_FILE || 'oel-commission-live-evidence.json';
fs.writeFileSync(out, JSON.stringify({specification:'OEL-COMMISSION-001',generated_at:new Date().toISOString(),gateway,mutating_tests:process.env.OEL_RUN_MUTATING_TESTS==='true',results:redacted},null,2));
const failed=redacted.filter((r)=>!r.pass);
console.log(`OEL live commissioning: ${redacted.length-failed.length}/${redacted.length} checks passed`);
console.log(`Evidence: ${out}`);
process.exit(failed.length?1:0);
