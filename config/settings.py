"""
HomeGenie Configuration

Central configuration for the home automation system.
"""

import os
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SRC_DIR = PROJECT_ROOT / "src"
TESTS_DIR = PROJECT_ROOT / "tests" 
CONFIG_DIR = PROJECT_ROOT / "config"
DOCS_DIR = PROJECT_ROOT / "docs"

# MQTT Configuration
MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", "1883"))
MQTT_BASE_TOPIC = os.getenv("MQTT_BASE_TOPIC", "home")

# API Configuration
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))
API_RELOAD = os.getenv("API_RELOAD", "true").lower() == "true"

# Logging Configuration
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# System Configuration
MAX_EXECUTION_HISTORY = int(os.getenv("MAX_EXECUTION_HISTORY", "100"))
MAX_USER_HISTORY = int(os.getenv("MAX_USER_HISTORY", "100"))
CONTEXT_STORE_BACKUP_INTERVAL = int(os.getenv("CONTEXT_STORE_BACKUP_INTERVAL", "300"))  # seconds

# Device Configuration
SUPPORTED_DEVICE_TYPES = [
    "light",
    "switch", 
    "thermostat",
    "lock",
    "fan",
    "sensor",
    "camera",
    "alarm"
]

# Default User Preferences
DEFAULT_PREFERENCES = {
    "default_brightness": 75,
    "default_temperature": 22.0,
    "sleep_temperature": 20.0,
    "away_temperature": 18.0,
    "default_fan_speed": 2
}