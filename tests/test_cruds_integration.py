from decimal import Decimal

from setc.cruds.integration import (
    IntelligenceProjection,
    OpportunityResponseReference,
    SettlementRail,
    SettlementRequest,
    WimMarketAccessRequest,
)


def test_opportunity_response_is_non_binding():
    response = OpportunityResponseReference("cruds:response:1")
    assert response.creates_binding_contract is False
    assert response.creates_transaction is False


def test_wim_request_does_not_own_wim_workflow():
    request = WimMarketAccessRequest("cruds:wim:1", "commercialization", "cruds:work:1")
    assert request.owns_wim_workflow is False


def test_source_coin_settlement_request_never_mutates_ledger_or_confers_finality():
    request = SettlementRequest(
        request_reference="cruds:settlement:1",
        idempotency_key="cruds-settlement-1",
        rail=SettlementRail.SOURCE_COIN,
        amount=Decimal("100"),
        currency_code="SRC",
    )
    assert request.is_final is False
    assert request.mutates_source_coin_ledger is False


def test_intelligence_projection_is_not_transaction_authority():
    projection = IntelligenceProjection("cruds:work:1", "v1", "wealth-ecology-v1")
    assert projection.is_authoritative_transaction_state is False
