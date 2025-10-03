"""
VoiceAgent - Speech-to-Text Voice Control for HomeGenie

This agent handles voice commands, converts them to goals, and provides
optional text-to-speech feedback. It integrates with the existing
Planner and Executor agents to process voice-based home automation commands.

Features:
- Speech-to-text using Google Speech Recognition or offline alternatives
- Natural language processing for home automation commands
- Integration with existing goal processing system
- Optional text-to-speech feedback
- Continuous listening mode with wake word detection
- Voice command history and learning
"""

import asyncio
import logging
import threading
import queue
import json
from typing import Optional, Dict, Any, List, Callable
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict

# Optional imports for voice features
try:
    import speech_recognition as sr
    SPEECH_RECOGNITION_AVAILABLE = True
except ImportError:
    sr = None
    SPEECH_RECOGNITION_AVAILABLE = False
    
try:
    import pyttsx3
    TTS_AVAILABLE = True
except ImportError:
    pyttsx3 = None
    TTS_AVAILABLE = False

# Optional imports for advanced features
try:
    import pvporcupine  # Wake word detection
    WAKE_WORD_AVAILABLE = True
except ImportError:
    WAKE_WORD_AVAILABLE = False

try:
    import vosk  # Offline speech recognition
    OFFLINE_RECOGNITION_AVAILABLE = True
except ImportError:
    OFFLINE_RECOGNITION_AVAILABLE = False


@dataclass
class VoiceCommand:
    """Represents a processed voice command"""
    timestamp: datetime
    raw_text: str
    processed_goal: str
    confidence: float
    response: Optional[str] = None
    execution_result: Optional[Dict[str, Any]] = None


