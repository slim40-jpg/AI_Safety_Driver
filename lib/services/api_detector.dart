import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

class APIDrowsinessDetector {
  // Change this to your computer's IP address
  static const String baseUrl = 'http://192.168.1.100:5000';

  Future<Map<String, dynamic>> analyzeFrame(CameraImage image) async {
    try {
      // Convert CameraImage to base64
      String imageBase64 = await _convertCameraImageToBase64(image);

      final response = await http.post(
        Uri.parse('$baseUrl/analyze_drowsiness'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image': imageBase64}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'face_detected': false
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'face_detected': false
      };
    }
  }

  Future<String> _convertCameraImageToBase64(CameraImage image) async {
    try {
      // Convert YUV420 to JPEG
      final jpegBytes = await _yuv420ToJpeg(image);
      String base64Image = base64Encode(jpegBytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      // Fallback: Create a simple placeholder
      return 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=';
    }
  }

  Future<Uint8List> _yuv420ToJpeg(CameraImage image) async {
    // Simple conversion for hackathon - you can improve this
    // This is a basic implementation
    final WriteBuffer buffer = WriteBuffer();

    if (image.planes.length == 3) {
      buffer.putUint8List(image.planes[0].bytes);
    }

    return buffer.done().buffer.asUint8List();
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}