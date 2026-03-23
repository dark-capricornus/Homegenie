import logging
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

from src.core.context_store import ContextStore
from src.core.rule_engine import RuleEngine
from src.core.rule_loader import Rule, parse_rule
from src.core import db_async as db
from src.agents.executor_agent import ExecutorAgent

logger = logging.getLogger(__name__)

class AutomationAgent:
    """
    AutomationAgent listens to ContextStore changes and executes rules.
    It bridges RuleEngine (decision) with ExecutorAgent (action).
    """
    
    def __init__(self, context_store: ContextStore, executor_agent: ExecutorAgent):
        self.context_store = context_store
        self.executor_agent = executor_agent
        self.rules: List[Rule] = []
        self.engine: Optional[RuleEngine] = None
        self._running = False
        self._lock = asyncio.Lock()
        
    async def start(self):
        """Start the automation agent and subscribe to context changes."""
        if self._running:
            return
        self._running = True
        
        await self.reload_rules()
        self.context_store.subscribe(self._on_context_change)
        logger.info("AutomationAgent started and subscribed to ContextStore")

    def stop(self):
        """Stop the automation agent and unsubscribe."""
        self._running = False
        self.context_store.unsubscribe(self._on_context_change)
        logger.info("AutomationAgent stopped")

    async def reload_rules(self):
        """Reload rules from the database."""
        async with self._lock:
            try:
                db_rules = await db.get_rules()
                parsed_rules = []
                for r in db_rules:
                    if r.enabled:
                        try:
                            # RuleTable.content should match Rule JSON schema
                            rule_dict = {
                                "id": str(r.id),
                                "name": r.name,
                                "priority": r.priority,
                                "enabled": r.enabled,
                                "conditions": r.content.get("conditions", []),
                                "outcome": r.content.get("outcome", {})
                            }
                            parsed_rules.append(parse_rule(rule_dict))
                        except Exception as e:
                            logger.error(f"Error parsing rule {r.id}: {e}")
                
                self.rules = parsed_rules
                self.engine = RuleEngine(self.rules)
                logger.info(f"AutomationAgent reloaded {len(self.rules)} rules")
            except Exception as e:
                logger.error(f"Error reloading rules: {e}")

    def _on_context_change(self, topic: str, payload: Any):
        """Callback from ContextStore."""
        try:
            loop = asyncio.get_running_loop()
            asyncio.run_coroutine_threadsafe(self._evaluate_rules(), loop)
        except RuntimeError:
            # No running loop — skip evaluation (startup/shutdown edge case)
            pass

    async def _evaluate_rules(self):
        """Evaluate rules against the current context and execute matches."""
        if not self.engine:
            return

        async with self._lock:
            try:
                # Get current state dump (flat dictionary of latest states)
                # Note: RuleEngine expects a specific state structure.
                # Here we simplify: we provide a dict where keys are topics.
                state_dump = await self.context_store.async_dump()
                current_state = state_dump.get("states", {})
                
                result = self.engine.evaluate(current_state)
                
                if result.matched_rules:
                    for match in result.matched_rules:
                        await self._execute_outcome(match.rule_id, match.outcome)
            except Exception as e:
                logger.error(f"Error in rule evaluation: {e}")

    async def _execute_outcome(self, rule_id: str, outcome: Any):
        """Execute the outcome of a matched rule."""
        try:
            # outcome is a core.rule_loader.Outcome object
            if outcome.type == "command":
                command = outcome.metadata.get("command")
                device_id = outcome.metadata.get("device_id")
                
                if command and device_id:
                    logger.info(f"Rule {rule_id} triggered command {command} for {device_id}")
                    # Correct format for ExecutorAgent.execute
                    task = {"device": device_id, "action": command}
                    await self.executor_agent.execute(task)
            
            # Update last_triggered in DB (best effort)
            try:
                # This would need a specific DB helper or direct session access
                pass
            except Exception:
                pass
                
        except Exception as e:
            logger.error(f"Error executing outcome for rule {rule_id}: {e}")
