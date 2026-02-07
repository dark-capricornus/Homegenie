
import asyncio
import json
from datetime import datetime

# Mock DB return value
MOCK_DB_DEVICES = {
    "light.kitchen": {
        "device_id": "light.kitchen", 
        "name": "Kitchen Light", 
        "type": "light", 
        "state": {"state": "off"}, 
        "last_updated": "2020-01-01T00:00:00"
    }
}

# Mock ContextStore entries
MOCK_CONTEXT_TOPICS = {
    "home/light/kitchen/state": {"state": "on", "timestamp": "2026-01-01T12:00:00"},
    "home/sensor/motion/state": {"detected": True, "timestamp": "2026-01-01T12:05:00"}
}

async def merge_logic(enable_db=True):
    devices = {}
    
    # 1. DB Fetch
    if enable_db:
        # Simulate DB fetch
        devices.update(MOCK_DB_DEVICES)
        print(f"[DB] Fetched {len(devices)} devices")
    else:
        print("[DB] Fetch skipped/failed")
        
    # 2. Context Store Fetch
    # Simulate ContextStore fetch
    for key, state in MOCK_CONTEXT_TOPICS.items():
        parts = key.split('/')
        if len(parts) >= 4 and parts[-1] == 'state':
            device_type = parts[1]
            device_name = parts[2]
            device_id = f"{device_type}.{device_name}"
            
            # Prepare live device object
            live_device = {
                "device_id": device_id,
                "type": device_type,
                "name": device_name, # Default if not in DB
                "state": state,
                "last_updated": state.get('timestamp')
            }
            
            if device_id in devices:
                print(f"[MERGE] Overriding DB state for {device_id}")
                # Keep static DB fields (name), override dynamic (state)
                # Note: db_async names are user-friendly "Kitchen Light", raw topic is "kitchen"
                # We want to preserve checking DB existence but update state
                devices[device_id]['state'] = state
                devices[device_id]['last_updated'] = live_device['last_updated']
                # Ensure merged flag or similar?
                devices[device_id]['source'] = 'merged'
            else:
                print(f"[MERGE] Adding new live device {device_id}")
                devices[device_id] = live_device
                devices[device_id]['source'] = 'live'
                
    return list(devices.values())

async def run_test():
    print("--- TEST 1: DB + Live (Merge) ---")
    result = await merge_logic(enable_db=True)
    print(json.dumps(result, indent=2))
    
    print("\n--- TEST 2: No DB (Fallback) ---")
    result = await merge_logic(enable_db=False)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    asyncio.run(run_test())
