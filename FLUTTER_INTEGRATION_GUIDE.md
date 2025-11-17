# Flutter Integration Guide for Driver Drowsiness Detection

This guide explains how to integrate the Python-based drowsiness detection model into your Flutter mobile application.

## Overview

The current Python implementation uses:
- **dlib** for face detection and 68 facial landmarks
- **OpenCV** for image processing
- **Computer Vision algorithms** for EAR, MAR, and Head Tilt calculations

## Integration Approaches

### Option 1: Flutter Native Implementation (Recommended)
Use Flutter packages for face detection and implement calculation logic in Dart.

**Advantages:**
- No Python dependency
- Better performance on mobile
- Easier deployment
- Real-time processing

**Required Packages:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.0+5        # Camera access
  google_mlkit_face_detection: ^0.8.0  # Face detection & landmarks
  google_mlkit_commons: ^0.3.0
  path_provider: ^2.1.0    # For storing face model files
  permission_handler: ^11.0.0  # Camera permissions
```

### Option 2: TensorFlow Lite (Alternative)
Convert models to TFLite and use `tflite_flutter`.

**Advantages:**
- More control over models
- Potential for offline inference

**Disadvantages:**
- Requires model conversion
- More complex setup

### Option 3: Backend API (For Complex Processing)
Keep Python backend and communicate via REST API.

**Advantages:**
- Keep existing Python code
- Easy to update models

**Disadvantages:**
- Requires internet connection
- Latency concerns
- Server costs

---

## Recommended Implementation (Option 1)

### Step 1: Setup Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.0+5
  google_mlkit_face_detection: ^0.8.0
  google_mlkit_commons: ^0.3.0
  permission_handler: ^11.0.0
```

### Step 2: Android Permissions

**android/app/src/main/AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

### Step 3: iOS Permissions

**ios/Runner/Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for drowsiness detection</string>
```

### Step 4: Create Dart Model Classes

Create a `DrowsinessModel` class to replicate the Python logic:

```dart
// lib/models/drowsiness_metrics.dart
class DrowsinessMetrics {
  final double eyeAspectRatio;      // EAR
  final double mouthAspectRatio;    // MAR
  final double? headTiltDegree;     // Head tilt angle
  final bool eyesOpen;
  final bool yawning;
  final bool headTilted;
  
  DrowsinessMetrics({
    required this.eyeAspectRatio,
    required this.mouthAspectRatio,
    this.headTiltDegree,
    required this.eyesOpen,
    required this.yawning,
    required this.headTilted,
  });
  
  bool get isDrowsy => !eyesOpen || yawning || headTilted;
}
```

### Step 5: Calculation Functions (Dart Implementation)

The key calculations from Python need to be implemented in Dart:

#### EAR (Eye Aspect Ratio)
```dart
// lib/utils/ear_calculator.dart
import 'dart:math';

double calculateEAR(List<Point> eyeLandmarks) {
  // Eye landmarks: 6 points (0-5)
  // Vertical distances
  double A = _euclideanDistance(eyeLandmarks[1], eyeLandmarks[5]);
  double B = _euclideanDistance(eyeLandmarks[2], eyeLandmarks[4]);
  // Horizontal distance
  double C = _euclideanDistance(eyeLandmarks[0], eyeLandmarks[3]);
  
  // EAR = (A + B) / (2.0 * C)
  return (A + B) / (2.0 * C);
}

