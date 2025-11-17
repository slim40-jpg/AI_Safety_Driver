# Quick Start: Flutter Integration

## Step-by-Step Implementation

### 1. Create a New Flutter Project

```bash
flutter create driver_drowsiness_app
cd driver_drowsiness_app
```

### 2. Add Dependencies to `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.0+5
  google_mlkit_face_detection: ^0.8.0
  google_mlkit_commons: ^0.3.0
  permission_handler: ^11.0.0
  vector_math: ^2.1.2  # For math calculations
```

Run: `flutter pub get`

### 3. Update Android Permissions

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" />
    <uses-feature android:name="android.hardware.camera.autofocus" />
    <!-- ... rest of manifest ... -->
</manifest>
```

### 4. Update iOS Permissions

**ios/Runner/Info.plist:**
```xml
<dict>
    <key>NSCameraUsageDescription</key>
    <string>Camera is required for drowsiness detection</string>
    <!-- ... rest of plist ... -->
</dict>
```

### 5. Create Utility Functions

**lib/utils/face_utils.dart:**
```dart
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceUtils {
  // Calculate Euclidean distance between two points
  static double euclideanDistance(Point p1, Point p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }
  
  // Calculate EAR (Eye Aspect Ratio) from ML Kit landmarks
  static double calculateEAR(List<Point> eyePoints) {
    if (eyePoints.length < 4) return 0.0;
    
    // ML Kit eye landmarks structure:
    // Assuming we get: leftCorner, rightCorner, top, bottom
    // Or we can use bounding box approach
    
    // Simplified: Use eye width and height
    final leftCorner = eyePoints[0];
    final rightCorner = eyePoints[1];
    final top = eyePoints[2];
    final bottom = eyePoints[3];
    
    // Vertical distance
    final vertical = euclideanDistance(top, bottom);
    // Horizontal distance
    final horizontal = euclideanDistance(leftCorner, rightCorner);
    
    if (horizontal == 0) return 0.0;
    return vertical / horizontal;
  }
  
  // Calculate MAR (Mouth Aspect Ratio) from ML Kit landmarks
  static double calculateMAR(List<Point> mouthPoints) {
    if (mouthPoints.length < 4) return 0.0;
    
    // Simplified MAR calculation
    final leftCorner = mouthPoints[0];
    final rightCorner = mouthPoints[1];
    final upper = mouthPoints[2];
    final lower = mouthPoints[3];
    
    // Vertical distance (mouth opening)
    final vertical = euclideanDistance(upper, lower);
    // Horizontal distance (mouth width)
    final horizontal = euclideanDistance(leftCorner, rightCorner);
    
    if (horizontal == 0) return 0.0;
    return vertical / horizontal;
  }
}
```

