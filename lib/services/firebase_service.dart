import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/health_model.dart';

class FirebaseService {
  late DatabaseReference _dbRef;
  String _userId = 'user_123';
  bool _isConnected = false;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "KtCUIsDF94NzqMo9eUM3Th2vC9glqE7ORzwgmcEEyour-api-key",
          appId: "1:513447776012:android:2e5da10b73376863918329",
          messagingSenderId: "513447776012",
          projectId: "driversafety-64e47",
          databaseURL: "https://driversafety-64e47-default-rtdb.europe-west1.firebasedatabase.app/",
        ),
      );

      _dbRef = FirebaseDatabase.instance.ref();
      _isConnected = true;
      print('Firebase initialized successfully');
    } catch (e) {
      print('Firebase initialization failed: $e');
      _isConnected = false;
    }
  }

  // Listen for health data updates
  void listenToHealthData(Function(HealthData) onData) {
    if (!_isConnected) {
      print('Not connected to Firebase');
      return;
    }

    _dbRef.child('watch_data/$_userId/latest').onValue.listen((event) {
      try {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final healthData = HealthData.fromJson(data);
          print('Health data received: HR ${healthData.heartRate}, SpO2 ${healthData.spo2}');
          onData(healthData);
        }
      } catch (e) {
        print('Error parsing health data: $e');
      }
    });
  }

  // Listen for emergency alerts
  void listenToEmergencyAlerts(Function(EmergencyAlert) onAlert) {
    if (!_isConnected) {
      print('Not connected to Firebase');
      return;
    }

    _dbRef.child('mobile_alerts/$_userId/last_alert').onValue.listen((event) {
      try {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final alert = EmergencyAlert.fromJson(data);
          print('Emergency alert received: ${alert.message}');
          onAlert(alert);
        }
      } catch (e) {
        print('Error parsing emergency alert: $e');
      }
    });
  }

  // Listen for STM32 commands (for display)
  void listenToSTM32Commands(Function(Map<String, dynamic>) onCommand) {
    if (!_isConnected) return;

    _dbRef.child('stm32_commands/$_userId/last_command').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        print('STM32 command: ${data['action']}');
        onCommand(data);
      }
    });
  }

  // Update user status
  Future<void> updateUserStatus(String status) async {
    if (!_isConnected) return;

    try {
      await _dbRef.child('users/$_userId/status').set(status);
      print('User status updated: $status');
    } catch (e) {
      print('Failed to update user status: $e');
    }
  }

  // Log emergency actions
  Future<void> logEmergencyAction(String action, String details) async {
    if (!_isConnected) return;

    try {
      final logId = 'log_${DateTime.now().millisecondsSinceEpoch}';
      await _dbRef.child('emergency_logs/$_userId/$logId').set({
        'action': action,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Emergency action logged: $action');
    } catch (e) {
      print('Failed to log emergency action: $e');
    }
  }

  bool get isConnected => _isConnected;
  String get userId => _userId;
}