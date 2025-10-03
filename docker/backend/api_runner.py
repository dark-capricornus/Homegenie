#!/usr/bin/env python3
"""
API + Agents Backend Container Runner

Runs the complete HomeGenie backend including:
- FastAPI REST API server
- Planner Agent (goal processing)
- Memory Agent (user preferences/history)
- Scheduler Agent (task optimization)
- Executor Agent (device commands via MQTT)
- Sensor Agent (device state monitoring via MQTT)
"""

import asyncio
import logging
import os
import signal
import sys
import uvicorn
from contextlib import asynccontextmanager

# Add src to Python path
sys.path.insert(0, '/app/src')

# Import the FastAPI app
from api.api_server import app

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class HomeGenieBackend:
    """Manages the complete HomeGenie backend services."""
    
    def __init__(self):
        self.host = os.getenv('API_HOST', '0.0.0.0')
        self.port = int(os.getenv('API_PORT', 8000))
        self.mqtt_broker_host = os.getenv('MQTT_BROKER_HOST', 'mqtt-broker')
        self.mqtt_broker_port = int(os.getenv('MQTT_BROKER_PORT', 1883))
        
        # Configure MQTT settings for the application
        os.environ['HOMEGENIE_MQTT_HOST'] = self.mqtt_broker_host
        os.environ['HOMEGENIE_MQTT_PORT'] = str(self.mqtt_broker_port)
        
        logger.info("🏠 HomeGenie Backend initialized")
        logger.info(f"🌐 API Server: {self.host}:{self.port}")
        logger.info(f"📡 MQTT Broker: {self.mqtt_broker_host}:{self.mqtt_broker_port}")
    
    async def run_server(self):
        """Run the FastAPI server with all agents."""
        logger.info("🚀 Starting HomeGenie API + Agents Backend...")
        
        # Configure uvicorn server
        config = uvicorn.Config(
            app=app,
            host=self.host,
            port=self.port,
            log_level=os.getenv('LOG_LEVEL', 'info').lower(),
            access_log=True,
            reload=False,  # Disable reload in container
            workers=1      # Single worker for simplicity
        )
        
        server = uvicorn.Server(config)
        
        try:
            # Start the server
            await server.serve()
        except Exception as e:
            logger.error(f"❌ Error running server: {e}")
            raise
    
    async def shutdown_handler(self, signum):
        """Handle graceful shutdown signals."""
        logger.info(f"📡 Received signal {signum}, shutting down gracefully...")
        
        # Additional cleanup if needed
        logger.info("✅ Backend shutdown complete")


async def main():
    """Main entry point for the backend container."""
    logger.info("🏠 HomeGenie Backend Container Starting...")
    
    backend = HomeGenieBackend()
    
    # Setup signal handlers for graceful shutdown
    loop = asyncio.get_event_loop()
    
    def signal_handler(signum, frame):
        logger.info(f"📡 Received signal {signum}")
        # Create shutdown task
        loop.create_task(backend.shutdown_handler(signum))
        # Stop the loop
        loop.stop()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Run the backend services
        await backend.run_server()
        
    except KeyboardInterrupt:
        logger.info("📡 Keyboard interrupt received")
    except Exception as e:
        logger.error(f"❌ Fatal error: {e}")
        sys.exit(1)
    
    logger.info("👋 HomeGenie Backend Container stopped")


if __name__ == "__main__":
    asyncio.run(main())