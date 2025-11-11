# NDI Webcam App - Development Guide

## Project Overview

This Flutter application transforms your mobile device into a professional webcam that can stream video over NDI (Network Device Interface). The app is designed to be cross-platform, supporting both Android and iOS devices.

## Features

### Implemented Features

1. **Multi-Camera Support**
   - Front camera
   - Back camera
   - Wide-angle camera (when available)
   - Telephoto camera (when available)
   - Automatic detection of available cameras

2. **Streaming Quality Presets**
   - 4K 30fps (Max Quality) - Ultra-high definition
   - 4K (Ultra High) - High resolution
   - 1080p 60fps (Very High) - Full HD with smooth motion
   - 1080p 30fps (High) - Standard Full HD
   - 720p (Medium) - Balanced quality
   - 480p (Low) - Lower bandwidth

3. **User Interface**
   - Real-time camera preview
   - Horizontal scrollable camera selector
   - Dropdown quality selector
   - Visual streaming indicator (LIVE badge)
   - Start/Stop streaming button
   - Permission request handling

4. **Permissions**
   - Camera access
   - Microphone access
   - Network access for NDI streaming

### Architecture

```
lib/
  ├── main.dart          # Main application entry and UI
  └── ndi_service.dart   # NDI streaming service layer

android/
  ├── app/
  │   ├── build.gradle
  │   └── src/main/
  │       ├── AndroidManifest.xml
  │       └── kotlin/
  └── build.gradle

ios/
  └── Runner/
      ├── Info.plist
      └── AppDelegate.swift
```

## Development Setup

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   ```bash
   flutter --version
   ```

2. **Android Studio** (for Android development)
   - Android SDK
   - Android Emulator or physical device

3. **Xcode** (for iOS development, macOS only)
   - iOS Simulator or physical device

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/josiebhai/ndi-webcam-app.git
   cd ndi-webcam-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Check for any issues:
   ```bash
   flutter doctor
   ```

### Running the App

#### Android
```bash
# List available devices
flutter devices

# Run on connected device
flutter run

# Run on specific device
flutter run -d <device-id>

# Build APK
flutter build apk --release
```

#### iOS
```bash
# Run on iOS simulator
flutter run

# Run on connected iPhone
flutter run -d <device-id>

# Build for iOS
flutter build ios --release
```

## Code Structure

### Main Application (main.dart)

The main application consists of three primary components:

1. **NDIWebcamApp**: Root MaterialApp widget
2. **CameraScreen**: Stateful widget managing the camera screen
3. **_CameraScreenState**: State management for camera and streaming

Key methods:
- `_requestPermissions()`: Handles camera permission requests
- `_initializeCamera(int cameraIndex)`: Initializes camera controller
- `_toggleStreaming()`: Starts/stops NDI streaming
- `_getCameraLabel()`: Generates camera labels
- `_getCameraType()`: Identifies camera types

### NDI Service (ndi_service.dart)

The NDI service provides an abstraction layer for streaming functionality:

```dart
class NDIService {
  // Initialize streaming
  Future<bool> initialize({...})
  
  // Start streaming
  Future<bool> startStreaming()
  
  // Stop streaming
  Future<void> stopStreaming()
  
  // Update quality
  Future<bool> updateQuality(ResolutionPreset quality)
  
  // Get statistics
  Map<String, dynamic> getStreamStats()
}
```

## Future Enhancements

### NDI SDK Integration

To integrate actual NDI streaming functionality:

1. **Add NDI SDK Dependencies**
   - Include NDI SDK for Android and iOS
   - Set up platform channels in Flutter

2. **Implement Platform Channels**
   ```dart
   // Create method channel
   static const platform = MethodChannel('com.example.ndi/stream');
   
   // Invoke native methods
   await platform.invokeMethod('startStream', {
     'streamName': 'My Webcam',
     'quality': 'high',
   });
   ```

3. **Native Android Implementation** (Kotlin)
   ```kotlin
   // In MainActivity.kt
   private val CHANNEL = "com.example.ndi/stream"
   
   override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
     MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
       .setMethodCallHandler { call, result ->
         when (call.method) {
           "startStream" -> {
             // Initialize NDI SDK
             // Start streaming
           }
         }
       }
   }
   ```

4. **Native iOS Implementation** (Swift)
   ```swift
   // In AppDelegate.swift
   let channel = FlutterMethodChannel(
     name: "com.example.ndi/stream",
     binaryMessenger: controller.binaryMessenger
   )
   
   channel.setMethodCallHandler({ [weak self] call, result in
     switch call.method {
     case "startStream":
       // Initialize NDI SDK
       // Start streaming
     }
   })
   ```

### Additional Features

- [ ] Portrait/Bokeh mode implementation
- [ ] Manual focus controls
- [ ] Exposure adjustment
- [ ] White balance settings
- [ ] Audio level monitoring
- [ ] Network device discovery
- [ ] Recording functionality
- [ ] Video effects/filters
- [ ] Stream statistics display
- [ ] Settings persistence
- [ ] Dark mode support

## Testing

### Unit Tests

Create tests in the `test/` directory:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ndi_webcam_app/ndi_service.dart';

void main() {
  test('NDI Service initialization', () async {
    final service = NDIService();
    expect(service.isStreaming, false);
  });
}
```

Run tests:
```bash
flutter test
```

### Integration Tests

Test on real devices:
1. Connect physical device
2. Run app: `flutter run`
3. Test all features:
   - Camera switching
   - Quality changes
   - Stream start/stop
   - Permission handling

## Troubleshooting

### Common Issues

1. **Camera Permission Denied**
   - Check AndroidManifest.xml and Info.plist
   - Ensure permissions are requested at runtime

2. **Camera Not Available**
   - Test on physical device (emulators may have limited camera support)
   - Check device compatibility

3. **Build Errors**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Check Flutter and SDK versions

4. **Gradle Issues** (Android)
   - Update gradle version
   - Sync project with gradle files
   - Clear gradle cache

## Contributing

When contributing to this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on both platforms
5. Submit a pull request

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Camera Plugin](https://pub.dev/packages/camera)
- [NDI SDK](https://ndi.video/for-developers/)
- [Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels)

## License

This project is open source and available under the MIT License.
