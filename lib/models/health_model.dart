import 'package:flutter/material.dart';

class HealthData {
  final int heartRate;
  final int spo2;
  final int stressLevel;
  final double bodyTemperature;
  final String activityLevel;
  final int sleepQuality;
  final DateTime timestamp;

  HealthData({
    required this.heartRate,
    required this.spo2,
    required this.stressLevel,
    required this.bodyTemperature,
    required this.activityLevel,
    required this.sleepQuality,
    required this.timestamp,
  });

  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      heartRate: (json['heart_rate'] ?? 70).toInt(),
      spo2: (json['spo2'] ?? 98).toInt(),
      stressLevel: (json['stress_level'] ?? 50).toInt(),
      bodyTemperature: (json['body_temperature'] ?? 36.5).toDouble(),
      activityLevel: json['activity_level'] ?? 'sedentary',
      sleepQuality: (json['sleep_quality'] ?? 80).toInt(),
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  // Health status checkers
  bool get isHeartRateCritical => heartRate < 50 || heartRate > 140;
  bool get isSpO2Critical => spo2 < 90;
  bool get isTemperatureCritical => bodyTemperature > 39.0 || bodyTemperature < 35.0;
  bool get isStressCritical => stressLevel > 85;

  bool get hasCriticalCondition =>
      isHeartRateCritical || isSpO2Critical || isTemperatureCritical;

  String get healthStatus {
    if (hasCriticalCondition) return 'CRITICAL';
    if (isStressCritical || spo2 < 94) return 'WARNING';
    return 'NORMAL';
  }

  Color get statusColor {
    switch (healthStatus) {
      case 'CRITICAL': return Colors.red;
      case 'WARNING': return Colors.orange;
      default: return Colors.green;
    }
  }
}

class EmergencyAlert {
  final String type;
  final String severity;
  final String message;
  final String timestamp;
  final Map<String, dynamic>? parameters;

  EmergencyAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.parameters,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      type: json['type'] ?? 'general',
      severity: json['severity'] ?? 'medium',
      message: json['message'] ?? 'Alert',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'])
          : null,
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isHighPriority => severity == 'high' || isCritical;
}