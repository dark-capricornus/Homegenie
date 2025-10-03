# 📱 HomeGenie Flutter App

A beautiful Flutter mobile app for controlling the HomeGenie Smart Home Automation System.

## ✨ Features

- **🎯 Quick Actions**: Two main buttons for common home scenarios
  - **"Make it Cozy"** - Creates a comfortable home environment
  - **"Save Energy"** - Optimizes devices for energy efficiency

- **📱 Real-time Device Monitoring**: 
  - Auto-refreshes device states every 3 seconds
  - Beautiful list view of all connected devices
  - Smart device icons and status indicators

- **🔄 Live Updates**: 
  - Real-time status messages
  - Loading indicators during API calls
  - Automatic state refresh after goal execution

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- HomeGenie API server running on `localhost:8000`

### Installation

1. **Install dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Run the app**:
   ```bash
   flutter run
   ```

3. **For web deployment**:
   ```bash
   flutter run -d chrome
   ```

## 🏗️ API Integration

The app integrates with the HomeGenie API server with these endpoints:

### Goal Execution
```http
POST /goal/user123?goal=make it cozy
POST /goal/user123?goal=save energy
```

### Device State Monitoring
```http
GET /state
```
- Auto-refreshes every 3 seconds
- Displays all device states in a scrollable list

## 📱 Screenshots & UI Features

### Main Screen Components:
- **Header**: HomeGenie Control title with home icon
- **Quick Actions Card**: Two prominent action buttons
- **Status Bar**: Shows current operation status and timestamps
- **Device List**: Scrollable list of all connected devices
- **Refresh FAB**: Manual refresh floating action button

### Device Display Features:
- **Smart Icons**: Different icons for lights, thermostats, locks, sensors
- **Formatted Names**: Clean device names from API paths
- **Status Indicators**: Color-coded status dots (green/red/grey)
- **Device Details**: Shows all device properties except timestamps

## 🎨 Design System

- **Material 3 Design**: Modern Flutter UI components
- **Color Scheme**: Deep purple primary with semantic colors
- **Responsive Layout**: Works on phones and tablets
- **Accessibility**: Proper contrast and touch targets

## 🔧 Configuration

### API Endpoint Configuration
Edit the base URL in `lib/main.dart`:
```dart
static const String baseUrl = 'http://localhost:8000';
static const String userId = 'user123';
```

### Refresh Interval
Modify the auto-refresh timer in `_startAutoRefresh()`:
```dart
Timer.periodic(const Duration(seconds: 3), (timer) {
  _fetchDeviceStates();
});
```

## 🧪 Testing

### Run Unit Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter test integration_test/
```

## 📦 Dependencies

- **flutter**: Core Flutter framework
- **http**: HTTP client for API requests
- **cupertino_icons**: iOS-style icons

## 🚀 Building for Production

### Android APK
```bash
flutter build apk --release
```

### iOS IPA
```bash
flutter build ios --release
```

### Web
```bash
flutter build web
```

## 🔄 App State Management

The app uses simple StatefulWidget state management with:
- **Device States**: Map of all device data from API
- **Loading States**: Boolean flags for UI feedback
- **Status Messages**: User-friendly status updates
- **Auto-refresh**: Timer-based periodic updates

## 🛠️ Development

### Project Structure
```
frontend/
├── lib/
│   └── main.dart              # Main app code
├── test/
│   └── widget_test.dart       # Unit tests
├── integration_test/
│   └── app_test.dart          # Integration tests
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

### Key Classes
- **HomeGenieApp**: Main app widget
- **HomeControlScreen**: Main screen with all functionality
- **_HomeControlScreenState**: State management for the main screen

---

**HomeGenie Flutter App** - Control your smart home with style! 🏠✨