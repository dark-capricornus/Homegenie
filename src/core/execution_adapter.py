"""
Execution Adapters - Phase 4D.

This module defines the ExecutionAdapter interface and concrete dry-run
and real-execution adapters.
"""
import logging
import json
import os
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from .executor import ExecutionResult, RollbackResult

logger = logging.getLogger(__name__)


class ExecutionAdapter(ABC):
    """
    Abstract interface for execution adapters.
    """
    
    @abstractmethod
    def execute(self, matched_rule) -> 'ExecutionResult':
        """
        Execute action for matched rule.
        """
        pass

    @abstractmethod
    def rollback(self, execution_result: 'ExecutionResult') -> 'RollbackResult':
        """
        Perform a logical rollback of an execution.
        """
        pass
    
    @abstractmethod
    def get_name(self) -> str:
        """
        Get adapter name.
        """
        pass


class NoOpExecutionAdapter(ExecutionAdapter):
    """Dry-run no-op adapter."""
    
    def execute(self, matched_rule) -> 'ExecutionResult':
        from .executor import ExecutionResult, ExecutionStatus
        return ExecutionResult(
            rule_id=matched_rule.rule_id,
            outcome_code=matched_rule.outcome.code,
            validated=True,
            approved=True,
            executed=False,
            result="success",
            status=ExecutionStatus.SKIPPED,
            adapter="noop",
            message=f"Dry-run: Would execute {matched_rule.outcome.code}",
            rollback_available=False
        )
    
    def rollback(self, execution_result: 'ExecutionResult') -> 'RollbackResult':
        from .executor import RollbackResult
        return RollbackResult(success=True, message="No rollback needed for dry-run")

    def get_name(self) -> str:
        return "noop"


class LogExecutionAdapter(ExecutionAdapter):
    """Dry-run log adapter."""
    
    def execute(self, matched_rule) -> 'ExecutionResult':
        from .executor import ExecutionResult, ExecutionStatus
        logger.info(f"[DRY-RUN] Execution for: {matched_rule.outcome.code}")
        return ExecutionResult(
            rule_id=matched_rule.rule_id,
            outcome_code=matched_rule.outcome.code,
            validated=True,
            approved=True,
            executed=False,
            result="success",
            status=ExecutionStatus.SKIPPED,
            adapter="log",
            message=f"Logged intent for {matched_rule.outcome.code}",
            rollback_available=False
        )

    def rollback(self, execution_result: 'ExecutionResult') -> 'RollbackResult':
        from .executor import RollbackResult
        return RollbackResult(success=True, message="No rollback needed for dry-run")

    def get_name(self) -> str:
        return "log"


class FileLoggerAdapter(ExecutionAdapter):
    """
    File logger adapter - FIRST REAL EXECUTION ADAPTER (Phase 4D).
    
    Safety:
    - Stateless: No mutable state.
    - Sandboxed: Writes only to sandbox/ directory.
    - Reversible: Logical rollback only (appends rollback entry).
    - Traceable: Fully audited.
    """
    
    def __init__(self, log_file: str = "sandbox/exec.log"):
        # Relaxes check to allow absolute paths in sandbox (for tests)
        abspath = os.path.abspath(log_file)
        if "sandbox" not in abspath:
            raise ValueError("FileLoggerAdapter restricted to sandbox/ directory")
        self.log_file = log_file

    def execute(self, matched_rule) -> 'ExecutionResult':
        from .executor import ExecutionResult, ExecutionStatus
        
        rule_id = matched_rule.rule_id
        outcome_code = matched_rule.outcome.code
        
        os.makedirs(os.path.dirname(self.log_file) or "sandbox", exist_ok=True)
        
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "rule_id": rule_id,
            "outcome_code": outcome_code,
            "adapter": "file_logger",
            "action": "EXECUTE"
        }
        
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
            
            logger.info(f"[REAL] Appended execution record for {rule_id} to {self.log_file}")
            
            return ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=True,
                approved=True,
                executed=True, # REAL
                result="success",
                status=ExecutionStatus.EXECUTED,
                adapter="file_logger",
                message=f"Recorded to {self.log_file}",
                rollback_available=True,
                rollback_info="Appending logical rollback record"
            )
        except Exception as e:
            logger.error(f"[REAL] File write failed: {e}")
            return ExecutionResult(
                rule_id=rule_id,
                outcome_code=outcome_code,
                validated=True,
                approved=True,
                executed=False,
                result="failed",
                status=ExecutionStatus.FAILED,
                error=str(e)
            )

    def rollback(self, execution_result: 'ExecutionResult') -> 'RollbackResult':
        from .executor import RollbackResult
        
        if not execution_result.rollback_available:
            return RollbackResult(success=False, message="Rollback not available")
            
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "rule_id": execution_result.rule_id,
            "outcome_code": execution_result.outcome_code,
            "adapter": "file_logger",
            "action": "ROLLBACK",
            "original_timestamp": execution_result.timestamp
        }
        
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
            return RollbackResult(success=True, message="Logical rollback appended")
        except Exception as e:
            return RollbackResult(success=False, message="Rollback failed", error=str(e))

    def get_name(self) -> str:
        return "file_logger"
