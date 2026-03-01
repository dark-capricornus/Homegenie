"""
Semantic Goal Schema - Standardized intent carrier for HomeGenie.

Enforces "Normalize intent before intelligence" by constraining
all natural language inputs to a fixed set of literals.
"""
from dataclasses import dataclass
from typing import Literal, Optional


@dataclass(frozen=True)
class SemanticGoal:
    """
    A normalized, auditable goal representation.
    No free text allowed in intents or dimensions.
    """
    intent: Literal["COMFORT", "SECURITY", "EFFICIENCY", "SAFETY"]
    dimension: Literal["THERMAL", "LIGHTING", "ENERGY", "AMBIENCE"]
    priority: Literal["LOW", "NORMAL", "HIGH"] = "NORMAL"
    source: Literal["user", "safe_default"] = "user"
    original_text: Optional[str] = None

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON/n8n representation."""
        return {
            "intent": self.intent,
            "dimension": self.dimension,
            "priority": self.priority,
            "source": self.source,
            "original_text": self.original_text
        }
