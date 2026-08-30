# SourceEnergy One Authorization Broker v1

## Invariant
HeartBeatID establishes bounded identity/presence assurance. It never constitutes authorization for a consequential action.

## Staging flow
1. Verify signed HeartBeat provider assertion.
2. Atomically consume assertion with `consume_heartbeat_step_up`.
3. Create an Access Context carrying the HeartBeat authentication factor.
4. Persist policy decision `require_authorization`.
5. Create a pending authorization request with `request_consequential_authorization`.
6. An accountable human approver explicitly approves or declines through `decide_consequential_authorization`.
7. Only an approved request may contribute an `allow` policy decision. Execution remains separately gated by the target adapter being enabled and the execution service validating the authorization/correlation chain.
8. Execution and failures produce correlated execution receipts and audit events.

## Staging evidence
A controlled staging assertion was consumed under correlation ID `2ba39c81-f75e-4df5-a7b0-295b6a037e10` and produced Access Context `78164d55-2ac7-4ba6-bb85-fee89daae834` at institutional assurance. The resulting policy decision is `require_authorization`. Authorization request `debcaef8-1894-4f6e-a7fd-133cfa90b9f8` is intentionally pending. At the verification point, executed receipts for the correlation were zero.

This fixture is non-biometric synthetic staging evidence; it contains no raw physiological signal or reusable biometric template.

## Production gate
Do not enable the `heartbeat-id` adapter until licensing/field-of-use rights, provider trust material, asymmetric signature verification, sensor attestation, privacy/consent controls, authorization-broker integration and release-gate tests are approved.
