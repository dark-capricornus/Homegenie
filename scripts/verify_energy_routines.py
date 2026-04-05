import asyncio
import os
import sys
from datetime import datetime, timedelta, timezone

# Add the project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.core import db_async as db_v2
from src.core.context_store import ContextStore
from src.agents.automation_agent import AutomationAgent

async def verify_energy():
    print("--- Verifying Energy History ---")
    # 1. Record some samples
    device_id = "test_ac_001"
    now = datetime.now(timezone.utc)
    
    print(f"Creating test samples for {device_id}...")
    # Add samples for today
    for i in range(10):
        timestamp = now - timedelta(minutes=i * 10)
        power = 500 + (i * 50)
        print(f"  Recording sample {i}...")
        await db_v2.record_energy_sample(device_id, power, timestamp)
    
    print("Fetching history...")
    # 2. Retrieve samples
    history = await db_v2.get_energy_history(days=1)
    print(f"Found {len(history)} energy samples in the last 24h.")
    
    # Check if our device is there
    found = any(s.device_id == device_id for s in history)
    if found:
        print(f"SUCCESS: Energy history recorded for {device_id}.")
    else:
        print(f"FAILURE: Could not find energy history for {device_id}.")
    return found

async def verify_routines():
    print("\n--- Verifying Routines Builder ---")
    # 1. Create a mock rule
    rule_data = {
        "id": 999,
        "name": "Test Routine",
        "priority": 1,
        "enabled": True,
        "content": {
            "conditions": [
                {
                    "field": "devices.sensor_01.observed.temperature",
                    "operator": ">",
                    "value": "25"
                }
            ],
            "outcome": {
                "type": "command",
                "code": "execute_device_cmd",
                "metadata": {
                    "device_id": "test_ac_001",
                    "command": "turn_on"
                }
            }
        }
    }
    
    print("Saving test rule...")
    rule_id = await db_v2.save_rule(rule_data)
    print(f"Rule saved with ID: {rule_id}")
    
    # 2. Verify retrieval
    rules = await db_v2.get_rules()
    test_rule = next((r for r in rules if r["name"] == "Test Routine"), None)
    if test_rule:
        print(f"SUCCESS: Rule retrieved from database.")
    else:
        print(f"FAILURE: Rule not found after saving.")
        return False
        
    # 3. Test AutomationAgent reload
    store = ContextStore()
    agent = AutomationAgent(store)
    print("Initializing AutomationAgent...")
    await agent.reload_rules()
    
    if len(agent.rules) > 0:
        print(f"SUCCESS: AutomationAgent reloaded {len(agent.rules)} rules.")
    else:
        print(f"FAILURE: AutomationAgent has 0 rules.")
        return False
        
    # 4. Trigger evaluation
    print("Triggering rule evaluation...")
    store.update_observed_state("sensor_01", {"temperature": 28})
    matched = await agent.check_rules()
    
    if any(m["rule"].name == "Test Routine" for m in matched):
        print("SUCCESS: Rule matched correctly when temperature > 25.")
    else:
        print("FAILURE: Rule did not match.")
        
    # 5. Test deletion
    print("Deleting test rule...")
    await db_v2.delete_rule(rule_id)
    rules_after = await db_v2.get_rules()
    if not any(r["id"] == rule_id for r in rules_after):
        print("SUCCESS: Rule deleted successfully.")
    else:
        print("FAILURE: Rule still exists after deletion.")
        
    return True

async def main():
    # Use SQLite for easier local verification
    test_db_url = "sqlite+aiosqlite:///test_homegenie.db"
    print(f"Initializing test database: {test_db_url}")
    
    # Overwrite settings for the duration of the test
    from src.core.settings_v2 import settings_v2
    settings_v2.POSTGRES_URL = test_db_url
    
    await db_v2.init_db(test_db_url)
    
    e_success = await verify_energy()
    r_success = await verify_routines()
    
    if e_success and r_success:
        print("\nALL VERIFICATIONS PASSED!")
    else:
        print("\nVERIFICATION FAILED!")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
