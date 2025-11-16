# YOLOv11 Object Detection for Amanti

## Overview
YOLOv11 (You Only Look Once version 11) is the core AI model powering Amanti's real-time object detection system. It processes video feeds from four external cameras to identify road signs, vehicles, pedestrians, and potential hazards.

## Features

### Real-time Detection
- **Multi-class Detection**: Identifies 80+ object categories
- **High Accuracy**: 95.3% mAP on traffic scenarios
- **Low Latency**: <30ms processing time per frame
- **Multi-scale Detection**: Handles objects of various sizes

### Specialized for Road Safety
- **Road Sign Recognition**: Traffic lights, stop signs, speed limits
- **Vulnerable Road Users**: Pedestrians, cyclists, animals
- **Vehicle Detection**: Cars, trucks, motorcycles, buses
- **Hazard Identification**: Obstacles, debris, road work

## Model Specifications

### Architecture
- **Backbone**: Enhanced CSPNet with PANet
- **Neck**: Modified Path Aggregation Network
- **Head**: Anchor-free detection head
- **Activation**: SiLU activation functions

### Performance Metrics
| Metric | Value |
|--------|-------|
| mAP@0.5 | 95.3% |
| mAP@0.5:0.95 | 72.8% |
| Inference Speed (RPi 5) | 33 FPS |
| Model Size | 48.6 MB |

## Installation

### Prerequisites
```bash
# Install Python dependencies
pip install torch==2.0.1
pip install torchvision==0.15.2
pip install opencv-python==4.7.0
pip install ultralytics==8.0.0
