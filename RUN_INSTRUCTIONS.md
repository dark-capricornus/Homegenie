# 🚀 HomeGenie Complete Deployment Guide

## Quick Start (Recommended)

### Option 1: Backend + Frontend Separation (Recommended for Development)

#### Terminal 1: Start Backend Services
```bash
# Navigate to project directory
cd /home/harish/Desktop/Homegenie

# Run the backend startup script
./start_backend.sh

# OR manually:
docker compose up --build mqtt-broker device-simulator api-backend

# This will start:
# - MQTT Broker (port 1883, WebSocket: 9001)
# - Device Simulator (internal)
# - API Backend (port 8000)
```

#### Terminal 2: Start Flutter Frontend
```bash
# In a new terminal, start Flutter
./start_frontend.sh

# OR manually:
cd frontend
flutter run -d chrome --web-port 3000
# OR for mobile device:
flutter run -d [your-device-id]
# OR for hot reload development:
flutter run --hot
```

### Option 2: Full Docker Deployment (Production)
```bash
# 1. Navigate to project directory
cd /home/harish/Desktop/Homegenie

# 2. Activate virtual environment (if using one)
source env/bin/activate

# 3. Clean up any existing containers
docker compose down

# 4. Kill any processes using port 8000 (if needed)
sudo fuser -k 8000/tcp

# 5. Uncomment web-app service in docker-compose.yml, then:
docker compose up --build

# This will start:
# - MQTT Broker (port 1883, WebSocket: 9001)
# - Device Simulator (internal)
# - API Backend (port 8000)
# - Web App (port 3000) - if uncommented
```

### Option 2: Mobile App Development

#### Prerequisites for Mobile Development
```bash
# Install Flutter SDK (if not already installed)
# Download from: https://flutter.dev/docs/get-started/install

# Verify Flutter installation
flutter doctor

# For Android development, ensure you have:
# - Android Studio installed
# - Android SDK configured
# - USB debugging enabled on device OR Android emulator running

# For iOS development (macOS only):
# - Xcode installed
# - iOS Simulator OR physical iOS device connected
```

#### Build and Run Mobile App
```bash
# 1. Navigate to frontend directory  
cd /home/harish/Desktop/Homegenie/frontend

# 2. Get Flutter dependencies
flutter pub get

# 3. Check connected devices
flutter devices

# 4. For Android (choose one):
# Build APK for testing
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Run on connected Android device/emulator
flutter run

# 5. For iOS (macOS only):
# Build for iOS
flutter build ios --release

# Run on iOS device/simulator
flutter run

# 6. For development with hot reload
flutter run --hot
```

### Option 3: Manual Deployment (Step by Step)

#### Terminal 1: Start MQTT Broker
```bash
cd /home/harish/Desktop/Homegenie
docker compose up mqtt-broker
```

#### Terminal 2: Start Device Simulator  
```bash
cd /home/harish/Desktop/Homegenie
source env/bin/activate
python src/simulators/device_simulator.py
```

#### Terminal 3: Start API Backend
```bash
cd /home/harish/Desktop/Homegenie
source env/bin/activate
python docker/backend/api_runner.py
```

#### Terminal 4: Start Flutter Web App
```bash
cd /home/harish/Desktop/Homegenie/frontend
flutter run -d web-server --web-port 3000
```

### Option 4: Development Mode (Hot Reload)
```bash
# Terminal 1: Start backend services
cd /home/harish/Desktop/Homegenie
docker compose up mqtt-broker device-simulator api-backend

# Terminal 2: Start Flutter in development mode
cd frontend
flutter run -d web-server --web-port 3000 --hot
# OR for mobile development
flutter run --hot  # Connects to first available device
```

---

## 🌐 Access Your System

### Docker Deployment Access:
- **📱 Web App**: http://localhost:3000
- **📖 API Documentation**: http://localhost:8000/docs  
- **🔧 Alternative API Docs**: http://localhost:8000/redoc
- **🔌 MQTT Broker**: localhost:1883
- **🌐 MQTT WebSocket**: localhost:9001

### Mobile App Configuration:
For mobile apps to connect to your backend, you'll need to:

1. **Find your local IP address:**
```bash
# On Linux/macOS
ip addr show | grep "inet " | grep -v 127.0.0.1
# OR
ifconfig | grep "inet " | grep -v 127.0.0.1
```

