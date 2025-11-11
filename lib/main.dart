import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get available cameras
  final cameras = await availableCameras();
  
  runApp(NDIWebcamApp(cameras: cameras));
}

class NDIWebcamApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const NDIWebcamApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NDI Webcam',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  ResolutionPreset _selectedQuality = ResolutionPreset.high;
  bool _isStreaming = false;
  bool _permissionGranted = false;

  final Map<ResolutionPreset, String> _qualityOptions = {
    ResolutionPreset.max: '4K 30fps (Max Quality)',
    ResolutionPreset.ultraHigh: '4K (Ultra High)',
    ResolutionPreset.veryHigh: '1080p 60fps (Very High)',
    ResolutionPreset.high: '1080p 30fps (High)',
    ResolutionPreset.medium: '720p (Medium)',
    ResolutionPreset.low: '480p (Low)',
  };

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    setState(() {
      _permissionGranted = status.isGranted;
    });
    
    if (_permissionGranted && widget.cameras.isNotEmpty) {
      _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final camera = widget.cameras[cameraIndex];
    _controller = CameraController(
      camera,
      _selectedQuality,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  String _getCameraLabel(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return 'Front Camera';
      case CameraLensDirection.back:
        return 'Back Camera';
      case CameraLensDirection.external:
        return 'External Camera';
    }
  }

  String _getCameraType(CameraDescription camera) {
    // Attempt to identify camera type from name
    final name = camera.name.toLowerCase();
    if (name.contains('wide')) {
      return ' (Wide)';
    } else if (name.contains('telephoto') || name.contains('tele')) {
      return ' (Telephoto)';
    } else if (name.contains('ultra')) {
      return ' (Ultra Wide)';
    }
    return '';
  }

  void _toggleStreaming() {
    setState(() {
      _isStreaming = !_isStreaming;
    });
    
    if (_isStreaming) {
      // In a real implementation, this would start NDI streaming
      // For now, we just toggle the state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NDI Streaming Started'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NDI Streaming Stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NDI Webcam'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Camera permission is required',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.cameras.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NDI Webcam'),
        ),
        body: const Center(
          child: Text('No cameras available'),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NDI Webcam'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NDI Webcam'),
        actions: [
          IconButton(
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleStreaming,
            tooltip: _isStreaming ? 'Stop Streaming' : 'Start Streaming',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  children: [
                    CameraPreview(_controller!),
                    if (_isStreaming)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera Selection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.cameras.length,
                    itemBuilder: (context, index) {
                      final camera = widget.cameras[index];
                      final isSelected = index == _selectedCameraIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            _getCameraLabel(camera) + _getCameraType(camera),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected && !_isStreaming) {
                              setState(() {
                                _selectedCameraIndex = index;
                              });
                              _initializeCamera(index);
                            } else if (_isStreaming) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Stop streaming before changing camera',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Streaming Quality',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<ResolutionPreset>(
                  value: _selectedQuality,
                  isExpanded: true,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  items: _qualityOptions.entries.map((entry) {
                    return DropdownMenuItem<ResolutionPreset>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: _isStreaming
                      ? null
                      : (ResolutionPreset? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedQuality = newValue;
                            });
                            _initializeCamera(_selectedCameraIndex);
                          }
                        },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleStreaming,
                    icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isStreaming ? 'Stop Streaming' : 'Start Streaming',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isStreaming ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
