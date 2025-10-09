# HomeGenie Smart Home Automation - Run Instructions

## 🏠 Overview
HomeGenie is a comprehensive smart home automation system with Flutter mobile app, FastAPI backend, MQTT device simulation, and real-time device management.

**Current Status: ✅ WORKING**
- Network IP: `10.132.71.35`
- API Endpoint: `http://<IP_ADDR>`
- Web Frontend: `http://10.132.71.35:3000` (nginx issues - use API directly)
- MQTT Broker: `10.132.71.35:1883`
- Device Count: 7 simulated devices (lights, thermostat, sensors, locks)

---

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Network connectivity on port 8080, 3000, and 1883

### 1. Start the System
```bash
cd /home/harish/Desktop/Homegenie
docker-compose up --build -d
```

### 2. Verify System Health
```bash
# Check containers are running
docker ps

# Test API health
curl http://<IP_ADDR>/health

# Check device count
curl http://<IP_ADDR>/devices
```

### 3. Access from Mobile/Other Devices
- **API Base URL**: `http://<IP_ADDR>`
- **Flutter App**: Update `lib/main.dart` to use IP `<IP_ADDR>`

---

## 📱 Flutter Mobile App Setup

### Update Network Configuration
Edit `/home/harish/Desktop/Homegenie/frontend/lib/main.dart`:

```dart
// Find and update the API base URL
static const String baseUrl = 'http://<IP_ADDR>';
```

### Run Flutter App
```bash
cd /home/harish/Desktop/Homegenie/frontend
flutter run
```

### Development Mode (Hot Reload)
```bash
# Terminal 1: Keep containers running
docker-compose up

# Terminal 2: Flutter hot reload
cd frontend
flutter run --hot
```

---

## 🔧 API Endpoints

### Base URL: `http://<IP_ADDR>`

### Core Endpoints
- `GET /` - API information
- `GET /health` - System health status
- `GET /devices` - List all devices and states
- `GET /state` - Complete system state
- `GET /devices/{device_id}` - Get specific device status

### Device Control
- `POST /devices/control` - Direct device control
- `POST /devices/{device_id}/toggle` - Toggle device on/off
- `POST /devices/{device_id}/set?parameter=value` - Set device parameter

### Goal Processing (AI-driven)
- `POST /goal/{user_id}?goal=<goal>` - Process natural language goals
  - Examples: "goodnight", "movie time", "turn on lights"

### User Management
- `POST /prefs/{user_id}?key=<key>&value=<value>` - Set user preferences
- `GET /prefs/{user_id}` - Get user preferences
- `GET /history/{user_id}` - Get user interaction history

---

## 🏡 Available Devices

The system currently simulates 7 smart home devices:

### Lights
- `light.living_room` - Living room light (brightness, color)
- `light.bedroom` - Bedroom light (brightness, color)  
- `light.kitchen` - Kitchen light (brightness, color)

### Climate
- `thermostat.living_room` - Thermostat (temperature, mode)

### Security
- `lock.front_door` - Smart lock (locked/unlocked)

### Sensors
- `sensor.outdoor_temp` - Outdoor temperature sensor
- `sensor.motion_living` - Living room motion sensor

---

## 📊 Example API Calls

### Check System Health
```bash
curl http://<IP_ADDR>/health
```

### Get All Devices
```bash
curl http://<IP_ADDR>/devices | python3 -m json.tool
```

### Control a Light
```bash
# Turn on living room light
curl -X POST "http://<IP_ADDR>/devices/light.living_room/toggle"

# Set brightness
curl -X POST "http://<IP_ADDR>/devices/light.living_room/set?parameter=brightness&value=75"
```

### Process Natural Language Goal
```bash
# Goodnight routine
curl -X POST "http://<IP_ADDR>/goal/user1?goal=goodnight"

# Movie time
curl -X POST "http://<IP_ADDR>/goal/user1?goal=movie time"
```

---

## 🐳 Docker Commands

### View Logs
```bash
# All container logs
docker-compose logs

# API logs only
docker-compose logs homegenie-app

# MQTT broker logs
docker-compose logs homegenie-mqtt
```

