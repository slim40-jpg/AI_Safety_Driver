import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  bool _isLoading = true;
  String _statusText = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();

      // Démarrer le streaming avec analyse d'image
      await _cameraService.startImageStream(_analyzeImage);

      setState(() {
        _isLoading = false;
        _statusText = 'Caméra active';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  void _analyzeImage(CameraImage image) {
    // Ici vous pouvez analyser l'image pour:
    // - Détection de fatigue (yeux fermés, bâillements)
    // - Détection de distraction (regard ailleurs)
    // - Détection de stress (expressions faciales)

    // Exemple: Log des dimensions de l'image
    if (image.format.group == ImageFormatGroup.yuv420) {
      // Traitement YUV pour l'analyse
      _processYUVImage(image);
    }

    // Mettre à jour l'UI si nécessaire
    if (mounted) {
      setState(() {
        _statusText = 'Streaming: ${image.width}x${image.height}';
      });
    }
  }

  void _processYUVImage(CameraImage image) {
    // Implémentez votre logique d'analyse d'image ici
    // Pour la détection de fatigue/stress
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Surveillance Caméra - Raqib Essahha'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera),
            onPressed: _switchCamera,
            tooltip: 'Changer de caméra',
          ),
          IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: _takePicture,
            tooltip: 'Prendre une photo',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statut
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey[900],
            child: Row(
              children: [
                Icon(
                  _cameraService.isStreaming ? Icons.videocam : Icons.videocam_off,
                  color: _cameraService.isStreaming ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  _statusText,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Vue caméra
          Expanded(
            child: Stack(
              children: [
                // Prévisualisation caméra
                _cameraService.getCameraPreview(),

                // Overlay pour l'analyse
                if (!_isLoading)
                  _buildAnalysisOverlay(),

                // Indicateur de chargement
                if (_isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Initialisation caméra...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Contrôles
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildAnalysisOverlay() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateurs de santé
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text(
                  'Vigilance: Active',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Zone de focus pour la détection
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Zone Analyse\nVisage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bouton enregistrement
          ElevatedButton.icon(
            onPressed: _toggleRecording,
            icon: Icon(_cameraService.isStreaming ? Icons.stop : Icons.play_arrow),
            label: Text(_cameraService.isStreaming ? 'Arrêter' : 'Démarrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cameraService.isStreaming ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

          // Bouton photo
          ElevatedButton.icon(
            onPressed: _takePicture,
            icon: Icon(Icons.camera_alt),
            label: Text('Photo'),
          ),

          // Bouton paramètres
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettings,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur changement caméra: $e')),
      );
    }
  }

  Future<void> _takePicture() async {
    final image = await _cameraService.takePicture();
    if (image != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo sauvegardée: ${image.path}')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_cameraService.isStreaming) {
      await _cameraService.stopImageStream();
    } else {
      await _cameraService.startImageStream(_analyzeImage);
    }
    setState(() {});
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Paramètres Caméra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Résolution: Moyenne'),
              subtitle: Text('Équilibre performance/qualité'),
            ),
            ListTile(
              leading: Icon(Icons.security),
              title: Text('Analyse en temps réel'),
              subtitle: Text('Détection fatigue et stress'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('FERMER'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}