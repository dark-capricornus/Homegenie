"""
Conversation Manager — Tracks dialogue state across turns.

Provides:
  - Per-user conversation history (last N turns)
  - Entity memory for coreference resolution ("it", "that light", "the same one")
  - Slot filling state for multi-turn disambiguation
"""
from __future__ import annotations

import logging
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

MAX_HISTORY = 20       # messages per user
CONTEXT_TTL_MIN = 30   # minutes before context expires


@dataclass
class SlotState:
    """Tracks pending disambiguation / slot-filling."""
    pending_question: Optional[str] = None
    options: Optional[List[str]] = None
    original_intent: Optional[Dict[str, Any]] = None
    timestamp: Optional[datetime] = None

    @property
    def is_active(self) -> bool:
        if self.pending_question is None:
            return False
        if self.timestamp and (datetime.now() - self.timestamp) > timedelta(minutes=5):
            return False
        return True


@dataclass
class EntityMemory:
    """Tracks the last-mentioned entities for coreference resolution."""
    device_id: Optional[str] = None
    room: Optional[str] = None
    device_type: Optional[str] = None
    action: Optional[str] = None
    updated_at: Optional[datetime] = None

    def update(self, **kwargs: Any) -> None:
        for k, v in kwargs.items():
            if v is not None and hasattr(self, k):
                setattr(self, k, v)
        self.updated_at = datetime.now()

    @property
    def is_stale(self) -> bool:
        if self.updated_at is None:
            return True
        return (datetime.now() - self.updated_at) > timedelta(minutes=CONTEXT_TTL_MIN)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "last_device": self.device_id,
            "last_room": self.room,
            "last_device_type": self.device_type,
            "last_action": self.action,
        }


@dataclass
class Message:
    role: str       # "user" | "assistant" | "tool_call" | "tool_result"
    content: str
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: Optional[Dict[str, Any]] = None


class ConversationManager:
    """Per-user conversation state manager."""

    def __init__(self) -> None:
        self._histories: Dict[str, List[Message]] = defaultdict(list)
        self._entities: Dict[str, EntityMemory] = defaultdict(EntityMemory)
        self._slots: Dict[str, SlotState] = defaultdict(SlotState)

    # ------------------------------------------------------------------
    # History
    # ------------------------------------------------------------------
    def add_message(self, user_id: str, role: str, content: str,
                    metadata: Optional[Dict[str, Any]] = None) -> None:
        history = self._histories[user_id]
        history.append(Message(role=role, content=content, metadata=metadata))
        # Trim to last N
        if len(history) > MAX_HISTORY:
            self._histories[user_id] = history[-MAX_HISTORY:]

    def get_history(self, user_id: str, last_n: int = 10) -> List[Dict[str, str]]:
        """Return last N messages formatted for LLM context."""
        history = self._histories.get(user_id, [])
        result = []
        for msg in history[-last_n:]:
            if msg.role in ("user", "assistant"):
                result.append({"role": msg.role, "content": msg.content})
            elif msg.role == "tool_call":
                result.append({"role": "assistant", "content": f"[Tool call: {msg.content}]"})
            elif msg.role == "tool_result":
                result.append({"role": "assistant", "content": f"[Tool result: {msg.content}]"})
        return result

    def clear_history(self, user_id: str) -> None:
        self._histories.pop(user_id, None)
        self._entities.pop(user_id, None)
        self._slots.pop(user_id, None)

    # ------------------------------------------------------------------
    # Entity memory (coreference resolution)
    # ------------------------------------------------------------------
    def update_entities(self, user_id: str, **kwargs: Any) -> None:
        self._entities[user_id].update(**kwargs)

    def get_entities(self, user_id: str) -> EntityMemory:
        mem = self._entities[user_id]
        if mem.is_stale:
            self._entities[user_id] = EntityMemory()
            return self._entities[user_id]
        return mem

    # ------------------------------------------------------------------
    # Slot filling / disambiguation
    # ------------------------------------------------------------------
    def set_pending_slot(self, user_id: str, question: str,
                         options: Optional[List[str]] = None,
                         original_intent: Optional[Dict[str, Any]] = None) -> None:
        self._slots[user_id] = SlotState(
            pending_question=question,
            options=options,
            original_intent=original_intent,
            timestamp=datetime.now(),
        )

    def get_pending_slot(self, user_id: str) -> Optional[SlotState]:
        slot = self._slots.get(user_id)
        if slot and slot.is_active:
            return slot
        return None

    def clear_slot(self, user_id: str) -> None:
        self._slots.pop(user_id, None)

    def build_context_block(self, user_id: str) -> str:
        """Build a context summary string for the LLM system prompt."""
        parts: List[str] = []
        # Entity memory
        ent = self.get_entities(user_id)
        if not ent.is_stale and ent.device_id:
            parts.append(
                f"Last mentioned device: {ent.device_id}"
                + (f" in {ent.room}" if ent.room else "")
                + (f" (action: {ent.action})" if ent.action else "")
            )
        # Pending slot
        slot = self.get_pending_slot(user_id)
        if slot:
            parts.append(f"Pending question: {slot.pending_question}")
            if slot.options:
                parts.append(f"Options: {', '.join(slot.options)}")
        if not parts:
            return ""
        return "Conversation context:\n" + "\n".join(f"- {p}" for p in parts)
