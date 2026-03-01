"""
Executor - Action execution layer with approval and safety interlocks.

This is the ONLY layer with authority to cause side effects.

Phase 4D: First real execution with safety gates.

The Executor:
- Validates safety and permissions
- Requires explicit approval
- Routes execution to adapters
- Manages idempotency (Phase 4D)
- Enforces real-execution gate (Phase 4D)
- Audits all actions

The Executor does NOT:
- Make decisions (Rule Engine does this)
- Evaluate rules (Rule Engine does this)
- Provide explanations (LLM Advisory does this)
"""
import logging
import os
from typing import Optional, List, Set, TYPE_CHECKING
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum

from .rule_engine import MatchedRule
from .approval import ApprovalProvider, ApprovalDecision, ApprovalStatus

if TYPE_CHECKING:
    from .execution_adapter import ExecutionAdapter

logger = logging.getLogger(__name__)


class ExecutionStatus(Enum):
    """Status of an execution attempt."""
    PENDING = "pending"
    EXECUTED = "executed"
    SKIPPED = "skipped"
    DENIED = "denied"
    FAILED = "failed"


@dataclass
class RollbackResult:
    """Result of a rollback attempt."""
    success: bool
    message: str
    error: Optional[str] = None


@dataclass
class ExecutionResult:
    """Result of an execution attempt."""
    rule_id: str
    outcome_code: str
    validated: bool
    approved: bool
    executed: bool
    result: str  # "success", "failed", "denied", "not_executed", "skipped"
    status: ExecutionStatus = ExecutionStatus.PENDING
    adapter: Optional[str] = None  # Name of adapter used
    message: Optional[str] = None  # Execution message
    approval_id: Optional[str] = None  # Link to approval decision (Phase 4D)
    rollback_available: bool = False  # Phase 4D
    rollback_info: Optional[str] = None  # Phase 4D
    error: Optional[str] = None
    timestamp: str = ""
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


