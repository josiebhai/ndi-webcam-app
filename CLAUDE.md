# NDI Webcam App

## What This Is

A native mobile app that turns an iPhone or Android phone into a professional NDI camera source, auto-discoverable by OBS, vMix, Wirecast, and any NDI-compatible software on the local network. Competes with NDI Camera (Vizrt) and VDO.Ninja.

Two fully independent native codebases — no shared runtime, no cross-platform framework:

| Platform | Language | Min OS | Camera API | NDI Integration |
|---|---|---|---|---|
| iOS | Swift 5.9 | iOS 14 | AVFoundation | libndi_ios.a static lib + headers (C bridge) |
| Android | Kotlin | API 26 (Android 8) | Camera2 | libndi.so via JNI (C++) |

Active PR: https://github.com/josiebhai/ndi-webcam-app/pull/3
Working branch: `claude/elegant-bell-v5i0nj`

---

## NDI SDK Setup (required before building)

The Vizrt NDI SDK is **free but not included** in this repo — it requires accepting their license agreement.

1. Download from https://ndi.video/for-developers/ndi-sdk/

2. **iOS** — run `Install_NDI_SDK_v6_Apple.pkg`, then copy from `/Library/NDI SDK for Apple/`:
   - `lib/iOS/libndi_ios.a` → `ios/Frameworks/libndi_ios.a`
   - entire `include/` folder → `ios/include/`

3. **Android** — extract `NDI 6 SDK (Android).exe` (use `7z x` on Mac), then copy:
   - `.aar` file → `android/app/libs/`
   - `.so` files per ABI → `android/app/src/main/jniLibs/arm64-v8a/`, `armeabi-v7a/`, `x86_64/`
   - Header files → `android/app/src/main/cpp/include/`

---

## Building

### iOS