2. **Update API base URL in mobile app:**
```bash
# Edit the Flutter app configuration
# Update API_BASE_URL from localhost to your actual IP
# Example: http://192.168.1.100:8000
```

3. **Test API connectivity from mobile:**
```bash
# From mobile device browser, visit:
# http://YOUR_IP:8000/docs
# Example: http://192.168.1.100:8000/docs
```

---

## 🛠️ Prerequisites Check

### Install Dependencies (if needed)
```bash
cd /home/harish/Desktop/Homegenie

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt

# Install Flutter dependencies
cd frontend
flutter pub get
cd ..
```

### System Requirements
- ✅ Docker & Docker Compose
- ✅ Python 3.12+
- ✅ Flutter SDK
- ✅ Web browser (Chrome/Firefox)

---

## 🎮 Using Your HomeGenie System

### Quick Actions (Web Dashboard)
- **🏠 Make it Cozy**: Dims lights, sets comfortable temperature
- **🌱 Save Energy**: Turns off unnecessary devices
- **🌙 Goodnight**: Locks doors, turns off lights, sets sleep mode

### Voice Commands (API)
```bash
# Test voice command via API
curl -X POST "http://localhost:8000/voice/command" \
  -H "Content-Type: application/json" \
  -d '{"text": "turn on living room lights"}'
```

### Manual Goals
```bash
# Send custom goals
curl -X POST "http://localhost:8000/goal/user123?goal=turn on kitchen lights"
```

### Device Control
- Click any device card to see details
- Use toggles to control lights, locks, media
- View real-time sensor data
- Auto-refresh every 2 seconds

---

## 🔧 Troubleshooting

### Docker Issues

#### If ports are already in use:
```bash
# Check what's using the ports
sudo netstat -tulpn | grep :8000
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :1883

# Kill processes using the ports
sudo fuser -k 8000/tcp
sudo fuser -k 3000/tcp
sudo fuser -k 1883/tcp
```

#### If Docker build fails with nginx.conf error:
```bash
# This should already be fixed, but if needed:
cp docker/frontend/nginx.conf frontend/nginx.conf
```

#### If Docker build takes too long:
```bash
# Stop current build
Ctrl+C

# Build only specific services
docker compose up mqtt-broker device-simulator api-backend
# Then run frontend manually
```

### Flutter Issues

#### If Flutter web fails to run:
```bash
cd frontend
flutter clean  
flutter pub get
flutter run -d web-server --web-port 3000
```

#### If mobile build fails:
```bash
# Check Flutter setup
flutter doctor

# For Android issues:




 # Accept licenses
flutter clean
flutter pub get

# For iOS issues (macOS only):
cd ios
pod install  # If CocoaPods issues
cd ..
flutter clean
flutter pub get
```

#### If devices don't appear in flutter devices:
```bash
# For Android:
adb devices  # Check USB debugging is enabled
adb kill-server && adb start-server  # Restart ADB

# For iOS:
# Ensure device is trusted and Xcode is properly configured
```

### System Issues

#### If devices don't appear in dashboard:
1. Check device simulator is running: `docker compose logs device-simulator`
2. Check API server logs: `docker compose logs api-backend`  
3. Verify MQTT broker: `docker compose logs mqtt-broker`
4. Test API directly: `curl http://localhost:8000/devices`

#### If mobile app can't connect to API:
1. Ensure backend is accessible from mobile device
2. Check firewall isn't blocking port 8000
3. Test from mobile browser: `http://YOUR_IP:8000/docs`
4. Update API base URL in Flutter app configuration

---

## 📊 System Status Monitoring

### Check API Health
```bash
curl http://localhost:8000/
```

### View Device States
```bash
curl http://localhost:8000/devices
```

### Monitor MQTT Messages
```bash
# Install mosquitto-clients
sudo apt install mosquitto-clients

# Subscribe to all topics
mosquitto_sub -h localhost -t "home/#"
```

---

## 🎯 Advanced Features

### Behavioral Learning
- System learns your usage patterns
- Get insights: `http://localhost:8000/learning/analytics/user123`
- View suggestions: `http://localhost:8000/learning/suggestions/user123`

