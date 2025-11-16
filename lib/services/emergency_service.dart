import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import '../models/health_model.dart';
import '../services/camera_service.dart';
import 'api_detector.dart'; // Add this import
import 'package:camera/camera.dart';
class EmergencyService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final CameraService _cameraService = CameraService();
  final APIDrowsinessDetector _drowsinessDetector = APIDrowsinessDetector(); // Add this

  Timer? _emergencyTimer;
  Timer? _countdownTimer;
  Timer? _fatigueTimer;
  Timer? _stressTimer;
  Timer? _speechTimeoutTimer;
  Timer? _cameraAnalysisTimer;

  int _countdownSeconds = 10;
  bool _isEmergencyActive = false;
  bool _userHasResponded = false;
  bool _isFatigueDetected = false;
  bool _isStressDetected = false;
  bool _isListening = false;
  bool _isCameraMonitoring = false;
  bool _smartwatchAvailable = true;
  bool _serverConnected = false;

  // Drowsiness detection variables
  Map<String, dynamic> _lastDrowsinessResult = {};
  int _consecutiveDrowsyFrames = 0;
  static const int DROWSINESS_CONSECUTIVE_THRESHOLD = 5;

  Function(int)? _onCountdownUpdate;
  Function(bool)? _onListeningStateChange;
  Function(String)? _onDrowsinessDetected;
  Function(Map<String, dynamic>)? _onDrowsinessUpdate;

  Future<void> initialize() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);

      // Initialize speech recognition
      bool available = await _speech.initialize();
      print('Speech recognition available: $available');

      // Initialize camera service
      await _cameraService.initializeCamera();
      print('Camera service initialized');

      // Check Python server connection
      _serverConnected = await _drowsinessDetector.checkServerHealth();
      print('Python Server Connected: $_serverConnected');

      if (!_serverConnected) {
        _tts.speak("Warning: Drowsiness detection server not connected. Using basic monitoring.");
      }

      print('Emergency service initialized');
    } catch (e) {
      print('Emergency service initialization failed: $e');
    }
  }

  // Set callback for countdown updates
  void setCountdownCallback(Function(int) onUpdate) {
    _onCountdownUpdate = onUpdate;
  }

  // Set callback for listening state changes
  void setListeningCallback(Function(bool) onListeningChange) {
    _onListeningStateChange = onListeningChange;
  }

  // Set callback for drowsiness detection
  void setDrowsinessCallback(Function(String) onDrowsinessDetected) {
    _onDrowsinessDetected = onDrowsinessDetected;
  }

  // Set callback for drowsiness data updates
  void setDrowsinessUpdateCallback(Function(Map<String, dynamic>) onUpdate) {
    _onDrowsinessUpdate = onUpdate;
  }

  // ========== SMARTWATCH DATA PROCESSING ==========

  void processHealthData(HealthData healthData, {bool smartwatchAvailable = true}) {
    _smartwatchAvailable = smartwatchAvailable;

    if (smartwatchAvailable) {
      // Use smartwatch data for detection
      _processSmartwatchData(healthData);
    } else {
      // Smartwatch not available - use camera for detection
      if (!_isCameraMonitoring) {
        _startCameraMonitoring();
      }
    }
  }

  void _processSmartwatchData(HealthData healthData) {
    // Check for cardiac emergencies (highest priority)
    if (isCardiacEmergency(healthData)) {
      startEmergencyCountdown(reason: "Critical cardiac condition detected");
      return;
    }

    // Check stress levels
    checkStress(healthData);

    // Check fatigue levels
    checkFatigue(healthData);
  }

  // ========== CAMERA-BASED DROWSINESS DETECTION ==========

  Future<void> _startCameraMonitoring() async {
    if (_isCameraMonitoring) return;

    try {
      await _cameraService.startImageStream(_analyzeCameraFrame);
      _isCameraMonitoring = true;

      print('📹 Camera monitoring started for drowsiness detection');

      _tts.speak("Starting camera-based drowsiness monitoring");

    } catch (e) {
      print('Error starting camera monitoring: $e');
      _tts.speak("Unable to start camera monitoring. Please drive carefully.");
    }
  }

  Future<void> _stopCameraMonitoring() async {
    _cameraAnalysisTimer?.cancel();
    await _cameraService.stopImageStream();
    _isCameraMonitoring = false;
    _consecutiveDrowsyFrames = 0;

    print('📹 Camera monitoring stopped');
  }

  void _analyzeCameraFrame(CameraImage image) async {
    if (!_serverConnected) {
      _fallbackDrowsinessDetection();
      return;
    }

    try {
      var result = await _drowsinessDetector.analyzeFrame(image);
      _lastDrowsinessResult = result;

      // Send update to dashboard
      _onDrowsinessUpdate?.call(result);

      if (result['face_detected'] == true) {
        if (result['is_drowsy'] == true) {
          _consecutiveDrowsyFrames++;
          if (_consecutiveDrowsyFrames >= DROWSINESS_CONSECUTIVE_THRESHOLD) {
            _handleDrowsinessDetection(result);
          }
        } else {
          _consecutiveDrowsyFrames = 0;
        }
      } else {
        _consecutiveDrowsyFrames = 0;
      }
    } catch (e) {
      print('Error analyzing frame: $e');
      _fallbackDrowsinessDetection();
    }
  }

  void _handleDrowsinessDetection(Map<String, dynamic> result) {
    if (_isFatigueDetected) return; // Already handling fatigue

    _isFatigueDetected = true;

    String alertMessage = "Drowsiness detected! ";
    if (result['eyes_closed'] == true) alertMessage += "Eyes closed. ";
    if (result['yawning'] == true) alertMessage += "Yawning detected. ";
    if (result['head_tilted'] == true) alertMessage += "Head tilted. ";
    alertMessage += "Please pull over and take a break immediately!";

    print('😴 DROWSINESS DETECTED: ${result['drowsiness_score']}');
    _tts.speak(alertMessage);
    _onDrowsinessDetected?.call(alertMessage);

    // Start emergency countdown if severe drowsiness
    if (result['drowsiness_score'] > 0.8) {
      _tts.speak("Severe drowsiness detected! Emergency alert activated.");
      startEmergencyCountdown(reason: "Severe driver drowsiness detected");
    }
  }

  void _fallbackDrowsinessDetection() {
    // Simple fallback when Python server is not available
    print('Using fallback drowsiness detection');
  }

  // ========== STRESS DETECTION ==========

  void checkStress(HealthData healthData) {
    bool isStressed = _isStressCondition(healthData);

    if (isStressed && !_isStressDetected) {
      _handleStressDetection();
    } else if (!isStressed && _isStressDetected) {
      _isStressDetected = false;
      _stressTimer?.cancel();
    }
  }

  bool _isStressCondition(HealthData healthData) {
    return healthData.heartRate > 120 || healthData.stressLevel > 70;
  }

  void _handleStressDetection() {
    _isStressDetected = true;
    print('😰 STRESS DETECTED: Driver appears stressed');

    _tts.speak("I notice you seem stressed. Please take deep breaths and consider taking a break when safe to do so.");
  }

  // ========== FATIGUE DETECTION ==========

  void checkFatigue(HealthData healthData) {
    bool isFatigued = _isFatigueCondition(healthData);

    if (isFatigued && !_isFatigueDetected) {
      _handleFatigueDetection();
    } else if (!isFatigued && _isFatigueDetected) {
      _isFatigueDetected = false;
      _fatigueTimer?.cancel();
    }
  }

  bool _isFatigueCondition(HealthData healthData) {
    return healthData.heartRate > 100;
  }

  void _handleFatigueDetection() {
    _isFatigueDetected = true;
    print('🫠 FATIGUE DETECTED: Driver appears fatigued');

    _tts.speak("Fatigue detected! Please consider taking a break. Your alertness is important for safety.");
  }

  // ========== EMERGENCY FUNCTIONALITY ==========

  void startEmergencyCountdown({String reason = "Critical health condition"}) {
    if (_isEmergencyActive) return;

    _isEmergencyActive = true;
    _userHasResponded = false;
    _countdownSeconds = 10;

    print('🚨 EMERGENCY COUNTDOWN STARTED: $reason');
    _playEmergencyAlert(reason);
    _startCountdownTimer();
    _startEmergencyCallTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        _onCountdownUpdate?.call(_countdownSeconds);

        // Speak countdown warnings
        if (_countdownSeconds == 10) _tts.speak("Emergency call in 10 seconds");
        else if (_countdownSeconds == 5) _tts.speak("Warning! Emergency call in 5 seconds!");
        else if (_countdownSeconds == 3) _tts.speak("3 seconds!");
        else if (_countdownSeconds == 2) _tts.speak("2 seconds!");
        else if (_countdownSeconds == 1) _tts.speak("1 second! Calling emergency!");
      } else {
        timer.cancel();
      }
    });
  }

  void _startEmergencyCallTimer() {
    _emergencyTimer = Timer(Duration(seconds: 10), () {
      if (!_userHasResponded && _isEmergencyActive) {
        _makeAutomaticEmergencyCall();
      }
    });
  }

  void userResponded() {
    if (!_isEmergencyActive) return;
    _userHasResponded = true;
    _cancelTimers();
    _tts.speak("Emergency call cancelled. Please monitor your condition.");
  }

  void _cancelTimers() {
    _emergencyTimer?.cancel();
    _countdownTimer?.cancel();
    _fatigueTimer?.cancel();
    _stressTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cameraAnalysisTimer?.cancel();
    _isEmergencyActive = false;
    _isFatigueDetected = false;
    _isStressDetected = false;
  }

  Future<void> _playEmergencyAlert(String reason) async {
    try {
      await _tts.speak(
          "EMERGENCY DETECTED! $reason. "
              "Emergency services will be called automatically in 10 seconds. "
              "Tap the screen to cancel automatic call."
      );
    } catch (e) {
      print('Emergency alert play failed: $e');
    }
  }

  Future<void> _makeAutomaticEmergencyCall() async {
    const emergencyNumber = '24541135';
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: emergencyNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        _isEmergencyActive = false;
        await Future.delayed(Duration(seconds: 2));
        _tts.speak("Emergency call connected. Please describe your medical emergency to the operator.");
      } else {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      _tts.speak("Unable to make automatic call. Please call emergency services manually.");
    }
  }

  Future<void> callEmergencyNumber() async {
    const emergencyNumber = '24541135';
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: emergencyNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _tts.speak("Failed to make emergency call. Please try manually.");
      }
    } catch (e) {
      _tts.speak("Failed to make emergency call. Please try manually.");
    }
  }

  // ========== HEALTH CHECKS ==========

  Future<void> handleEmergencyAlert(EmergencyAlert alert) async {
    if (alert.isCritical) {
      startEmergencyCountdown(reason: alert.message);
    } else if (alert.isHighPriority) {
      await _tts.speak("Health alert: ${alert.message}");
    }
  }

  bool isCardiacEmergency(HealthData healthData) {
    return healthData.heartRate < 50 || healthData.heartRate > 140 || healthData.spo2 < 90;
  }

  // Manual triggers for testing
  void triggerFatigueAlert() {
    _handleFatigueDetection();
  }

  void triggerStressAlert() {
    _handleStressDetection();
  }

  void startCameraMonitoring() {
    _startCameraMonitoring();
  }

  void stopCameraMonitoring() {
    _stopCameraMonitoring();
  }

  // Stop all alerts and timers
  Future<void> stopAllAlerts() async {
    try {
      _cancelTimers();
      await _stopCameraMonitoring();
      await _tts.stop();
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping alerts: $e');
    }
  }

  // Getters
  bool get isEmergencyActive => _isEmergencyActive;
  int get countdownSeconds => _countdownSeconds;
  bool get userHasResponded => _userHasResponded;
  bool get isFatigueDetected => _isFatigueDetected;
  bool get isStressDetected => _isStressDetected;
  bool get isListening => _isListening;
  bool get isCameraMonitoring => _isCameraMonitoring;
  bool get smartwatchAvailable => _smartwatchAvailable;
  bool get serverConnected => _serverConnected;
  Map<String, dynamic> get lastDrowsinessResult => _lastDrowsinessResult;

  void dispose() {
    stopAllAlerts();
    _cameraService.dispose();
    _speech.stop();
  }
}