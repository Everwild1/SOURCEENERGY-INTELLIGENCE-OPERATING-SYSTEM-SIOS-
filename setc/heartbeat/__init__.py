"""SETC HeartBeat biometric identity domain.

Implements the bounded engineering contract from SETC-HB-001. This package
models authentication, liveness, continuity, and authority-binding assertions;
it does not model clinical diagnosis or confer legal, financial, or governance
authority.
"""

from .models import (
    HeartBeatAssertion,
    HeartBeatCapability,
    HeartBeatDecision,
    HeartBeatIdentifiers,
)

__all__ = [
    "HeartBeatAssertion",
    "HeartBeatCapability",
    "HeartBeatDecision",
    "HeartBeatIdentifiers",
]
