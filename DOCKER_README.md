# 🐳 HomeGenie Docker Deployment

A complete containerized deployment of the HomeGenie Smart Home Automation System using Docker Compose.

## 🏗️ Architecture Overview

The Docker deployment consists of 4 services running on a shared network:

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                       │
│                   (homegenie-net)                       │
├─────────────────────────────────────────────────────────┤
│  🌐 Web App        │  📡 API Backend   │  🏠 Simulator   │
│  (Port 3000)       │  (Port 8000)      │  (Internal)     │
├─────────────────────────────────────────────────────────┤
│              📡 MQTT Broker (Port 1883)                 │
└─────────────────────────────────────────────────────────┘
```

### 📦 Services

| Service | Container | Description | Ports |
|---------|-----------|-------------|-------|
| **mqtt-broker** | `eclipse-mosquitto:2.0` | MQTT message broker | 1883, 9001 |
| **device-simulator** | Custom Python | Multiple IoT device simulators | Internal |
| **api-backend** | Custom Python | FastAPI + All Agents | 8000 |
| **web-app** | Flutter Web | Mobile/Web interface | 3000 |

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB RAM available
- Ports 1883, 3000, 8000, 9001 available

### 1. Start the System
```bash
# Simple start
./deploy.sh start

# Or manually
docker-compose up -d
```

### 2. Verify Services
```bash
# Check service status
./deploy.sh status

# View real-time logs
./deploy.sh logs
```

### 3. Test the System
```bash
# Automated tests
./deploy.sh test

# Manual API test
curl "http://localhost:8000/goal/user123?goal=make it cozy"

# Open web interface
open http://localhost:3000
```

## 🔧 Configuration

### Environment Variables

Create or edit `.env` file:
```env
# MQTT Settings
MQTT_BROKER_HOST=mqtt-broker
MQTT_BROKER_PORT=1883

# API Settings
API_HOST=0.0.0.0
API_PORT=8000

# Device Simulation
SIMULATOR_DEVICES=light,thermostat,lock,media,sensor

# Logging
LOG_LEVEL=INFO
```

### Device Configuration

Edit `docker/simulators/devices.json`:
```json
{
  "light": [
    {
      "id": "living_room",
      "name": "Living Room Light",
      "initial_brightness": 80,
      "features": ["brightness", "color", "dimming"]
    }
  ]
}
```

### MQTT Configuration

Modify `docker/mosquitto/mosquitto.conf`:
```conf
# Custom MQTT settings
listener 1883 0.0.0.0
allow_anonymous true
persistence true
```

## 📱 Service Details

### 🌐 Web App Service
- **Image**: Custom Flutter build
- **Port**: 3000
- **Features**: 
  - "Make it Cozy" & "Save Energy" buttons
  - Real-time device state display (3s refresh)
  - Mobile-responsive Material 3 UI
- **Health Check**: HTTP GET to nginx

### 📡 API Backend Service  
- **Image**: Custom Python 3.12
- **Port**: 8000
- **Components**:
  - FastAPI REST API server
  - Planner Agent (goal processing)
  - Memory Agent (user preferences)
  - Scheduler Agent (task optimization)
  - Executor Agent (MQTT device commands)
  - Sensor Agent (MQTT state monitoring)
- **Health Check**: GET `/health`

### 🏠 Device Simulator Service
- **Image**: Custom Python 3.12
- **Devices Simulated**:
  - **Lights**: Living room, bedroom, kitchen, hallway
  - **Thermostats**: Main, bedroom
  - **Locks**: Front door, back door, garage
  - **Media**: TV, speakers, radio
  - **Sensors**: Motion, temperature, humidity, door/window
- **MQTT Topics**:
  - Commands: `home/<type>/<id>/set`
  - States: `home/<type>/<id>/state`

### 📡 MQTT Broker Service
- **Image**: `eclipse-mosquitto:2.0`
- **Ports**: 
  - 1883 (MQTT)
  - 9001 (WebSocket)
- **Features**:
  - Persistent message storage
  - Anonymous connections (dev mode)
  - WebSocket support for web clients

## 🔍 Monitoring & Debugging

### View Logs
```bash
# All services
./deploy.sh logs

# Specific service
docker-compose logs -f api-backend
docker-compose logs -f device-simulator
docker-compose logs -f mqtt-broker
```

### Service Health
```bash
# Check all containers
docker-compose ps

# Individual health checks
curl http://localhost:8000/health
docker-compose exec mqtt-broker mosquitto_pub -h localhost -t test -m "ping"
```

### MQTT Monitoring
```bash
# Subscribe to all device states
docker-compose exec mqtt-broker mosquitto_sub -h localhost -t "home/+/+/state"

