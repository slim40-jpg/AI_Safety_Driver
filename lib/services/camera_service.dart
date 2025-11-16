import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  Function(CameraImage)? _onImageStream;

  Future<void> initializeCamera() async {
    try {
      // Demander la permission caméra
      final permissionStatus = await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        throw Exception('Permission caméra refusée');
      }

      // Obtenir les caméras disponibles
      _cameras = await availableCameras();

      if (_cameras!.isEmpty) {
        throw Exception('Aucune caméra disponible');
      }

      // Utiliser la caméra arrière par défaut
      final firstCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false, // Désactiver audio pour la surveillance
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialiser le contrôleur
      await _controller!.initialize();
      _isInitialized = true;

      print('✅ Caméra initialisée: ${firstCamera.name}');

    } catch (e) {
      print('❌ Erreur initialisation caméra: $e');
      throw Exception('Impossible d\'initialiser la caméra: $e');
    }
  }

  // Démarrer le streaming vidéo
  Future<void> startImageStream(void Function(CameraImage) onImage) async {
    if (!_isInitialized || _controller == null) {
      await initializeCamera();
    }

    _onImageStream = onImage;

    // CORRECTION: Utiliser le bon type de callback
    await _controller!.startImageStream((CameraImage image) {
      if (_onImageStream != null) {
        _onImageStream!(image);
      }
    });

    print('📹 Streaming vidéo démarré');
  }


  // Arrêter le streaming
  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
      _onImageStream = null;
      print('⏹️ Streaming vidéo arrêté');
    }
  }

  // Changer de caméra
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentLens = _controller!.description.lensDirection;
    final newCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection != currentLens,
      orElse: () => _cameras!.first,
    );

    await _controller!.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    print('🔄 Caméra changée: ${newCamera.name}');
  }

  // Prendre une photo
  Future<XFile?> takePicture() async {
    if (!_isInitialized) return null;

    try {
      final image = await _controller!.takePicture();
      print('📸 Photo prise: ${image.path}');
      return image;
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
      return null;
    }
  }

  // Obtenir le widget de prévisualisation
  Widget getCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initialisation caméra...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreview(_controller!);
  }

  // Nettoyage
  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _isInitialized = false;
    print('🧹 Caméra libérée');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _controller?.value.isStreamingImages ?? false;
  CameraController? get controller => _controller;
}