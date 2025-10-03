"""
FastAPI Endpoint Testing Script

Tests all the home automation API endpoints to ensure they work correctly.
Can be run without requiring FastAPI dependencies installed.
"""

import asyncio
import json
import sys
import time
from datetime import datetime
from typing import Dict, Any

# Try to import httpx for HTTP testing, fallback to manual testing if not available
try:
    import httpx
    HTTPX_AVAILABLE = True
except ImportError:
    HTTPX_AVAILABLE = False
    print("⚠️  httpx not available - showing test examples instead")


class APITester:
    """Test the FastAPI home automation endpoints."""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.client = httpx.AsyncClient(base_url=base_url) if HTTPX_AVAILABLE else None
    
    async def test_root_endpoint(self) -> Dict[str, Any]:
        """Test the root endpoint."""
        if not self.client:
            return {"test": "root", "expected": "API information", "status": "simulated"}
        
        try:
            response = await self.client.get("/")
            result = {
                "test": "GET /",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            }
            return result
        except Exception as e:
            return {"test": "GET /", "error": str(e), "status": "failed"}
    
    async def test_health_endpoint(self) -> Dict[str, Any]:
        """Test the health check endpoint."""
        if not self.client:
            return {"test": "health", "expected": "System health status", "status": "simulated"}
        
        try:
            response = await self.client.get("/health")
            result = {
                "test": "GET /health",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            }
            return result
        except Exception as e:
            return {"test": "GET /health", "error": str(e), "status": "failed"}
    
    async def test_preferences_endpoints(self, user_id: str = "test_user") -> Dict[str, Any]:
        """Test preference setting and getting."""
        if not self.client:
            return {
                "test": "preferences", 
                "examples": [
                    f"POST /prefs/{user_id}?key=default_brightness&value=75",
                    f"GET /prefs/{user_id}"
                ],
                "status": "simulated"
            }
        
        results = []
        
        # Test setting preferences
        test_prefs = [
            ("default_brightness", "75"),
            ("default_temperature", "22.5"),
            ("sleep_time", "23:00")
        ]
        
        for key, value in test_prefs:
            try:
                response = await self.client.post(f"/prefs/{user_id}?key={key}&value={value}")
                results.append({
                    "test": f"POST /prefs/{user_id}?key={key}&value={value}",
                    "status": response.status_code,
                    "data": response.json() if response.status_code == 200 else None
                })
            except Exception as e:
                results.append({
                    "test": f"POST /prefs/{user_id}?key={key}&value={value}",
                    "error": str(e),
                    "status": "failed"
                })
        
        # Test getting preferences
        try:
            response = await self.client.get(f"/prefs/{user_id}")
            results.append({
                "test": f"GET /prefs/{user_id}",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            })
        except Exception as e:
            results.append({
                "test": f"GET /prefs/{user_id}",
                "error": str(e),
                "status": "failed"
            })
        
        return {"test": "preferences", "results": results}
    
    async def test_state_endpoint(self) -> Dict[str, Any]:
        """Test the system state endpoint."""
        if not self.client:
            return {
                "test": "state",
                "example": "GET /state",
                "expected": "Current device states from ContextStore",
                "status": "simulated"
            }
        
        try:
            response = await self.client.get("/state")
            result = {
                "test": "GET /state",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            }
            return result
        except Exception as e:
            return {"test": "GET /state", "error": str(e), "status": "failed"}
    
    async def test_goal_endpoint(self, user_id: str = "test_user") -> Dict[str, Any]:
        """Test goal processing endpoint."""
        if not self.client:
            return {
                "test": "goal",
                "examples": [
                    f"POST /goal/{user_id}?goal=goodnight",
                    f"POST /goal/{user_id}?goal=good%20morning",
                    f"POST /goal/{user_id}?goal=movie%20time"
                ],
                "expected": "Goal processing through Planner → Scheduler → Executor",
                "status": "simulated"
            }
        
        test_goals = [
            "goodnight",
            "good morning", 
            "movie time",
            "lights on"
        ]
        
        results = []
        
        for goal in test_goals:
            try:
                response = await self.client.post(f"/goal/{user_id}?goal={goal}")
                results.append({
                    "test": f"POST /goal/{user_id}?goal={goal}",
                    "status": response.status_code,
                    "data": response.json() if response.status_code == 200 else None
                })
                
                # Small delay between goals
                await asyncio.sleep(0.5)
                
            except Exception as e:
                results.append({
                    "test": f"POST /goal/{user_id}?goal={goal}",
                    "error": str(e),
                    "status": "failed"
                })
        
        return {"test": "goal", "results": results}
    
    async def test_history_endpoint(self, user_id: str = "test_user") -> Dict[str, Any]:
        """Test history retrieval endpoint."""
        if not self.client:
            return {
                "test": "history",
                "examples": [
                    f"GET /history/{user_id}",
                    f"GET /history/{user_id}?limit=10"
                ],
                "expected": "User interaction history from MemoryAgent",
                "status": "simulated"
            }
        
        results = []
        
        # Test getting history
        try:
            response = await self.client.get(f"/history/{user_id}")
            results.append({
                "test": f"GET /history/{user_id}",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            })
        except Exception as e:
            results.append({
                "test": f"GET /history/{user_id}",
                "error": str(e),
                "status": "failed"
            })
        
        # Test getting limited history
        try:
            response = await self.client.get(f"/history/{user_id}?limit=5")
            results.append({
                "test": f"GET /history/{user_id}?limit=5",
                "status": response.status_code,
                "data": response.json() if response.status_code == 200 else None
            })
        except Exception as e:
            results.append({
                "test": f"GET /history/{user_id}?limit=5",
                "error": str(e),
                "status": "failed"
            })
        
        return {"test": "history", "results": results}
    
    async def run_all_tests(self, user_id: str = "test_user") -> Dict[str, Any]:
        """Run all API endpoint tests."""
        print("🧪 FASTAPI ENDPOINT TESTING")
        print("="*50)
        print()
        
        if not HTTPX_AVAILABLE:
            print("📝 Note: Running in simulation mode (httpx not available)")
            print("💡 To run actual HTTP tests: pip install httpx")
            print()
        
        tests = [
            ("Root Endpoint", self.test_root_endpoint()),
            ("Health Check", self.test_health_endpoint()),
            ("Preferences", self.test_preferences_endpoints(user_id)),
            ("System State", self.test_state_endpoint()),
            ("Goal Processing", self.test_goal_endpoint(user_id)),
            ("User History", self.test_history_endpoint(user_id))
        ]
        
        all_results = {}
        
        for test_name, test_coro in tests:
            print(f"🔧 Testing: {test_name}")
            try:
                result = await test_coro
                all_results[test_name] = result
                
                if isinstance(result.get("results"), list):
                    success_count = len([r for r in result["results"] if r.get("status") == 200])
                    total_count = len(result["results"])
                    print(f"   ✅ {success_count}/{total_count} sub-tests passed")
                elif result.get("status") == 200:
                    print(f"   ✅ Passed")
                elif result.get("status") == "simulated":
                    print(f"   📝 Simulated")
                else:
                    print(f"   ❌ Failed: {result.get('error', 'Unknown error')}")
                    
            except Exception as e:
                all_results[test_name] = {"error": str(e), "status": "failed"}
                print(f"   ❌ Error: {e}")
            
            print()
        
        return all_results
    
    async def close(self):
        """Close the HTTP client."""
        if self.client:
            await self.client.aclose()


