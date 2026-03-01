"""
LLM Advisory Layer - Human-readable summaries of rule engine decisions.

This module provides ADVISORY-ONLY output. The LLM:
- Does NOT make decisions
- Does NOT execute actions
- Does NOT mutate state
- Does NOT bypass rule engine

The LLM is a commentator, not a controller.
"""
import json
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from copy import deepcopy

from .llm_client import LLMClient
from .rule_engine import RuleEvaluationResult, MatchedRule

logger = logging.getLogger(__name__)


@dataclass
class RuleDetail:
    """Human-readable explanation of a single rule."""
    rule_id: str
    explanation: str


@dataclass
class AdvisoryResult:
    """
    Advisory output from LLM (non-authoritative).
    
    This is commentary only, not a decision.
    """
    summary: str
    details: List[RuleDetail]
    suggestions: List[str]
    confidence: float
    enabled: bool  # Whether LLM was actually used


class LLMAdvisor:
    """
    Advisory layer that summarizes rule engine decisions.
    
    CRITICAL: This class does NOT make decisions, execute actions, or mutate state.
    It only provides human-readable explanations of existing decisions.
    
    The rule engine is the single source of truth.
    The LLM is a commentator only.
    """
    
    # LOCKED SYSTEM PROMPT (immutable, hard-coded)
    SYSTEM_PROMPT = """You are an advisory assistant.
You do NOT make decisions, execute actions, or override rules.
You explain and summarize provided decisions only.
You must never invent data or recommend actions beyond given outcomes."""
    
    # DEVELOPER PROMPT (structural guidance)
    DEVELOPER_PROMPT = """Given the following rule evaluation results, provide:

1. A brief summary of what happened
2. Human-readable explanations for each matched rule
3. Optional, non-binding suggestions based ONLY on the outcomes provided

Rules:
- Do NOT invent new facts or data
- Do NOT change rule priorities or outcome codes
- Do NOT recommend actions beyond what the outcomes suggest
- Keep explanations clear and concise

Respond in JSON format:
{
  "summary": "Brief overview",
  "details": [
    {"rule_id": "R001", "explanation": "Human-readable explanation"}
  ],
  "suggestions": ["Optional suggestion based on outcomes"],
  "confidence": 0.0-1.0
}"""
    
    def __init__(self, llm_client: LLMClient, enabled: bool = True):
        """
        Initialize advisory layer.
        
        Args:
            llm_client: LLM client for generating summaries
            enabled: Whether to use LLM (if False, always use fallback)
        """
        self.llm_client = llm_client
        self.enabled = enabled
        
        if not enabled:
            logger.info("LLM advisory layer disabled by configuration")
        elif not llm_client.enabled:
            logger.info("LLM advisory layer disabled (LLM client not available)")
    
    def summarize(self, result: RuleEvaluationResult) -> AdvisoryResult:
        """
        Generate human-readable summary of rule evaluation.
        
        This method:
        - Does NOT modify the input result
        - Returns safe fallback if LLM unavailable
        - Validates LLM output strictly
        - Never crashes on LLM failure
        
        Args:
            result: Rule evaluation result from rule engine
            
        Returns:
            AdvisoryResult with human-readable summaries
        """
        # Check if LLM is available
        if not self.enabled or not self.llm_client.enabled:
            logger.debug("LLM advisory disabled, using fallback")
            return self._create_fallback_advisory(result)
        
        # Sanitize input (only matched rules, no raw state)
        sanitized_input = self._sanitize_input(result)
        
        # Construct prompt
        user_prompt = f"Rule evaluation results:\n{json.dumps(sanitized_input, indent=2)}"
        
        # Combine prompts
        full_prompt = f"{self.DEVELOPER_PROMPT}\n\n{user_prompt}"
        
        # Query LLM
        try:
            logger.debug("Requesting advisory summary from LLM")
            llm_response = self.llm_client.query(
                prompt=full_prompt,
                system_prompt=self.SYSTEM_PROMPT,
                json_mode=True
            )
            
            # Validate response
            if llm_response is None:
                logger.warning("LLM returned None, using fallback")
                return self._create_fallback_advisory(result)
            
            # Validate JSON schema
            validated = self._validate_advisory_output(llm_response)
            if validated is None:
                logger.warning("LLM output validation failed, using fallback")
                return self._create_fallback_advisory(result)
            
            # Parse into AdvisoryResult
            return AdvisoryResult(
                summary=validated["summary"],
                details=[
                    RuleDetail(
                        rule_id=detail["rule_id"],
                        explanation=detail["explanation"]
                    )
                    for detail in validated["details"]
                ],
                suggestions=validated.get("suggestions", []),
                confidence=validated.get("confidence", 0.5),
                enabled=True
            )
            
        except Exception as e:
            logger.error(f"LLM advisory failed: {e}")
            return self._create_fallback_advisory(result)
    
    def _sanitize_input(self, result: RuleEvaluationResult) -> Dict[str, Any]:
        """
        Sanitize input for LLM (remove sensitive data).
        
        Only pass matched rules, not raw system state.
        
        Args:
            result: Rule evaluation result
            
        Returns:
            Sanitized dictionary safe for LLM
        """
        # Deep copy to avoid mutation
        matched_rules_data = []
        
        for rule in result.matched_rules:
            rule_data = {
                "rule_id": rule.rule_id,
                "rule_name": rule.rule_name,
                "priority": rule.priority,
                "outcome": {
                    "type": rule.outcome.type,
                    "code": rule.outcome.code,
                    "metadata": rule.outcome.metadata
                },
                "explanations": [
                    {
                        "field": exp.field,
                        "operator": exp.operator,
                        "expected": exp.expected,
                        "actual": exp.actual,
                        "passed": exp.passed
                    }
                    for exp in rule.explanations
                ]
            }
            matched_rules_data.append(rule_data)
        
        return {"matched_rules": matched_rules_data}
    
    def _validate_advisory_output(self, llm_output: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Validate LLM output against schema.
        
        Args:
            llm_output: Raw LLM output
            
        Returns:
            Validated output or None if invalid
        """
        try:
            # Check required fields
            if "summary" not in llm_output or not isinstance(llm_output["summary"], str):
                logger.error("Advisory output missing or invalid 'summary'")
                return None
            
            if "details" not in llm_output or not isinstance(llm_output["details"], list):
                logger.error("Advisory output missing or invalid 'details'")
                return None
            
            # Validate details
            for detail in llm_output["details"]:
                if not isinstance(detail, dict):
                    logger.error("Advisory detail is not a dict")
                    return None
                if "rule_id" not in detail or "explanation" not in detail:
                    logger.error("Advisory detail missing required fields")
                    return None
                if not isinstance(detail["rule_id"], str) or not isinstance(detail["explanation"], str):
                    logger.error("Advisory detail fields have wrong types")
                    return None
            
            # Validate suggestions (optional)
            if "suggestions" not in llm_output:
                llm_output["suggestions"] = []
            elif not isinstance(llm_output["suggestions"], list):
                logger.warning("Advisory suggestions invalid, using empty list")
                llm_output["suggestions"] = []
            
            # Validate confidence (optional)
            if "confidence" not in llm_output:
                llm_output["confidence"] = 0.5
            else:
                try:
                    confidence = float(llm_output["confidence"])
                    if not (0.0 <= confidence <= 1.0):
                        logger.warning(f"Confidence {confidence} out of range, using 0.5")
                        llm_output["confidence"] = 0.5
                    else:
                        llm_output["confidence"] = confidence
                except (ValueError, TypeError):
                    logger.warning("Invalid confidence value, using 0.5")
                    llm_output["confidence"] = 0.5
            
            return llm_output
            
        except Exception as e:
            logger.error(f"Advisory output validation error: {e}")
            return None
    
    def _create_fallback_advisory(self, result: RuleEvaluationResult) -> AdvisoryResult:
        """
        Create deterministic fallback when LLM unavailable.
        
        Args:
            result: Rule evaluation result
            
        Returns:
            Safe fallback advisory
        """
        if len(result.matched_rules) == 0:
            summary = "No rules matched the current state."
            details = []
        else:
            summary = f"{len(result.matched_rules)} rule(s) matched."
            details = [
                RuleDetail(
                    rule_id=rule.rule_id,
                    explanation=f"{rule.rule_name}: {rule.outcome.code}"
                )
                for rule in result.matched_rules
            ]
        
        return AdvisoryResult(
            summary=summary,
            details=details,
            suggestions=[],
            confidence=1.0,  # Fallback is deterministic
            enabled=False
        )
