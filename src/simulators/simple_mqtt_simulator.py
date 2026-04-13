#!/usr/bin/env python3
"""
Simple MQTT Device Simulator using paho-mqtt
Creates realistic IoT devices for HomeGenie testing without complex async dependencies.
"""

import json
import logging
import random
import threading
import time
import os
from datetime import datetime
from typing import Dict, Any

import paho.mqtt.client as mqtt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SimpleMQTTSimulator:
    """Simple device simulator using paho-mqtt."""
    
    def __init__(self, broker_host="localhost", broker_port=1883):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client = mqtt.Client()
        self.running = False
        self.devices = self._create_devices()
        
        # Set longer socket timeout (default is 1 second which is too short)
        self.client._sock_timeout = 10.0
        
        # MQTT callbacks
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.on_disconnect = self._on_disconnect
        
        logger.info(f"SimpleMQTTSimulator initialized for {broker_host}:{broker_port}")
    
    def _create_devices(self) -> Dict[str, Dict[str, Any]]:
        """Create devices from config file or fallback to samples."""
        devices = {}
        
        # Try to load from config file
        config_paths = [
            os.getenv('DEVICES_CONFIG_PATH', ''),
            '/app/config/devices.json',
            'config/devices.json',
            '../config/devices.json',
            'docker/simulators/devices.json'
        ]
        
        for path in config_paths:
            if not path or not os.path.exists(path):
                continue
                
            try:
                logger.info(f"Loading devices from {path}...")
                with open(path, 'r') as f:
                    config = json.load(f)
                    
                for category, device_list in config.items():
                    for d in device_list:
                        # Normalize fields
                        device_type = category
                        # Handle switch/fan ambiguity if needed, otherwise rely on category
                        if category == 'switch' and d.get('id', '').startswith('fan_'):
                            device_type = 'fan'
                            
                        location_raw = d.get('location', 'unknown')
                        location = location_raw.lower().replace(' ', '_')
                        
                        # Generate unique key
                        key = f"{device_type}.{location}"
                        
                        # Build device state
                        device_state = {
                            "device_type": device_type,
                            "location": location,
                            "name": d.get('name', f"{device_type} {location}"),
                            "online": True,
                            "timestamp": datetime.now().isoformat()
                        }
                        
                        # Type-specific defaults
                        if device_type == "light":
                            brightness = d.get("initial_brightness", 0)
                            is_on = brightness > 0
                            device_state.update({
                                "state": "on" if is_on else "off",
                                "brightness": brightness,
                                "color": "white",
                                "power_consumption": brightness * 0.15 if is_on else 0.0
                            })
                        elif device_type == "switch":
                            is_on = d.get("initial_state", False)
                            device_state.update({
                                "state": "on" if is_on else "off",
                                "power_consumption": random.uniform(5.0, 15.0) if is_on else 0.0
                            })
                        elif device_type == "fan":
                            speed = d.get("initial_speed", 0)
                            is_on = speed > 0
                            device_state.update({
                                "state": "on" if is_on else "off",
                                "speed": speed,
                                "power_consumption": speed * 15.0 if is_on else 0.0
                            })
                        elif device_type == "lock":
                            device_state.update({
                                "locked": d.get("initial_locked", True),
                                "battery": 100,
                                "last_access": datetime.now().isoformat()
                            })
                        elif device_type == "thermostat":
                            device_state.update({
                                "temperature": d.get("initial_temperature", 22.0),
                                "target": d.get("initial_temperature", 22.0),
                                "mode": "auto",
                                "humidity": 50
                            })
                        elif device_type == "sensor":
                            sensor_type = d.get("sensor_type", "generic")
                            device_state.update({
                                "value": 0.0,
                                "battery": 100
                            })
                            if sensor_type == "motion":
                                device_state["detected"] = False
                                device_state["confidence"] = 0.0
                            elif sensor_type == "temperature":
                                device_state["value"] = 20.0
                                device_state["unit"] = "C"
                            elif sensor_type == "humidity":
                                device_state["value"] = 50.0
                                device_state["unit"] = "%"
                        
                        devices[key] = device_state
                        
                logger.info(f"✅ Loaded {len(devices)} devices from config")
                return devices
                
            except Exception as e:
                logger.error(f"Failed to load config from {path}: {e}")

        logger.warning("⚠️ No config file found, using hardcoded fallback devices")
        return {
            "light.living_room": {

                "device_type": "light",
                "location": "living_room", 
                "name": "Living Room Light",
                "state": "on",
                "brightness": 75,
                "color": "warm_white",
                "power_consumption": 12.0,
                "online": True
            },
            "light.bedroom": {
                "device_type": "light",
                "location": "bedroom",
                "name": "Bedroom Light", 
                "state": "off",
                "brightness": 0,
                "color": "white",
                "power_consumption": 0.0,
                "online": True
            },
            "light.kitchen": {
                "device_type": "light",
                "location": "kitchen",
                "name": "Kitchen Light",
                "state": "on",
                "brightness": 90,
                "color": "daylight", 
                "power_consumption": 14.0,
                "online": True
            },
            "thermostat.living_room": {
                "device_type": "thermostat",
                "location": "living_room",
                "name": "Main Thermostat",
                "temperature": 22.5,
                "target": 23.0, 
                "mode": "auto",
                "humidity": 45,
                "online": True
            },
            "lock.front_door": {
                "device_type": "lock",
                "location": "front_door",
                "name": "Front Door Lock",
                "locked": True,
                "battery": 85,
                "last_access": "2025-10-06T06:30:00",
                "online": True
            },
            "sensor.outdoor_temp": {
                "device_type": "sensor", 
                "location": "outdoor",
                "name": "Outdoor Temperature",
                "value": 18.5,
                "unit": "°C",
                "battery": 92,
                "online": True
            },
            "sensor.motion_living": {
                "device_type": "sensor",
                "location": "living_room",
                "name": "Motion Sensor", 
                "detected": False,
                "confidence": 0.0,
                "battery": 78,
                "online": True
            }
        }
    
    def _on_connect(self, client, userdata, flags, rc):
        """Called when MQTT client connects."""
        if rc == 0:
            logger.info("✅ Connected to MQTT broker")
            client.subscribe("home/+/+/set")
            logger.info("🎯 Subscribed to device commands")
            # Publish initial device states
            self._publish_all_states()
        else:
            logger.error(f"❌ Failed to connect to MQTT broker: {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """Called when MQTT client disconnects."""
        logger.info("🔌 Disconnected from MQTT broker")
    
    def _on_message(self, client, userdata, msg):
        """Handle incoming MQTT messages."""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            logger.info(f"🔧 Command received: {topic} -> {payload}")
            
            # Parse topic: home/device_type/location/set
            parts = topic.split('/')
            if len(parts) >= 4 and parts[-1] == 'set':
                device_type = parts[1] 
                location = parts[2]
                device_key = f"{device_type}.{location}"
                
                if device_key in self.devices:
                    # Parse command
                    command = json.loads(payload)
                    self._process_command(device_key, command)
                    
                    # Publish updated state
                    state_topic = f"home/{device_type}/{location}/state"
                    state = self.devices[device_key].copy()
                    state["timestamp"] = datetime.now().isoformat()
                    
                    client.publish(state_topic, json.dumps(state))
                    logger.info(f"📊 Published state: {device_key}")
                
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def _process_command(self, device_key: str, command: Dict[str, Any]):
        """Process device command and update state.""" 
        device = self.devices[device_key]
        action = command.get("action", "")
        value = command.get("value")
        
        if action in ["turn_on", "on"]:
            device["state"] = "on"
            if device["device_type"] == "light":
                device["brightness"] = device.get("brightness", 50) or 50
                device["power_consumption"] = device["brightness"] * 0.15
            elif device["device_type"] == "switch":
                device["power_consumption"] = random.uniform(5.0, 15.0)
            elif device["device_type"] == "fan":
                device["speed"] = device.get("speed", 2) or 2
                device["power_consumption"] = device["speed"] * 15.0

        elif action in ["turn_off", "off"]:
            device["state"] = "off"
            if device["device_type"] == "light":
                device["brightness"] = 0
            elif device["device_type"] == "fan":
                device["speed"] = 0
            device["power_consumption"] = 0.0
                
        elif action == "set_brightness" and value is not None:
            device["brightness"] = max(0, min(100, int(value)))
            device["state"] = "on" if device["brightness"] > 0 else "off"
            device["power_consumption"] = device["brightness"] * 0.15
            
        elif action == "set_color" and value is not None:
            device["color"] = value
            device["state"] = "on"
            
        elif action == "set_temperature" and value is not None:
            device["target"] = float(value)
            
        elif action in ["lock", "unlock"]:
            device["locked"] = (action == "lock")
            device["last_access"] = datetime.now().isoformat()
            
        device["timestamp"] = datetime.now().isoformat()
    
    def _publish_all_states(self):
        """Publish all device states."""
        for device_key, device in self.devices.items():
            device_type, location = device_key.split('.')
            topic = f"home/{device_type}/{location}/state"
            
            state = device.copy()
            state["timestamp"] = datetime.now().isoformat()
            
            self.client.publish(topic, json.dumps(state))
            logger.info(f"📋 Published initial state: {device_key}")
    
    def _periodic_updates(self):
        """Send periodic updates for all devices."""
        while self.running:
            try:
                # Update sensor values  
                if "sensor.outdoor_temp" in self.devices:
                    self.devices["sensor.outdoor_temp"]["value"] = round(
                        random.uniform(15.0, 25.0), 1
                    )
                    
                if "sensor.motion_living" in self.devices:
                    self.devices["sensor.motion_living"]["detected"] = random.choice([True, False])
                    self.devices["sensor.motion_living"]["confidence"] = round(
                        random.uniform(0.6, 0.95), 2
                    ) if self.devices["sensor.motion_living"]["detected"] else 0.0
                
                # Republish ALL device states to ensure they're always available
                for device_key, device in self.devices.items():
                    device_type, location = device_key.split('.')
                    topic = f"home/{device_type}/{location}/state"
                    
                    state = device.copy()
                    state["timestamp"] = datetime.now().isoformat()
                    
                    self.client.publish(topic, json.dumps(state))
                    logger.debug(f"📊 Republished state: {device_key}")
                
                time.sleep(30)  # Update every 30 seconds
                
            except Exception as e:
                logger.error(f"Error in periodic updates: {e}")
                time.sleep(5)
    
    def start(self):
        """Start the simulator."""
        if self.running:
            logger.warning("Simulator already running")
            return
            
        self.running = True
        logger.info("🚀 Starting SimpleMQTTSimulator...")
        
        try:
            # Connect to MQTT broker with longer timeout
            logger.info(f"Connecting to {self.broker_host}:{self.broker_port}...")
            self.client.connect(self.broker_host, self.broker_port, keepalive=60)
            
            # Start MQTT loop in background
            self.client.loop_start()
            
            # Start periodic updates in background thread
            update_thread = threading.Thread(target=self._periodic_updates, daemon=True)
            update_thread.start()
            
            logger.info("✅ SimpleMQTTSimulator started successfully")
            
            # Keep main thread alive
            while self.running:
                time.sleep(1)
                
        except Exception as e:
            logger.error(f"Error starting simulator: {e}")
            self.stop()
    
    def stop(self):
        """Stop the simulator."""
        logger.info("🛑 Stopping SimpleMQTTSimulator...")
        self.running = False
        self.client.loop_stop()
        self.client.disconnect()
        logger.info("SimpleMQTTSimulator stopped")


def main():
    """Main entry point."""
    import os
    
    broker_host = os.getenv('MQTT_BROKER_HOST', 'localhost')
    broker_port = int(os.getenv('MQTT_BROKER_PORT', 1883))
    
    simulator = SimpleMQTTSimulator(broker_host, broker_port)
    
    try:
        simulator.start()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
        simulator.stop()


if __name__ == "__main__":
    main()