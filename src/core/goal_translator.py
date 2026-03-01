"""
Goal Translator - Deterministic NL to Semantic Goal mapping.

Implements "Intelligence after Normalization" by converting free-form
text into constrained SemanticGoal objects. Conservative and deterministic.
"""
import re
from typing import Optional, Dict, Any
from .goal_schema import SemanticGoal


class GoalTranslator:
    """
    Translates natural language text into a structured SemanticGoal.
    Uses pattern matching and keyword analysis for determinism.
    """

    def __init__(self):
        # Intent/Dimension keyword maps
        self.mappings = {
            "COMFORT": ["cozy", "comfort", "warm", "cool", "relax", "chill", "nice"],
            "SECURITY": ["secure", "lock", "guard", "safe", "away", "vacation"],
            "EFFICIENCY": ["save", "efficient", "green", "eco", "minimize", "cheap"],
            "SAFETY": ["emergency", "danger", "fire", "leak", "hazard"]
        }
        
        self.dimensions = {
            "THERMAL": ["warm", "heat", "cool", "temp", "cold", "degree"],
            "LIGHTING": ["light", "dark", "dim", "bright", "lamp", "glow"],
            "ENERGY": ["power", "electricity", "watt", "bill", "energy"],
            "AMBIENCE": ["mood", "relax", "cozy", "feeling", "color", "atmosphere", "away", "secure"]
        }

    def translate(self, text: str) -> SemanticGoal:
        """
        Translates raw text to a SemanticGoal.
        
        Args:
            text: Raw natural language string.
            
        Returns:
            A SemanticGoal object (User derived or SAFE_DEFAULT).
        """
        if not text:
            return self._get_safe_default("Empty input")

        # Normalize text
        text_lower = text.lower().strip()
        
        # Determine Priority
        priority = "NORMAL"
        if any(word in text_lower for word in ["urgent", "emergency", "fast", "now", "critical", "high"]):
            priority = "HIGH"
        elif any(word in text_lower for word in ["eventually", "low", "slow", "background"]):
            priority = "LOW"

        # Determine Intent
        intent = None
        for i, keywords in self.mappings.items():
            if any(re.search(rf"\b{k}\b", text_lower) for k in keywords):
                intent = i
                break
        
        # Determine Dimension
        dimension = None
        for d, keywords in self.dimensions.items():
            if any(re.search(rf"\b{k}\b", text_lower) for k in keywords):
                dimension = d
                break

        # Result Logic
        if intent and dimension:
            return SemanticGoal(
                intent=intent,      # type: ignore
                dimension=dimension, # type: ignore
                priority=priority,   # type: ignore
                source="user",
                original_text=text
            )
        
        # Ambiguity or partial match handling
        # If we have only dimension, try to infer intent
        if dimension == "THERMAL" and not intent:
            intent = "COMFORT"
        elif dimension == "ENERGY" and not intent:
            intent = "EFFICIENCY"
        
        if intent and dimension:
            return SemanticGoal(
                intent=intent,      # type: ignore
                dimension=dimension, # type: ignore
                priority=priority,   # type: ignore
                source="user",
                original_text=text
            )

        # Fail safe
        return self._get_safe_default(text)

    def _get_safe_default(self, original_text: str) -> SemanticGoal:
        """Returns the explicit auditable safe default goal."""
        return SemanticGoal(
            intent="SAFETY",
            dimension="ENERGY",
            priority="HIGH",
            source="safe_default",
            original_text=original_text
        )