class Executor:
    """
    Executor layer with approval and safety interlocks.
    
    CRITICAL: This is the ONLY layer with authority to cause side effects.
    """
    
    def __init__(
        self,
        enabled: bool = True,
        approval_required: bool = True,
        kill_switch: bool = False,
        whitelist: Optional[list] = None,
        blacklist: Optional[list] = None,
        approval_provider: Optional[ApprovalProvider] = None,
        execution_adapter: Optional['ExecutionAdapter'] = None,
        real_execution_enabled: bool = False  # Gate for real power (Phase 4D)
    ):
        """
        Initialize executor.
        """
        self.enabled = enabled
        self.approval_required = approval_required
        self.kill_switch = kill_switch
        self.whitelist = whitelist or []
        self.blacklist = blacklist or []
        self.approval_provider = approval_provider
        self.execution_adapter = execution_adapter
        self.real_execution_enabled = real_execution_enabled
        
        # Idempotency tracking (Phase 4D - in-memory for now)
        self._executed_ids: Set[str] = set()
        
        # Audit logs (in-memory for now)
        self._approval_log: List[ApprovalDecision] = []
        self._execution_log: List[ExecutionResult] = []
        
        # Internal state for traceability
        self._last_approval_id: Optional[str] = None
        
        if not enabled:
            logger.info("Executor disabled by configuration")
        if kill_switch:
            logger.warning("⚠️  KILL SWITCH ACTIVE - All execution blocked")
        if real_execution_enabled:
            logger.warning("🚨 REAL EXECUTION ENABLED - Use with caution")
    
    def validate(self, matched_rule: MatchedRule) -> bool:
        """
        Validate that action is safe and allowed.
        """
        if not self.enabled:
            logger.info(f"Rule {matched_rule.rule_id}: Executor disabled")
            return False
        
        if self.kill_switch:
            logger.info(f"Rule {matched_rule.rule_id}: Kill switch active")
            return False
        
        outcome_code = matched_rule.outcome.code
        
        if self.blacklist and outcome_code in self.blacklist:
            logger.info(f"Rule {matched_rule.rule_id}: Outcome code '{outcome_code}' blacklisted")
            return False
        
        if self.whitelist and outcome_code not in self.whitelist:
            logger.info(f"Rule {matched_rule.rule_id}: Outcome code '{outcome_code}' not in whitelist")
            return False
        
        logger.debug(f"Rule {matched_rule.rule_id}: Validation passed")
        return True
    
    def request_approval(self, matched_rule: MatchedRule) -> bool:
        """
        Request approval for action execution.
        """
        if not self.approval_required:
            logger.debug(f"Rule {matched_rule.rule_id}: Auto-approved")
            return True
        
        if self.approval_provider:
            decision = self.approval_provider.request_approval(matched_rule)
            self._approval_log.append(decision)
            
            # Explicit reference for Phase 4D Traceability
            self._last_approval_id = f"approval_{len(self._approval_log)}"
            
            logger.info(f"Rule {matched_rule.rule_id}: Approval {decision.status.value} - {decision.reason}")
            return decision.status == ApprovalStatus.APPROVED
        
        logger.info(f"Rule {matched_rule.rule_id}: Approval required (no provider)")
        return False
    
    def execute(self, matched_rule: MatchedRule) -> ExecutionResult:
        """
        Execute action for matched rule.
        """
        rule_id = matched_rule.rule_id
        outcome_code = matched_rule.outcome.code
        
        # PHASE 4D: Idempotency Check (before any side effects)
        execution_id = f"{rule_id}:{outcome_code}"
        if execution_id in self._executed_ids:
            logger.info(f"Rule {rule_id}: Duplicate execution prevented (idempotent)")
            result = ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=True,
                approved=True,
                executed=False,
                result="skipped",
                status=ExecutionStatus.SKIPPED,
                message="Duplicate execution prevented"
            )
            self._execution_log.append(result)
            return result

        # 1. Validate
        if not self.validate(matched_rule):
            logger.info(f"Rule {rule_id}: Validation failed, not executing")
            result = ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=False,
                approved=False,
                executed=False,
                result="not_executed",
                status=ExecutionStatus.DENIED,
                error="Validation failed"
            )
            self._execution_log.append(result)
            return result
        
        # 2. Request approval
        if not self.request_approval(matched_rule):
            logger.info(f"Rule {rule_id}: Approval denied, not executing")
            result = ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=True,
                approved=False,
                executed=False,
                result="denied",
                status=ExecutionStatus.DENIED,
                error="Approval denied"
            )
            self._execution_log.append(result)
            return result
        
        # 3. Handle Real Execution Gate (Phase 4D)
        if self._is_real_adapter():
            if not self.real_execution_enabled:
                logger.warning(f"Rule {rule_id}: Real execution blocked by configuration gate")
                result = ExecutionResult(
                    rule_id=rule_id,
                    outcome_code=outcome_code,
                    validated=True,
                    approved=True,
                    executed=False,
                    result="failed",
                    status=ExecutionStatus.FAILED,
                    error="Real execution disabled (EXECUTOR_REAL_EXECUTION_ENABLED=false)"
                )
                self._execution_log.append(result)
                return result

        # 4. Route to Adapter
        if self.execution_adapter:
            logger.info(f"Rule {rule_id}: Routing to adapter '{self.execution_adapter.get_name()}'")
            result = self.execution_adapter.execute(matched_rule)
            
            # Traceability: Link explicit approval ID
            result.approval_id = self._last_approval_id
            
            # Idempotency: Record successful real execution
            if result.executed:
                 self._executed_ids.add(execution_id)
                 
            self._execution_log.append(result)
            return result
        else:
            # No adapter - backward compatible skeleton mode
            logger.info(f"Rule {rule_id}: No execution adapter configured (skeleton mode)")
            result = ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=True,
                approved=True,
                executed=False,
                result="success",
                status=ExecutionStatus.PENDING,
                message="No execution adapter configured (skeleton mode)"
            )
            self._execution_log.append(result)
            return result

    def _is_real_adapter(self) -> bool:
        """Checks if the configured adapter is a real (not dry-run) adapter."""
        if not self.execution_adapter:
            return False
        # Logic: dry-run adapters are explicitly named
        return self.execution_adapter.get_name() not in ["noop", "log"]

    def activate_kill_switch(self):
        """Emergency stop."""
        self.kill_switch = True
        logger.critical("⚠️  KILL SWITCH ACTIVATED")
    
    def deactivate_kill_switch(self):
        """Resumes normal operation."""
        self.kill_switch = False
        logger.info("Kill switch deactivated")

    def is_kill_switch_active(self) -> bool:
        """Check if kill switch is active."""
        return self.kill_switch
    
    def get_approval_log(self) -> List[ApprovalDecision]:
        return self._approval_log.copy()
    
    def clear_approval_log(self):
        self._approval_log.clear()
        self._last_approval_id = None
    
    def get_execution_log(self) -> List[ExecutionResult]:
        return self._execution_log.copy()
    
    def clear_execution_log(self):
        self._execution_log.clear()
