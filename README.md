# NDI Webcam App

Turn your iPhone or Android phone into a professional NDI camera source, discoverable by OBS, vMix, Wirecast, and any other NDI-compatible software on your local network.

## Features

- NDI and NDI|HX output (Wi-Fi-optimised compressed stream)
- Front / back camera switching with live preview
- Manual camera controls: exposure, white balance, ISO, shutter speed, focus lock
- External microphone selection (USB-C, Lightning, Bluetooth)
- Background streaming (screen can be locked while streaming)
- Torch / fill light toggle
- Configurable source name, resolution (720p / 1080p / 4K), frame rate (30 / 60 fps)
- Live connection status: receiver count and latency

## Tech Stack

| Platform | Language | Camera API | NDI SDK |
|---|---|---|---|
| iOS 14+ | Swift 5 | AVFoundation | Vizrt NDI SDK (xcframework) |
| Android 8+ | Kotlin | Camera2 | Vizrt NDI SDK (AAR + .so) |

## Prerequisites

### NDI SDK (required — not included in repo)

The NDI SDK is free but requires accepting Vizrt's license agreement.

1. Register and download at: https://ndi.video/for-developers/ndi-sdk/
2. **iOS**: Copy `NDIlib.xcframework` into `ios/Frameworks/`
3. **Android**: Copy the NDI `.aar` file into `android/app/libs/` and `.so` libraries into `android/app/src/main/jniLibs/<ABI>/`

### iOS

- Xcode 15+
- iOS 14+ device (NDI streaming requires a real device, not simulator)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Android

- Android Studio Hedgehog (2023.1) or newer
- Android device with API 26+ (Android 8.0)

## Building

### iOS

```bash
cd ios
xcodegen generate        # creates NDIWebcam.xcodeproj from project.yml
open NDIWebcam.xcodeproj
```

Select your device and hit Run (⌘R).

### Android

Open `android/` in Android Studio and click Run.

## Project Structure

```
ndi-webcam-app/
├── ios/
│   ├── project.yml                          # XcodeGen spec
│   ├── Frameworks/
│   │   └── NDIlib.xcframework               # ← place Vizrt SDK here
│   └── NDIWebcam/
│       ├── AppDelegate.swift
│       ├── CameraViewController.swift       # main screen
│       ├── NDIStreamer.swift                 # NDI send wrapper
│       ├── AudioManager.swift               # mic selection
│       ├── ManualControlsView.swift         # camera controls panel
│       ├── SettingsViewController.swift
│       └── NDIWebcam-Bridging-Header.h
│
└── android/
    ├── app/
    │   ├── build.gradle
    │   ├── libs/                            # ← place NDI .aar here
    │   └── src/main/
    │       ├── AndroidManifest.xml
    │       ├── cpp/
    │       │   ├── CMakeLists.txt
    │       │   └── ndi_jni.cpp              # JNI bridge to NDI C API
    │       └── java/com/ndiwebcam/
    │           ├── MainActivity.kt
    │           ├── CameraFragment.kt
    │           ├── NDIStreamer.kt
    │           ├── NDIAudioManager.kt
    │           ├── StreamingService.kt
    │           ├── ManualControlsFragment.kt
    │           └── SettingsActivity.kt
    ├── build.gradle
    └── settings.gradle
```

## Network Requirements

Both the phone and the receiving computer must be on the **same Wi-Fi network** (or wired to the same router). NDI uses mDNS for discovery — ensure multicast is enabled on your router/switch.

For cross-subnet operation, configure an NDI Discovery Server address in the app settings.

## License

This project is licensed under the MIT License. The NDI SDK is subject to Vizrt's separate license agreement.
