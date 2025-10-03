#!/bin/bash

# HomeGenie Flutter Web Demo
echo "🚀 Starting HomeGenie Flutter Web App Demo..."
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter SDK first."
    echo "   Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Navigate to frontend directory
cd "$(dirname "$0")"

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo ""
echo "🌐 Starting web server..."
echo "📱 HomeGenie Flutter App will open at: http://localhost:8080"
echo ""
echo "💡 Usage Instructions:"
echo "   1. Make sure HomeGenie API is running: python ../main.py api"
echo "   2. Click 'Make it Cozy' or 'Save Energy' buttons"
echo "   3. Watch device states update automatically every 3 seconds"
echo ""
echo "🛑 Press Ctrl+C to stop the web server"
echo ""

# Run Flutter web app
flutter run -d chrome --web-port=8080