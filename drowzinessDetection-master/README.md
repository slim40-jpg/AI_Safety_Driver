# Amanti - Driver Drowsiness Detection System

## Overview
Amanti's Drowsiness Detection System is an AI-powered safety feature that monitors driver alertness in real-time using computer vision and biometric sensors to prevent fatigue-related accidents.

## Features

### Real-time Monitoring
- **Facial Analysis**: Tracks eye closure, blinking patterns, and yawning
- **Head Position**: Monitors head nodding and position changes
- **Biometric Data**: Integrates with smartwatch for heart rate variability

### Alert System
- **Visual Alerts**: On-screen warnings with increasing intensity
- **Audio Alerts**: Progressive sound alerts from gentle to urgent
- **Haptic Feedback**: Smartwatch vibrations for physical notification
- **Emergency Protocol**: Automatic safety measures for severe cases

### Safety Actions
- **Early Warning**: Gentle alerts at first signs of fatigue
- **Break Reminders**: Suggests rest stops when needed
- **Emergency Contacts**: Notifies designated contacts if unresponsive
- **Emergency Services**: Automatic alert with location for critical situations

## Technology Stack

### Hardware Requirements
- Mobile device with front-facing camera
- Optional: Smartwatch with heart rate monitor
- Raspberry Pi 5 (for vehicle integration)

### AI Components
- **Computer Vision**: Real-time facial landmark detection
- **Behavioral Analysis**: Eye aspect ratio calculation
- **Pattern Recognition**: Fatigue pattern identification
- **Sensor Fusion**: Combines visual and biometric data

## Installation

### Mobile Application
```bash
# Clone the repository
git clone https://github.com/amanti/drowsiness-detection.git

# Install dependencies
npm install

# Run the application
npm start
