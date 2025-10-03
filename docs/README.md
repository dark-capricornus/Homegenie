# HomeGenie - Smart Home Automation System

A comprehensive home automation system with MQTT integration, REST API, and intelligent goal processing.

## 🏗️ System Architecture

The system consists of eight integrated components that work together:

### 1. **ContextStore** (`context_store.py`)
- **P## 🎯 Complete System Workflow

### 1. **REST API Goal Processing Flow**
```
HTTP Request → FastAPI → Planner → Scheduler → ExecutorAgent → MQTT → DeviceSimulator → ContextStore
```

### 2. **Example Complete Round-Trip**
1. **HTTP Request**: `POST /goal/john?goal=goodnight`
2. **Planner**: Converts "goodnight" → [turn off lights, lock doors, set sleep temp]
3. **Scheduler**: Optimizes tasks, filters redundant commands
4. **ExecutorAgent**: Publishes commands to MQTT topics
5. **DeviceSimulator**: Receives commands, updates device states
6. **SensorAgent**: Collects state updates from MQTT
7. **ContextStore**: Stores latest device states
8. **MemoryAgent**: Records goal execution in user history
9. **Response**: `{"tasks_executed": 4, "execution_time": 2.1}`

### 3. **Direct Command Execution Flow**
```
ExecutorAgent → MQTT Broker → DeviceSimulator → Device State → SensorAgent → ContextStore
```

### 4. **Example Direct Command**
1. **Command**: `{"device": "light.livingroom", "action": "set_brightness", "value": 40}`
2. **ExecutorAgent**: Publishes to `home/light/livingroom/set`
3. **DeviceSimulator**: Receives command, processes it, prints debug info
4. **DeviceSimulator**: Publishes state to `home/light/livingroom/state`
5. **SensorAgent**: Receives state update
6. **ContextStore**: Stores latest device state
7. **Result**: `{"brightness": 40, "state": "on", "power_consumption": 32.0}`

## � FastAPI Endpoints

### Goal Processing
- **POST** `/goal/{user_id}?goal=<goal>` - Process natural language goals
  - Examples: "goodnight", "good morning", "movie time", "lights on"
  - Returns: Task execution results and timing

### User Preferences  
- **POST** `/prefs/{user_id}?key=<k>&value=<v>` - Set user preference
- **GET** `/prefs/{user_id}` - Get all user preferences
  - Examples: default_brightness=75, default_temperature=22.5

### System State
- **GET** `/state` - Get current device states from ContextStore
  - Returns: All device states with timestamps

### User History
- **GET** `/history/{user_id}?limit=50` - Get user interaction history
  - Returns: Goal requests, executions, preference changes

### Health & Utility
- **GET** `/health` - System health check
- **GET** `/` - API information and available endpoints
- **DELETE** `/history/{user_id}` - Clear user history

### Interactive Documentation
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## �🎯 Next Steps

1. **Add MQTT Broker**: Install Mosquitto or similar MQTT broker
2. **Connect Real Devices**: Replace DeviceSimulator with actual IoT devices  
3. **Add Authentication**: Implement user authentication and API keys
4. **Add Database**: Store states and history in persistent database
5. **Web Dashboard**: Create React/Vue frontend for the API
6. **Advanced NLP**: Use better natural language processing for goals
7. **Mobile App**: Create mobile app using the REST API
8. **Security**: Add HTTPS, rate limiting, and input validation

---

**Perfect Home Automation System** - Built with Python 🐍, FastAPI ⚡, MQTT 📡, and ❤️read-safe storage for device states
- **Features**: 
  - Asyncio and thread-safe operations
  - Automatic timestamp tracking
  - JSON export capabilities
- **Key Methods**:
  - `update_state(topic, payload)` - Store device state
  - `get_state(topic)` - Retrieve device state  
  - `dump()` - Export all states

### 2. **SensorAgent** (`sensor_agent.py`)
- **Purpose**: MQTT-based sensor data collection
- **Features**:
  - Connects to MQTT broker (`localhost:1883`)
  - Subscribes to `"home/+/+/state"` topics
  - Parses JSON messages automatically
  - Updates ContextStore with latest sensor data
  - Auto-reconnection and error handling
- **Usage**: Runs continuously in asyncio loop

### 3. **ExecutorAgent** (`executor_agent.py`)
- **Purpose**: Device command execution via MQTT
- **Features**:
  - Publishes device control commands
  - Supports batch command execution
  - Execution history tracking
  - Flexible device type mapping
- **Task Format**: 
  ```json
  {
    "device": "light.livingroom",
    "action": "set_brightness", 
    "value": 40
  }
  ```

### 4. **DeviceSimulator** (`device_simulator.py`)
- **Purpose**: Mock IoT devices for testing and development
- **Features**:
  - Subscribes to `"home/+/+/set"` command topics
  - Processes commands and prints them for debugging
  - Publishes realistic device states to `"home/+/+/state"`
  - Simulates 6+ device types with realistic behaviors
  - Periodic sensor data generation
