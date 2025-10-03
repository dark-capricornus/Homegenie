#!/bin/bash

# HomeGenie Flutter App Runner
echo "🚀 Starting HomeGenie Flutter App..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter SDK first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Navigate to frontend directory
cd "$(dirname "$0")"

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully!"
    echo ""
    echo "🎯 Available commands:"
    echo "  flutter run              # Run on connected device"
    echo "  flutter run -d chrome    # Run in Chrome browser"
    echo "  flutter test             # Run unit tests"
    echo "  flutter build apk        # Build Android APK"
    echo ""
    echo "🏠 Make sure HomeGenie API server is running on localhost:8000"
    echo "   In the main project: python main.py api"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi