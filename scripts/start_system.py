"""
Home Automation System Startup Script

This script demonstrates how to start and test the complete home automation system
with all components working together.
"""

import os
import sys
import time
import subprocess
from pathlib import Path


def check_dependencies():
    """Check if required dependencies are available."""
    required_packages = [
        ("fastapi", "FastAPI web framework"),
        ("uvicorn", "ASGI server for FastAPI"),
        ("aiomqtt", "Async MQTT client")
    ]
    
    missing_packages = []
    
    for package, description in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append((package, description))
    
    if missing_packages:
        print("❌ Missing required packages:")
        for package, description in missing_packages:
            print(f"   📦 {package} - {description}")
        print()
        print("🔧 To install missing packages:")
        print("   pip install fastapi uvicorn aiomqtt")
        print("   # OR")
        print("   pip install -r requirements.txt")
        return False
    
    return True


def show_system_overview():
    """Show overview of the complete system."""
    print("🏠 HOME AUTOMATION SYSTEM")
    print("="*50)
    print()
    
    components = [
        ("ContextStore", "Thread-safe device state storage", "✅ Ready"),
        ("SensorAgent", "MQTT sensor data collection", "✅ Ready"),
        ("ExecutorAgent", "Device command execution", "✅ Ready"),
        ("DeviceSimulator", "Mock IoT devices for testing", "✅ Ready"),
        ("FastAPI Server", "REST API web interface", "🚀 New!"),
        ("Planner", "Goal → device action planning", "🚀 New!"),
        ("Scheduler", "Task optimization and scheduling", "🚀 New!"),
        ("MemoryAgent", "User interaction history", "🚀 New!")
    ]
    
    print("📋 System Components:")
    for name, description, status in components:
        print(f"   {status} {name:<16} - {description}")
    print()
    
    print("🎯 New FastAPI Endpoints:")
    endpoints = [
        ("POST /goal/{user_id}?goal=<goal>", "Process natural language goals"),
        ("POST /prefs/{user_id}?key=<k>&value=<v>", "Set user preferences"),
        ("GET /prefs/{user_id}", "Get user preferences"),
        ("GET /state", "Get current device states"),
        ("GET /history/{user_id}", "Get user interaction history")
    ]
    
    for endpoint, description in endpoints:
        print(f"   📍 {endpoint}")
        print(f"      {description}")
        print()


def show_startup_instructions():
    """Show instructions for starting the complete system."""
    print("🚀 COMPLETE SYSTEM STARTUP GUIDE")
    print("="*50)
    print()
    
    print("📋 Option 1: Full System (with MQTT broker)")
    print("-" * 30)
    print("1. Start MQTT broker:")
    print("   sudo systemctl start mosquitto")
    print("   # OR")
    print("   mosquitto -v")
    print()
    print("2. Terminal 1 - Device Simulator:")
    print("   python3 device_simulator.py")
    print()
    print("3. Terminal 2 - FastAPI Server:")
    print("   python3 api_server.py")
    print()
    print("4. Terminal 3 - Test the system:")
    print("   python3 test_api.py")
    print("   # OR use web browser:")
    print("   # http://localhost:8000/docs")
    print()
    
    print("📋 Option 2: API Testing (no MQTT required)")
    print("-" * 30)
    print("1. Start FastAPI Server:")
    print("   python3 api_server.py")
    print()
    print("2. Test endpoints:")
    print("   curl http://localhost:8000/")
    print("   curl 'http://localhost:8000/goal/john?goal=goodnight'")
    print("   curl 'http://localhost:8000/prefs/john?key=brightness&value=75'")
    print()
    
    print("📋 Option 3: Development Testing (no dependencies)")
    print("-" * 30)
    print("1. Test individual components:")
    print("   python3 test_device_simulator.py")
    print("   python3 test_complete_system.py")
    print()
    print("2. Test API examples:")
    print("   python3 test_api.py")
    print()


def show_api_usage_examples():
    """Show practical API usage examples."""
    print("🎯 PRACTICAL API USAGE EXAMPLES")
    print("="*50)
    print()
    
    print("💡 Morning Routine:")
    print("   curl -X POST 'http://localhost:8000/goal/alice?goal=good%20morning'")
    print("   Expected: Turn on lights, set comfortable temperature, start coffee")
    print()
    
    print("🌙 Bedtime Routine:")
    print("   curl -X POST 'http://localhost:8000/goal/bob?goal=goodnight'")
    print("   Expected: Dim lights, lock doors, set sleep temperature")
    print()
    
    print("🎬 Entertainment Mode:")
    print("   curl -X POST 'http://localhost:8000/goal/jane?goal=movie%20time'")
    print("   Expected: Dim lights for watching movies")
    print()
    
    print("⚙️  Set User Preferences:")
    print("   curl -X POST 'http://localhost:8000/prefs/alice?key=default_brightness&value=80'")
    print("   curl -X POST 'http://localhost:8000/prefs/alice?key=default_temperature&value=23.5'")
    print()
    
    print("📊 Check System State:")
    print("   curl http://localhost:8000/state")
    print("   Returns: All current device states from ContextStore")
    print()
    
    print("📜 View User History:")
    print("   curl http://localhost:8000/history/alice")
    print("   Returns: All user interactions and goal executions")
    print()
    
    print("🏥 Health Check:")
    print("   curl http://localhost:8000/health")
    print("   Returns: System health and component status")
    print()


def main():
    """Main startup script function."""
    print("🏠 HOME AUTOMATION SYSTEM - STARTUP HELPER")
    print("="*60)
    print()
    
    # Check working directory
    current_dir = Path.cwd()
    required_files = [
        "src/core/context_store.py",
        "src/agents/sensor_agent.py", 
        "src/agents/executor_agent.py",
        "src/simulators/device_simulator.py",
        "src/api/api_server.py"
    ]
    
    missing_files = [f for f in required_files if not (current_dir / f).exists()]
    
    if missing_files:
        print("❌ Missing required files:")
        for file in missing_files:
            print(f"   📄 {file}")
        print()
        print("💡 Please run this script from the Homegenie directory")
        return
    
    print("✅ All system files found")
    print()
    
    # Show menu
    print("Choose an option:")
    print("  1. Show System Overview")
    print("  2. Show Startup Instructions")
    print("  3. Show API Usage Examples")
    print("  4. Check Dependencies")
    print("  5. Quick Test (no server required)")
    print("  6. Start FastAPI Server (if dependencies available)")
    print()
    
    try:
        choice = input("Enter choice (1-6): ").strip()
        print()
        
        if choice == "1":
            show_system_overview()
        elif choice == "2":
            show_startup_instructions()
        elif choice == "3":
            show_api_usage_examples()
        elif choice == "4":
            deps_ok = check_dependencies()
            if deps_ok:
                print("✅ All dependencies are available!")
                print("🚀 You can start the FastAPI server with: python3 api_server.py")
            else:
                print("📝 Install missing dependencies to use the FastAPI server")
        elif choice == "5":
            print("🧪 Running quick test...")
            os.system("python3 test_api.py")
        elif choice == "6":
            if check_dependencies():
                print("🚀 Starting FastAPI server...")
                print("📖 API docs will be available at: http://localhost:8000/docs")
                print("🛑 Press Ctrl+C to stop the server")
                print()
                try:
                    os.system("python3 api_server.py")
                except KeyboardInterrupt:
                    print("\n🛑 Server stopped")
            else:
                print("❌ Cannot start server - missing dependencies")
        else:
            print("Invalid choice. Showing system overview...")
            show_system_overview()
    
    except KeyboardInterrupt:
        print("\n👋 Startup helper ended")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    main()