### Container Management
```bash
# Stop system
docker-compose down

# Rebuild and restart
docker-compose up --build -d

# Rebuild without cache
docker-compose build --no-cache && docker-compose up -d
```

### Debug Container
```bash
# Execute shell in container
docker exec -it homegenie-app /bin/bash

# Check supervisor status
docker exec homegenie-app supervisorctl status

# View supervisor logs
docker exec homegenie-app cat /var/log/supervisor/api.log
```

---

## 🔍 Troubleshooting

### Container Issues
1. **Containers not starting**: Check `docker-compose logs`
2. **API not responding**: Verify port 8080 is available
3. **MQTT connection issues**: Check port 1883 accessibility

### Network Connectivity
1. **API not accessible from other devices**: 
   - Verify IP address: `ip addr show`
   - Check firewall settings
   - Ensure port 8080 is open

2. **Flutter app can't connect**:
   - Update `baseUrl` in Flutter app to `<IP_ADDR>`
   - Check device is on same network

### Performance Issues
1. **Slow response**: Check container resource usage with `docker stats`
2. **Memory issues**: Restart containers with `docker-compose restart`

---

## 🏗️ System Architecture

### Container Structure
- **homegenie-app**: Unified container with API, simulator, and web frontend
- **homegenie-mqtt**: Eclipse Mosquitto MQTT broker

### Internal Services (in homegenie-app container)
- **API Server**: FastAPI on port 8000 (mapped to 8080)
- **Device Simulator**: Publishes device states via MQTT
- **Sensor Agent**: Listens to MQTT and updates API state
- **Web Frontend**: Nginx on port 3000 (nginx has issues, use API directly)

### Data Flow
```
Device Simulator → MQTT Broker → Sensor Agent → Context Store → API → Flutter App
```

---

## 📝 Development Notes

### Known Issues
1. **Nginx Web Frontend**: Has configuration issues, use API endpoints directly
2. **Device Control**: Executor agent needs paho-mqtt fix for device control commands
3. **Web UI**: Flutter web build works, but nginx serving has problems

### Working Features ✅
- ✅ MQTT broker and device simulation
- ✅ API server with all endpoints
- ✅ Real-time device state updates
- ✅ Network accessibility (<IP_ADDR>)
- ✅ Flutter mobile app (with correct IP configuration)
- ✅ Natural language goal processing
- ✅ User preferences and history
- ✅ Device discovery and state management

### Future Improvements
1. Fix executor agent to use paho-mqtt for device control
2. Resolve nginx configuration for web frontend
3. Add authentication and user management
4. Implement device grouping and scenes
5. Add voice control integration

---

## 🎯 Testing Checklist

### Basic Functionality
- [ ] Containers start successfully: `docker ps`
- [ ] API health check: `curl http://<IP_ADDR>/health`
- [ ] Device discovery: `curl http://<IP_ADDR>/devices`
- [ ] Flutter app connects and shows devices

### Network Access
- [ ] API accessible from other devices on network
- [ ] Flutter app works on mobile devices
- [ ] MQTT broker accessible for external clients

### Advanced Features
- [ ] Goal processing works: `curl -X POST "http://<IP_ADDR>/goal/test?goal=goodnight"`
- [ ] Device state updates in real-time
- [ ] User preferences save and load correctly

---

## 🆘 Support

### Log Locations
- API logs: `/var/log/supervisor/api.log` (inside container)
- Simulator logs: `/var/log/supervisor/simulator.log` (inside container)
- Nginx logs: `/var/log/supervisor/nginx.log` (inside container)

### Container Health
```bash
# Check all container status
docker-compose ps

# View container health
docker inspect homegenie-app | grep Health -A 10
```

### Network Diagnostics
```bash
# Check which ports are open
netstat -tlnp | grep -E '(8080|3000|1883)'

# Test connectivity from another device
curl -v http://<IP_ADDR>/health
```

---

## 🏆 Success Metrics

**✅ System is working when:**
- All containers show "healthy" status
- API returns device count > 0
- Flutter app successfully connects and displays devices
- Real-time device state updates are visible
- Network access works from other devices on `<IP_ADDR>`

**Current Status: ✅ Core system functional with 7 devices accessible on network IP <IP_ADDR>**