### Voice Control
- Process voice commands through web interface
- Natural language understanding
- Command history tracking

### Real-time Updates
- Dashboard auto-refreshes every 2 seconds
- Live device state synchronization
- Instant feedback on actions

---

## 🐛 Logs & Debugging

### View API Server Logs
```bash
cd /home/harish/Desktop/Homegenie/src/api
python3 api_server.py
# Logs will appear in terminal
```

### View Device Simulator Logs
```bash
cd /home/harish/Desktop/Homegenie/src/simulators
python3 device_simulator.py
# Device updates will be logged
```

### Flutter Debug Mode
```bash
cd frontend
flutter run -d web --web-port 8080 --debug
```

---

## 🎉 Success Indicators

### Docker Deployment Success:
✅ **Web App** loads at http://localhost:3000  
✅ **Device cards** appear showing lights, thermostat, locks, etc.  
✅ **Status message** shows "Ready • Auto-refresh: 2s"  
✅ **Quick actions** (Make it Cozy, Save Energy, Goodnight) work  
✅ **Device toggles** respond and update states  
✅ **API docs** accessible at http://localhost:8000/docs  
✅ **No Docker errors** in terminal output

### Mobile App Success:
✅ **Flutter doctor** shows no critical issues  
✅ **flutter devices** lists your target device  
✅ **App installs** on device without errors  
✅ **API connection** works (can see devices)  
✅ **Device controls** respond from mobile app  
✅ **Hot reload** works during development

### System Health Check Commands:
```bash
# Check all Docker containers are running
docker compose ps

# Test API health
curl http://localhost:8000/health

# Test device data
curl http://localhost:8000/devices

# Check MQTT broker
docker compose logs mqtt-broker | tail -10

# Flutter app debug info
flutter run --verbose  # Shows detailed startup info
```  

---

## 🚀 What You've Built

Your HomeGenie system includes:

- **🏠 Smart Home Control**: Full device management
- **🎤 Voice Commands**: Natural language processing
- **🧠 AI Learning**: Behavioral pattern detection
- **📱 Modern UI**: Material 3 responsive design  
- **🔄 Real-time Updates**: Live synchronization
- **🐳 Docker Deployment**: Easy containerized setup
- **📡 MQTT Integration**: IoT device communication
- **📊 Analytics Dashboard**: Usage insights
- **🔧 REST API**: 16+ comprehensive endpoints

**Congratulations! You now have a complete AI-powered smart home system! 🎊**

---

## 📱 Mobile App Configuration

### Connecting Mobile App to Backend

The Flutter app needs to know where to find your HomeGenie API. By default, it may be configured for localhost, but mobile devices need your actual IP address.

#### Step 1: Find Your Server IP
```bash
# Find your local network IP
hostname -I | awk '{print $1}'
# OR
ip route get 1.1.1.1 | awk '{print $7; exit}'
```

#### Step 2: Update Flutter App Configuration
```bash
# Look for API configuration in Flutter app
cd frontend
grep -r "localhost\|127.0.0.1\|8000" lib/
# Update any hardcoded localhost references to your actual IP
```

#### Step 3: Test API Accessibility  
```bash
# From another device on your network, test:
curl http://YOUR_IP:8000/devices
# Example: curl http://192.168.1.100:8000/devices
```

#### Step 4: Build and Deploy Mobile App
```bash
cd frontend

# For development/testing
flutter run --release

# For production Android APK
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk

# For production iOS (macOS only)  
flutter build ios --release
```

### Mobile App Features

Your mobile app will have:
- 📱 **Native UI** - Material Design on Android, Cupertino on iOS
- 🔄 **Real-time sync** - Live device status updates  
- 🎤 **Voice commands** - Same AI voice processing as web
- 🏠 **Full device control** - All smart home features
- 📊 **Dashboard** - Complete system overview
- 🌙 **Quick actions** - One-tap scene control
- 📡 **Offline handling** - Graceful connection management

### Distribution Options

1. **Development Testing**: Install APK directly on Android devices
2. **Internal Testing**: Use Firebase App Distribution or TestFlight
3. **Public Release**: Google Play Store / Apple App Store
4. **Enterprise**: MDM deployment for business use

**Your HomeGenie system now works on web, mobile, and desktop! 🚀📱💻**