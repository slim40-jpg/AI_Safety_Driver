// Simplified Drowsiness Detector for Flutter using ML Kit
// This is a practical implementation that adapts to ML Kit's landmark structure

import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class SimpleDrowsinessDetector {
  final FaceDetector faceDetector;
  
  // Thresholds (same as Python version)
  static const double EYE_AR_THRESH = 0.25;
  static const double MOUTH_AR_THRESH = 0.79;
  static const int EYE_AR_CONSEC_FRAMES = 3;
  
  int _eyeClosedCounter = 0;
  
  SimpleDrowsinessDetector()
      : faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableLandmarks: true,
            enableClassification: false,
            enableTracking: false,
          ),
        );
  
  Future<DrowsinessState?> detect(CameraImage cameraImage) async {
    try {
      final inputImage = _cameraImageToInputImage(cameraImage);
      final faces = await faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) return null;
      
      final face = faces.first;
      final landmarks = face.landmarks;
      
      if (landmarks == null) return null;
      
      // Get eye landmarks
      final leftEye = landmarks[FaceLandmarkType.leftEye];
      final rightEye = landmarks[FaceLandmarkType.rightEye];
      
      if (leftEye == null || rightEye == null) return null;
      
      // Calculate EAR for both eyes
      final leftEAR = _calculateEAR_MLKit(leftEye);
      final rightEAR = _calculateEAR_MLKit(rightEye);
      final avgEAR = (leftEAR + rightEAR) / 2.0;
      
      // Get mouth landmarks
      final upperLip = landmarks[FaceLandmarkType.upperLipTop];
      final lowerLip = landmarks[FaceLandmarkType.lowerLipBottom];
      final leftMouth = landmarks[FaceLandmarkType.mouthLeft];
      final rightMouth = landmarks[FaceLandmarkType.mouthRight];
      
      double? mar;
      if (upperLip != null && lowerLip != null && 
          leftMouth != null && rightMouth != null) {
        mar = _calculateMAR_MLKit(upperLip, lowerLip, leftMouth, rightMouth);
      }
      
      // Check eye closure
      final eyesOpen = avgEAR >= EYE_AR_THRESH;
      if (!eyesOpen) {
        _eyeClosedCounter++;
      } else {
        _eyeClosedCounter = 0;
      }
      
      final eyesActuallyOpen = _eyeClosedCounter < EYE_AR_CONSEC_FRAMES;
      
      // Calculate head tilt (simplified - from face bounding box angle)
      final headTilt = face.headEulerAngleY; // Y-axis rotation
      
      return DrowsinessState(
        eyeAspectRatio: avgEAR,
        mouthAspectRatio: mar,
        headTiltDegree: headTilt?.abs(),
        eyesOpen: eyesActuallyOpen,
        yawning: mar != null && mar > MOUTH_AR_THRESH,
        headTilted: headTilt != null && headTilt.abs() > 10.0,
      );
    } catch (e) {
      print('Error in drowsiness detection: $e');
      return null;
    }
  }
  
  // Calculate EAR adapted for ML Kit landmarks
  double _calculateEAR_MLKit(FaceLandmark eye) {
    // ML Kit eye landmarks: leftCorner, rightCorner, top, bottom
    final leftCorner = eye.positions.firstWhere(
      (p) => p.type == FaceLandmarkType.leftEyeLeftCorner,
      orElse: () => eye.positions[0],
    );
    final rightCorner = eye.positions.firstWhere(
      (p) => p.type == FaceLandmarkType.leftEyeRightCorner,
      orElse: () => eye.positions[1],
    );
    final top = eye.positions.firstWhere(
      (p) => p.type == FaceLandmarkType.leftEyeTop,
      orElse: () => eye.positions[2],
    );
    final bottom = eye.positions.firstWhere(
      (p) => p.type == FaceLandmarkType.leftEyeBottom,
      orElse: () => eye.positions[3],
    );
    
    // Vertical distance
    final vertical = _euclideanDistance(top.position, bottom.position);
    // Horizontal distance
    final horizontal = _euclideanDistance(leftCorner.position, rightCorner.position);
    
    // Prevent division by zero
    if (horizontal == 0) return 0.0;
    
    // EAR = vertical / horizontal (simplified but effective)
    return vertical / horizontal;
  }
  
  // Calculate MAR adapted for ML Kit landmarks
  double _calculateMAR_MLKit(
    FaceLandmark upperLip,
    FaceLandmark lowerLip,
    FaceLandmark leftMouth,
    FaceLandmark rightMouth,
  ) {
    // Vertical distance (mouth opening)
    final vertical = _euclideanDistance(
      upperLip.positions.first.position,
      lowerLip.positions.first.position,
    );
    
    // Horizontal distance (mouth width)
    final horizontal = _euclideanDistance(
      leftMouth.position,
      rightMouth.position,
    );
    
    // Prevent division by zero
    if (horizontal == 0) return 0.0;
    
    // MAR = vertical / horizontal
    return vertical / horizontal;
  }
  
  double _euclideanDistance(Point point1, Point point2) {
    return sqrt(
      pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2),
    );
  }
  
  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    
    final imageRotation = InputImageRotation.rotation0deg;
    
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: imageRotation,
        format: InputImageFormat.yuv420,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      ),
    );
  }
  
  void dispose() {
    faceDetector.close();
  }
}

// Drowsiness State Model
class DrowsinessState {
  final double eyeAspectRatio;
  final double? mouthAspectRatio;
  final double? headTiltDegree;
  final bool eyesOpen;
  final bool yawning;
  final bool headTilted;
  
  DrowsinessState({
    required this.eyeAspectRatio,
    this.mouthAspectRatio,
    this.headTiltDegree,
    required this.eyesOpen,
    required this.yawning,
    required this.headTilted,
  });
  
  bool get isDrowsy => !eyesOpen || yawning || headTilted;
  
  String get status {
    if (isDrowsy) {
      if (!eyesOpen) return 'Eyes Closed!';
      if (yawning) return 'Yawning!';
      if (headTilted) return 'Head Tilted!';
      return 'Drowsy';
    }
    return 'Alert';
  }
}


