# IBG-08 — Treasury & Infrastructure Assurance Matrices

Status: CONTROLLED DRAFT / NON-PRODUCTION
Governance owner: SourceEnergy Foundation Core
Office owner: Office of Treasury & Infrastructure Assurance
Executive lead: Dahlia A. Harrison — Chief Treasury & Infrastructure Assurance Officer
GSF functional assignment: GSF Finance & Treasury Integration Lead

## 1. Purpose

This control document operationalizes the Office of Treasury & Infrastructure Assurance mandate across IBG-02 through IBG-08. It supports GSF strategic institutional integration while preserving confidentiality, maker-checker separation, regulated-authority boundaries, and fail-closed production certification.

Nothing in this document establishes a banking relationship, correspondent relationship, sponsorship, settlement authority, account authority, guarantee, borrowing authority, or production connectivity.

## 2. Executive separation

| Domain | Kai Alexander Ortega | Dahlia A. Harrison | Independent control gate |
|---|---|---|---|
| Sensitive institutional relationships | Steward / relationship navigation | Need-to-know finance coordination | Authorized disclosure + evidence gate |
| Treasury strategy | Consulted where relationship-sensitive | Accountable | Governance approval |
| Account/custody evidence | Consulted | Responsible | IBG-02 checker/compliance |
| Payment funding readiness | Consulted | Responsible | IBG-03 maker-checker + compliance |
| Liquidity/exposure | Informed as necessary | Accountable | IBG-04 limits/governance |
| Trade/project finance | Relationship coordination | Responsible for bankability/assurance | IBG-05 legal/compliance/credit approvals |
| Reconciliation | No settlement-finality authority | Finance assurance | IBG-06 independent settlement-finality gate |
| Institutional certification | Relationship evidence contributor | Treasury evidence owner | IBG-07/08 independent certification |

## 3. Treasury & Infrastructure Assurance responsibility matrix

| Control area | Office responsibility | Required evidence | Prohibited unilateral action | IBG |
|---|---|---|---|---|
| Account & custody | Coordinate mandates, ownership, custody and control evidence | legal entity, account mandate, custody terms, authorized signers | Open/activate/represent an account as production without certification | IBG-02 |
| Payment orchestration | Confirm funding readiness and treasury controls | route scope, limits, maker/checker, funding evidence | Execute or release payments alone | IBG-03 |
| Treasury & liquidity | Set strategy; monitor liquidity, FX and exposure | liquidity source, limits, reserve policy, FX controls | Override limits/compliance holds | IBG-04 |
| Trade/project finance | Structure bankability and assurance package | project model, security package, guarantees, insurance/surety, covenants | Bind guarantor/lender/collateral provider without mandate | IBG-05 |
| Settlement/reconciliation | Coordinate finance evidence and reconciliation assurance | settlement records, reconciliations, exceptions | Declare settlement finality alone | IBG-06 |
| Certification | Own treasury/infrastructure evidence package | immutable evidence refs, scope, dates, approvals | Self-certify institution/route | IBG-07/08 |
| External representation | Coordinate approved finance engagements | written mandate, disclosure scope, authority record | Disclose sensitive relationships or make binding commitments outside mandate | Governance |

## 4. GSF project-bankability & guarantee-assurance matrix

Each project is scored independently. `READY` means evidence is complete for the stated assurance domain; it does not mean financing or a guarantee has been approved.

