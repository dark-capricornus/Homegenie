#!/bin/bash

echo "📱 Starting HomeGenie Flutter App..."
echo "Make sure backend services are running first!"
echo ""

# Navigate to frontend directory
cd "$(dirname "$0")/frontend"

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Make sure you're in the right directory."
    exit 1
fi

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check available devices
echo "📱 Available devices:"
flutter devices

echo ""
echo "🚀 Choose how to run:"
echo "1. Web (Chrome): flutter run -d chrome"
echo "2. Android device: flutter run -d [device-id]"
echo "3. Hot reload mode: flutter run --hot"
echo ""
echo "Starting in web mode..."
flutter run -d chrome --web-port 3000