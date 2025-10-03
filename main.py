#!/usr/bin/env python3
"""
HomeGenie - Main Entry Point

This script provides a unified entry point for running different components
of the home automation system.
"""

import sys
import os
import argparse
from pathlib import Path

# Add src directory to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def main():
    """Main entry point for HomeGenie system."""
    parser = argparse.ArgumentParser(
        description='HomeGenie - Smart Home Automation System',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py api              # Start FastAPI server
  python main.py simulator        # Start device simulator
  python main.py demo             # Run system demo
  python main.py test             # Run tests
        """
    )
    
    parser.add_argument(
        'command',
        choices=['api', 'simulator', 'demo', 'test', 'help'],
        help='Command to run'
    )
    
    parser.add_argument(
        '--host',
        default='localhost',
        help='Host address (default: localhost)'
    )
    
    parser.add_argument(
        '--port',
        type=int,
        default=8000,
        help='Port number (default: 8000 for API, 1883 for MQTT)'
    )
    
    args = parser.parse_args()
    
    if args.command == 'api':
        print("🚀 Starting FastAPI Server...")
        print(f"📡 Server will be available at: http://{args.host}:{args.port}")
        print("📖 API docs: http://{0}:{1}/docs".format(args.host, args.port))
        print("🛑 Press Ctrl+C to stop")
        print()
        
        try:
            import uvicorn
            uvicorn.run(
                "src.api.api_server:app",
                host=args.host,
                port=args.port,
                reload=True,
                log_level="info"
            )
        except ImportError:
            print("❌ FastAPI/uvicorn not installed. Install with:")
            print("   pip install -r config/requirements.txt")
        except KeyboardInterrupt:
            print("\n🛑 API Server stopped")
    
    elif args.command == 'simulator':
        print("🤖 Starting Device Simulator...")
        print(f"📡 MQTT Broker: {args.host}:1883")
        print("🛑 Press Ctrl+C to stop")
        print()
        
        try:
            from src.simulators.device_simulator import DeviceSimulator
            import asyncio
            
            async def run_simulator():
                simulator = DeviceSimulator(broker_host=args.host)
                await simulator.start()
            
            asyncio.run(run_simulator())
        except KeyboardInterrupt:
            print("\n🛑 Device Simulator stopped")
        except Exception as e:
            print(f"❌ Error: {e}")
    
    elif args.command == 'demo':
        print("🧪 Running System Demo...")
        try:
            from tests.home_automation_demo import demo_home_automation
            import asyncio
            asyncio.run(demo_home_automation())
        except Exception as e:
            print(f"❌ Error: {e}")
    
    elif args.command == 'test':
        print("🧪 Running Tests...")
        try:
            from tests.test_api import main as test_main
            import asyncio
            asyncio.run(test_main())
        except Exception as e:
            print(f"❌ Error: {e}")
    
    elif args.command == 'help':
        show_help()
    
    else:
        parser.print_help()

def show_help():
    """Show detailed help information."""
    print("🏠 HOMEGENIE - SMART HOME AUTOMATION SYSTEM")
    print("="*50)
    print()
    
    print("📋 Available Commands:")
    print("  api        - Start FastAPI REST API server")
    print("  simulator  - Start device simulator (mock IoT devices)")
    print("  demo       - Run interactive system demonstration")
    print("  test       - Run test suite")
    print("  help       - Show this help message")
    print()
    
    print("🚀 Quick Start:")
    print("  1. Install dependencies:")
    print("     pip install -r config/requirements.txt")
    print()
    print("  2. Start API server:")
    print("     python main.py api")
    print()
    print("  3. In another terminal, start simulator:")
    print("     python main.py simulator")
    print()
    print("  4. Test the system:")
    print("     curl 'http://localhost:8000/goal/john?goal=goodnight'")
    print()
    
    print("📁 Project Structure:")
    print("  src/")
    print("    core/       - Core components (ContextStore)")
    print("    agents/     - Automation agents (SensorAgent, ExecutorAgent)")
    print("    api/        - FastAPI server and endpoints")
    print("    simulators/ - Mock device simulators")
    print("  tests/        - Test suites and demos")
    print("  config/       - Configuration files")
    print("  docs/         - Documentation")
    print("  scripts/      - Utility scripts")
    print()

if __name__ == "__main__":
    main()