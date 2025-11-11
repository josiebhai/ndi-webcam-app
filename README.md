# NDI Webcam App

A cross-platform mobile application built with Flutter that enables your phone to function as a professional webcam, streaming video to your computer over NDI (Network Device Interface).

📖 **[Quick Start Guide](QUICKSTART.md)** | 🛠️ **[Development Guide](DEVELOPMENT.md)** | 🤝 **[Contributing](CONTRIBUTING.md)** | 📝 **[Changelog](CHANGELOG.md)**

## Features

### 📸 1. Camera Selection
- Choose between front and back cameras
- Support for wide-angle cameras
- Support for telephoto cameras
- Automatic detection of available camera types

### 🎨 2. Portrait/Bokeh Mode
- Option to enable portrait mode when available
- Creates professional-looking background blur effect

### 🎥 3. Streaming Quality Options
- **4K 30fps (Max Quality)** - Ultra-high definition for maximum detail
- **4K (Ultra High)** - High resolution streaming
- **1080p 60fps (Very High)** - Full HD with smooth motion
- **1080p 30fps (High)** - Standard Full HD quality
- **720p (Medium)** - Balanced quality and performance
- **480p (Low)** - Lower bandwidth option

### ✨ Additional Features
- 🔴 Real-time LIVE indicator while streaming
- 🎛️ Easy-to-use camera switching controls
- 📊 Multiple quality presets
- 🔐 Secure permission handling
- 📱 Cross-platform support (Android & iOS)

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio or Xcode (depending on target platform)
- Physical device (camera functionality requires actual hardware)

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

3. Run the app:
```bash
# For Android
flutter run

# For iOS
flutter run
```

## Permissions

The app requires the following permissions:
- **Camera**: To access device cameras
- **Microphone**: To capture audio for streaming
- **Internet**: To stream video over network (NDI)

These permissions will be requested when you first launch the app.

## Usage

1. **Launch the App**: Open the NDI Webcam app on your device
2. **Grant Permissions**: Allow camera and microphone access when prompted
3. **Select Camera**: Choose your preferred camera (front/back/wide/telephoto)
4. **Choose Quality**: Select the streaming quality based on your needs and network capability
5. **Start Streaming**: Tap the "Start Streaming" button to begin broadcasting
6. **Connect from Computer**: Use NDI-compatible software on your computer to receive the stream

## Architecture

```
lib/
  └── main.dart          # Main application entry and UI
android/
  └── app/
      └── src/main/      # Android-specific configuration
ios/
  └── Runner/            # iOS-specific configuration
```

## Technical Details

- **Framework**: Flutter
- **Camera Plugin**: camera ^0.10.5
- **Permissions**: permission_handler ^11.0.1
- **Minimum SDK**: Android 21+ / iOS 11+

## NDI Integration

This app provides the foundation for NDI streaming. The current implementation includes:
- Camera preview and controls
- Quality selection
- Multi-camera support

**Note**: Full NDI SDK integration requires platform-specific native code implementation, which would be added via Flutter platform channels in a production version.

## Future Enhancements

- [ ] Native NDI SDK integration
- [ ] Network discovery of NDI receivers
- [ ] Audio level monitoring
- [ ] Focus and exposure controls
- [ ] Video effects and filters
- [ ] Recording functionality
- [ ] Multi-device sync

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/josiebhai/ndi-webcam-app).