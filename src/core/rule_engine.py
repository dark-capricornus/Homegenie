"""
Rule Engine - Deterministic rule evaluation engine.

This is a DECISION ENGINE, not an automation engine.
It evaluates rules against state and returns decisions with explanations.

NO LLM usage. NO automation execution. NO side effects.
"""
import logging
import time
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime, timezone

from .rule_loader import Rule, Condition, Outcome

logger = logging.getLogger(__name__)


@dataclass
class ConditionExplanation:
    """Explanation of a single condition evaluation."""
    field: str
    operator: str
    expected: Any
    actual: Any
    passed: bool


@dataclass
class MatchedRule:
    """A rule that matched the current state."""
    rule_id: str
    rule_name: str
    priority: int
    outcome: Outcome
    explanations: List[ConditionExplanation]


@dataclass
class RuleEvaluationResult:
    """Result of evaluating all rules against state."""
    matched_rules: List[MatchedRule]
    evaluation_time_ms: float
    total_rules_evaluated: int
    timestamp: str


class RuleEngine:
    """
    Deterministic rule evaluation engine.
    
    This engine:
    - Evaluates rules against system state
    - Returns decisions with explanations
    - Does NOT execute actions
    - Does NOT use LLMs
    - Is completely deterministic
    """
    
    # Operator implementations (finite set, no eval/exec)
    OPERATORS = {
        "==": lambda a, e: a == e,
        "!=": lambda a, e: a != e,
        "<": lambda a, e: a < e if a is not None and e is not None else False,
        "<=": lambda a, e: a <= e if a is not None and e is not None else False,
        ">": lambda a, e: a > e if a is not None and e is not None else False,
        ">=": lambda a, e: a >= e if a is not None and e is not None else False,
        "in": lambda a, e: a in e if e is not None else False,
        "not_in": lambda a, e: a not in e if e is not None else False,
        "exists": lambda a, e: a is not None,
        "not_exists": lambda a, e: a is None,
    }
    
    def __init__(self, rules: List[Rule]):
        """
        Initialize rule engine with rules.
        
        Args:
            rules: List of validated Rule objects
        """
        self.rules = rules
        logger.info(f"Rule engine initialized with {len(rules)} rules")
    
    def evaluate(self, state: dict) -> RuleEvaluationResult:
        """
        Evaluate all enabled rules against state.
        
        This is the main entry point. It:
        1. Filters enabled rules
        2. Evaluates each rule
        3. Sorts by priority (descending)
        4. Returns structured result with explanations
        
        Args:
            state: System state dictionary
            
        Returns:
            RuleEvaluationResult with matched rules and metadata
        """
        # Use monotonic clock for timing (not wall-clock)
        start_time = time.perf_counter()
        
        # Filter enabled rules only
        enabled_rules = [r for r in self.rules if r.enabled]
        
        logger.debug(f"Evaluating {len(enabled_rules)} enabled rules")
        
        # Evaluate each rule
        matched_rules = []
        for rule in enabled_rules:
            matched = self._evaluate_rule(rule, state)
            if matched:
                matched_rules.append(matched)
        
        # Sort by priority (descending - higher priority first)
        matched_rules.sort(key=lambda r: r.priority, reverse=True)
        
        # Calculate evaluation time
        end_time = time.perf_counter()
        evaluation_time_ms = (end_time - start_time) * 1000
        
        logger.info(f"Evaluation complete: {len(matched_rules)} rules matched in {evaluation_time_ms:.2f}ms")
        
        return RuleEvaluationResult(
            matched_rules=matched_rules,
            evaluation_time_ms=round(evaluation_time_ms, 2),
            total_rules_evaluated=len(enabled_rules),
            timestamp=datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        )
    
    def _evaluate_rule(self, rule: Rule, state: dict) -> Optional[MatchedRule]:
        """
        Evaluate a single rule against state.
        
        All conditions are evaluated using logical AND.
        If all conditions pass, the rule matches.
        
        Args:
            rule: Rule to evaluate
            state: System state
            
        Returns:
            MatchedRule if all conditions pass, None otherwise
        """
        explanations = []
        all_passed = True
        
        # Evaluate all conditions (AND logic)
        for condition in rule.conditions:
            explanation = self._evaluate_condition(condition, state)
            explanations.append(explanation)
            
            if not explanation.passed:
                all_passed = False
                # Continue evaluating for complete explanations
        
        # If all conditions passed, return matched rule
        if all_passed:
            return MatchedRule(
                rule_id=rule.id,
                rule_name=rule.name,
                priority=rule.priority,
                outcome=rule.outcome,
                explanations=explanations
            )
        
        return None
    
    def _evaluate_condition(self, condition: Condition, state: dict) -> ConditionExplanation:
        """
        Evaluate a single condition against state.
        
        Args:
            condition: Condition to evaluate
            state: System state
            
        Returns:
            ConditionExplanation with actual vs expected values
        """
        # Get actual value from state using dot notation
        actual_value = self._get_field_value(state, condition.field)
        
        # Apply operator
        passed = self._apply_operator(
            actual_value,
            condition.operator,
            condition.value
        )
        
        return ConditionExplanation(
            field=condition.field,
            operator=condition.operator,
            expected=condition.value,
            actual=actual_value,
            passed=passed
        )
    
    def _get_field_value(self, state: dict, field: str) -> Any:
        """
        Extract field value from state using dot notation.
        
        Examples:
            "finance.savings.emergency" -> state["finance"]["savings"]["emergency"]
            "devices.light.status" -> state["devices"]["light"]["status"]
        
        Args:
            state: System state dictionary
            field: Dot-notation field path
            
        Returns:
            Field value or None if not found
        """
        parts = field.split(".")
        current = state
        
        for part in parts:
            if not isinstance(current, dict):
                return None
            
            if part not in current:
                return None
            
            current = current[part]
        
        return current
    
    def _apply_operator(self, actual: Any, operator: str, expected: Any) -> bool:
        """
        Apply operator to compare actual vs expected values.
        
        Args:
            actual: Actual value from state
            operator: Operator string
            expected: Expected value from condition
            
        Returns:
            True if condition passes, False otherwise
        """
        if operator not in self.OPERATORS:
            logger.error(f"Unknown operator: {operator}")
            return False
        
        try:
            op_func = self.OPERATORS[operator]
            result = op_func(actual, expected)
            return bool(result)
        except Exception as e:
            logger.error(f"Error applying operator '{operator}': {e}")
            return False
