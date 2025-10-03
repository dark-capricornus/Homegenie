# 🏠 HomeGenie - Smart Home Automation System

A comprehensive home automation system built with Python, featuring real-time device monitoring, intelligent goal processing, and RESTful API control.

## 🚀 Features

- **Real-time Device Monitoring**: MQTT-based sensor data collection
- **Intelligent Automation**: Natural language goal processing and execution
- **RESTful API**: Complete FastAPI-based control interface
- **📱 Flutter Mobile App**: Beautiful mobile interface with quick actions
- **Device Simulation**: Built-in IoT device simulator for testing
- **Thread-Safe Architecture**: Concurrent operation support
- **Extensible Design**: Easy to add new devices and automation rules

## 📁 Project Structure

```
HomeGenie/
├── src/
│   ├── core/           # Core system components
│   │   └── context_store.py    # Thread-safe state management
│   ├── agents/         # Automation agents
│   │   ├── sensor_agent.py     # MQTT sensor data collector
│   │   └── executor_agent.py   # Device command executor
│   ├── api/            # REST API server
│   │   └── api_server.py       # FastAPI server with endpoints
│   └── simulators/     # Device simulators
│       └── device_simulator.py # Mock IoT devices
├── frontend/           # Flutter mobile app
│   ├── lib/main.dart           # Flutter app code
│   ├── pubspec.yaml            # Flutter dependencies
│   └── README.md              # Flutter app documentation
├── tests/              # Test suites and demonstrations
├── config/             # Configuration files
│   └── requirements.txt        # Python dependencies
├── docs/               # Documentation
├── scripts/            # Utility scripts
└── main.py             # Unified entry point
```

## 🛠️ Installation

1. **Clone the project** (if from repository)
2. **Install dependencies**:
   ```bash
   pip install -r config/requirements.txt
   ```

## 🚀 Quick Start

### 1. Start the System Components

**Terminal 1 - Start API Server:**
```bash
python main.py api
```

**Terminal 2 - Start Device Simulator:**
```bash
python main.py simulator
```

**Terminal 3 - Start Flutter App (optional):**
```bash
cd frontend
flutter run -d chrome
```

### 2. Test the System

**Set a goal via API:**
```bash
curl "http://localhost:8000/goal/john?goal=goodnight"
```

**Check device states:**
```bash
curl "http://localhost:8000/state"
```

**View execution history:**
```bash
curl "http://localhost:8000/history"
```

## 📊 API Endpoints

The FastAPI server provides these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/goal/{user}` | GET | Process natural language goals |
| `/preferences/{user}` | GET/POST | User preference management |
| `/state` | GET | Current device states |
| `/history` | GET | Execution history |
| `/plan` | POST | Generate action plans |
| `/schedule` | POST | Schedule optimized actions |
| `/devices` | GET | Available device list |
| `/docs` | GET | Interactive API documentation |

## 🏗️ Architecture

### Core Components

1. **ContextStore**: Thread-safe state management for all devices
2. **SensorAgent**: MQTT subscriber for real-time sensor data
3. **ExecutorAgent**: Device command execution and batch processing
4. **DeviceSimulator**: Mock IoT devices for development and testing

### API Layer

- **FastAPI Server**: RESTful API with automatic documentation
- **Planner**: Converts natural language goals to actionable steps
- **Scheduler**: Optimizes action execution timing
- **MemoryAgent**: Tracks execution history and user patterns

## 🧪 Testing

Run the comprehensive test suite:
```bash
python main.py test
```

Or run individual demos:
```bash
python main.py demo
```

## 📱 Supported Device Types

- **Lights**: Smart bulbs, dimmers, color-changing lights
- **Climate**: Thermostats, AC units, heaters
- **Security**: Door locks, cameras, motion sensors
- **Entertainment**: TVs, speakers, streaming devices
- **Appliances**: Coffee makers, dishwashers, microwaves
- **Sensors**: Temperature, humidity, motion, door/window sensors

## 🔧 Configuration

Edit `config/app_config.py` to customize:
- MQTT broker settings
- Device discovery parameters
- API server configuration
- Logging levels

## 🌟 Example Usage

### Setting Up a "Goodnight" Routine

```python
# Via API
curl "http://localhost:8000/goal/alice?goal=goodnight"

# This automatically:
# 1. Turns off all lights
# 2. Locks doors
# 3. Sets thermostat to night mode
# 4. Arms security system
```

### Monitoring Device Status

```python
# Get all device states
curl "http://localhost:8000/state"

# Response includes real-time status of all connected devices
```

## 🚀 Advanced Features

- **Natural Language Processing**: Understands complex automation goals
- **User Preferences**: Learns and adapts to individual user patterns  
- **Conflict Resolution**: Handles competing automation requests intelligently
- **Historical Analysis**: Tracks usage patterns for optimization
- **Extensible Plugin System**: Easy integration of new device types

## 📝 Development

### Adding New Device Types

1. Extend `DeviceSimulator` with new device logic
2. Update `ExecutorAgent` with device-specific commands
3. Add device discovery to `SensorAgent`
4. Test with the built-in simulator

### API Extension

1. Add new endpoints to `api_server.py`
2. Update the Planner for new goal types
3. Test with the interactive documentation at `/docs`

## 🤝 Contributing

1. Follow the existing code structure in `src/`
2. Add tests for new features in `tests/`
3. Update documentation in `docs/`
4. Run the test suite before submitting changes

## 📄 License

This project is designed as a comprehensive example of modern home automation architecture using Python, FastAPI, and MQTT protocols.

---

**HomeGenie** - Making homes smarter, one automation at a time! 🏠✨