### 6. Create Main Detection Widget

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'drowsiness_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  MyApp({required this.cameras});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver Drowsiness Detection',
      theme: ThemeData.dark(),
      home: DrowsinessDetectionScreen(cameras: cameras),
    );
  }
}
```

### 7. Create Camera Screen

**lib/drowsiness_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'utils/face_utils.dart';

class DrowsinessDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  DrowsinessDetectionScreen({required this.cameras});
  
  @override
  _DrowsinessDetectionScreenState createState() => _DrowsinessDetectionScreenState();
}

class _DrowsinessDetectionScreenState extends State<DrowsinessDetectionScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: false,
    ),
  );
  
  bool _isInitialized = false;
  Map<String, dynamic> _detectionResults = {};
  
  // Thresholds (from Python code)
  static const double EYE_AR_THRESH = 0.25;
  static const double MOUTH_AR_THRESH = 0.79;
  static const int EYE_AR_CONSEC_FRAMES = 3;
  
  int _eyeClosedCounter = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      print('No cameras available');
      return;
    }
    
    _cameraController = CameraController(
      widget.cameras[0], // Use first camera (front camera if available)
      ResolutionPreset.medium,
      enableAudio: false,
    );
    
    try {
      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processImage);
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }
  
  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        setState(() => _detectionResults = {});
        return;
      }
      
      final face = faces.first;
      _processFaceDetection(face);
    } catch (e) {
      print('Error processing image: $e');
    }
  }
  
  void _processFaceDetection(Face face) {
    // Extract landmarks
    final landmarks = face.landmarks;
    
    if (landmarks == null) return;
    
    // Get eye landmarks (simplified - using bounding box approach)
    final leftEye = landmarks[FaceLandmarkType.leftEye];
    final rightEye = landmarks[FaceLandmarkType.rightEye];
    
    // Get mouth landmarks
    final mouth = landmarks[FaceLandmarkType.mouthBottom];
    
    // Calculate metrics
    double? ear, mar;
    
    // Simplified EAR calculation from eye bounding boxes
    if (leftEye != null && rightEye != null) {
      final leftEyePoints = _extractEyePoints(leftEye);
      final rightEyePoints = _extractEyePoints(rightEye);
      
      final leftEAR = FaceUtils.calculateEAR(leftEyePoints);
      final rightEAR = FaceUtils.calculateEAR(rightEyePoints);
      ear = (leftEAR + rightEAR) / 2.0;
      
      // Check if eyes are closed
      if (ear < EYE_AR_THRESH) {
        _eyeClosedCounter++;
      } else {
        _eyeClosedCounter = 0;
      }
    }
    
    // Calculate MAR if mouth landmarks available
    if (mouth != null && landmarks[FaceLandmarkType.upperLipTop] != null) {
      final mouthPoints = _extractMouthPoints(landmarks);
      mar = FaceUtils.calculateMAR(mouthPoints);
    }
    
    // Get head tilt from face rotation
    final headTilt = face.headEulerAngleY;
    
    setState(() {
      _detectionResults = {
        'ear': ear,
        'mar': mar,
        'headTilt': headTilt,
        'eyesOpen': _eyeClosedCounter < EYE_AR_CONSEC_FRAMES,
        'yawning': mar != null && mar > MOUTH_AR_THRESH,
        'headTilted': headTilt != null && headTilt.abs() > 10.0,
      };
    });
    
    // Trigger alert if drowsy
    if (_isDrowsy()) {
      _triggerAlert();
    }
  }
  
  bool _isDrowsy() {
    return (!(_detectionResults['eyesOpen'] ?? true) ||
            (_detectionResults['yawning'] ?? false) ||
            (_detectionResults['headTilted'] ?? false));
  }
  
  void _triggerAlert() {
    // Vibrate, play sound, show notification, etc.
    // This is just a visual indicator for now
  }
  
  List<Point> _extractEyePoints(FaceLandmark eye) {
    // Extract eye corner points from ML Kit landmark
    // This is a simplified version - adjust based on actual ML Kit structure
    return eye.positions.map((p) => p.position).toList();
  }
  
  List<Point> _extractMouthPoints(Map<FaceLandmarkType, FaceLandmark> landmarks) {
    // Extract mouth corner and lip points
    final mouthLeft = landmarks[FaceLandmarkType.mouthLeft];
    final mouthRight = landmarks[FaceLandmarkType.mouthRight];
    final upperLip = landmarks[FaceLandmarkType.upperLipTop];
    final lowerLip = landmarks[FaceLandmarkType.lowerLipBottom];
    
    return [
      mouthLeft?.positions.first.position ?? Point(0, 0),
      mouthRight?.positions.first.position ?? Point(0, 0),
      upperLip?.positions.first.position ?? Point(0, 0),
      lowerLip?.positions.first.position ?? Point(0, 0),
    ];
  }
  
  InputImage _inputImageFromCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          _buildOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildOverlay() {
    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusText('Eyes', _detectionResults['eyesOpen'] ?? true),
            if (_detectionResults['ear'] != null)
              _buildMetricText('EAR', _detectionResults['ear'], 0.25, true),
            if (_detectionResults['mar'] != null)
              _buildMetricText('MAR', _detectionResults['mar'], 0.79, false),
            if (_detectionResults['headTilt'] != null)
              _buildMetricText('Head Tilt', 
                _detectionResults['headTilt'].abs(), 10.0, true),
            if (_isDrowsy())
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ DROWSY!',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusText(String label, bool isGood) {
    return Text(
      '$label: ${isGood ? "Open/Good" : "Closed/Alert"}',
      style: TextStyle(
        color: isGood ? Colors.green : Colors.red,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildMetricText(String label, double value, double threshold, bool lowerIsBetter) {
    final isGood = lowerIsBetter 
        ? value < threshold 
        : value < threshold;
    
    return Text(
      '$label: ${value.toStringAsFixed(2)}',
      style: TextStyle(
        color: isGood ? Colors.green : Colors.red,
        fontSize: 14,
      ),
    );
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}
```

### 8. Run the App

```bash
flutter run
```

## Testing Tips

1. **Start Simple**: Test with one metric (e.g., eye closure) first
2. **Adjust Thresholds**: The thresholds may need tuning for your use case
3. **Performance**: Process every 3rd frame to improve performance
4. **Lighting**: Test in different lighting conditions
5. **Device Testing**: Test on actual devices, not just emulator

## Troubleshooting

- **Camera not working**: Check permissions in AndroidManifest.xml and Info.plist
- **Face detection not working**: Ensure ML Kit is properly initialized
- **Poor performance**: Reduce resolution or process fewer frames
- **Inaccurate detection**: Tune thresholds based on your test results

## Next Steps

1. Add vibration/audio alerts for drowsiness
2. Log drowsiness events
3. Add calibration feature
4. Implement data persistence
5. Add user settings for thresholds