- **Example Response**: `{"brightness": 40, "state": "on", "power_consumption": 32.0}`

### 5. **FastAPI Server** (`api_server.py`)
- **Purpose**: REST API web interface for the home automation system
- **Features**:
  - Goal processing through natural language
  - User preference management
  - Real-time system state access
  - User interaction history tracking
  - Interactive API documentation
- **Endpoints**: POST /goal, GET/POST /prefs, GET /state, GET /history

### 6. **Planner** (integrated in api_server.py)
- **Purpose**: Converts natural language goals into device action plans
- **Features**:
  - Parses goals like "goodnight", "movie time", "good morning"
  - Considers user preferences for personalization
  - Generates optimized task sequences
- **Example**: "goodnight" → Turn off lights, lock doors, set sleep temperature

### 7. **Scheduler** (integrated in api_server.py)
- **Purpose**: Optimizes and schedules planned tasks for execution
- **Features**:
  - Filters redundant commands based on current device states
  - Prioritizes tasks (security > lighting > climate)
  - Estimates execution times
- **Optimization**: Skips commands if device already in desired state

### 8. **MemoryAgent** (integrated in api_server.py)
- **Purpose**: Tracks user interactions and system history
- **Features**:
  - Records goal requests and execution results
  - Tracks preference changes
  - Maintains per-user history with timestamps
- **Storage**: In-memory with configurable limits (100 entries per user)

## 🚀 Quick Start

### REST API Usage (Recommended)

```bash
# Start the FastAPI server
python3 api_server.py

# Process natural language goals
curl -X POST "http://localhost:8000/goal/john?goal=goodnight"
curl -X POST "http://localhost:8000/goal/jane?goal=good%20morning"
curl -X POST "http://localhost:8000/goal/bob?goal=movie%20time"

# Set user preferences
curl -X POST "http://localhost:8000/prefs/john?key=default_brightness&value=75"

# Get system state
curl http://localhost:8000/state

# View user history
curl http://localhost:8000/history/john
```

### Python API Usage

```python
import asyncio
from context_store import ContextStore
from sensor_agent import SensorAgent  
from executor_agent import ExecutorAgent

# Create components
context_store = ContextStore()
sensor_agent = SensorAgent(context_store=context_store)
executor_agent = ExecutorAgent()

# Execute device commands
task = {"device": "light.livingroom", "action": "set_brightness", "value": 40}
await executor_agent.execute(task)

# Get device states
state = await context_store.async_get_state("home/living_room/temperature/state")
```

### Integrated System

```python
from home_automation_demo import HomeAutomationSystem

# Create integrated system
home_system = HomeAutomationSystem()

# Execute commands
await home_system.execute_command({
    "device": "light.bedroom", 
    "action": "turn_on", 
    "value": True
})

# Query device states
temperature = await home_system.get_device_state("home/living_room/temperature/state")
all_states = await home_system.get_all_states()
```

## 📡 MQTT Topic Structure

### Sensor Data (Subscribe)
- **Pattern**: `home/+/+/state`
- **Examples**:
  - `home/living_room/temperature/state`
  - `home/kitchen/light/state`
  - `home/bedroom/motion/state`

### Device Commands (Publish)
- **Format**: `home/{device_type}/{location}/set`
- **Examples**:
  - `home/light/livingroom/set`
  - `home/thermostat/bedroom/set`
  - `home/lock/front_door/set`

## 🎯 Task Format

The ExecutorAgent uses a standardized task format:

```json
{
  "device": "light.livingroom",     // Required: device_type.location
  "action": "set_brightness",       // Required: command to execute
  "value": 40,                      // Optional: main parameter
  "transition": 2,                  // Optional: additional parameters
  "reason": "user_request"          // Optional: execution reason
}
```

### Device Types Supported
- `light` - Smart lights, bulbs, strips
- `switch` - Smart switches, outlets
- `thermostat` - Climate control
- `lock` - Smart locks
- `fan` - Ceiling fans, ventilation
- `sensor` - Various sensors
- `camera` - Security cameras
- `alarm` - Security systems

## 📦 Installation

### Dependencies
```bash
# Install all dependencies
pip install -r requirements.txt

# Or install individually
pip install fastapi uvicorn pydantic aiomqtt httpx
```

### Files Structure
```
/home/harish/Desktop/Homegenie/
├── context_store.py              # Thread-safe state storage
├── sensor_agent.py              # MQTT sensor monitoring  
├── executor_agent.py            # Device command execution
├── device_simulator.py          # Mock IoT devices for testing
├── api_server.py                # FastAPI REST API server
├── home_automation_demo.py      # Integrated system demo
├── test_executor.py             # ExecutorAgent testing
├── test_device_simulator.py     # DeviceSimulator manual testing
├── test_complete_system.py      # Full system integration test
├── test_api.py                  # FastAPI endpoint testing
├── start_system.py              # System startup helper
└── requirements.txt             # Python dependencies
```