def show_api_examples():
    """Show example API usage without requiring the server to be running."""
    print("🏠 HOME AUTOMATION API - ENDPOINT EXAMPLES")
    print("="*60)
    print()
    
    examples = [
        {
            "name": "🎯 Goal Processing",
            "endpoint": "POST /goal/{user_id}?goal=<goal>",
            "examples": [
                "POST /goal/john?goal=goodnight",
                "POST /goal/jane?goal=good%20morning",
                "POST /goal/bob?goal=movie%20time",
                "POST /goal/alice?goal=lights%20on"
            ],
            "description": "Process natural language goals through Planner → Scheduler → Executor"
        },
        {
            "name": "⚙️  User Preferences",
            "endpoint": "POST /prefs/{user_id}?key=<k>&value=<v>",
            "examples": [
                "POST /prefs/john?key=default_brightness&value=75",
                "POST /prefs/john?key=default_temperature&value=22.5",
                "GET /prefs/john"
            ],
            "description": "Manage user preferences for personalized automation"
        },
        {
            "name": "📊 System State",
            "endpoint": "GET /state",
            "examples": [
                "GET /state"
            ],
            "description": "Get current device states from ContextStore"
        },
        {
            "name": "📜 User History",
            "endpoint": "GET /history/{user_id}",
            "examples": [
                "GET /history/john",
                "GET /history/john?limit=10"
            ],
            "description": "Retrieve user interaction history from MemoryAgent"
        },
        {
            "name": "🏥 Health Check",
            "endpoint": "GET /health",
            "examples": [
                "GET /health"
            ],
            "description": "Check system health and component status"
        }
    ]
    
    for example in examples:
        print(f"{example['name']}")
        print(f"   📍 Endpoint: {example['endpoint']}")
        print(f"   📝 Description: {example['description']}")
        print(f"   🧪 Examples:")
        for ex in example['examples']:
            print(f"      {ex}")
        print()
    
    print("🔗 API Documentation:")
    print("   📖 Interactive docs: http://localhost:8000/docs")
    print("   📚 Alternative docs: http://localhost:8000/redoc")
    print()
    
    print("🎯 Goal Examples and Expected Actions:")
    goal_examples = [
        ("goodnight", "Turn off lights, lock doors, set sleep temperature"),
        ("good morning", "Turn on lights, set comfortable temperature, start coffee"),
        ("movie time", "Dim lights, set entertainment lighting"),
        ("party mode", "Set colorful lighting, adjust climate"),
        ("leaving home", "Turn off all lights, lock doors, set away temperature"),
        ("lights on", "Turn on all room lights at preferred brightness")
    ]
    
    for goal, action in goal_examples:
        print(f"   🎯 '{goal}' → {action}")
    print()


