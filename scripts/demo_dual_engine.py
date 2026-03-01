"""
Demo: Dual-Engine Agentic AI Flow (n8n-friendly)

This script demonstrates the interaction between the Rule Engine and the Planner Agent.
It outputs structured JSON suitable for an IEEE review demo / n8n integration.
"""
import json
import logging
import os
from typing import Dict, Any
from dotenv import load_dotenv

# CRITICAL: Load environment variables BEFORE importing core modules
load_dotenv(override=True)

from src.core.rule_engine import RuleEngine, RuleEvaluationResult
from src.core.rule_loader import Rule, Condition, Outcome
from src.core.planner_agent import PlannerAgent, AgentPlan
from src.core.arbiter import Arbiter, ArbiterDecision
from src.core.llm_client import LLMClient
from src.core.goal_schema import SemanticGoal
from src.core.goal_translator import GoalTranslator

# Setup minimal logging to stdout
logging.basicConfig(level=logging.INFO, format='%(message)s')

def run_demo(state: Dict[str, Any], goal: str):
    # 1. Translate NL Goal -> Semantic Goal (Normalize before Intelligence)
    translator = GoalTranslator()
    semantic_goal = translator.translate(goal)
    
    print(f"--- HOMEGENIE DUAL-ENGINE DEMO ---")
    print(f"LLM Provider: {os.getenv('LLM_PROVIDER')}")
    print(f"Goal Text: {goal}")
    print(f"Semantic Goal: {semantic_goal.intent} / {semantic_goal.dimension} (Source: {semantic_goal.source})")
    print(f"State: {json.dumps(state)}")
    print("-" * 34)

    # 1. Setup Mock Rules (Deterministic Baseline)
    rules = [
        Rule(
            id="R_COZY",
            name="Cozy Mode Safety",
            conditions=[Condition(field="environment.temp", operator="<", value=20.0)],
            outcome=Outcome(type="ACTION", code="HEATER_ON"),
            priority=10,
            enabled=True
        )
    ]
    rule_engine = RuleEngine(rules)

    # 2. Setup LLM Client & Planner Agent
    llm_client = LLMClient() 
    # For demo purposes, we'll assume LLM might be mocked or real
    planner = PlannerAgent(llm_client)

    # 3. Setup Arbiter
    arbiter = Arbiter()

    # --- EXECUTION FLOW ---

    # A. Rule Engine Evaluation
    rule_result = rule_engine.evaluate(state)
    
    # B. Planner Agent Proposal (Uses Semantic Goal)
    agent_plan = planner.propose_plan(state, semantic_goal)
    
    # C. Arbiter Decision (Safety Gate)
    decision = arbiter.decide(rule_result, agent_plan)

    # --- RESULTS (n8n friendly JSON) ---
    
    output = {
        "input": {
            "goal_text": goal,
            "semantic_goal": semantic_goal.to_dict(),
            "state": state
        },
        "rule_engine_results": {
            "matched_rules": [r.rule_id for r in rule_result.matched_rules],
            "outcomes": [r.outcome.code for r in rule_result.matched_rules]
        },
        "agentic_proposals": {
            "used": agent_plan.agent_used,
            "proposals": agent_plan.proposed_outcomes,
            "reasoning": agent_plan.reasoning,
            "confidence": agent_plan.confidence
        },
        "final_arbiter_decision": {
            "outcomes": decision.final_outcomes,
            "source": decision.decision_source,
            "safety_gate": "PASSED" if decision.final_outcomes == [r.outcome.code for r in rule_result.matched_rules] else "OVERRIDDEN"
        }
    }

    print("\n[FINAL OUTPUT (n8n JSON)]")
    print(json.dumps(output, indent=2))
    print("-" * 34)

if __name__ == "__main__":
    # Scenario: Cold room, user wants it cozy
    sample_state = {
        "environment": {
            "temp": 18.5,
            "humidity": 45
        }
    }
    sample_goal = "make it cozy and warm"
    
    run_demo(sample_state, sample_goal)