Requires: Xcode 15+, a real device (NDI won't work on simulator), [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios
xcodegen generate          # produces NDIWebcam.xcodeproj from project.yml
open NDIWebcam.xcodeproj
```

Set your Apple Developer Team ID in `ios/project.yml` under `settings.base.DEVELOPMENT_TEAM` before building for device.

### Android

Requires: Android Studio Hedgehog (2023.1)+, NDK installed.

Open `android/` in Android Studio → Run. CMake builds the JNI bridge automatically via `app/src/main/cpp/CMakeLists.txt`.

---

## Architecture

### iOS Pipeline

```
AVCaptureSession
  ├── AVCaptureDeviceInput (camera)    ← addCameraInput() in CameraViewController
  ├── AVCaptureAudioDataOutput         ← delegate → NDIStreamer.sendAudioFrame()
  └── AVCaptureVideoDataOutput (BGRA)  ← delegate → NDIStreamer.sendVideoFrame()
                                                          ↓
                                              NDIlib_send_send_video_v2()
                                              NDIlib_send_send_audio_v3()
```

- Video pixel format: `kCVPixelFormatType_32BGRA` → `NDIlib_FourCC_type_BGRA`
- Audio format: float32, de-interleaved to planar (FLTP) before sending
- Background keep-alive: `AVAudioSession` category `.playAndRecord` + `UIBackgroundModes: audio` in Info.plist
- NDI send runs on a dedicated serial `DispatchQueue` in `NDIStreamer`

### Android Pipeline

```
Camera2 (CameraDevice / CameraCaptureSession)
  └── ImageReader (YUV_420_888)   ← onImageAvailable → CameraFragment.processFrame()
                                        ↓ YUV→UYVY conversion (inline byte loop)
                                   NDIStreamer.sendVideoFrame(ByteArray, UYVY)
                                        ↓
                                   nativeSendVideoFrame() JNI → NDIlib_send_send_video_v2()

AudioRecord (float32, stereo)
  └── coroutine loop → deinterleave → NDIStreamer.sendAudioFrame()
                                        ↓
                                   nativeSendAudioFrame() JNI → NDIlib_send_send_audio_v3()
```

- Background keep-alive: `StreamingService` (foreground service, type `camera|microphone`)
- Camera ops run on `HandlerThread("CameraBackground")`
- Audio capture runs on a `CoroutineScope(Dispatchers.IO)` coroutine

---

## iOS Source Map

| File | Responsibility |
|---|---|
| `ios/project.yml` | XcodeGen project spec — frameworks, permissions, build settings |
| `NDIWebcam/AppDelegate.swift` | App entry; configures `AVAudioSession` for background streaming |
| `NDIWebcam/SceneDelegate.swift` | Creates `UIWindow` with `CameraViewController` as root |
| `NDIWebcam/CameraViewController.swift` | Main screen: preview, tap-to-focus, camera switch, torch, stream start/stop, status timer, `ManualControlsDelegate` implementation |
| `NDIWebcam/NDIStreamer.swift` | Thread-safe NDI sender; wraps C `NDIlib_send_*` API; serial dispatch queue |
| `NDIWebcam/AudioManager.swift` | `AVAudioSession` input enumeration; Combine `@Published` device list; live route-change monitoring |
| `NDIWebcam/ManualControlsView.swift` | Sliding panel: EV, ISO, shutter, WB sliders + focus lock/auto buttons; `ManualControlsDelegate` protocol |
| `NDIWebcam/SettingsViewController.swift` | Grouped table: source name, resolution/fps/NDI-mode segments, mic picker, discovery server |
| `NDIWebcam/NDIWebcam-Bridging-Header.h` | Imports `NDIlib.h` from xcframework so Swift can call C NDI functions |

---

## Android Source Map

| File | Responsibility |
|---|---|
| `android/settings.gradle` | Project name, flatDir for local NDI AAR |
| `android/app/build.gradle` | Compile SDK 34, minSdk 26, CMake config, ABI filters, dependencies |
| `app/src/main/AndroidManifest.xml` | Permissions, foreground service declaration (`camera\|microphone` type) |
| `app/src/main/cpp/CMakeLists.txt` | Links `libndi.so` (imported); builds `libndiwebcam.so`; NDI headers from `include/` |
| `app/src/main/cpp/ndi_jni.cpp` | JNI bridge: `nativeInit`, `nativeSendVideoFrame` (UYVY), `nativeSendAudioFrame` (FLTP), `nativeGetReceiverCount`, `nativeDestroy` |
| `java/com/ndiwebcam/NDIStreamer.kt` | Kotlin wrapper; `System.loadLibrary("ndi")` + `"ndiwebcam"`; calls JNI externals |
| `java/com/ndiwebcam/MainActivity.kt` | Runtime permission handling (camera + mic); hosts `CameraFragment` |
| `java/com/ndiwebcam/CameraFragment.kt` | Camera2 session management; YUV→UYVY conversion; manual control methods; torch; stream start/stop |
| `java/com/ndiwebcam/NDIAudioManager.kt` | `AudioRecord` float32 capture; de-interleave to planar; `AudioDeviceInfo` routing |
| `java/com/ndiwebcam/StreamingService.kt` | Foreground service; ongoing notification with Stop action; keeps process alive when screen off |
| `java/com/ndiwebcam/ManualControlsFragment.kt` | Seekbars for EV, ISO (log scale 100–3200), shutter (log scale), WB preset buttons |
| `java/com/ndiwebcam/SettingsActivity.kt` | `PreferenceFragmentCompat`: source name, resolution, fps, NDI mode, audio device picker |

---

## Key Patterns

### Settings keys

**iOS** (`UserDefaults`):
- `sourceName` — NDI source name shown in OBS/vMix
- `resolution` — Int index: 0=720p, 1=1080p, 2=4K
- `fps` — Int index: 0=24, 1=30, 2=60
- `ndiMode` — Int index: 0=NDI|HX, 1=Full NDI
- `discoveryServer` — String IP (optional)

**Android** (`SharedPreferences`, key `"settings"`):
- Same key names as above; resolution stored as `"720"/"1080"/"2160"`, fps as `"24"/"30"/"60"`, ndiMode as `"HX"/"FULL"`

### NDI timecode
Both platforms pass `Int64(bitPattern: 0x8000000000000000)` (Swift) / `NDIlib_send_timecode_synthesize` (C++) as the timecode — this tells the SDK to synthesize timecodes automatically.

### Manual camera controls (iOS)
All camera device mutations go through `device.lockForConfiguration()` / `device.unlockForConfiguration()`. Shutter and ISO are set together via `setExposureModeCustom(duration:iso:)`.

### Manual camera controls (Android)
Manual controls set `CONTROL_AE_MODE_OFF` and write `SENSOR_SENSITIVITY` + `SENSOR_EXPOSURE_TIME` to the `CaptureRequest`. Auto mode restores `CONTROL_AE_MODE_ON`. Changes take effect on the next `setRepeatingRequest` call via `refreshCapture()`.

---

## Permissions

### iOS (`Info.plist` via `project.yml`)
- `NSCameraUsageDescription` — required for camera access
- `NSMicrophoneUsageDescription` — required for mic access
- `UIBackgroundModes: [audio]` — keeps session alive when screen locks

### Android (`AndroidManifest.xml`)
- `CAMERA`, `RECORD_AUDIO` — runtime permissions requested on launch
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`
- `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` — NDI network discovery
- `FLASHLIGHT`, `POST_NOTIFICATIONS`

---

## Network Requirements

- Phone and receiving PC must be on the **same Wi-Fi network** (or same switch)
- Router must allow **multicast / mDNS** — NDI uses this for auto-discovery
- NDI|HX streams at ~10–20 Mbps; Full NDI at ~100–200 Mbps — Wi-Fi must support this
- For cross-subnet setups: enter an NDI Discovery Server IP in Settings