## 🧪 Testing

### Quick Start Testing
```bash
# Use the startup helper
python3 start_system.py

# Test API endpoints (no server required)
python3 test_api.py
```

### Run Individual Components
```bash
# Test FastAPI server
python3 api_server.py

# Test ContextStore and SensorAgent
python3 sensor_agent.py

# Test ExecutorAgent with mock MQTT
python3 test_executor.py

# Test DeviceSimulator logic (no MQTT broker required)
python3 test_device_simulator.py

# Run integrated system demo
python3 home_automation_demo.py
```

### Complete System Integration Test
```bash
# Terminal 1: Start device simulator
python3 device_simulator.py

# Terminal 2: Start FastAPI server
python3 api_server.py

# Terminal 3: Test the complete system
python3 test_api.py
# OR browse to: http://localhost:8000/docs
```

### Expected Output
- ✅ Thread-safe state management
- ✅ MQTT topic/payload generation
- ✅ JSON parsing and validation
- ✅ Execution history tracking
- ✅ Device command processing
- ✅ Realistic device state simulation
- ✅ Error handling and reconnection

## 🤖 Smart Automation Examples

### Motion-Activated Lighting
```python
# Check conditions
motion_detected = await context_store.async_get_state("home/living_room/motion/state")
light_state = await context_store.async_get_state("home/living_room/light/state")

# Execute automation
if motion_detected and motion_detected['detected'] and light_state['state'] == 'off':
    await executor_agent.execute({
        "device": "light.living_room",
        "action": "turn_on", 
        "value": True,
        "brightness": 70
    })
```

### Temperature Control
```python
# Monitor temperature
temp_state = await context_store.async_get_state("home/bedroom/temperature/state")

if temp_state['value'] > 25.0:  # Too hot
    await executor_agent.execute({
        "device": "thermostat.bedroom",
        "action": "set_temperature",
        "value": 22.0
    })
```

## 🔧 Configuration

### MQTT Broker Settings
```python
# Custom broker configuration
sensor_agent = SensorAgent(
    broker_host="192.168.1.100",  # Custom broker IP
    broker_port=1883,             # Standard MQTT port
    topic_pattern="home/+/+/state"
)

executor_agent = ExecutorAgent(
    broker_host="192.168.1.100",
    broker_port=1883,
    base_topic="home"             # Base topic for commands
)
```

### Custom Device Mappings
```python
# Add custom device types
executor_agent.add_device_mapping("garage_door", "garage")
executor_agent.add_device_mapping("sprinkler", "irrigation")

# Now supports: garage_door.main -> home/garage/main/set
```

## 📊 Monitoring & Statistics

### System Statistics
```python
# Get comprehensive stats
stats = home_system.get_system_stats()

# Sample output:
{
  "sensor_agent": {
    "broker": "localhost:1883",
    "topic_pattern": "home/+/+/state", 
    "stored_topics": 4
  },
  "executor_agent": {
    "total_executions": 15,
    "successful_executions": 14,
    "success_rate": 93.3
  },
  "context_store": {
    "total_devices": 4,
    "stored_topics": ["home/living_room/temp/state", ...]
  }
}
```

### Execution History
```python
# Get recent command history
history = executor_agent.get_execution_history(limit=10)

# Sample record:
{
  "timestamp": "2025-09-27T16:20:46.160439",
  "task": {"device": "light.bedroom", "action": "turn_on"},
  "topic": "home/light/bedroom/set", 
  "status": "success"
}
```

## 🔐 Thread Safety

All components are designed for concurrent use:

- **ContextStore**: Uses `threading.Lock()` and `asyncio.Lock()`
- **SensorAgent**: Safe for multiple concurrent message handling
- **ExecutorAgent**: Thread-safe execution tracking and statistics

## 🎯 Production Ready Features

✅ **Error Handling**: Comprehensive exception handling and logging  
✅ **Auto-Reconnection**: Automatic MQTT reconnection on failures  
✅ **Validation**: Input validation for all commands and data  
✅ **Logging**: Structured logging with configurable levels  
✅ **Statistics**: Real-time monitoring and performance metrics  
✅ **History**: Command execution history with timestamps  
✅ **Callbacks**: Customizable success/error callbacks  
✅ **Thread Safety**: Safe for concurrent access patterns  

## 🚦 Next Steps

1. **Add MQTT Broker**: Install Mosquitto or similar MQTT broker
2. **Connect Real Devices**: Integrate with actual IoT devices
3. **Add Persistence**: Store states in database for reliability
4. **Web Interface**: Create dashboard for monitoring/control
5. **Advanced Rules**: Implement complex automation logic
6. **Security**: Add authentication and encryption

---

**Perfect Home Automation System** - Built with Python 🐍, MQTT 📡, and ❤️