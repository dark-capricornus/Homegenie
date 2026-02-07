import asyncio
import httpx
import json
import time

async def verify_state():
    url = "http://localhost:8000/state"
    print(f"Polling {url} 5 times...")
    
    async with httpx.AsyncClient() as client:
        for i in range(5):
            try:
                response = await client.get(url)
                if response.status_code == 200:
                    data = response.json()
                    print(f"\n--- Poll {i+1} ---")
                    print(f"Total Devices: {data.get('total_devices')}")
                    states = data.get('states', {})
                    # Print simplified state summary
                    for key, val in states.items():
                        if isinstance(val, dict):
                            # extract core state
                            s = val.get('state')
                            v = val.get('value')
                            d = val.get('detected')
                            ts = val.get('timestamp')
                            print(f"{key}: state={s} val={v} detected={d} ts={ts}")
                        else:
                            print(f"{key}: {val}")
                else:
                    print(f"Error: {response.status_code} - {response.text}")
            except Exception as e:
                print(f"Exception: {e}")
            
            await asyncio.sleep(2)

if __name__ == "__main__":
    asyncio.run(verify_state())
