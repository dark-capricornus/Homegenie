
import asyncio
import logging
import sys
import os

# Add src to path
sys.path.insert(0, os.getcwd())

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def run_check():
    try:
        from src.agents.sensor_agent import SensorAgent
        from src.core.context_store import ContextStore
        
        print("Imports successful")
        
        store = ContextStore()
        agent = SensorAgent(context_store=store)
        
        # Test loading probes
        print("Testing probe loading...")
        agent._load_probes()
        print(f"Loaded {len(agent.probes)} probes")
        
        if not agent.probes:
            # Create a mock probe if file load failed (though it should exist)
            agent.probes = [{"name": "test", "url": "https://httpbin.org/get", "enabled": True}]
            
        # Test single probe
        print(f"Testing probe target: {agent.probes[0]}")
        await agent._probe_target(agent.probes[0])
        
        # Check store
        state = await store.async_get_state(f"probes/{agent.probes[0]['name']}")
        print(f"Probe state in store: {state}")
        
        if state and state.get("status") in ["online", "offline"]:
             print("SUCCESS: Probe logic updated store")
        else:
             print("FAILURE: Store not updated correctly")
             
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(run_check())