# Monitor specific device
docker-compose exec mqtt-broker mosquitto_sub -h localhost -t "home/light/+/state"

# Send test command
docker-compose exec mqtt-broker mosquitto_pub -h localhost -t "home/light/living_room/set" -m '{"action":"turn_on","brightness":80}'
```

## 🚀 API Endpoints

Once deployed, access the API at `http://localhost:8000`:

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/docs` | GET | Interactive API documentation | Auto-generated |
| `/goal/{user_id}` | POST | Process natural language goals | `?goal=make it cozy` |
| `/state` | GET | Current device states | All device status |
| `/history` | GET | User interaction history | Past goal executions |
| `/health` | GET | Service health check | System status |

## 🔄 Development Workflow

### Code Changes
```bash
# Rebuild after code changes
docker-compose build --no-cache
docker-compose up -d

# Or specific service
docker-compose build api-backend
docker-compose up -d api-backend
```

### Adding New Devices
1. Edit `docker/simulators/devices.json`
2. Restart simulator: `docker-compose restart device-simulator`
3. Verify in logs: `docker-compose logs device-simulator`

### Configuration Updates
1. Modify `.env` file
2. Restart affected services: `docker-compose up -d`

## 🧪 Testing

### Automated Testing
```bash
# Full test suite
./deploy.sh test

# Expected output:
✅ API health check passed
✅ Goal endpoint test passed  
✅ State endpoint test passed
```

### Manual Testing
```bash
# 1. Set a goal
curl -X POST "http://localhost:8000/goal/testuser?goal=goodnight"

# 2. Check device states
curl "http://localhost:8000/state"

# 3. View execution history
curl "http://localhost:8000/history/testuser"

# 4. Test Flutter app
open http://localhost:3000
# Click "Make it Cozy" button
# Verify device list updates
```

## 🛠️ Troubleshooting

### Common Issues

**MQTT Connection Failed**
```bash
# Check MQTT broker status
docker-compose ps mqtt-broker
docker-compose logs mqtt-broker

# Test MQTT connectivity
docker-compose exec mqtt-broker mosquitto_pub -h localhost -t test -m "hello"
```

**API Backend Not Responding**
```bash
# Check backend logs
docker-compose logs api-backend

# Verify Python environment
docker-compose exec api-backend python -c "import fastapi; print('FastAPI OK')"
```

**Device Simulator Issues**
```bash
# Check simulator logs
docker-compose logs device-simulator

# Verify device configuration
docker-compose exec device-simulator cat /app/config/devices.json
```

**Web App Not Loading**
```bash
# Check web container
docker-compose ps web-app
docker-compose logs web-app

# Test API proxy
curl http://localhost:3000/api/health
```

### Performance Optimization

**Memory Usage**
```bash
# Monitor container resources
docker stats

# Reduce device simulation frequency
# Edit docker/simulators/devices.json - reduce polling intervals
```

**Network Issues**
```bash
# Check Docker network
docker network inspect homegenie_homegenie-net

# Reset network
docker-compose down
docker network prune
docker-compose up -d
```

## 📊 Production Deployment

### Security Enhancements
1. **Enable MQTT Authentication**:
   ```conf
   # docker/mosquitto/mosquitto.conf
   allow_anonymous false
   password_file /mosquitto/config/passwd
   ```

2. **Add API Authentication**:
   ```python
   # Set ENABLE_AUTHENTICATION=true in .env
   ```

3. **Use HTTPS**:
   ```yaml
   # Add SSL certificates and nginx proxy
   ```

### Scaling
```bash
# Scale device simulators
docker-compose up -d --scale device-simulator=3

# Use external MQTT broker
# Update MQTT_BROKER_HOST in .env
```

## 🔄 Cleanup

```bash
# Stop all services
./deploy.sh stop

# Complete cleanup (removes volumes)
./deploy.sh cleanup

# Or manually
docker-compose down -v --remove-orphans
```

## 📋 Commands Reference

| Command | Description |
|---------|-------------|
| `./deploy.sh start` | Build and start all services |
| `./deploy.sh stop` | Stop all services |
| `./deploy.sh restart` | Restart all services |
| `./deploy.sh status` | Show service status |
| `./deploy.sh logs` | View service logs |
| `./deploy.sh test` | Run deployment tests |
| `./deploy.sh cleanup` | Complete cleanup |

---

🏠✨ **HomeGenie Docker Deployment - Complete Smart Home in Containers!** ✨🏠