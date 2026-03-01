"""
Rule Loader - Load and validate declarative rules from JSON.

This module handles:
- Loading rules from JSON files
- Schema validation
- Operator validation
- Rule uniqueness checks

No LLM usage. No automation execution. Pure data loading.
"""
import json
import logging
from typing import List, Dict, Any
from dataclasses import dataclass, field
from pathlib import Path

logger = logging.getLogger(__name__)

# Allowed operators (finite set)
ALLOWED_OPERATORS = {
    "==", "!=", "<", "<=", ">", ">=",
    "in", "not_in", "exists", "not_exists"
}

# Operators that don't require a value
NO_VALUE_OPERATORS = {"exists", "not_exists"}


class RuleValidationError(Exception):
    """Raised when rule validation fails."""
    pass


@dataclass
class Condition:
    """A single condition within a rule."""
    field: str
    operator: str
    value: Any = None
    
    def __post_init__(self):
        """Validate condition after initialization."""
        if not self.field or not isinstance(self.field, str):
            raise RuleValidationError(f"Condition field must be non-empty string, got: {self.field}")
        
        if self.operator not in ALLOWED_OPERATORS:
            raise RuleValidationError(
                f"Invalid operator '{self.operator}'. Allowed: {sorted(ALLOWED_OPERATORS)}"
            )
        
        # Validate value requirements
        if self.operator in NO_VALUE_OPERATORS:
            if self.value is not None:
                raise RuleValidationError(
                    f"Operator '{self.operator}' should not have a value"
                )
        else:
            if self.value is None:
                raise RuleValidationError(
                    f"Operator '{self.operator}' requires a value"
                )


@dataclass
class Outcome:
    """The outcome/decision of a rule."""
    type: str
    code: str
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def __post_init__(self):
        """Validate outcome after initialization."""
        if not self.type or not isinstance(self.type, str):
            raise RuleValidationError(f"Outcome type must be non-empty string, got: {self.type}")
        
        if not self.code or not isinstance(self.code, str):
            raise RuleValidationError(f"Outcome code must be non-empty string, got: {self.code}")


@dataclass
class Rule:
    """A declarative rule definition."""
    id: str
    name: str
    priority: int
    enabled: bool
    conditions: List[Condition]
    outcome: Outcome
    
    def __post_init__(self):
        """Validate rule after initialization."""
        if not self.id or not isinstance(self.id, str):
            raise RuleValidationError(f"Rule ID must be non-empty string, got: {self.id}")
        
        if not self.name or not isinstance(self.name, str):
            raise RuleValidationError(f"Rule name must be non-empty string, got: {self.name}")
        
        if not isinstance(self.priority, int) or self.priority < 0:
            raise RuleValidationError(f"Rule priority must be integer >= 0, got: {self.priority}")
        
        if not isinstance(self.enabled, bool):
            raise RuleValidationError(f"Rule enabled must be boolean, got: {self.enabled}")
        
        if not self.conditions or not isinstance(self.conditions, list):
            raise RuleValidationError(f"Rule must have at least one condition")
        
        if len(self.conditions) == 0:
            raise RuleValidationError(f"Rule must have at least one condition")


def load_rules(file_path: str) -> List[Rule]:
    """
    Load and validate rules from JSON file.
    
    Args:
        file_path: Path to JSON file containing rules
        
    Returns:
        List of validated Rule objects
        
    Raises:
        RuleValidationError: If validation fails
        FileNotFoundError: If file doesn't exist
        json.JSONDecodeError: If JSON is invalid
    """
    path = Path(file_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Rules file not found: {file_path}")
    
    logger.info(f"Loading rules from: {file_path}")
    
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Validate top-level structure
    if not isinstance(data, dict):
        raise RuleValidationError("Rules file must contain a JSON object")
    
    # Check for version (optional, for future schema evolution)
    version = data.get("version", "1.0")
    logger.debug(f"Rules schema version: {version}")
    
    if "rules" not in data:
        raise RuleValidationError("Rules file must contain 'rules' array")
    
    rules_data = data["rules"]
    
    if not isinstance(rules_data, list):
        raise RuleValidationError("'rules' must be an array")
    
    # Parse and validate each rule
    rules = []
    rule_ids = set()
    
    for idx, rule_dict in enumerate(rules_data):
        try:
            rule = parse_rule(rule_dict)
            
            # Check for duplicate IDs
            if rule.id in rule_ids:
                raise RuleValidationError(f"Duplicate rule ID: {rule.id}")
            
            rule_ids.add(rule.id)
            rules.append(rule)
            
        except RuleValidationError as e:
            raise RuleValidationError(f"Rule #{idx} ({rule_dict.get('id', 'unknown')}): {e}")
    
    logger.info(f"✅ Loaded {len(rules)} valid rules")
    return rules


def parse_rule(rule_dict: Dict[str, Any]) -> Rule:
    """
    Parse a single rule from dictionary.
    
    Args:
        rule_dict: Dictionary containing rule data
        
    Returns:
        Validated Rule object
        
    Raises:
        RuleValidationError: If validation fails
    """
    # Validate required fields
    required_fields = ["id", "name", "priority", "enabled", "conditions", "outcome"]
    for field in required_fields:
        if field not in rule_dict:
            raise RuleValidationError(f"Missing required field: {field}")
    
    # Parse conditions
    conditions = []
    for cond_dict in rule_dict["conditions"]:
        condition = Condition(
            field=cond_dict.get("field"),
            operator=cond_dict.get("operator"),
            value=cond_dict.get("value")
        )
        conditions.append(condition)
    
    # Parse outcome
    outcome_dict = rule_dict["outcome"]
    outcome = Outcome(
        type=outcome_dict.get("type"),
        code=outcome_dict.get("code"),
        metadata=outcome_dict.get("metadata", {})
    )
    
    # Create rule
    rule = Rule(
        id=rule_dict["id"],
        name=rule_dict["name"],
        priority=rule_dict["priority"],
        enabled=rule_dict["enabled"],
        conditions=conditions,
        outcome=outcome
    )
    
    return rule


def validate_operator(operator: str) -> None:
    """
    Validate that operator is in allowed set.
    
    Args:
        operator: Operator string to validate
        
    Raises:
        RuleValidationError: If operator is invalid
    """
    if operator not in ALLOWED_OPERATORS:
        raise RuleValidationError(
            f"Invalid operator '{operator}'. Allowed: {sorted(ALLOWED_OPERATORS)}"
        )
