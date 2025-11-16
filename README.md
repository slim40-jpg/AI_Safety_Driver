# أمانتي (Amanti) - Intelligent Driver Safety System

## Overview
Amanti is an integrated hardware-software solution that brings advanced driver safety features to all vehicles through retrofittable technology. The system combines AI-powered object detection, driver health monitoring, and V2X communication to create a comprehensive safety ecosystem.

## System Architecture

### Hardware Components
- **Raspberry Pi 5** - Central processing unit
- **4 External Cameras** - 360° vehicle surveillance
- **Solar-Powered Module** - Sustainable energy source
- **V2X Communication** - Vehicle-to-everything connectivity

### Software Components
- **Mobile Application** - Real-time interface and alerts
- **Smart Watch Integration** - Health and biometric monitoring
- **Cloud Services** - Community data and analytics

## Key Features

### Safety & ADAS
- Real-time object detection using YOLOv11
- Surround View Monitor (SVM) bird's eye view
- Lane departure warnings
- Collision avoidance alerts
- Community hazard sharing

### Driver Monitoring
- Drowsiness detection via mobile camera
- Health monitoring through smartwatch sensors
- Real-time vital sign tracking (heart rate, stress levels)
- Emergency auto-response system

### Sustainability
- Solar-powered operation
- Extends vehicle lifespan through retrofitting
- Reduces electronic waste

## Technical Specifications

### Processing
- **Object Detection**: YOLOv11 model
- **View Generation**: SVM stitching algorithm
- **Health Analytics**: Real-time biometric processing
- **Data Communication**: V2X and 5G/4G connectivity

### Sensors
- 4x HD cameras (external)
- Mobile front camera (driver monitoring)
- Smartwatch sensors (health metrics)
- GPS and motion sensors

## Installation

### Hardware Setup
1. Mount 4 external cameras on vehicle
2. Install Raspberry Pi 5 module on dashboard
3. Connect solar power unit
4. Pair with mobile device

### Software Setup
1. Install Amenti mobile application
2. Pair smartwatch with application
3. Configure safety preferences
4. Connect to cloud services

## RSE Alignment

| Aspect | Implementation |
|--------|----------------|
| **Social Equality** | Makes safety features accessible to all vehicle owners |
| **Environmental** | Solar-powered, extends vehicle lifespan |
| **Health & Wellness** | Comprehensive driver monitoring and protection |
| **Community** | Shared hazard data for collective safety |

## Safety Outcomes

- **Prevents accidents** through real-time object detection
- **Monitors driver health** for medical emergencies
- **Reduces collisions** with vulnerable road users
- **Enables quick emergency response** in critical situations

## Development

This project uses:
- Python for AI/ML processing
- TensorFlow/PyTorch for model training
- React Native for mobile application
- Firebase for cloud services
- Raspberry Pi OS for hardware control

## License

MIT License - See LICENSE file for details

## Contact

For more information about Amenti and collaboration opportunities, please contact our development team.

---
**Making road safety accessible to everyone**
