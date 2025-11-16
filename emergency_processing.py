import firebase_admin
from firebase_admin import credentials, db
import time
import logging
import requests
import json
from datetime import datetime, timedelta
from enum import Enum
import threading
from typing import Dict, List, Optional
import os

# Configure logging for Windows compatibility
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - [%(name)s] - %(message)s',
    handlers=[
        logging.FileHandler('emergency_ai.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class EmergencyLevel(Enum):
    NORMAL = "normal"
    WARNING = "warning"
    HIGH_ALERT = "high_alert"
    CRITICAL = "critical"
    LIFE_THREATENING = "life_threatening"

class VehicleAction(Enum):
    REDUCE_SPEED = "reduce_speed"
    PREPARE_STOP = "prepare_stop"
    EMERGENCY_STOP = "emergency_stop"
    AUTO_PARK = "auto_park"
    HAZARD_LIGHTS = "hazard_lights"
    CALL_EMERGENCY = "call_emergency"
    NOTIFY_CONTACTS = "notify_contacts"
    FIND_NEAREST_HOSPITAL = "find_nearest_hospital"

class MedicalCondition(Enum):
    CARDIAC_ARREST = "cardiac_arrest"
    HEART_ATTACK = "heart_attack"
    STROKE = "stroke"
    SEIZURE = "seizure"
    FAINTING = "fainting"
    HYPOGLYCEMIA = "hypoglycemia"
    SEVERE_FATIGUE = "severe_fatigue"
    RESPIRATORY_DISTRESS = "respiratory_distress"

class EmergencyAIProcessor:
    def __init__(self, user_id="user_123"):
        self.user_id = user_id
        self.is_running = False
        self.emergency_thread = None
        self.last_health_data = None
        self.emergency_history = []
        self.vehicle_state = {}
        
        # Medical thresholds
        self.medical_thresholds = {
            'cardiac_arrest': {
                'heart_rate_max': 40,
                'heart_rate_min': 200,
                'spo2_min': 85,
                'duration_min': 10  # seconds
            },
            'heart_attack': {
                'heart_rate_min': 120,
                'stress_level_min': 85,
                'spo2_max': 92,
                'duration_min': 30
            },
            'stroke': {
                'heart_rate_min': 100,
                'stress_level_min': 80,
                'body_temp_max': 38.0,
                'duration_min': 60
            },
            'seizure': {
                'heart_rate_min': 140,
                'stress_level_min': 90,
                'activity_level': 'high',
                'duration_min': 15
            },
            'fainting': {
                'heart_rate_max': 50,
                'spo2_min': 90,
                'stress_level_min': 70,
                'duration_min': 5
            }
        }
        
        # Initialize Firebase
        self._initialize_firebase()
        
        logging.info(f"Emergency AI Processor initialized for user: {user_id}")

    def _initialize_firebase(self):
        """Initialize Firebase Admin SDK"""
        try:
            # Check if Firebase app already exists
            if not firebase_admin._apps:
                # Try to find service account key
                service_account_path = "serviceAccountKey.json"
                
                if os.path.exists(service_account_path):
                    cred = credentials.Certificate(service_account_path)
                    firebase_admin.initialize_app(cred, {
                        'databaseURL': 'https://driversafety-64e47-default-rtdb.europe-west1.firebasedatabase.app/'
                    })
                    logging.info("Firebase initialized successfully with service account")
                else:
                    # Use default credentials (for testing)
                    cred = credentials.ApplicationDefault()
                    firebase_admin.initialize_app(cred, {
                        'databaseURL': 'https://driversafety-64e47-default-rtdb.europe-west1.firebasedatabase.app/'
                    })
                    logging.info("Firebase initialized with default credentials")
            
            self.db_ref = db.reference('/')
            
        except Exception as e:
            logging.error(f"Firebase initialization failed: {e}")
            logging.warning("Running in simulation mode - no real Firebase connection")
            self.db_ref = None

    def start_monitoring(self):
        """Start the emergency monitoring system"""
        if self.is_running:
            logging.warning("Monitoring already running")
            return

        self.is_running = True
        logging.info("Starting emergency health monitoring...")
        
        # Start listening to health data
        if self.db_ref:
            self._setup_firebase_listeners()
        else:
            # Run in simulation mode
            self._start_simulation_mode()
        
        # Start emergency processing thread
        self.emergency_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.emergency_thread.start()
        
        logging.info("Emergency monitoring system active")

    def _start_simulation_mode(self):
        """Start simulation mode for testing without Firebase"""
        logging.info("Running in SIMULATION MODE - Generating test health data")
        
        def simulate_health_data():
            import random
            while self.is_running:
                # Generate random health data for testing
                health_data = {
                    'heart_rate': random.randint(60, 120),
                    'spo2': random.randint(95, 99),
                    'stress_level': random.randint(30, 80),
                    'body_temperature': round(random.uniform(36.0, 37.5), 1),
                    'activity_level': random.choice(['sedentary', 'light', 'moderate']),
                    'sleep_quality': random.randint(60, 95),
                    'timestamp': datetime.now().isoformat()
                }
                
                # Occasionally simulate emergencies for testing
                if random.random() < 0.1:  # 10% chance of emergency
                    health_data['heart_rate'] = random.randint(140, 180)
                    health_data['spo2'] = random.randint(80, 89)
                
                self._health_data_callback_simulated(health_data)
                time.sleep(5)
        
        sim_thread = threading.Thread(target=simulate_health_data, daemon=True)
        sim_thread.start()

    def _health_data_callback_simulated(self, health_data):
        """Simulated health data callback for testing"""
        try:
            self.last_health_data = health_data
            timestamp = health_data.get('timestamp', datetime.now().isoformat())
            
            logging.info(f"SIMULATION - Health data: HR: {health_data.get('heart_rate', 'N/A')}, SpO2: {health_data.get('spo2', 'N/A')}")
            
            # Immediate emergency check
            emergency_level = self._assess_emergency_level(health_data)
            
            if emergency_level != EmergencyLevel.NORMAL:
                self._handle_emergency(emergency_level, health_data)
                
        except Exception as e:
            logging.error(f"Health data callback error: {e}")

    def stop_monitoring(self):
        """Stop the emergency monitoring system"""
        self.is_running = False
        if self.emergency_thread:
            self.emergency_thread.join(timeout=5)
        logging.info("Emergency monitoring stopped")

    def _setup_firebase_listeners(self):
        """Setup Firebase real-time listeners"""
        try:
            # First, check if the database exists by trying to read a value
            test_ref = self.db_ref.child('watch_data').get()
            if test_ref is None:
                logging.warning("Firebase database appears to be empty. Creating initial structure...")
                self._initialize_database_structure()
            
            # Listen for health data
            self.db_ref.child(f'watch_data/{self.user_id}/latest').listen(
                self._health_data_callback
            )
            
            # Listen for vehicle state
            self.db_ref.child(f'vehicle_controls/{self.user_id}/current_state').listen(
                self._vehicle_state_callback
            )
            
            logging.info("Firebase listeners established")
            
        except Exception as e:
            logging.error(f"Firebase listener setup failed: {e}")
            logging.info("Falling back to simulation mode...")
            self._start_simulation_mode()

    def _initialize_database_structure(self):
        """Initialize the database structure if it doesn't exist"""
        try:
            initial_data = {
                'watch_data': {
                    self.user_id: {
                        'latest': {
                            'heart_rate': 72,
                            'spo2': 98,
                            'stress_level': 45,
                            'body_temperature': 36.5,
                            'activity_level': 'sedentary',
                            'sleep_quality': 85,
                            'timestamp': datetime.now().isoformat()
                        }
                    }
                },
                'vehicle_controls': {
                    self.user_id: {
                        'current_state': {
                            'speed': 0,
                            'lane_position': 'center',
                            'following_distance': 2.0,
                            'driver_attention': 'high',
                            'timestamp': datetime.now().isoformat()
                        }
                    }
                }
            }
            
            self.db_ref.set(initial_data)
            logging.info("Initial database structure created")
            
        except Exception as e:
            logging.error(f"Failed to initialize database: {e}")

    def _health_data_callback(self, event):
        """Callback for health data updates"""
        try:
            if event.data:
                health_data = event.data
                self.last_health_data = health_data
                timestamp = health_data.get('timestamp', datetime.now().isoformat())
                
                logging.info(f"Health data received - HR: {health_data.get('heart_rate', 'N/A')}, SpO2: {health_data.get('spo2', 'N/A')}")
                
                # Immediate emergency check
                emergency_level = self._assess_emergency_level(health_data)
                
                if emergency_level != EmergencyLevel.NORMAL:
                    self._handle_emergency(emergency_level, health_data)
                    
        except Exception as e:
            logging.error(f"Health data callback error: {e}")

    def _vehicle_state_callback(self, event):
        """Callback for vehicle state updates"""
        try:
            if event.data:
                self.vehicle_state = event.data
                logging.debug(f"Vehicle state: {self.vehicle_state.get('speed', 'N/A')} km/h")
        except Exception as e:
            logging.error(f"Vehicle state callback error: {e}")

    def _monitoring_loop(self):
        """Main monitoring loop for continuous assessment"""
        while self.is_running:
            try:
                if self.last_health_data:
                    # Continuous monitoring for deteriorating conditions
                    self._continuous_assessment()
                
                time.sleep(2)  # Check every 2 seconds
                
            except Exception as e:
                logging.error(f"Monitoring loop error: {e}")
                time.sleep(5)

    def _assess_emergency_level(self, health_data) -> EmergencyLevel:
        """Assess the emergency level based on health data"""
        heart_rate = health_data.get('heart_rate', 70)
        spo2 = health_data.get('spo2', 98)
        stress_level = health_data.get('stress_level', 50)
        body_temp = health_data.get('body_temperature', 36.5)
        
        # Life-threatening conditions
        if heart_rate < 40 or heart_rate > 180:
            return EmergencyLevel.LIFE_THREATENING
        if spo2 < 85:
            return EmergencyLevel.LIFE_THREATENING
        if body_temp > 40.0 or body_temp < 35.0:
            return EmergencyLevel.LIFE_THREATENING
            
        # Critical conditions
        if heart_rate < 50 or heart_rate > 140:
            return EmergencyLevel.CRITICAL
        if spo2 < 90:
            return EmergencyLevel.CRITICAL
        if stress_level > 90:
            return EmergencyLevel.CRITICAL
            
        # High alert conditions
        if heart_rate < 60 or heart_rate > 120:
            return EmergencyLevel.HIGH_ALERT
        if spo2 < 94:
            return EmergencyLevel.HIGH_ALERT
        if stress_level > 80:
            return EmergencyLevel.HIGH_ALERT
            
        # Warning conditions
        if heart_rate < 65 or heart_rate > 100:
            return EmergencyLevel.WARNING
        if spo2 < 96:
            return EmergencyLevel.WARNING
        if stress_level > 70:
            return EmergencyLevel.WARNING
            
        return EmergencyLevel.NORMAL

    def _detect_medical_condition(self, health_data) -> Optional[MedicalCondition]:
        """Detect specific medical conditions"""
        heart_rate = health_data.get('heart_rate', 70)
        spo2 = health_data.get('spo2', 98)
        stress_level = health_data.get('stress_level', 50)
        body_temp = health_data.get('body_temperature', 36.5)
        activity_level = health_data.get('activity_level', 'sedentary')
        
        # Cardiac arrest detection
        if (heart_rate < 40 or heart_rate > 200) and spo2 < 85:
            return MedicalCondition.CARDIAC_ARREST
            
        # Heart attack detection
        if heart_rate > 120 and stress_level > 85 and spo2 < 92:
            return MedicalCondition.HEART_ATTACK
            
        # Stroke detection
        if heart_rate > 100 and stress_level > 80 and body_temp > 38.0:
            return MedicalCondition.STROKE
            
        # Seizure detection
        if heart_rate > 140 and stress_level > 90 and activity_level == 'high':
            return MedicalCondition.SEIZURE
            
        # Fainting detection
        if heart_rate < 50 and spo2 < 90:
            return MedicalCondition.FAINTING
            
        # Respiratory distress
        if spo2 < 88 and heart_rate > 110:
            return MedicalCondition.RESPIRATORY_DISTRESS
            
        return None

    def _continuous_assessment(self):
        """Continuous assessment for deteriorating conditions"""
        if not self.last_health_data:
            return
            
        # Check for condition deterioration
        medical_condition = self._detect_medical_condition(self.last_health_data)
        
        if medical_condition:
            logging.warning(f"Medical condition detected: {medical_condition.value}")
            self._handle_medical_emergency(medical_condition, self.last_health_data)

    def _handle_emergency(self, emergency_level: EmergencyLevel, health_data: Dict):
        """Handle emergency based on severity level"""
        timestamp = datetime.now().isoformat()
        medical_condition = self._detect_medical_condition(health_data)
        
        emergency_event = {
            'timestamp': timestamp,
            'emergency_level': emergency_level.value,
            'medical_condition': medical_condition.value if medical_condition else 'unknown',
            'health_data': health_data,
            'vehicle_state': self.vehicle_state
        }
        
        self.emergency_history.append(emergency_event)
        
        logging.warning(f"EMERGENCY: {emergency_level.value} - {medical_condition.value if medical_condition else 'General emergency'}")
        
        # Take appropriate actions
        if emergency_level == EmergencyLevel.LIFE_THREATENING:
            self._execute_life_threatening_protocol(medical_condition, health_data)
        elif emergency_level == EmergencyLevel.CRITICAL:
            self._execute_critical_protocol(medical_condition, health_data)
        elif emergency_level == EmergencyLevel.HIGH_ALERT:
            self._execute_high_alert_protocol(medical_condition, health_data)

    def _handle_medical_emergency(self, condition: MedicalCondition, health_data: Dict):
        """Handle specific medical emergencies"""
        logging.critical(f"MEDICAL EMERGENCY: {condition.value}")
        
        protocol_actions = {
            MedicalCondition.CARDIAC_ARREST: self._cardiac_arrest_protocol,
            MedicalCondition.HEART_ATTACK: self._heart_attack_protocol,
            MedicalCondition.STROKE: self._stroke_protocol,
            MedicalCondition.SEIZURE: self._seizure_protocol,
            MedicalCondition.FAINTING: self._fainting_protocol,
            MedicalCondition.RESPIRATORY_DISTRESS: self._respiratory_distress_protocol
        }
        
        action = protocol_actions.get(condition, self._general_medical_protocol)
        action(health_data)

    def _execute_life_threatening_protocol(self, condition: Optional[MedicalCondition], health_data: Dict):
        """Execute life-threatening emergency protocol"""
        logging.critical("LIFE-THREATENING PROTOCOL ACTIVATED")
        
        # Immediate vehicle actions
        self._send_stm32_command({
            'action': 'emergency_stop',
            'priority': 'highest',
            'parameters': {
                'stop_type': 'immediate_safe',
                'activate_hazards': True,
                'alert_authorities': True
            }
        })
        
        # Call emergency services
        self._call_emergency_services(condition, health_data)
        
        # Send mobile app alert
        self._send_mobile_alert({
            'type': 'life_threatening_emergency',
            'message': f'IMMEDIATE MEDICAL ATTENTION REQUIRED: {condition.value if condition else "Critical health condition"}',
            'actions': ['call_emergency', 'prepare_medical_info', 'stay_calm'],
            'priority': 'critical'
        })

    def _execute_critical_protocol(self, condition: Optional[MedicalCondition], health_data: Dict):
        """Execute critical emergency protocol"""
        logging.critical("CRITICAL PROTOCOL ACTIVATED")
        
        # Vehicle safety actions
        self._send_stm32_command({
            'action': 'prepare_emergency_stop',
            'priority': 'high',
            'parameters': {
                'reduce_speed': True,
                'target_speed': 40,
                'find_safe_stop': True,
                'activate_hazards': True
            }
        })
        
        # Send mobile app alert
        self._send_mobile_alert({
            'type': 'critical_health_alert',
            'message': f'CRITICAL HEALTH CONDITION: {condition.value if condition else "Immediate attention needed"}',
            'actions': ['prepare_to_stop', 'call_emergency_if_worsens', 'monitor_vitals'],
            'priority': 'high'
        })

    def _cardiac_arrest_protocol(self, health_data: Dict):
        """Cardiac arrest emergency protocol"""
        logging.critical("CARDIAC ARREST PROTOCOL")
        
        self._send_stm32_command({
            'action': 'emergency_stop_and_park',
            'priority': 'highest',
            'parameters': {
                'stop_immediately': True,
                'park_vehicle': True,
                'unlock_doors': True,
                'activate_emergency_lights': True,
                'call_emergency': True
            }
        })
        
        self._send_mobile_alert({
            'type': 'cardiac_arrest',
            'message': 'CARDIAC ARREST DETECTED! Vehicle stopping immediately. Emergency services notified.',
            'actions': ['call_emergency_immediately', 'prepare_aed_if_available', 'perform_cpr_if_trained'],
            'priority': 'critical'
        })

    def _send_stm32_command(self, command_data: Dict):
        """Send command to STM32 car system"""
        try:
            if self.db_ref:
                # Send to Firebase for STM32 to read
                self.db_ref.child(f'stm32_commands/{self.user_id}/last_command').set({
                    **command_data,
                    'timestamp': datetime.now().isoformat(),
                    'executed': False
                })
                
                logging.info(f"STM32 Command sent: {command_data['action']}")
            else:
                logging.info(f"SIMULATION - STM32 Command: {command_data['action']}")
                
        except Exception as e:
            logging.error(f"STM32 command send failed: {e}")

    def _send_mobile_alert(self, alert_data: Dict):
        """Send alert to mobile app"""
        try:
            if self.db_ref:
                self.db_ref.child(f'mobile_alerts/{self.user_id}/last_alert').set({
                    **alert_data,
                    'timestamp': datetime.now().isoformat(),
                    'acknowledged': False
                })
                
                logging.info(f"Mobile alert sent: {alert_data['type']}")
            else:
                logging.info(f"SIMULATION - Mobile Alert: {alert_data['type']}")
                
        except Exception as e:
            logging.error(f"Mobile alert send failed: {e}")

    def _call_emergency_services(self, condition: Optional[MedicalCondition], health_data: Dict):
        """Simulate calling emergency services"""
        try:
            emergency_data = {
                'user_id': self.user_id,
                'medical_condition': condition.value if condition else 'unknown',
                'health_data': health_data,
                'vehicle_location': self.vehicle_state.get('location', 'unknown'),
                'timestamp': datetime.now().isoformat(),
                'priority': 'highest'
            }
            
            if self.db_ref:
                # Send to Firebase for emergency services integration
                self.db_ref.child(f'emergency_calls/{self.user_id}/active').set(emergency_data)
                
            logging.critical("EMERGENCY SERVICES NOTIFIED")
            
        except Exception as e:
            logging.error(f"Emergency services call failed: {e}")

    def get_emergency_history(self) -> List[Dict]:
        """Get emergency history"""
        return self.emergency_history.copy()

    def get_current_status(self) -> Dict:
        """Get current system status"""
        return {
            'is_running': self.is_running,
            'last_health_check': self.last_health_data.get('timestamp') if self.last_health_data else None,
            'active_emergencies': len([e for e in self.emergency_history 
                                    if datetime.fromisoformat(e['timestamp']) > 
                                    datetime.now() - timedelta(minutes=5)]),
            'system_status': 'active' if self.is_running else 'inactive',
            'firebase_connected': self.db_ref is not None
        }

def main():
    """Main function to run the emergency AI processor"""
    processor = EmergencyAIProcessor(user_id="user_123")
    
    try:
        processor.start_monitoring()
        
        print("Emergency AI Processor Started!")
        print("Press Ctrl+C to stop")
        print("Monitoring health data and vehicle state...")
        
        # Keep the main thread alive and show status
        while True:
            status = processor.get_current_status()
            print(f"\rStatus: {status['system_status']} | Emergencies: {status['active_emergencies']} | Firebase: {'Connected' if status['firebase_connected'] else 'Simulation'}", end="", flush=True)
            time.sleep(2)
            
    except KeyboardInterrupt:
        print("\nShutting down emergency AI processor...")
        processor.stop_monitoring()
    except Exception as e:
        print(f"Fatal error: {e}")
        processor.stop_monitoring()

if __name__ == "__main__":
    main()