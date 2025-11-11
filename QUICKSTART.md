# Quick Start Guide - NDI Webcam App

Get up and running with the NDI Webcam App in minutes!

## Prerequisites

- Flutter SDK installed ([Get Flutter](https://flutter.dev/docs/get-started/install))
- Android Studio or Xcode (depending on your target platform)
- A physical mobile device (camera functionality requires real hardware)

## Installation

### Step 1: Get the Code

```bash
git clone https://github.com/josiebhai/ndi-webcam-app.git
cd ndi-webcam-app
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Connect Your Device

**Android:**
1. Enable Developer Options on your phone
2. Enable USB Debugging
3. Connect via USB cable
4. Allow USB debugging when prompted

**iOS:**
1. Connect iPhone via USB cable
2. Trust the computer when prompted

### Step 4: Run the App

```bash
flutter run
```

## First Use

### 1. Grant Permissions

When you first open the app, it will request:
- **Camera permission** - Required to access your device cameras
- **Microphone permission** - Required for audio streaming

Tap "Grant Permission" or "Allow" to enable these features.

### 2. Select Your Camera

Choose from available cameras:
- 📱 **Front Camera** - For face-to-face calls
- 📷 **Back Camera** - For showing your environment  
- 🔭 **Wide Camera** - For wider field of view (if available)
- 🔎 **Telephoto** - For zoomed shots (if available)

Tap on any camera chip to switch.

### 3. Choose Quality

Select streaming quality from the dropdown:

| Quality | Resolution | Use Case |
|---------|-----------|----------|
| 4K 30fps | 3840x2160 | Maximum detail, requires fast connection |
| 1080p 60fps | 1920x1080 | Smooth motion, good detail |
| 1080p 30fps | 1920x1080 | Balanced quality (recommended) |
| 720p | 1280x720 | Good quality, lower bandwidth |
| 480p | 854x480 | Low bandwidth situations |

### 4. Start Streaming

1. Tap the **"Start Streaming"** button (green)
2. You'll see a red **"LIVE"** indicator appear
3. The app is now streaming over NDI

### 5. Connect from Computer

On your computer:
1. Open NDI-compatible software (OBS Studio, vMix, etc.)
2. Look for "NDI Webcam" in available sources
3. Select it to see your phone's camera feed

### 6. Stop Streaming

When finished:
1. Tap the **"Stop Streaming"** button (red)
2. The LIVE indicator will disappear
3. Camera stays active for preview

## Tips & Tricks

### Battery Saving
- Use lower quality settings for longer battery life
- Connect to charger for extended sessions
- Close other apps to free up resources

### Best Quality
- Use 4K or 1080p 60fps settings
- Ensure good lighting
- Keep phone stable (use tripod/mount)
- Connect to strong WiFi network

### Troubleshooting

**Camera not working?**
- Check permissions in phone settings
- Restart the app
- Make sure no other app is using the camera

**Can't see stream on computer?**
- Ensure phone and computer are on same network
- Check firewall settings
- Restart NDI receiving software

**App crashes?**
- Update to latest version
- Clear app data and restart
- Report bug on GitHub

## Keyboard Shortcuts (Coming Soon)

| Action | Android | iOS |
|--------|---------|-----|
| Start/Stop Stream | - | - |
| Switch Camera | - | - |
| Change Quality | - | - |

## Common Workflows

### Video Calls
1. Use **Front Camera**
2. Select **1080p 30fps** quality
3. Position phone at eye level
4. Ensure good lighting on face

### Presentations
1. Use **Back Camera**
2. Select **1080p 60fps** for smooth motion
3. Mount phone overhead or at angle
4. Show documents, products, demos

### Content Creation
1. Use **4K 30fps** for maximum quality
2. Test lighting and framing
3. Use **Back Camera** with telephoto if available
4. Record or stream to your platform

## Next Steps

- Read the full [README.md](README.md) for detailed features
- Check [DEVELOPMENT.md](DEVELOPMENT.md) for technical details
- Review [CONTRIBUTING.md](CONTRIBUTING.md) to help improve the app
- Report issues on [GitHub Issues](https://github.com/josiebhai/ndi-webcam-app/issues)

## Need Help?

- 📖 Check the documentation
- 🐛 Search existing issues
- 💬 Ask in GitHub Discussions
- 📧 Contact maintainers

Happy streaming! 📹✨
