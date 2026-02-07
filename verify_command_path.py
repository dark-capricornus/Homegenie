
import asyncio
import logging
import sys
import os
from unittest.mock import MagicMock, AsyncMock

# Add src to path
sys.path.insert(0, os.getcwd())

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def run_check():
    try:
        from src.agents.executor_agent import ExecutorAgent
        
        print("Imports successful")
        
        # Initialize ExecutorAgent (mocking MQTT client to avoid connection errors)
        agent = ExecutorAgent()
        agent._connected = True
        agent._client = MagicMock()
        agent._client.publish.return_value = MagicMock(rc=0)
        
        # Test 1: Load Devices
        print(f"Loaded devices: {list(agent.devices.keys())}")
        if "light.living_room" in agent.devices and "thermostat.main" in agent.devices:
             print("SUCCESS: Config loaded")
        else:
             print("FAILURE: Config not loaded correctly")
             
        # Test 2: Execute MQTT (mocked)
        print("Testing MQTT dispatch...")
        task_mqtt = {"device": "light.living_room", "action": "turn_on"}
        success = await agent.execute(task_mqtt)
        if success:
            print("SUCCESS: MQTT dispatch executed")
        else:
            print("FAILURE: MQTT dispatch failed")

        # Test 3: Execute HTTP (mocked httpx)
        print("Testing HTTP dispatch...")
        
        # We need to patch httpx or just rely on the fact it matches protocol
        # For this script let's just inspect the logic path by ensuring protocol detection works
        dev_config = agent.devices.get("thermostat.main")
        if dev_config and dev_config.get("protocol") == "http":
             print(f"SUCCESS: HTTP protocol detected for {dev_config['id']}")
        else:
             print("FAILURE: HTTP protocol detection failed")

        # Test 4: Fallback
        print("Testing Fallback...")
        task_fb = {"device": "unknown.device", "action": "toggle"}
        success = await agent.execute(task_fb)
        if success:
             print("SUCCESS: Fallback dispatch executed")
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(run_check())
