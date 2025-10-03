#!/bin/bash

echo "🚀 Starting HomeGenie Backend Services..."
echo "This will start: MQTT Broker + Device Simulator + API Backend"
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Clean up any existing containers
echo "🧹 Cleaning up existing containers..."
docker compose down

# Kill any processes using port 8000
echo "🔧 Freeing up port 8000..."
sudo fuser -k 8000/tcp 2>/dev/null || true

# Start only backend services
echo "🐳 Starting backend services with Docker..."
docker compose up --build mqtt-broker device-simulator api-backend

echo "✅ Backend services should be running on:"
echo "   📡 MQTT Broker: localhost:1883"
echo "   🌐 API Backend: localhost:8000"
echo "   🏠 Device Simulator: internal"
echo ""
echo "🔗 Test API: curl http://localhost:8000/devices"
echo "📖 API Docs: http://localhost:8000/docs"