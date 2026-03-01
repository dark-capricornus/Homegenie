"""
Approval Models and Providers - Phase 4B.

This module defines:
- Approval domain models (ApprovalDecision, ApprovalStatus)
- ApprovalProvider abstract interface
- Concrete approval providers (Manual, Policy-based)

No execution logic. No side effects. Approval decisions only.
"""
import logging
from enum import Enum
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional, List
from abc import ABC, abstractmethod

from .rule_engine import MatchedRule

logger = logging.getLogger(__name__)


class ApprovalStatus(Enum):
    """Status of an approval request."""
    PENDING = "pending"
    APPROVED = "approved"
    DENIED = "denied"
    EXPIRED = "expired"


@dataclass
class ApprovalDecision:
    """
    Result of an approval request.
    
    This is the output of an approval provider.
    """
    status: ApprovalStatus
    reason: str
    timestamp: str
    approver: str  # "manual", "policy", "auto", etc.
    rule_id: str
    outcome_code: str
    
    def __post_init__(self):
        """Ensure timestamp is set."""
        if not self.timestamp:
            self.timestamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


class ApprovalProvider(ABC):
    """
    Abstract interface for approval providers.
    
    Approval providers make decisions about whether to approve
    or deny execution of a matched rule.
    
    Providers must be:
    - Deterministic (same input → same output)
    - Pure (no side effects)
    - Fast (no blocking I/O)
    """
    
    @abstractmethod
    def request_approval(self, matched_rule: MatchedRule) -> ApprovalDecision:
        """
        Request approval for a matched rule.
        
        Args:
            matched_rule: Rule requiring approval
            
        Returns:
            ApprovalDecision with status and reason
        """
        pass


class ManualApprovalProvider(ApprovalProvider):
    """
    Manual approval provider (simulated).
    
    In production, this would prompt a human operator via CLI, UI, or API.
    For now, it's a configurable stub for testing.
    
    Default behavior: DENY (safe default).
    """
    
    def __init__(self, auto_approve: bool = False, auto_deny: bool = True):
        """
        Initialize manual approval provider.
        
        Args:
            auto_approve: If True, automatically approve all requests
            auto_deny: If True, automatically deny all requests (default)
        """
        if auto_approve and auto_deny:
            raise ValueError("Cannot set both auto_approve and auto_deny to True")
        
        self.auto_approve = auto_approve
        self.auto_deny = auto_deny
        
        if auto_approve:
            logger.warning("ManualApprovalProvider: Auto-approve enabled (unsafe for production)")
    
    def request_approval(self, matched_rule: MatchedRule) -> ApprovalDecision:
        """
        Request manual approval (simulated).
        
        Args:
            matched_rule: Rule to approve
            
        Returns:
            ApprovalDecision
        """
        if self.auto_approve:
            logger.debug(f"Rule {matched_rule.rule_id}: Auto-approved (manual provider configured)")
            return ApprovalDecision(
                status=ApprovalStatus.APPROVED,
                reason="Auto-approved (manual provider configured for testing)",
                timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                approver="manual",
                rule_id=matched_rule.rule_id,
                outcome_code=matched_rule.outcome.code
            )
        else:
            # Default: deny (safe default)
            logger.debug(f"Rule {matched_rule.rule_id}: Denied (manual approval required)")
            return ApprovalDecision(
                status=ApprovalStatus.DENIED,
                reason="Manual approval required (not implemented)",
                timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                approver="manual",
                rule_id=matched_rule.rule_id,
                outcome_code=matched_rule.outcome.code
            )


class PolicyApprovalProvider(ApprovalProvider):
    """
    Policy-based approval provider.
    
    Makes approval decisions based on:
    - Outcome code whitelist/blacklist
    - Priority thresholds
    - Pure deterministic logic
    
    No side effects. No LLM calls. No external dependencies.
    Default behavior: DENY (safe default).
    """
    
    def __init__(
        self,
        auto_approve_codes: Optional[List[str]] = None,
        auto_deny_codes: Optional[List[str]] = None,
        max_auto_approve_priority: Optional[int] = None
    ):
        """
        Initialize policy approval provider.
        
        Args:
            auto_approve_codes: Outcome codes to auto-approve
            auto_deny_codes: Outcome codes to auto-deny (takes precedence)
            max_auto_approve_priority: Max priority for auto-approval
        """
        self.auto_approve_codes = auto_approve_codes or []
        self.auto_deny_codes = auto_deny_codes or []
        self.max_auto_approve_priority = max_auto_approve_priority
        
        logger.info(f"PolicyApprovalProvider initialized: "
                   f"approve={self.auto_approve_codes}, "
                   f"deny={self.auto_deny_codes}, "
                   f"max_priority={self.max_auto_approve_priority}")
    
    def request_approval(self, matched_rule: MatchedRule) -> ApprovalDecision:
        """
        Make approval decision based on policy.
        
        Args:
            matched_rule: Rule to approve
            
        Returns:
            ApprovalDecision
        """
        outcome_code = matched_rule.outcome.code
        priority = matched_rule.priority
        
        # Check deny list first (takes precedence)
        if outcome_code in self.auto_deny_codes:
            logger.debug(f"Rule {matched_rule.rule_id}: Denied by policy (blacklisted)")
            return ApprovalDecision(
                status=ApprovalStatus.DENIED,
                reason=f"Outcome code '{outcome_code}' is in deny list",
                timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                approver="policy",
                rule_id=matched_rule.rule_id,
                outcome_code=outcome_code
            )
        
        # Check approve list
        if outcome_code in self.auto_approve_codes:
            # Also check priority threshold if set
            if self.max_auto_approve_priority is not None:
                if priority > self.max_auto_approve_priority:
                    logger.debug(f"Rule {matched_rule.rule_id}: Denied by policy (priority too high)")
                    return ApprovalDecision(
                        status=ApprovalStatus.DENIED,
                        reason=f"Priority {priority} exceeds max auto-approve priority {self.max_auto_approve_priority}",
                        timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                        approver="policy",
                        rule_id=matched_rule.rule_id,
                        outcome_code=outcome_code
                    )
            
            logger.debug(f"Rule {matched_rule.rule_id}: Approved by policy (whitelisted)")
            return ApprovalDecision(
                status=ApprovalStatus.APPROVED,
                reason=f"Outcome code '{outcome_code}' is in approve list",
                timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
                approver="policy",
                rule_id=matched_rule.rule_id,
                outcome_code=outcome_code
            )
        
        # Default: deny (safe default)
        logger.debug(f"Rule {matched_rule.rule_id}: Denied by policy (no match)")
        return ApprovalDecision(
            status=ApprovalStatus.DENIED,
            reason="No policy match (default deny)",
            timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            approver="policy",
            rule_id=matched_rule.rule_id,
            outcome_code=outcome_code
        )
