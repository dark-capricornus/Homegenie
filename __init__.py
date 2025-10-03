"""
HomeGenie - Smart Home Automation System

A comprehensive home automation system with MQTT integration, 
REST API, and intelligent goal processing.
"""

__version__ = "1.0.0"
__author__ = "HomeGenie Team"
__description__ = "Smart Home Automation System"

# Core components
from src.core.context_store import ContextStore
from src.agents.sensor_agent import SensorAgent
from src.agents.executor_agent import ExecutorAgent
from src.simulators.device_simulator import DeviceSimulator

__all__ = [
    "ContextStore",
    "SensorAgent", 
    "ExecutorAgent",
    "DeviceSimulator"
]