async def main():
    """Main test function."""
    print("🏠 FASTAPI HOME AUTOMATION API TESTER")
    print("Choose test mode:")
    print("  1. Show API Examples (no server required)")
    print("  2. Run Live Tests (requires API server running)")
    print()
    
    try:
        choice = input("Enter choice (1 or 2): ").strip()
        
        if choice == "1":
            show_api_examples()
        elif choice == "2":
            if not HTTPX_AVAILABLE:
                print("❌ httpx not available. Install with: pip install httpx")
                print("📝 Showing examples instead...\n")
                show_api_examples()
                return
            
            print("🚀 Starting live API tests...")
            print("📋 Prerequisites:")
            print("   1. API server running: python3 api_server.py")
            print("   2. Server accessible at: http://localhost:8000")
            print()
            
            proceed = input("Is API server running? (y/N): ").lower().strip()
            if proceed != 'y':
                print("👋 Please start API server first: python3 api_server.py")
                return
            
            tester = APITester()
            
            try:
                results = await tester.run_all_tests()
                
                print("="*50)
                print("📊 TEST SUMMARY")
                print("="*50)
                
                for test_name, result in results.items():
                    if isinstance(result.get("results"), list):
                        success_count = len([r for r in result["results"] if r.get("status") == 200])
                        total_count = len(result["results"])
                        status = "✅" if success_count == total_count else "⚠️"
                        print(f"{status} {test_name}: {success_count}/{total_count}")
                    elif result.get("status") == 200:
                        print(f"✅ {test_name}: Passed")
                    elif result.get("status") == "simulated":
                        print(f"📝 {test_name}: Simulated")
                    else:
                        print(f"❌ {test_name}: Failed")
                
                print()
                print("🎉 API testing completed!")
                
            finally:
                await tester.close()
        
        else:
            print("Invalid choice. Showing examples...")
            show_api_examples()
            
    except KeyboardInterrupt:
        print("\n👋 Testing interrupted")
    except Exception as e:
        print(f"❌ Error: {e}")


def test_without_server():
    """Test function that can run without external dependencies."""
    print("🏠 HOME AUTOMATION API - OFFLINE TESTING")
    print("="*50)
    print()
    
    # Simulate API responses
    simulated_responses = {
        "POST /goal/john?goal=goodnight": {
            "message": "Goal 'goodnight' processed successfully",
            "tasks_planned": 4,
            "tasks_scheduled": 4,
            "tasks_executed": 4,
            "execution_time": 2.1
        },
        "POST /prefs/john?key=default_brightness&value=75": {
            "user_id": "john",
            "preferences": {
                "default_brightness": 75,
                "default_temperature": 22.0
            }
        },
        "GET /state": {
            "timestamp": datetime.now().isoformat(),
            "states": {
                "home/light/livingroom/state": {"brightness": 40, "state": "on"},
                "home/thermostat/main/state": {"temperature": 22.5, "target": 22.0}
            },
            "total_devices": 2
        },
        "GET /history/john": {
            "user_id": "john",
            "entries": [
                {"timestamp": "2025-09-27T16:45:00", "type": "goal_request", "data": {"goal": "goodnight"}},
                {"timestamp": "2025-09-27T16:45:02", "type": "goal_execution", "data": {"tasks_executed": 4}}
            ],
            "total_entries": 2
        }
    }
    
    print("📝 Simulated API Responses:")
    print("-" * 30)
    
    for endpoint, response in simulated_responses.items():
        print(f"\n🔧 {endpoint}")
        print(f"📦 Response: {json.dumps(response, indent=2)}")
    
    print("\n✅ All endpoints would return structured JSON responses")
    print("🎯 The complete system integrates:")
    print("   - Goal processing (Planner → Scheduler → Executor)")
    print("   - User preference management")
    print("   - Real-time device state access")
    print("   - User interaction history tracking")


if __name__ == "__main__":
    if HTTPX_AVAILABLE:
        asyncio.run(main())
    else:
        # Fallback for systems without httpx
        try:
            choice = input("Choose: 1) Show examples, 2) Offline test: ").strip()
            if choice == "2":
                test_without_server()
            else:
                show_api_examples()
        except KeyboardInterrupt:
            print("\n👋 Testing ended")
        except:
            show_api_examples()