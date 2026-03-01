"""
Planner Agent - LLM-powered advisory planner.

This module provides the PlannerAgent which interprets goals and proposes
candidate outcomes based on current system state.

CRITICAL SAFETY INVARIANTS:
- The PlannerAgent is ADVISORY-ONLY.
- It NEVER executes actions.
- It NEVER approves decisions.
- It NEVER overrides rules (managed by Arbiter).
"""
import logging
import json
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from .llm_client import LLMClient
from .goal_schema import SemanticGoal

logger = logging.getLogger(__name__)


@dataclass
class AgentPlan:
    """Proposals from the Agentic AI."""
    proposed_outcomes: List[str]
    reasoning: str
    confidence: float
    agent_used: bool


class PlannerAgent:
    """
    LLM-powered advisory planner.
    
    This agent:
    - Interprets natural language goals
    - Reasons over current state
    - Proposes possible outcomes
    - Does NOT execute or approve
    """
    
    # LOCKED SYSTEM PROMPT (immutable, hard-coded for safety)
    SYSTEM_PROMPT = """You are a Smart Home Advisory Planner.
Your role is to interpret a user's Goal given the current State and propose a list of Outcome codes.
Each outcome code must be a string (e.g., 'LIGHT_BRIGHT', 'COZY_MODE').

SAFETY RULES:
1. You are ADVISORY ONLY.
2. You do NOT execute actions.
3. You do NOT mutate state.
4. You do NOT have authority to override hard rules.
5. If the goal is unclear or state is missing, return an empty list of outcomes.

Output format: JSON only.
{
  "proposed_outcomes": ["CODE1", "CODE2"],
  "reasoning": "Brief explanation of your plan",
  "confidence": 0.0-1.0
}"""

    def __init__(
        self,
        llm_client: LLMClient,
        enabled: bool = True,
        timeout_sec: float = 2.0
    ):
        """
        Initialize planner agent.
        
        Args:
            llm_client: Client for LLM interactions
            enabled: Configuration-level switch
            timeout_sec: Maximum time allowed for LLM response
        """
        self.llm_client = llm_client
        self.enabled = enabled
        self.timeout_sec = timeout_sec
        
        if not enabled:
            logger.info("Planner Agent disabled by configuration")
        elif not llm_client.enabled:
            logger.info("Planner Agent disabled (LLM client not available)")

    def propose_plan(self, state: Dict[str, Any], goal: SemanticGoal) -> AgentPlan:
        """
        Generate a plan based on goal and state.
        
        This is a non-authoritative proposal.
        
        Args:
            state: Current system state
            goal: Natural language goal
            
        Returns:
            AgentPlan with proposals or fallback if failed
        """
        if not self.enabled or not self.llm_client or not self.llm_client.enabled:
            return self._fallback_plan("Agent disabled")
            
        # Construct prompt using normalized semantic goal
        goal_data = {
            "intent": goal.intent,
            "dimension": goal.dimension,
            "priority": goal.priority
        }
        prompt = f"System State: {json.dumps(state)}\nNormalized Goal: {json.dumps(goal_data)}"
        
        try:
            logger.debug(f"Planner Agent requesting plan for semantic goal: {goal.intent}/{goal.dimension}")
            
            # Using query directly (timeout handled by LLMClient/Provider)
            llm_response = self.llm_client.query(
                prompt=prompt,
                system_prompt=self.SYSTEM_PROMPT,
                json_mode=True
            )
            
            if llm_response is None:
                logger.warning("Planner LLM returned None")
                return self._fallback_plan("LLM failed to respond")
            
            # Validate and parse response
            return self._parse_agent_response(llm_response)
            
        except Exception as e:
            logger.error(f"Planner Agent failed: {e}")
            return self._fallback_plan(str(e))

    def _parse_agent_response(self, response: Dict[str, Any]) -> AgentPlan:
        """Validates and parses the LLM output into an AgentPlan."""
        try:
            outcomes = response.get("proposed_outcomes", [])
            if not isinstance(outcomes, list):
                outcomes = []
            
            # Filter for string codes only
            outcomes = [str(o) for o in outcomes]
            
            reasoning = str(response.get("reasoning", "No reasoning provided"))
            
            try:
                confidence = float(response.get("confidence", 0.0))
                confidence = max(0.0, min(1.0, confidence))
            except (ValueError, TypeError):
                confidence = 0.0
                
            return AgentPlan(
                proposed_outcomes=outcomes,
                reasoning=reasoning,
                confidence=confidence,
                agent_used=True
            )
        except Exception as e:
            logger.error(f"Error parsing agent response: {e}")
            return self._fallback_plan("Invalid JSON structure")

    def _fallback_plan(self, message: str) -> AgentPlan:
        """Safe fallback when agent is unavailable or fails."""
        return AgentPlan(
            proposed_outcomes=[],
            reasoning=f"Fallback: {message}",
            confidence=0.0,
            agent_used=False
        )
