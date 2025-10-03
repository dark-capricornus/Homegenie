#!/usr/bin/env python3
"""
Device Simulator Container Runner

Runs multiple device simulators in a containerized environment with MQTT connectivity.
Each device type listens on home/<type>/<id>/set and publishes to home/<type>/<id>/state.
"""

import asyncio
import json
import logging
import os
import signal
import sys
from typing import Dict, List, Any
from datetime import datetime

# Add src to Python path
sys.path.insert(0, '/app/src')

from simulators.device_simulator import DeviceSimulator

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ContainerizedDeviceSimulator:
    """Manages multiple device simulators in container environment."""
    
    def __init__(self):
        self.broker_host = os.getenv('MQTT_BROKER_HOST', 'mqtt-broker')
        self.broker_port = int(os.getenv('MQTT_BROKER_PORT', 1883))
        self.device_types = os.getenv('SIMULATOR_DEVICES', 'light,thermostat,lock,media,sensor').split(',')
        
        self.simulators: List[DeviceSimulator] = []
        self.device_configs = self._load_device_configs()
        self.running = False
        
        logger.info(f"Containerized Device Simulator initialized")
        logger.info(f"MQTT Broker: {self.broker_host}:{self.broker_port}")
        logger.info(f"Device Types: {', '.join(self.device_types)}")
    
    def _load_device_configs(self) -> Dict[str, List[Dict[str, Any]]]:
        """Load device configurations from JSON file."""
        config_path = '/app/config/devices.json'
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Config file not found: {config_path}, using defaults")
            return self._get_default_device_configs()
    
    def _get_default_device_configs(self) -> Dict[str, List[Dict[str, Any]]]:
        """Get default device configurations."""
        return {
            "light": [
                {"id": "living_room", "name": "Living Room Light", "initial_brightness": 80},
                {"id": "bedroom", "name": "Bedroom Light", "initial_brightness": 60},
                {"id": "kitchen", "name": "Kitchen Light", "initial_brightness": 100}
            ],
            "thermostat": [
                {"id": "main", "name": "Main Thermostat", "initial_temperature": 22},
                {"id": "bedroom", "name": "Bedroom Thermostat", "initial_temperature": 20}
            ],
            "lock": [
                {"id": "front_door", "name": "Front Door Lock", "initial_locked": True},
                {"id": "back_door", "name": "Back Door Lock", "initial_locked": False}
            ],
            "media": [
                {"id": "living_room", "name": "Living Room TV", "initial_volume": 30},
                {"id": "bedroom", "name": "Bedroom Speaker", "initial_volume": 20}
            ],
            "sensor": [
                {"id": "motion_living", "name": "Living Room Motion", "sensor_type": "motion"},
                {"id": "temp_outdoor", "name": "Outdoor Temperature", "sensor_type": "temperature"},
                {"id": "humidity_bathroom", "name": "Bathroom Humidity", "sensor_type": "humidity"}
            ]
        }
    
    async def start_simulators(self):
        """Start all device simulators."""
        logger.info("Starting device simulators...")
        
        for device_type in self.device_types:
            if device_type not in self.device_configs:
                logger.warning(f"No configuration found for device type: {device_type}")
                continue
            
            for device_config in self.device_configs[device_type]:
                device_id = device_config['id']
                simulator = DeviceSimulator(
                    broker_host=self.broker_host,
                    broker_port=self.broker_port,
                    client_id=f"simulator_{device_type}_{device_id}_{datetime.now().strftime('%H%M%S')}"
                )
                
                # Configure device-specific initial state
                self._configure_device(simulator, device_type, device_config)
                
                self.simulators.append(simulator)
                logger.info(f"Configured {device_type} simulator: {device_config['name']} ({device_id})")
        
        # Start all simulators
        start_tasks = []
        for simulator in self.simulators:
            task = asyncio.create_task(simulator.start())
            start_tasks.append(task)
        
        if start_tasks:
            await asyncio.gather(*start_tasks, return_exceptions=True)
        
        self.running = True
        logger.info(f"Started {len(self.simulators)} device simulators")
    
    def _configure_device(self, simulator: DeviceSimulator, device_type: str, config: Dict[str, Any]):
        """Configure device-specific behavior."""
        device_id = config['id']
        
        if device_type == "light":
            # Set initial light state - will be handled by the simulator internally
            # The DeviceSimulator will create and manage device states automatically
            pass
            
        elif device_type == "thermostat":
            # Set initial thermostat state - will be handled by the simulator internally
            pass
            
        elif device_type == "lock":
            # Set initial lock state - will be handled by the simulator internally
            pass
            
        elif device_type == "media":
            # Set initial media device state - will be handled by the simulator internally
            pass
            
        elif device_type == "sensor":
            # Set initial sensor state - will be handled by the simulator internally
            pass
    
    async def stop_simulators(self):
        """Stop all device simulators."""
        logger.info("Stopping device simulators...")
        
        # Stop all simulators (stop() is synchronous)
        for simulator in self.simulators:
            simulator.stop()
        
        self.running = False
        logger.info("All device simulators stopped")
    
    async def run(self):
        """Main run loop."""
        try:
            await self.start_simulators()
            
            logger.info("Device simulators running... Press Ctrl+C to stop")
            
            # Keep running until interrupted
            while self.running:
                await asyncio.sleep(1)
                
        except asyncio.CancelledError:
            logger.info("Received shutdown signal")
        except Exception as e:
            logger.error(f"Error in simulator runner: {e}")
        finally:
            await self.stop_simulators()


async def main():
    """Main entry point."""
    logger.info("HomeGenie Device Simulator Container Starting...")
    
    simulator_manager = ContainerizedDeviceSimulator()
    
    # Handle graceful shutdown
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        # Cancel the main task, which will trigger cleanup
        for task in asyncio.all_tasks():
            task.cancel()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await simulator_manager.run()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
    
    logger.info("Device Simulator Container stopped")


if __name__ == "__main__":
    asyncio.run(main())