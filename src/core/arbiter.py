"""
Arbiter - Safety gate for Dual-Engine Architecture.

This module provides the Arbiter which combines Rule Engine results
with Agent proposals to produce a final, safe decision.

CRITICAL SAFETY INVARIANTS:
- Rule Engine outcomes are ALWAYS prioritized.
- Agent proposals are ADVISORY-ONLY.
- Rule Engine remains the authoritative source of truth.
"""
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime, timezone

from .rule_engine import RuleEvaluationResult, MatchedRule
from .planner_agent import AgentPlan

logger = logging.getLogger(__name__)


@dataclass
class ArbiterDecision:
    """Final decision from the Arbiter gate."""
    rule_outcomes: List[str]
    agent_outcomes: List[str]
    agent_confidence: float
    agent_used: bool
    final_outcomes: List[str]
    decision_source: str # "rule_engine", "agent_optimized"
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'))


class Arbiter:
    """
    Arbiter gate for combining rules and LLM advice.
    
    This gate:
    - Maintains rule engine authority
    - Merges advisory outcomes safely
    - Defaults to rule engine on conflict
    """
    
    def __init__(self, override_allowed: bool = False):
        """
        Initialize arbiter.
        
        Args:
            override_allowed: Whether agent can theoretically override rules 
                             (CRITICAL: False for Phase 5 demo).
        """
        self.override_allowed = override_allowed

    def decide(
        self,
        rule_result: RuleEvaluationResult,
        agent_plan: AgentPlan
    ) -> ArbiterDecision:
        """
        Combines rule results with agent plan.
        
        Args:
            rule_result: Authoritative results from Rule Engine
            agent_plan: Advisory proposals from Planner Agent
            
        Returns:
            ArbiterDecision resolving conflict with safety
        """
        # Extract rule-based outcome codes
        rule_codes = [rule.outcome.code for rule in rule_result.matched_rules]
        
        # Determine final outcomes
        # Phase 5 Safety Rule: Rule Engine ALWAYS wins.
        # We include agent outcomes only if they don't conflict, 
        # or we just show them alongside for human approval.
        
        final_outcomes = list(rule_codes) # Authority
        
        # SOURCE TRACEABILITY
        source = "rule_engine"
        
        # If agent is high confidence and used, we could potentially add its advice,
        # but for the demo, we keep rules as the absolute baseline.
        # We return both for the Advisor and Approver to see.
        
        logger.info(f"Arbiter: Rules matched {len(rule_codes)}, Agent plan used: {agent_plan.agent_used}")
        
        return ArbiterDecision(
            rule_outcomes=rule_codes,
            agent_outcomes=agent_plan.proposed_outcomes,
            agent_confidence=agent_plan.confidence,
            agent_used=agent_plan.agent_used,
            final_outcomes=final_outcomes,
            decision_source=source
        )