double _euclideanDistance(Point p1, Point p2) {
  return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
}
```

#### MAR (Mouth Aspect Ratio)
```dart
// lib/utils/mar_calculator.dart
double calculateMAR(List<Point> mouthLandmarks) {
  // Mouth landmarks: 20 points (0-19)
  // Vertical distances
  double A = _euclideanDistance(mouthLandmarks[2], mouthLandmarks[10]);
  double B = _euclideanDistance(mouthLandmarks[4], mouthLandmarks[8]);
  // Horizontal distance
  double C = _euclideanDistance(mouthLandmarks[0], mouthLandmarks[6]);
  
  // MAR = (A + B) / (2.0 * C)
  return (A + B) / (2.0 * C);
}
```

#### Head Tilt Calculation
```dart
// lib/utils/head_pose_calculator.dart
double? calculateHeadTilt(
  List<Point> faceLandmarks,
  int imageWidth,
  int imageHeight,
) {
  // Extract key points:
  // Nose tip (30), Chin (8), Left eye corner (36), 
  // Right eye corner (45), Left mouth (48), Right mouth (54)
  
  // Implementation of solvePnP equivalent
  // This requires 3D model points and camera calibration
  // More complex - consider using a simplified version or
  // angle between eye landmarks and horizontal
  
  // Simplified version: Calculate angle from eye alignment
  Point leftEye = faceLandmarks[36];
  Point rightEye = faceLandmarks[45];
  
  double angle = atan2(
    rightEye.y - leftEye.y,
    rightEye.x - leftEye.x,
  ) * 180 / pi;
  
  return angle;
}
```

### Step 6: Main Detection Service

```dart
// lib/services/drowsiness_detector.dart
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import '../utils/ear_calculator.dart';
import '../utils/mar_calculator.dart';
import '../utils/head_pose_calculator.dart';
import '../models/drowsiness_metrics.dart';

class DrowsinessDetector {
  final FaceDetector faceDetector;
  
  // Thresholds (from Python code)
  static const double EYE_AR_THRESH = 0.25;
  static const double MOUTH_AR_THRESH = 0.79;
  static const double HEAD_TILT_THRESH = 10.0;
  static const int EYE_AR_CONSEC_FRAMES = 3;
  
  int _eyeClosedCounter = 0;
  
  DrowsinessDetector() : faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
    ),
  );
  
  Future<DrowsinessMetrics?> detect(CameraImage cameraImage) async {
    final inputImage = _cameraImageToInputImage(cameraImage);
    final faces = await faceDetector.processImage(inputImage);
    
    if (faces.isEmpty) return null;
    
    final face = faces.first;
    final landmarks = face.landmarks;
    
    if (landmarks == null) return null;
    
    // Extract eye landmarks
    final leftEye = _getEyeLandmarks(landmarks, isLeft: true);
    final rightEye = _getEyeLandmarks(landmarks, isLeft: false);
    
    // Calculate EAR
    final leftEAR = calculateEAR(leftEye);
    final rightEAR = calculateEAR(rightEye);
    final avgEAR = (leftEAR + rightEAR) / 2.0;
    
    // Extract mouth landmarks
    final mouth = _getMouthLandmarks(landmarks);
    final mar = calculateMAR(mouth);
    
    // Calculate head tilt
    final allLandmarks = _getAllLandmarks(landmarks);
    final headTilt = calculateHeadTilt(
      allLandmarks,
      cameraImage.width,
      cameraImage.height,
    );
    
    // Determine drowsiness states
    final eyesOpen = avgEAR >= EYE_AR_THRESH;
    if (!eyesOpen) {
      _eyeClosedCounter++;
    } else {
      _eyeClosedCounter = 0;
    }
    
    final eyesActuallyOpen = _eyeClosedCounter < EYE_AR_CONSEC_FRAMES;
    final yawning = mar > MOUTH_AR_THRESH;
    final headTilted = headTilt != null && headTilt.abs() > HEAD_TILT_THRESH;
    
    return DrowsinessMetrics(
      eyeAspectRatio: avgEAR,
      mouthAspectRatio: mar,
      headTiltDegree: headTilt,
      eyesOpen: eyesActuallyOpen,
      yawning: yawning,
      headTilted: headTilted,
    );
  }
  
  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    // Convert CameraImage to InputImage
    // Implementation depends on your camera setup
    // This is a simplified version
    return InputImage.fromBytes(
      bytes: cameraImage.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      ),
    );
  }
  
  List<Point> _getEyeLandmarks(FaceLandmarks landmarks, {required bool isLeft}) {
    // Extract 6 eye landmarks
    // ML Kit provides different landmark structure than dlib
    // You'll need to map ML Kit landmarks to dlib's 68-point structure
    // This is a placeholder - adjust based on ML Kit's actual structure
    return [];
  }
  
  List<Point> _getMouthLandmarks(FaceLandmarks landmarks) {
    // Extract mouth landmarks
    return [];
  }
  
  List<Point> _getAllLandmarks(FaceLandmarks landmarks) {
    // Extract all 68 landmarks
    return [];
  }
  
  void dispose() {
    faceDetector.close();
  }
}
```

### Step 7: Camera Screen Widget

```dart
// lib/screens/drowsiness_detection_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/drowsiness_detector.dart';
import '../models/drowsiness_metrics.dart';

