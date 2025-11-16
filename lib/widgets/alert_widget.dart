import 'package:flutter/material.dart';
import '../models/health_model.dart';

class AlertWidget extends StatelessWidget {
  final HealthData? healthData;
  final EmergencyAlert? emergencyAlert;
  final VoidCallback onEmergencyCall;

  const AlertWidget({
    Key? key,
    this.healthData,
    this.emergencyAlert,
    required this.onEmergencyCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show emergency alert if present
    if (emergencyAlert != null) {
      return _buildEmergencyAlert(emergencyAlert!, context);
    }

    // Show health-based alert
    if (healthData != null && healthData!.hasCriticalCondition) {
      return _buildCriticalHealthAlert(healthData!, context);
    }

    // No alerts
    return Container();
  }

  Widget _buildEmergencyAlert(EmergencyAlert alert, BuildContext context) {
    Color backgroundColor;
    IconData icon;

    if (alert.isCritical) {
      backgroundColor = Colors.red;
      icon = Icons.emergency;
    } else {
      backgroundColor = Colors.orange;
      icon = Icons.warning;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'EMERGENCY ALERT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            alert.message,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          if (alert.isCritical)
            ElevatedButton(
              onPressed: onEmergencyCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone),
                  SizedBox(width: 8),
                  Text('CALL EMERGENCY (24541135)'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCriticalHealthAlert(HealthData healthData, BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'CRITICAL HEALTH CONDITION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _getCriticalConditionMessage(healthData),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (healthData.isHeartRateCritical)
                _buildMetricChip('Heart Rate: ${healthData.heartRate} BPM', Colors.white),
              if (healthData.isSpO2Critical)
                _buildMetricChip('Oxygen: ${healthData.spo2}%', Colors.white),
              if (healthData.isTemperatureCritical)
                _buildMetricChip('Temp: ${healthData.bodyTemperature}°C', Colors.white),
            ],
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: onEmergencyCall,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone),
                SizedBox(width: 8),
                Text('CALL 24541135'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getCriticalConditionMessage(HealthData healthData) {
    List<String> conditions = [];

    if (healthData.isHeartRateCritical) {
      conditions.add('abnormal heart rate');
    }
    if (healthData.isSpO2Critical) {
      conditions.add('low oxygen levels');
    }
    if (healthData.isTemperatureCritical) {
      conditions.add('critical body temperature');
    }

    return 'Critical condition detected: ${conditions.join(', ')}. Emergency assistance required.';
  }
}