| Assurance domain | Minimum evidence package | Primary owner | Checker | State |
|---|---|---|---|---|
| Construction/completion protection | scope, EPC/contracting structure, schedule, completion tests, contingency | Project + Dahlia office | Legal/Risk | UNASSESSED |
| Performance/payment security | obligations, performance metrics, payment waterfall, security instruments | Dahlia office | Legal/Compliance | UNASSESSED |
| Revenue/liquidity safeguards | revenue model, reserve policy, DSCR/liquidity analysis, waterfall | Dahlia office | Treasury/Risk | UNASSESSED |
| Credit enhancement/risk sharing | proposed enhancement, risk allocation, counterparties, trigger mechanics | Dahlia office | Credit/Legal | UNASSESSED |
| Insurance/surety | coverage schedule, insurer/surety evidence, exclusions, limits | Dahlia office | Risk/Legal | UNASSESSED |
| Political/currency risk | jurisdiction analysis, FX exposure, mitigation/hedging framework | Dahlia office | Risk/Compliance | UNASSESSED |
| Community asset ring-fencing | ownership, permitted uses, segregation controls, beneficiary protections | Foundation Core | Legal/Governance | UNASSESSED |
| Spatial/data/evidence assurance | asset registry refs, provenance, data controls, evidence integrity | Assurance/Data | Independent checker | UNASSESSED |
| Covenant/exposure/guarantee monitoring | covenant register, exposure limits, monitoring cadence, escalation | Dahlia office | Risk/Governance | UNASSESSED |

## 5. Bankability stage gates

1. `VISION` — concept exists; no finance representation.
2. `FEASIBILITY` — technical/economic feasibility evidence assembled.
3. `CONTROLLED_STRUCTURE` — legal, financial, risk and community protections documented.
4. `ASSURANCE_READY` — evidence package independently checked.
5. `COUNTERPARTY_READY` — authorized package suitable for controlled external engagement.
6. `COMMITMENT_PENDING` — third-party approvals/conditions remain outstanding.
7. `AUTHORIZED_COMMITMENT` — binding authority exists under governing documents and applicable law.
8. `DEPLOYMENT_MONITORING` — covenants, exposure, guarantees and outcomes monitored.

No stage may be skipped by executive assertion.

## 6. Sensitive institutional relationship protocol

- Named institutions and relationship mechanics are need-to-know.
- Ordinary repository records should use controlled relationship identifiers where practical.
- Do not infer relationship scope from logos, introductions, screenshots, BICs, websites or verbal statements.
- Do not publicly characterize endorsement, sponsorship, correspondent status, settlement authority or contractual scope without explicit authorization and evidence.
- Relationship evidence may be referenced by immutable restricted evidence ID rather than copied into GitHub.
- Secrets, reusable credentials, private keys, tokens and private certificate material are prohibited in the repository.
- Kai's relationship stewardship and Dahlia's treasury coordination are complementary but do not substitute for independent certification.

## 7. Approval matrix

| Decision | Preparer | Required independent approval |
|---|---|---|
| Finance evidence package | Dahlia office | Checker + Compliance |
| Payment production enablement | Treasury/Operations | Compliance + IBG certification authority |
| Guarantee/security commitment | Dahlia office / authorized structurer | Governing authority + Legal + applicable credit/risk approval |
| Borrowing/collateral commitment | Authorized finance preparer | Governing authority + Legal + applicable policy approvals |
| Sensitive relationship disclosure | Relationship owner | Authorized mandate / governance |
| Settlement finality | Operations/Reconciliation | Independent IBG-06 finality authority |
| Institution/route production certification | Evidence owners | IBG-07 independent approvers |

## 8. Wave 1 deliverable template

For every applicable GSF/SourceEnergy project or institutional pathway create:

- controlled project/pathway ID
- legal entities and jurisdictions
- authorized relationship owner
- treasury evidence owner
- bankability stage
- assurance-domain states
- evidence references (restricted where necessary)
- exceptions/contradictions
- maker/checker assignments
- required external approvals
- expiry/revalidation dates
- final governance disposition: `NO-GO`, `REMEDIATE`, `CONDITIONALLY_READY`, or `AUTHORIZED`

## 9. Non-authority statement

The Office of Treasury & Infrastructure Assurance coordinates, structures, monitors and assures treasury/infrastructure activities. Guarantees, borrowing, collateral commitments, banking authority, fund transfers and other binding obligations remain subject to governing documents, authorized approvals, contractual requirements and applicable law.
