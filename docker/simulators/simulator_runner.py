#!/usr/bin/env python3
"""
Simple Device Simulator Container Runner

Runs a simple MQTT device simulator using paho-mqtt for better compatibility.
"""

import logging
import os
import signal
import sys
import time

# Add src to Python path
sys.path.insert(0, '/app/src')

from simulators.simple_mqtt_simulator import SimpleMQTTSimulator

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main entry point."""
    logger.info("HomeGenie Simple Device Simulator Starting...")
    
    broker_host = os.getenv('MQTT_BROKER_HOST', 'mqtt-broker')
    broker_port = int(os.getenv('MQTT_BROKER_PORT', 1883))
    
    simulator = SimpleMQTTSimulator(broker_host, broker_port)
    
    # Handle graceful shutdown
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        simulator.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        simulator.start()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
        simulator.stop()
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
    
    logger.info("Device Simulator stopped")


if __name__ == "__main__":
    main()