class DrowsinessDetectionScreen extends StatefulWidget {
  @override
  _DrowsinessDetectionScreenState createState() => _DrowsinessDetectionScreenState();
}

class _DrowsinessDetectionScreenState extends State<DrowsinessDetectionScreen> {
  CameraController? _cameraController;
  DrowsinessDetector? _detector;
  DrowsinessMetrics? _currentMetrics;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _detector = DrowsinessDetector();
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0], // Front camera
      ResolutionPreset.medium,
    );
    
    await _cameraController!.initialize();
    _cameraController!.startImageStream(_processImage);
    
    setState(() => _isInitialized = true);
  }
  
  Future<void> _processImage(CameraImage image) async {
    if (_detector == null) return;
    
    final metrics = await _detector!.detect(image);
    
    setState(() {
      _currentMetrics = metrics;
    });
    
    // Alert if drowsy
    if (metrics?.isDrowsy ?? false) {
      _showDrowsinessAlert();
    }
  }
  
  void _showDrowsinessAlert() {
    // Show alert, play sound, vibrate, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ Drowsiness Detected!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
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
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            top: 40,
            left: 20,
            child: _buildMetricsDisplay(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricsDisplay() {
    if (_currentMetrics == null) {
      return Text('No face detected', style: TextStyle(color: Colors.white));
    }
    
    final m = _currentMetrics!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eyes: ${m.eyesOpen ? "Open" : "Closed"}',
          style: TextStyle(
            color: m.eyesOpen ? Colors.green : Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'MAR: ${m.mouthAspectRatio.toStringAsFixed(2)}',
          style: TextStyle(
            color: m.mouthAspectRatio < 0.79 ? Colors.green : Colors.red,
            fontSize: 16,
          ),
        ),
        if (m.headTiltDegree != null)
          Text(
            'Head Tilt: ${m.headTiltDegree!.toStringAsFixed(2)}°',
            style: TextStyle(
              color: m.headTiltDegree!.abs() < 10 ? Colors.green : Colors.red,
              fontSize: 16,
            ),
          ),
      ],
    );
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _detector?.dispose();
    super.dispose();
  }
}
```

---

## Key Differences: Python vs Flutter

1. **Face Detection**: dlib → Google ML Kit Face Detection
2. **Image Processing**: OpenCV → Dart image processing or ML Kit
3. **Landmark Structure**: ML Kit provides different landmarks than dlib's 68-point model
4. **Camera Access**: OpenCV VideoStream → Flutter Camera plugin

## Important Notes

1. **ML Kit Landmark Mapping**: Google ML Kit doesn't use the same 68-point model as dlib. You'll need to:
   - Map ML Kit landmarks to approximate dlib positions, OR
   - Adjust calculations to work with ML Kit's landmark structure

2. **Performance**: Process frames every few frames (not every frame) to maintain performance:
   ```dart
   int _frameCounter = 0;
   void _processImage(CameraImage image) {
     _frameCounter++;
     if (_frameCounter % 3 == 0) { // Process every 3rd frame
       // ... detection logic
     }
   }
   ```

3. **Head Tilt Calculation**: The full head pose calculation (solvePnP) is complex. Consider:
   - Using a simplified version based on eye/face alignment
   - Using a pre-trained model
   - Offloading to backend if precision is critical

## Testing

1. Test with different lighting conditions
2. Test with different face orientations
3. Calibrate thresholds for your use case
4. Optimize frame processing rate for performance

## Additional Resources

- [Google ML Kit Face Detection](https://developers.google.com/ml-kit/vision/face-detection)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [ML Kit Face Detection Guide](https://developers.google.com/ml-kit/vision/face-detection/get-started)

---

## Alternative: Simplified Implementation

If the full implementation is complex, consider a simplified version:
- Use ML Kit's built-in face detection
- Calculate basic eye closure from bounding box or simple landmarks
- Use head angle from face orientation
- Focus on one metric (e.g., eye closure) first, then expand


