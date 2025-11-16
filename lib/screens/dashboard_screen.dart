import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emergency_service.dart';
import '../models/health_model.dart';
import '../services/camera_service.dart';
import '../widgets/health_metric_card.dart';
import '../widgets/emergency_coutdown.dart';
import '../widgets/drowsiness_detector.dart';
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late EmergencyService _emergencyService;
  late CameraService _cameraService;

  // Simulated health data (replace with real Firebase data)
  HealthData _healthData = HealthData(
    heartRate: 72,
    bodyTemperature: 36.9,
    activityLevel: "normal",
    sleepQuality: 10,
    spo2: 98,
    stressLevel: 45,
    timestamp: DateTime.now(),
  );

  Map<String, dynamic> _drowsinessData = {};
  bool _showCameraPreview = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() async {
    _emergencyService = Provider.of<EmergencyService>(context, listen: false);
    _cameraService = Provider.of<CameraService>(context, listen: false);

    // Set up callbacks
    _emergencyService.setDrowsinessUpdateCallback(_onDrowsinessUpdate);
    _emergencyService.setCountdownCallback(_onCountdownUpdate);
  }

  void _onDrowsinessUpdate(Map<String, dynamic> data) {
    setState(() {
      _drowsinessData = data;
    });
  }

  void _onCountdownUpdate(int seconds) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Driver Health Monitor'),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.emergency),
            onPressed: _showEmergencyDialog,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Emergency Countdown Overlay
              if (_emergencyService.isEmergencyActive)
                EmergencyCountdownWidget(
                  seconds: _emergencyService.countdownSeconds,
                  onCancel: _emergencyService.userResponded,
                ),

              // Connection Status
              _buildConnectionStatus(),

              // Drowsiness Detection Section
              _buildDrowsinessSection(),

              // Health Metrics
              _buildHealthMetrics(),

              // Camera Preview
              if (_showCameraPreview) _buildCameraPreview(),

              // Quick Actions
              _buildQuickActions(),
            ],
          ),
        ),

        // Bottom Emergency Bar
        _buildEmergencyBar(),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _emergencyService.smartwatchAvailable ?
              Icons.watch : Icons.videocam,
              color: _emergencyService.smartwatchAvailable ?
              Colors.green : Colors.orange,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _emergencyService.smartwatchAvailable ?
                'Smartwatch Connected' : 'Using Camera Monitoring',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(
              _emergencyService.serverConnected ?
              Icons.cloud_done : Icons.cloud_off,
              color: _emergencyService.serverConnected ?
              Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrowsinessSection() {
    bool faceDetected = _drowsinessData['face_detected'] == true;
    bool isDrowsy = _drowsinessData['is_drowsy'] == true;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: isDrowsy ? Colors.red : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Drowsiness Detection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (!faceDetected)
              _buildNoFaceDetected()
            else
              _buildDrowsinessMetrics(),

            SizedBox(height: 16),
            _buildDrowsinessControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFaceDetected() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No face detected. Please position yourself in camera view.',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrowsinessMetrics() {
    double ear = _drowsinessData['ear']?.toDouble() ?? 0.0;
    double mar = _drowsinessData['mar']?.toDouble() ?? 0.0;
    double headTilt = _drowsinessData['head_tilt']?.toDouble() ?? 0.0;
    double score = _drowsinessData['drowsiness_score']?.toDouble() ?? 0.0;

    return Column(
      children: [
        // Drowsiness Score
        DrowsinessIndicatorWidget(score: score),

        SizedBox(height: 16),

        // Detailed Metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                'EAR',
                ear.toStringAsFixed(2),
                ear < 0.25 ? Colors.red : Colors.green,
                Icons.remove_red_eye,
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                'MAR',
                mar.toStringAsFixed(2),
                mar > 0.79 ? Colors.red : Colors.green,
                Icons.sick,
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                'Head Tilt',
                '${headTilt.toStringAsFixed(1)}°',
                headTilt > 15 ? Colors.red : Colors.green,
                Icons.phone_iphone,
              ),
            ),
          ],
        ),

        // Alerts
        if (_drowsinessData['eyes_closed'] == true)
          _buildAlertItem('Eyes Closed', Icons.visibility_off),
        if (_drowsinessData['yawning'] == true)
          _buildAlertItem('Yawning Detected', Icons.sick),
        if (_drowsinessData['head_tilted'] == true)
          _buildAlertItem('Head Tilted', Icons.phone_iphone),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertItem(String text, IconData icon) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.red, size: 16),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDrowsinessControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(_showCameraPreview ? Icons.videocam_off : Icons.videocam),
            label: Text(_showCameraPreview ? 'Hide Camera' : 'Show Camera'),
            onPressed: _toggleCameraPreview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Icons.emergency_recording),
            label: Text('Test Alert'),
            onPressed: _testDrowsinessAlert,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        HealthMetricCard(
          title: 'Heart Rate',
          value: '${_healthData.heartRate}',
          unit: 'BPM',
          icon: Icons.favorite,
          color: _healthData.heartRate > 100 ? Colors.orange : Colors.green,
          trend: Icons.trending_up,
        ),
        HealthMetricCard(
          title: 'Oxygen',
          value: '${_healthData.spo2}',
          unit: '%',
          icon: Icons.air,
          color: _healthData.spo2 < 95 ? Colors.orange : Colors.green,
          trend: Icons.trending_flat,
        ),
        HealthMetricCard(
          title: 'Stress',
          value: '${_healthData.stressLevel}',
          unit: '%',
          icon: Icons.psychology,
          color: _healthData.stressLevel > 70 ? Colors.orange : Colors.green,
          trend: Icons.trending_down,
        ),
        HealthMetricCard(
          title: 'Status',
          value: _emergencyService.isFatigueDetected ? 'Fatigue' : 'Normal',
          unit: '',
          icon: Icons.health_and_safety,
          color: _emergencyService.isFatigueDetected ? Colors.orange : Colors.green,
          trend: Icons.trending_flat,
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera Preview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _cameraService.isInitialized
                  ? _cameraService.getCameraPreview()
                  : Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(Icons.emergency, color: Colors.white),
                  label: Text('Call Emergency'),
                  backgroundColor: Colors.red,
                  labelStyle: TextStyle(color: Colors.white),
                  onPressed: _emergencyService.callEmergencyNumber,
                ),
                ActionChip(
                  avatar: Icon(Icons.camera_alt, color: Colors.white),
                  label: Text('Start Monitoring'),
                  backgroundColor: Colors.blue,
                  labelStyle: TextStyle(color: Colors.white),
                  onPressed: _emergencyService.startCameraMonitoring,
                ),
                ActionChip(
                  avatar: Icon(Icons.stop, color: Colors.white),
                  label: Text('Stop Monitoring'),
                  backgroundColor: Colors.grey,
                  labelStyle: TextStyle(color: Colors.white),
                  onPressed: _emergencyService.stopCameraMonitoring,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        height: _emergencyService.isEmergencyActive ? 80 : 0,
        child: Container(
          color: Colors.red,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 30),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'EMERGENCY DETECTED! Tap to cancel automatic call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _emergencyService.userResponded,
                child: Text('CANCEL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'camera',
          onPressed: _toggleCameraPreview,
          child: Icon(_showCameraPreview ? Icons.camera_alt : Icons.camera),
          backgroundColor: Colors.blue,
        ),
        SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'emergency',
          onPressed: _showEmergencyDialog,
          child: Icon(Icons.emergency),
          backgroundColor: Colors.red,
        ),
      ],
    );
  }

  void _toggleCameraPreview() {
    setState(() {
      _showCameraPreview = !_showCameraPreview;
    });

    if (_showCameraPreview) {
      _emergencyService.startCameraMonitoring();
    } else {
      _emergencyService.stopCameraMonitoring();
    }
  }

  void _testDrowsinessAlert() {
    _emergencyService.triggerFatigueAlert();
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Options'),
        content: Text('Choose an emergency action:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _emergencyService.callEmergencyNumber();
            },
            child: Text('Call Emergency'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _emergencyService.triggerFatigueAlert();
            },
            child: Text('Test Fatigue Alert'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _emergencyService.triggerStressAlert();
            },
            child: Text('Test Stress Alert'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}