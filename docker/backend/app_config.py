"""
HomeGenie Backend Configuration for Docker Container

This configuration file contains settings for the HomeGenie backend
when running in a Docker container environment.
"""

import os
from typing import Dict, Any

# MQTT Configuration
MQTT_CONFIG = {
    "broker_host": os.getenv('MQTT_BROKER_HOST', 'mqtt-broker'),
    "broker_port": int(os.getenv('MQTT_BROKER_PORT', 1883)),
    "client_id_prefix": "homegenie_backend",
    "keepalive": 60,
    "retry_interval": 5,
    "max_retries": 10
}

# API Configuration
API_CONFIG = {
    "host": os.getenv('API_HOST', '0.0.0.0'),
    "port": int(os.getenv('API_PORT', 8000)),
    "title": "HomeGenie Smart Home API",
    "description": "REST API for HomeGenie Smart Home Automation System",
    "version": "1.0.0",
    "docs_url": "/docs",
    "redoc_url": "/redoc"
}

# Agent Configuration
AGENT_CONFIG = {
    "sensor_agent": {
        "topic_pattern": "home/+/+/state",
        "auto_start": True,
        "reconnect_interval": 5
    },
    "executor_agent": {
        "base_topic": "home",
        "command_timeout": 10,
        "batch_size": 10
    },
    "planner": {
        "max_tasks_per_goal": 20,
        "enable_optimization": True
    },
    "scheduler": {
        "max_concurrent_tasks": 5,
        "enable_conflict_resolution": True
    },
    "memory_agent": {
        "max_history_per_user": 100,
        "enable_preferences_learning": True
    }
}

# Logging Configuration
LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        },
        "detailed": {
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s"
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "level": os.getenv('LOG_LEVEL', 'INFO'),
            "formatter": "default",
            "stream": "ext://sys.stdout"
        },
        "file": {
            "class": "logging.FileHandler",
            "level": "DEBUG",
            "formatter": "detailed",
            "filename": "/app/logs/homegenie.log",
            "mode": "a"
        }
    },
    "loggers": {
        "": {  # Root logger
            "level": "DEBUG",
            "handlers": ["console", "file"]
        },
        "uvicorn": {
            "level": "INFO",
            "handlers": ["console"],
            "propagate": False
        },
        "fastapi": {
            "level": "INFO", 
            "handlers": ["console"],
            "propagate": False
        }
    }
}

# Device Simulation Configuration
DEVICE_CONFIG = {
    "default_devices": {
        "lights": ["living_room", "bedroom", "kitchen", "hallway"],
        "thermostats": ["main", "bedroom"],
        "locks": ["front_door", "back_door", "garage"],
        "media": ["living_room", "bedroom", "kitchen"],
        "sensors": ["motion_living", "motion_hallway", "temp_outdoor", "humidity_bathroom"]
    },
    "state_update_interval": 30,  # seconds
    "battery_drain_simulation": True
}

# Security Configuration (Basic for container environment)
SECURITY_CONFIG = {
    "enable_cors": True,
    "cors_origins": ["*"],  # Allow all origins in development
    "cors_methods": ["GET", "POST", "PUT", "DELETE"],
    "cors_headers": ["*"],
    "enable_authentication": False,  # Disable for development
    "api_key_header": "X-API-Key"
}

# Storage Configuration
STORAGE_CONFIG = {
    "data_directory": "/app/data",
    "enable_persistence": True,
    "backup_interval": 3600,  # seconds
    "max_backup_files": 5
}

# Health Check Configuration
HEALTH_CONFIG = {
    "check_mqtt_connection": True,
    "check_device_simulators": True,
    "check_agents_status": True,
    "unhealthy_threshold": 3  # consecutive failures
}

# Get configuration by section
def get_config(section: str) -> Dict[str, Any]:
    """Get configuration for a specific section."""
    configs = {
        "mqtt": MQTT_CONFIG,
        "api": API_CONFIG,
        "agents": AGENT_CONFIG,
        "logging": LOGGING_CONFIG,
        "devices": DEVICE_CONFIG,
        "security": SECURITY_CONFIG,
        "storage": STORAGE_CONFIG,
        "health": HEALTH_CONFIG
    }
    return configs.get(section, {})

# Get all configuration
def get_all_config() -> Dict[str, Any]:
    """Get all configuration sections."""
    return {
        "mqtt": MQTT_CONFIG,
        "api": API_CONFIG,
        "agents": AGENT_CONFIG,
        "logging": LOGGING_CONFIG,
        "devices": DEVICE_CONFIG,
        "security": SECURITY_CONFIG,
        "storage": STORAGE_CONFIG,
        "health": HEALTH_CONFIG
    }