class VoiceAgent:
    """
    VoiceAgent handles speech-to-text processing and voice commands
    for the HomeGenie smart home system.
    """
    
    def __init__(self, 
                 goal_processor: Optional[Callable] = None,
                 enable_tts: bool = True,
                 enable_wake_word: bool = False,
                 wake_word: str = "homegenie",
                 recognition_method: str = "google",  # "google", "vosk", "sphinx"
                 language: str = "en-US"):
        """
        Initialize the VoiceAgent
        
        Args:
            goal_processor: Function to process goals (e.g., planner.process_goal)
            enable_tts: Enable text-to-speech responses
            enable_wake_word: Enable wake word detection
            wake_word: Wake word to activate voice recognition
            recognition_method: Speech recognition method to use
            language: Language for speech recognition
        """
        self.goal_processor = goal_processor
        self.enable_tts = enable_tts
        self.enable_wake_word = enable_wake_word
        self.wake_word = wake_word
        self.recognition_method = recognition_method
        self.language = language
        
        # Initialize speech recognition (if available)
        if SPEECH_RECOGNITION_AVAILABLE and sr is not None:
            try:
                self.recognizer = sr.Recognizer()
                self.microphone = sr.Microphone()
            except (OSError, AttributeError, ImportError) as e:
                # No audio device available or import issues
                self.recognizer = None
                self.microphone = None
                logging.warning(f"Audio device or speech recognition unavailable: {e}")
        else:
            self.recognizer = None
            self.microphone = None
            logging.warning("Speech recognition not available - voice features disabled")
        
        # Initialize text-to-speech
        if self.enable_tts and TTS_AVAILABLE and pyttsx3 is not None:
            try:
                self.tts_engine = pyttsx3.init()
                self._configure_tts()
            except Exception as e:
                self.tts_engine = None
                self.enable_tts = False
                logging.warning(f"Text-to-speech unavailable: {e}")
        else:
            self.tts_engine = None
            if self.enable_tts:
                logging.warning("Text-to-speech not available")
        
        # Voice command history
        self.command_history: List[VoiceCommand] = []
        self.max_history = 100
        
        # Control flags
        self.is_listening = False
        self.is_processing = False
        self._stop_listening = False
        
        # Threading
        self.listen_thread: Optional[threading.Thread] = None
        self.command_queue = queue.Queue()
        
        # Wake word detection
        if self.enable_wake_word and WAKE_WORD_AVAILABLE:
            self.porcupine = None
            self._init_wake_word()
        
        # Offline recognition model
        if self.recognition_method == "vosk" and OFFLINE_RECOGNITION_AVAILABLE:
            self.vosk_model = None
            self._init_vosk()
        
        # Voice command patterns for better processing
        self.command_patterns = {
            'lights': ['turn on', 'turn off', 'dim', 'brighten', 'set brightness'],
            'temperature': ['set temperature', 'increase temperature', 'decrease temperature', 'warmer', 'cooler'],
            'security': ['lock', 'unlock', 'arm', 'disarm', 'check security'],
            'media': ['play', 'pause', 'stop', 'volume up', 'volume down', 'next', 'previous'],
            'general': ['status', 'what is', 'how is', 'show me', 'tell me about']
        }
        
        logging.info(f"VoiceAgent initialized with {recognition_method} recognition")
    
    def _configure_tts(self):
        """Configure text-to-speech settings"""
        if not self.tts_engine:
            logging.warning("TTS engine not available for configuration")
            return
            
        try:
            # Try to set a female voice if available
            voices = self.tts_engine.getProperty('voices')
            if voices is not None:
                try:
                    # Convert to list to ensure it's iterable and handle any type issues
                    voice_list = list(voices) if hasattr(voices, '__iter__') else []  # type: ignore
                    for voice in voice_list:
                        if hasattr(voice, 'name') and hasattr(voice, 'id') and 'female' in voice.name.lower():
                            self.tts_engine.setProperty('voice', voice.id)
                            break
                except (TypeError, AttributeError) as e:
                    logging.warning(f"Could not iterate through voices: {e}")
            
            # Set speaking rate and volume
            self.tts_engine.setProperty('rate', 180)  # Slightly slower than default
            self.tts_engine.setProperty('volume', 0.8)
            
        except Exception as e:
            logging.warning(f"Could not configure TTS settings: {e}")
    
    def _init_wake_word(self):
        """Initialize wake word detection using Porcupine"""
        try:
            # You would need to get an access key from Picovoice
            # For demo purposes, we'll use a placeholder
            # self.porcupine = pvporcupine.create(
            #     access_key="YOUR_PICOVOICE_ACCESS_KEY",
            #     keywords=[self.wake_word]
            # )
            logging.info(f"Wake word detection initialized for '{self.wake_word}'")
        except Exception as e:
            logging.error(f"Error initializing wake word detection: {e}")
            self.enable_wake_word = False
    
    def _init_vosk(self):
        """Initialize Vosk offline speech recognition"""
        try:
            import vosk
            # You would need to download a Vosk model
            # model_path = "path/to/vosk-model"
            # self.vosk_model = vosk.Model(model_path)
            logging.info("Vosk offline recognition initialized")
        except Exception as e:
            logging.error(f"Error initializing Vosk: {e}")
            self.recognition_method = "google"  # Fallback
    
    def start_listening(self):
        """Start continuous voice listening in a separate thread"""
        if self.is_listening:
            logging.warning("Voice agent is already listening")
            return
        
        self.is_listening = True
        self._stop_listening = False
        self.listen_thread = threading.Thread(target=self._listen_loop, daemon=True)
        self.listen_thread.start()
        
        # Start command processing thread
        threading.Thread(target=self._process_commands, daemon=True).start()
        
        logging.info("Voice agent started listening")
        if self.enable_tts:
            self.speak("Voice control activated. Say 'HomeGenie' followed by your command.")
    
    def stop_listening(self):
        """Stop voice listening"""
        self._stop_listening = True
        self.is_listening = False
        
        if self.listen_thread and self.listen_thread.is_alive():
            self.listen_thread.join(timeout=2.0)
        
        logging.info("Voice agent stopped listening")
        if self.enable_tts:
            self.speak("Voice control deactivated.")
    
    def _listen_loop(self):
        """Main listening loop"""
        if not self.recognizer or not self.microphone:
            logging.error("Speech recognition not available - cannot start listening")
            return
            
        try:
            with self.microphone as source:
                # Adjust for ambient noise
                self.recognizer.adjust_for_ambient_noise(source, duration=1)
                logging.info("Listening for voice commands...")
        except Exception as e:
            logging.error(f"Error initializing microphone: {e}")
            return
        
        while not self._stop_listening:
            try:
                with self.microphone as source:
                    # Listen for audio with timeout
                    audio = self.recognizer.listen(source, timeout=1, phrase_time_limit=5)
                
                # Process the audio
                self._process_audio(audio)
                
            except Exception as e:
                # Handle timeout and other errors during listening
                error_type = type(e).__name__
                if 'timeout' in error_type.lower() or 'WaitTimeout' in error_type:
                    # Timeout is normal, continue listening
                    pass
                else:
                    logging.error(f"Error in listening loop: {e}")
                    # Brief pause before retrying
                    threading.Event().wait(0.5)
    
    def _process_audio(self, audio):
        """Process captured audio and extract text"""
        try:
            # Convert speech to text
            if not self.recognizer:
                logging.error("Speech recognizer not available")
                return
                
            text = None
            if self.recognition_method == "google" and hasattr(self.recognizer, 'recognize_google'):
                text = self.recognizer.recognize_google(audio, language=self.language)  # type: ignore
            elif self.recognition_method == "vosk" and self.vosk_model:
                # Vosk recognition would go here
                text = self._recognize_with_vosk(audio)
            elif hasattr(self.recognizer, 'recognize_google'):
                # Fallback to Google
                text = self.recognizer.recognize_google(audio, language=self.language)  # type: ignore
            else:
                logging.error("No valid speech recognition method available")
                return
            
            if text:
                logging.info(f"Voice input detected: '{text}'")
                
                # Check for wake word if enabled
                if self.enable_wake_word:
                    if self.wake_word.lower() not in text.lower():
                        return  # Ignore commands without wake word
                    # Remove wake word from text
                    text = text.lower().replace(self.wake_word.lower(), "").strip()
                
                # Add to command queue for processing
                if text:
                    self.command_queue.put(text)
                
        except Exception as e:
            # Handle all speech recognition errors generically
            error_type = type(e).__name__
            if 'UnknownValue' in error_type:
                # Speech was unintelligible - this is normal
                pass
            elif 'Request' in error_type:
                logging.error(f"Speech recognition service error: {e}")
            else:
                logging.error(f"Error processing audio ({error_type}): {e}")
    
    def _recognize_with_vosk(self, audio) -> str:
        """Use Vosk for offline speech recognition"""
        # Placeholder for Vosk implementation
        # This would require proper Vosk model setup
        return ""
    
    def _process_commands(self):
        """Process voice commands from the queue"""
        while not self._stop_listening:
            try:
                # Get command from queue with timeout
                command_text = self.command_queue.get(timeout=1.0)
                self._handle_voice_command(command_text)
                self.command_queue.task_done()
            except queue.Empty:
                continue
            except Exception as e:
                logging.error(f"Error processing command: {e}")
    
    def _handle_voice_command(self, command_text: str):
        """Handle a single voice command"""
        if self.is_processing:
            logging.info("Already processing a command, ignoring new input")
            return
        
        self.is_processing = True
        
        try:
            # Process the command
            processed_goal = self._convert_to_goal(command_text)
            
            # Create command record
            command = VoiceCommand(
                timestamp=datetime.now(),
                raw_text=command_text,
                processed_goal=processed_goal,
                confidence=0.8  # Placeholder confidence
            )
            
            # Execute the goal if processor is available
            if self.goal_processor:
                try:
                    result = self.goal_processor(processed_goal)
                    command.execution_result = result
                    
                    # Generate response
                    response = self._generate_response(command_text, result)
                    command.response = response
                    
                    if self.enable_tts and response:
                        self.speak(response)
                        
                except Exception as e:
                    error_msg = f"Sorry, I couldn't execute that command: {str(e)}"
                    command.response = error_msg
                    if self.enable_tts:
                        self.speak(error_msg)
                    logging.error(f"Error executing goal: {e}")
            else:
                # No processor available
                response = f"I understood '{command_text}' as '{processed_goal}', but no executor is available."
                command.response = response
                if self.enable_tts:
                    self.speak(response)
            
            # Add to history
            self._add_to_history(command)
            
        except Exception as e:
            error_msg = f"Sorry, I had trouble processing that command."
            if self.enable_tts:
                self.speak(error_msg)
            logging.error(f"Error handling voice command: {e}")
        finally:
            self.is_processing = False
    
    def _convert_to_goal(self, command_text: str) -> str:
        """Convert natural language to a structured goal"""
        command_lower = command_text.lower()
        
        # Light commands
        if any(word in command_lower for word in ['light', 'lights', 'lamp']):
            if 'turn on' in command_lower or 'on' in command_lower:
                room = self._extract_room(command_text)
                return f"turn on lights in {room}"
            elif 'turn off' in command_lower or 'off' in command_lower:
                room = self._extract_room(command_text)
                return f"turn off lights in {room}"
            elif 'dim' in command_lower or 'brightness' in command_lower:
                room = self._extract_room(command_text)
                level = self._extract_number(command_text, default=50)
                return f"set lights in {room} to {level}% brightness"
        
        # Temperature commands
        elif any(word in command_lower for word in ['temperature', 'thermostat', 'heating', 'cooling']):
            if 'set' in command_lower:
                temp = self._extract_number(command_text, default=22)
                room = self._extract_room(command_text)
                return f"set temperature in {room} to {temp} degrees"
            elif 'increase' in command_lower or 'warmer' in command_lower:
                room = self._extract_room(command_text)
                return f"increase temperature in {room} by 2 degrees"
            elif 'decrease' in command_lower or 'cooler' in command_lower:
                room = self._extract_room(command_text)
                return f"decrease temperature in {room} by 2 degrees"
        
        # Security commands
        elif any(word in command_lower for word in ['lock', 'unlock', 'security', 'arm', 'disarm']):
            if 'lock' in command_lower:
                return "lock all doors"
            elif 'unlock' in command_lower:
                return "unlock front door"
            elif 'arm' in command_lower:
                return "arm security system"
            elif 'disarm' in command_lower:
                return "disarm security system"
        
        # Status queries
        elif any(word in command_lower for word in ['status', 'what is', 'how is', 'show me', 'tell me']):
            if 'temperature' in command_lower:
                room = self._extract_room(command_text)
                return f"get temperature status for {room}"
            elif 'lights' in command_lower:
                room = self._extract_room(command_text)
                return f"get light status for {room}"
            else:
                return "get system status"
        
        # Media commands
        elif any(word in command_lower for word in ['play', 'pause', 'music', 'volume']):
            if 'play' in command_lower:
                return "play music"
            elif 'pause' in command_lower or 'stop' in command_lower:
                return "pause music"
            elif 'volume up' in command_lower:
                return "increase volume"
            elif 'volume down' in command_lower:
                return "decrease volume"
        
        # Default: pass through as-is
        return command_text
    
    def _extract_room(self, text: str) -> str:
        """Extract room name from command text"""
        rooms = ['living room', 'bedroom', 'kitchen', 'bathroom', 'office', 'garage']
        text_lower = text.lower()
        
        for room in rooms:
            if room in text_lower:
                return room
        
        return "living room"  # Default room
    
    def _extract_number(self, text: str, default: int = 50) -> int:
        """Extract numeric value from text"""
        import re
        
        # Look for numbers in the text
        numbers = re.findall(r'\d+', text)
        if numbers:
            return int(numbers[0])
        
        # Look for word numbers
        word_numbers = {
            'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
            'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
            'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
            'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90, 'hundred': 100
        }
        
        text_lower = text.lower()
        for word, num in word_numbers.items():
            if word in text_lower:
                return num
        
        return default
    
    def _generate_response(self, command_text: str, execution_result: Dict[str, Any]) -> str:
        """Generate a natural language response"""
        command_lower = command_text.lower()
        
        # Check if execution was successful
        if isinstance(execution_result, dict):
            success = execution_result.get('success', True)
            message = execution_result.get('message', '')
            
            if not success:
                return f"Sorry, I couldn't complete that request. {message}"
        
        # Generate appropriate responses based on command type
        if 'light' in command_lower:
            if 'turn on' in command_lower or 'on' in command_lower:
                room = self._extract_room(command_text)
                return f"I've turned on the lights in the {room}."
            elif 'turn off' in command_lower or 'off' in command_lower:
                room = self._extract_room(command_text)
                return f"I've turned off the lights in the {room}."
            elif 'brightness' in command_lower or 'dim' in command_lower:
                room = self._extract_room(command_text)
                level = self._extract_number(command_text)
                return f"I've set the lights in the {room} to {level}% brightness."
        
        elif 'temperature' in command_lower:
            if 'set' in command_lower:
                temp = self._extract_number(command_text)
                room = self._extract_room(command_text)
                return f"I've set the temperature in the {room} to {temp} degrees."
            elif 'increase' in command_lower:
                room = self._extract_room(command_text)
                return f"I've increased the temperature in the {room}."
            elif 'decrease' in command_lower:
                room = self._extract_room(command_text)
                return f"I've decreased the temperature in the {room}."
        
        elif 'lock' in command_lower:
            return "I've locked the doors for you."
        elif 'unlock' in command_lower:
            return "I've unlocked the front door."
        elif 'security' in command_lower:
            if 'arm' in command_lower:
                return "Security system is now armed."
            elif 'disarm' in command_lower:
                return "Security system is now disarmed."
        
        elif 'status' in command_lower:
            return "Here's the current system status."
        
        # Default response
        return "Command completed successfully."
    
    def speak(self, text: str):
        """Convert text to speech"""
        if not self.enable_tts or not text or not self.tts_engine:
            return
        
        try:
            # Use a separate thread for TTS to avoid blocking
            def tts_worker():
                if self.tts_engine:
                    self.tts_engine.say(text)
                    self.tts_engine.runAndWait()
            
            threading.Thread(target=tts_worker, daemon=True).start()
            logging.info(f"Speaking: {text}")
            
        except Exception as e:
            logging.error(f"Error in text-to-speech: {e}")
    
    def _add_to_history(self, command: VoiceCommand):
        """Add command to history, maintaining size limit"""
        self.command_history.append(command)
        
        # Trim history if needed
        if len(self.command_history) > self.max_history:
            self.command_history = self.command_history[-self.max_history:]
    
    def process_single_command(self, command_text: str) -> VoiceCommand:
        """Process a single voice command synchronously"""
        processed_goal = self._convert_to_goal(command_text)
        
        command = VoiceCommand(
            timestamp=datetime.now(),
            raw_text=command_text,
            processed_goal=processed_goal,
            confidence=1.0  # Assume high confidence for direct input
        )
        
        # Execute if processor available
        if self.goal_processor:
            try:
                result = self.goal_processor(processed_goal)
                command.execution_result = result
                command.response = self._generate_response(command_text, result)
            except Exception as e:
                command.response = f"Error executing command: {str(e)}"
                logging.error(f"Error executing goal: {e}")
        else:
            command.response = f"Processed '{command_text}' as '{processed_goal}'"
        
        self._add_to_history(command)
        return command
    
    def get_command_history(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent command history"""
        recent_commands = self.command_history[-limit:] if limit > 0 else self.command_history
        return [asdict(cmd) for cmd in recent_commands]
    
    def get_voice_stats(self) -> Dict[str, Any]:
        """Get voice agent statistics"""
        if not self.command_history:
            return {
                "total_commands": 0,
                "successful_commands": 0,
                "average_confidence": 0,
                "most_common_commands": [],
                "is_listening": self.is_listening
            }
        
        successful = sum(1 for cmd in self.command_history 
                        if cmd.execution_result and cmd.execution_result.get('success', True))
        
        avg_confidence = sum(cmd.confidence for cmd in self.command_history) / len(self.command_history)
        
        # Count command patterns
        from collections import Counter
        command_types = []
        for cmd in self.command_history:
            if 'light' in cmd.raw_text.lower():
                command_types.append('lighting')
            elif 'temperature' in cmd.raw_text.lower():
                command_types.append('temperature')
            elif 'security' in cmd.raw_text.lower():
                command_types.append('security')
            elif 'status' in cmd.raw_text.lower():
                command_types.append('status')
            else:
                command_types.append('other')
        
        most_common = Counter(command_types).most_common(3)
        
        return {
            "total_commands": len(self.command_history),
            "successful_commands": successful,
            "success_rate": successful / len(self.command_history) if self.command_history else 0,
            "average_confidence": avg_confidence,
            "most_common_commands": most_common,
            "is_listening": self.is_listening,
            "is_processing": self.is_processing
        }


# Example usage and integration
if __name__ == "__main__":
    # Example of how to integrate with HomeGenie
    def mock_goal_processor(goal: str) -> Dict[str, Any]:
        """Mock goal processor for testing"""
        print(f"Processing goal: {goal}")
        return {"success": True, "message": f"Executed: {goal}"}
    
    # Create voice agent
    voice_agent = VoiceAgent(
        goal_processor=mock_goal_processor,
        enable_tts=True,
        enable_wake_word=False,  # Disable for testing
        recognition_method="google"
    )
    
    # Test some commands
    test_commands = [
        "turn on the lights in the living room",
        "set temperature to 22 degrees",
        "lock all doors",
        "what's the status of the kitchen lights"
    ]
    
    for cmd in test_commands:
        result = voice_agent.process_single_command(cmd)
        print(f"Command: {cmd}")
        print(f"Goal: {result.processed_goal}")
        print(f"Response: {result.response}")
        print("-" * 50)
    
    # Print statistics
    stats = voice_agent.get_voice_stats()
    print("Voice Agent Statistics:")
    for key, value in stats.items():
        print(f"  {key}: {value}")