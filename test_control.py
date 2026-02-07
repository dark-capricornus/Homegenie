import asyncio
import httpx
import json
import sys

# API Configuration
API_URL = "http://localhost:8000"

async def test_control(device_id, action, params=None):
    """Send a control command to the API and check response."""
    url = f"{API_URL}/devices/{device_id}/command"
    payload = {
        "action": action,
        "user_id": "test_script"
    }
    if params:
        payload["parameters"] = params

    print(f"\n🚀 Sending Command: {device_id} -> {action} {params or ''}")
    
    async with httpx.AsyncClient() as client:
        try:
            # 1. Send Command
            response = await client.post(url, json=payload, timeout=10.0)
            
            if response.status_code == 200:
                print(f"✅ API Accepted Command: {response.json()}")
            else:
                print(f"❌ API Error {response.status_code}: {response.text}")
                return

            # 2. Wait for Sim to Process (Async nature)
            print("⏳ Waiting 2s for simulator to process...")
            await asyncio.sleep(2)

            # 3. Check State
            state_url = f"{API_URL}/devices/{device_id}"
            state_resp = await client.get(state_url)
            
            if state_resp.status_code == 200:
                state_data = state_resp.json()
                print(f"📋 Current State: {json.dumps(state_data.get('state'), indent=2)}")
            else:
                print(f"⚠️ Could not fetch state: {state_resp.status_code}")

        except Exception as e:
            print(f"❌ Exception: {e}")

async def main():
    print("=== HomeGenie Device Control Test (Expanded) ===")
    
    # Existing Tests
    await test_control("light.living_room", "turn_on")
    await test_control("lock.front_door", "unlock")
    
    # New Device Tests
    print("\n--- Testing New Devices ---")
    
    # Fan Test (mapped as 'bedoom fan' in devices.json -> fan.bedroom)
    # Note: Logic in simulator maps 'Switch' with id 'fan_...' to 'fan' type
    await test_control("fan.bedroom", "turn_on")
    await test_control("fan.bedroom", "set_speed", {"speed": 3, "oscillate": True})
    
    # Coffee Maker Test (switch.kitchen)
    # devices.json id: outlet_kitchen -> location: Kitchen -> key: switch.kitchen
    # Wait, simple_mqtt_simulator key generation: type.location_lower
    # type=switch, location=Kitchen -> switch.kitchen
    await test_control("switch.kitchen", "turn_on")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        asyncio.run(test_control(sys.argv[1], sys.argv[2]))
    else:
        asyncio.run(main())
