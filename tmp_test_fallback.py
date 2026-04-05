import asyncio
import json
import os
import sys
from datetime import datetime, timezone

# Mocking parts of api_server to test the logic
class MockContextStore:
    def dump(self):
        return {"states": {}, "total_topics": 0}

context_store = MockContextStore()

# We need to mock 'logger' 
import logging
logger = logging.getLogger("test")

# Now we can define a simplified version of the function to test the logic I just added
async def test_get_system_state():
    start_time = datetime.now()
    raw_data = context_store.dump()
    states = {}
    
    # 1. Observed
    for topic, payload in raw_data.get('states', {}).items():
        if topic.startswith("devices/") and topic.endswith("/observed"):
            device_id = topic.split("/")[1]
            states[device_id] = payload
    
    # 2. Probes
    for topic, payload in raw_data.get('states', {}).items():
        if topic.startswith("probes/"):
            probe_state = payload.get('state', {})
            if isinstance(probe_state, dict):
                sim_devices = probe_state.get('states') or probe_state.get('devices') or {}
                if isinstance(sim_devices, dict):
                    for dev_id, dev_state in sim_devices.items():
                        if dev_id not in states:
                            states[dev_id] = dev_state
    
    # 3. Fallback (THE NEW LOGIC)
    # Using absolute paths based on workspace info
    config_paths = [
        r'd:\Homegenie\config\devices.json',
        r'd:\Homegenie\docker\simulators\devices.json'
    ]
    for path in config_paths:
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    config_data = json.load(f)
                    device_list = []
                    if isinstance(config_data, list):
                        device_list = config_data
                    elif isinstance(config_data, dict):
                        for category, d_list in config_data.items():
                            if isinstance(d_list, list):
                                for d in d_list:
                                    if isinstance(d, dict):
                                        if 'category' not in d: d['category'] = category
                                        device_list.append(d)
                    
                    for d in device_list:
                        dev_id = d.get('id')
                        if dev_id and dev_id not in states:
                            d_type = d.get('category') or (dev_id.split('.')[0] if '.' in dev_id else 'unknown')
                            states[dev_id] = {
                                "name": d.get('name', dev_id),
                                "device_type": d_type,
                                "online": False,
                                "loading": True,
                                "location": d.get('location', 'unknown'),
                                "metadata": d.get('features', [])
                            }
                if len(device_list) > 0:
                    print(f"Successfully loaded from {path}")
                    break
            except Exception as e:
                print(f"Error loading {path}: {e}")

    print(f"Result: {len(states)} devices found.")
    for k, v in list(states.items())[:3]:
        print(f" - {k}: {v['name']} (loading={v.get('loading')})")

if __name__ == "__main__":
    asyncio.run(test_get_system_state())
