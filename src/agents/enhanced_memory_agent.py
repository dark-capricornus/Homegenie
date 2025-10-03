"""
Enhanced MemoryAgent with Behavioral Learning

This enhanced version of the MemoryAgent includes behavioral pattern detection,
learning from user preferences, and proactive suggestions based on historical data.

Features:
- Timestamped interaction history
- Pattern detection for user behavior
- Preference learning and adaptation
- Proactive suggestions based on patterns
- Device usage analytics
- Time-based behavior analysis
- Contextual recommendations
"""

import asyncio
import json
import logging
from datetime import datetime, timedelta, time
from typing import Dict, Any, List, Optional, Tuple
from collections import defaultdict, Counter
from dataclasses import dataclass
import statistics
from enum import Enum


class InteractionType(Enum):
    """Types of user interactions"""
    DEVICE_COMMAND = "device_command"
    GOAL_REQUEST = "goal_request"
    VOICE_COMMAND = "voice_command"
    SCHEDULE_CREATE = "schedule_create"
    PREFERENCE_SET = "preference_set"
    STATUS_CHECK = "status_check"


@dataclass
class BehaviorPattern:
    """Represents a detected behavior pattern"""
    pattern_id: str
    description: str
    frequency: int
    confidence: float
    last_occurrence: datetime
    time_patterns: List[str]  # e.g., ["morning", "evening"]
    devices_involved: List[str]
    conditions: Dict[str, Any]


@dataclass
class ProactiveSuggestion:
    """Represents a proactive suggestion"""
    suggestion_id: str
    title: str
    description: str
    action: Dict[str, Any]
    confidence: float
    reason: str
    expires_at: datetime


class EnhancedMemoryAgent:
    """
    Enhanced MemoryAgent with behavioral learning capabilities.
    
    This agent learns from user interactions to detect patterns,
    adapt to preferences, and provide proactive suggestions.
    """
    
    def __init__(self, context_store=None):
        """
        Initialize the Enhanced Memory Agent
        
        Args:
            context_store: Reference to the main context store
        """
        self.context_store = context_store
        
        # Core history storage
        self._history: Dict[str, List[Dict[str, Any]]] = {}
        self._max_history_per_user = 1000
        
        # Behavioral learning data
        self._behavior_patterns: Dict[str, List[BehaviorPattern]] = {}
        self._user_preferences: Dict[str, Dict[str, Any]] = {}
        self._device_usage_stats: Dict[str, Dict[str, Any]] = {}
        self._time_patterns: Dict[str, Dict[str, List[datetime]]] = defaultdict(lambda: defaultdict(list))
        
        # Proactive suggestions
        self._active_suggestions: Dict[str, List[ProactiveSuggestion]] = {}
        self._suggestion_counter = 0
        
        # Learning parameters
        self.pattern_detection_threshold = 3  # Minimum occurrences to detect pattern
        self.suggestion_confidence_threshold = 0.7
        self.learning_window_days = 30
        
        # Analytics
        self._analytics_cache: Dict[str, Dict[str, Any]] = {}
        self._cache_expiry: Dict[str, datetime] = {}
        
        logging.info("Enhanced Memory Agent initialized with behavioral learning")
    
    def add_entry(self, user_id: str, entry_type: str, data: Dict[str, Any]) -> None:
        """
        Add an entry to user's history with enhanced learning.
        
        Args:
            user_id: User identifier
            entry_type: Type of interaction (InteractionType)
            data: Interaction data
        """
        if user_id not in self._history:
            self._history[user_id] = []
        
        timestamp = datetime.now()
        entry = {
            "timestamp": timestamp.isoformat(),
            "type": entry_type,
            "data": data,
            "processed": False  # For learning pipeline
        }
        
        self._history[user_id].append(entry)
        
        # Maintain history limit
        if len(self._history[user_id]) > self._max_history_per_user:
            self._history[user_id].pop(0)
        
        # Update learning data
        self._update_learning_data(user_id, entry_type, data, timestamp)
        
        # Detect patterns (async to avoid blocking)
        asyncio.create_task(self._detect_patterns_async(user_id))
        
        # Generate suggestions if appropriate
        asyncio.create_task(self._update_suggestions_async(user_id))
        
        # Invalidate analytics cache
        if user_id in self._analytics_cache:
            del self._analytics_cache[user_id]
        
        logging.debug(f"Added {entry_type} entry for user {user_id} with learning")
    
    def _update_learning_data(self, user_id: str, entry_type: str, data: Dict[str, Any], timestamp: datetime):
        """Update various learning data structures"""
        
        # Update device usage statistics
        if entry_type == InteractionType.DEVICE_COMMAND.value:
            device = data.get('device', 'unknown')
            action = data.get('action', 'unknown')
            
            if user_id not in self._device_usage_stats:
                self._device_usage_stats[user_id] = {}
            
            device_stats = self._device_usage_stats[user_id].setdefault(device, {
                'total_uses': 0,
                'actions': Counter(),
                'times_used': [],
                'last_used': None
            })
            
            device_stats['total_uses'] += 1
            device_stats['actions'][action] += 1
            device_stats['times_used'].append(timestamp)
            device_stats['last_used'] = timestamp
            
            # Keep only recent usage times
            cutoff = timestamp - timedelta(days=self.learning_window_days)
            device_stats['times_used'] = [t for t in device_stats['times_used'] if t > cutoff]
        
        # Update time patterns
        time_category = self._categorize_time(timestamp)
        self._time_patterns[user_id][entry_type].append(timestamp)
        
        # Update preferences based on repeated actions
        self._update_preferences(user_id, entry_type, data)
    
    def _categorize_time(self, timestamp: datetime) -> str:
        """Categorize time into periods"""
        hour = timestamp.hour
        
        if 5 <= hour < 12:
            return "morning"
        elif 12 <= hour < 17:
            return "afternoon"
        elif 17 <= hour < 21:
            return "evening"
        else:
            return "night"
    
    def _update_preferences(self, user_id: str, entry_type: str, data: Dict[str, Any]):
        """Learn and update user preferences"""
        if user_id not in self._user_preferences:
            self._user_preferences[user_id] = {
                'device_preferences': {},
                'time_preferences': {},
                'action_preferences': {},
                'learned_at': datetime.now()
            }
        
        prefs = self._user_preferences[user_id]
        
        # Learn device preferences
        if entry_type == InteractionType.DEVICE_COMMAND.value:
            device = data.get('device', '')
            action = data.get('action', '')
            
            # Track preferred settings for devices
            if device and action:
                device_prefs = prefs['device_preferences'].setdefault(device, {
                    'preferred_actions': Counter(),
                    'settings': {}
                })
                
                device_prefs['preferred_actions'][action] += 1
                
                # Learn specific settings
                for key, value in data.items():
                    if key not in ['device', 'action', 'timestamp']:
                        if key not in device_prefs['settings']:
                            device_prefs['settings'][key] = []
                        device_prefs['settings'][key].append(value)
                        
                        # Keep only recent settings
                        if len(device_prefs['settings'][key]) > 10:
                            device_prefs['settings'][key] = device_prefs['settings'][key][-10:]
    
    async def _detect_patterns_async(self, user_id: str):
        """Detect behavioral patterns asynchronously"""
        try:
            await self._detect_patterns(user_id)
        except Exception as e:
            logging.error(f"Error detecting patterns for {user_id}: {e}")
    
    async def _detect_patterns(self, user_id: str):
        """Detect behavioral patterns for a user"""
        if user_id not in self._history:
            return
        
        history = self._history[user_id]
        if len(history) < self.pattern_detection_threshold:
            return
        
        # Time-based patterns
        await self._detect_time_patterns(user_id, history)
        
        # Device usage patterns
        await self._detect_device_patterns(user_id, history)
        
        # Sequential patterns
        await self._detect_sequence_patterns(user_id, history)
    
    async def _detect_time_patterns(self, user_id: str, history: List[Dict[str, Any]]):
        """Detect time-based behavioral patterns"""
        # Group actions by time periods
        time_actions = defaultdict(list)
        
        for entry in history[-30:]:  # Last 30 entries
            timestamp = datetime.fromisoformat(entry['timestamp'])
            time_cat = self._categorize_time(timestamp)
            time_actions[time_cat].append(entry)
        
        # Look for recurring patterns
        for time_period, actions in time_actions.items():
            if len(actions) >= self.pattern_detection_threshold:
                # Find common device/action combinations
                device_actions = Counter()
                for action in actions:
                    if action['type'] == InteractionType.DEVICE_COMMAND.value:
                        device = action['data'].get('device', '')
                        action_type = action['data'].get('action', '')
                        device_actions[f"{device}:{action_type}"] += 1
                
                # Create patterns for frequent combinations
                for combo, freq in device_actions.items():
                    if freq >= self.pattern_detection_threshold:
                        pattern_id = f"time_{time_period}_{combo.replace(':', '_')}"
                        
                        pattern = BehaviorPattern(
                            pattern_id=pattern_id,
                            description=f"User typically performs {combo} during {time_period}",
                            frequency=freq,
                            confidence=min(freq / len(actions), 1.0),
                            last_occurrence=datetime.now(),
                            time_patterns=[time_period],
                            devices_involved=[combo.split(':')[0]],
                            conditions={'time_period': time_period}
                        )
                        
                        if user_id not in self._behavior_patterns:
                            self._behavior_patterns[user_id] = []
                        
                        # Update or add pattern
                        existing = next((p for p in self._behavior_patterns[user_id] 
                                       if p.pattern_id == pattern_id), None)
                        if existing:
                            existing.frequency = freq
                            existing.confidence = pattern.confidence
                            existing.last_occurrence = pattern.last_occurrence
                        else:
                            self._behavior_patterns[user_id].append(pattern)
    
    async def _detect_device_patterns(self, user_id: str, history: List[Dict[str, Any]]):
        """Detect device usage patterns"""
        device_sequences = defaultdict(list)
        
        for entry in history[-50:]:  # Last 50 entries
            if entry['type'] == InteractionType.DEVICE_COMMAND.value:
                device = entry['data'].get('device', '')
                if device:
                    device_sequences[device].append(entry)
        
        # Analyze patterns for each device
        for device, usage_list in device_sequences.items():
            if len(usage_list) >= self.pattern_detection_threshold:
                # Analyze usage frequency
                times = [datetime.fromisoformat(u['timestamp']) for u in usage_list]
                
                # Check for daily patterns
                hours = [t.hour for t in times]
                if len(set(hours)) <= 3:  # Used at consistent times
                    avg_hour = statistics.mean(hours)
                    pattern_id = f"device_{device}_time_{int(avg_hour)}"
                    
                    pattern = BehaviorPattern(
                        pattern_id=pattern_id,
                        description=f"User typically uses {device} around {int(avg_hour)}:00",
                        frequency=len(usage_list),
                        confidence=0.8,
                        last_occurrence=max(times),
                        time_patterns=[self._categorize_time(max(times))],
                        devices_involved=[device],
                        conditions={'preferred_hour': int(avg_hour)}
                    )
                    
                    if user_id not in self._behavior_patterns:
                        self._behavior_patterns[user_id] = []
                    
                    # Update or add pattern
                    existing = next((p for p in self._behavior_patterns[user_id] 
                                   if p.pattern_id == pattern_id), None)
                    if existing:
                        existing.frequency = len(usage_list)
                        existing.last_occurrence = max(times)
                    else:
                        self._behavior_patterns[user_id].append(pattern)
    
    async def _detect_sequence_patterns(self, user_id: str, history: List[Dict[str, Any]]):
        """Detect sequential action patterns"""
        # Look for sequences of actions that often occur together
        sequences = []
        window_size = 5  # Look for patterns within 5 actions
        
        device_commands = [entry for entry in history[-100:] 
                          if entry['type'] == InteractionType.DEVICE_COMMAND.value]
        
        for i in range(len(device_commands) - 1):
            window = device_commands[i:i + window_size]
            devices_in_window = [cmd['data'].get('device', '') for cmd in window]
            
            # Look for device pairs that appear together frequently
            if len(devices_in_window) >= 2:
                for j in range(len(devices_in_window) - 1):
                    pair = (devices_in_window[j], devices_in_window[j + 1])
                    sequences.append(pair)
        
        # Find frequent sequences
        sequence_counts = Counter(sequences)
        for (dev1, dev2), count in sequence_counts.items():
            if count >= self.pattern_detection_threshold and dev1 != dev2:
                pattern_id = f"sequence_{dev1}_{dev2}"
                
                pattern = BehaviorPattern(
                    pattern_id=pattern_id,
                    description=f"User often controls {dev2} after {dev1}",
                    frequency=count,
                    confidence=min(count / len(sequences) * 10, 1.0) if sequences else 0,
                    last_occurrence=datetime.now(),
                    time_patterns=[],
                    devices_involved=[dev1, dev2],
                    conditions={'sequence': [dev1, dev2]}
                )
                
                if user_id not in self._behavior_patterns:
                    self._behavior_patterns[user_id] = []
                
                # Update or add pattern
                existing = next((p for p in self._behavior_patterns[user_id] 
                               if p.pattern_id == pattern_id), None)
                if existing:
                    existing.frequency = count
                    existing.confidence = pattern.confidence
                else:
                    self._behavior_patterns[user_id].append(pattern)
    
    async def _update_suggestions_async(self, user_id: str):
        """Update proactive suggestions asynchronously"""
        try:
            await self._generate_proactive_suggestions(user_id)
        except Exception as e:
            logging.error(f"Error generating suggestions for {user_id}: {e}")
    
    async def _generate_proactive_suggestions(self, user_id: str):
        """Generate proactive suggestions based on patterns"""
        if user_id not in self._behavior_patterns:
            return
        
        current_time = datetime.now()
        current_hour = current_time.hour
        current_time_cat = self._categorize_time(current_time)
        
        if user_id not in self._active_suggestions:
            self._active_suggestions[user_id] = []
        
        # Clean expired suggestions
        self._active_suggestions[user_id] = [
            s for s in self._active_suggestions[user_id] 
            if s.expires_at > current_time
        ]
        
        patterns = self._behavior_patterns[user_id]
        
        for pattern in patterns:
            if pattern.confidence < self.suggestion_confidence_threshold:
                continue
            
            suggestion = None
            
            # Time-based suggestions
            if 'time_period' in pattern.conditions:
                if pattern.conditions['time_period'] == current_time_cat:
                    # Suggest typical action for this time
                    suggestion = self._create_time_based_suggestion(user_id, pattern)
            
            # Hour-based suggestions
            elif 'preferred_hour' in pattern.conditions:
                preferred_hour = pattern.conditions['preferred_hour']
                if abs(current_hour - preferred_hour) <= 1:  # Within 1 hour
                    suggestion = self._create_device_suggestion(user_id, pattern)
            
            # Sequence-based suggestions
            elif 'sequence' in pattern.conditions:
                suggestion = self._create_sequence_suggestion(user_id, pattern)
            
            if suggestion:
                # Check if similar suggestion already exists
                existing = next((s for s in self._active_suggestions[user_id] 
                               if s.suggestion_id == suggestion.suggestion_id), None)
                if not existing:
                    self._active_suggestions[user_id].append(suggestion)
    
    def _create_time_based_suggestion(self, user_id: str, pattern: BehaviorPattern) -> Optional[ProactiveSuggestion]:
        """Create a time-based suggestion"""
        if not pattern.devices_involved:
            return None
        
        device = pattern.devices_involved[0]
        time_period = pattern.conditions.get('time_period', 'now')
        
        self._suggestion_counter += 1
        return ProactiveSuggestion(
            suggestion_id=f"time_{self._suggestion_counter}",
            title=f"Typical {time_period} routine",
            description=f"You usually control {device} during {time_period}. Would you like me to do that now?",
            action={
                'type': 'device_command',
                'device': device,
                'action': 'toggle'  # Could be more specific based on preferences
            },
            confidence=pattern.confidence,
            reason=f"Based on {pattern.frequency} similar actions during {time_period}",
            expires_at=datetime.now() + timedelta(hours=2)
        )
    
    def _create_device_suggestion(self, user_id: str, pattern: BehaviorPattern) -> Optional[ProactiveSuggestion]:
        """Create a device-based suggestion"""
        if not pattern.devices_involved:
            return None
        
        device = pattern.devices_involved[0]
        preferred_hour = pattern.conditions.get('preferred_hour')
        
        self._suggestion_counter += 1
        return ProactiveSuggestion(
            suggestion_id=f"device_{self._suggestion_counter}",
            title=f"Usual {device} time",
            description=f"You typically use {device} around this time. Ready to control it?",
            action={
                'type': 'device_command',
                'device': device,
                'action': 'status_check'
            },
            confidence=pattern.confidence,
            reason=f"You usually use {device} around {preferred_hour}:00",
            expires_at=datetime.now() + timedelta(hours=1)
        )
    
    def _create_sequence_suggestion(self, user_id: str, pattern: BehaviorPattern) -> Optional[ProactiveSuggestion]:
        """Create a sequence-based suggestion"""
        sequence = pattern.conditions.get('sequence', [])
        if len(sequence) < 2:
            return None
        
        # Check if first device was recently used
        recent_history = self._history.get(user_id, [])[-10:]  # Last 10 actions
        first_device_used = False
        
        for entry in recent_history:
            if (entry['type'] == InteractionType.DEVICE_COMMAND.value and 
                entry['data'].get('device') == sequence[0]):
                entry_time = datetime.fromisoformat(entry['timestamp'])
                if datetime.now() - entry_time < timedelta(minutes=30):
                    first_device_used = True
                    break
        
        if first_device_used:
            self._suggestion_counter += 1
            return ProactiveSuggestion(
                suggestion_id=f"sequence_{self._suggestion_counter}",
                title=f"Complete your routine?",
                description=f"You just used {sequence[0]}. You often control {sequence[1]} next.",
                action={
                    'type': 'device_command',
                    'device': sequence[1],
                    'action': 'suggest_control'
                },
                confidence=pattern.confidence,
                reason=f"Based on {pattern.frequency} similar sequences",
                expires_at=datetime.now() + timedelta(minutes=30)
            )
        
        return None
    
    def get_behavior_patterns(self, user_id: str) -> List[Dict[str, Any]]:
        """Get detected behavior patterns for a user"""
        patterns = self._behavior_patterns.get(user_id, [])
        return [
            {
                'pattern_id': p.pattern_id,
                'description': p.description,
                'frequency': p.frequency,
                'confidence': p.confidence,
                'last_occurrence': p.last_occurrence.isoformat(),
                'time_patterns': p.time_patterns,
                'devices_involved': p.devices_involved,
                'conditions': p.conditions
            }
            for p in patterns
        ]
    
    def get_proactive_suggestions(self, user_id: str) -> List[Dict[str, Any]]:
        """Get active proactive suggestions for a user"""
        suggestions = self._active_suggestions.get(user_id, [])
        
        # Filter out expired suggestions
        current_time = datetime.now()
        active_suggestions = [s for s in suggestions if s.expires_at > current_time]
        
        return [
            {
                'suggestion_id': s.suggestion_id,
                'title': s.title,
                'description': s.description,
                'action': s.action,
                'confidence': s.confidence,
                'reason': s.reason,
                'expires_at': s.expires_at.isoformat()
            }
            for s in active_suggestions
        ]
    
    def dismiss_suggestion(self, user_id: str, suggestion_id: str) -> bool:
        """Dismiss a proactive suggestion"""
        if user_id not in self._active_suggestions:
            return False
        
        initial_count = len(self._active_suggestions[user_id])
        self._active_suggestions[user_id] = [
            s for s in self._active_suggestions[user_id] 
            if s.suggestion_id != suggestion_id
        ]
        
        return len(self._active_suggestions[user_id]) < initial_count
    
    def get_user_analytics(self, user_id: str) -> Dict[str, Any]:
        """Get comprehensive user analytics"""
        
        # Check cache first
        if (user_id in self._analytics_cache and 
            user_id in self._cache_expiry and 
            self._cache_expiry[user_id] > datetime.now()):
            return self._analytics_cache[user_id]
        
        history = self._history.get(user_id, [])
        device_stats = self._device_usage_stats.get(user_id, {})
        patterns = self._behavior_patterns.get(user_id, [])
        
        # Calculate analytics
        analytics = {
            'total_interactions': len(history),
            'interactions_by_type': Counter(entry['type'] for entry in history),
            'most_used_devices': [],
            'device_usage_stats': {},
            'time_distribution': {
                'morning': 0, 'afternoon': 0, 'evening': 0, 'night': 0
            },
            'detected_patterns': len(patterns),
            'active_suggestions': len(self._active_suggestions.get(user_id, [])),
            'learning_insights': []
        }
        
        # Device usage analysis
        for device, stats in device_stats.items():
            analytics['most_used_devices'].append({
                'device': device,
                'total_uses': stats['total_uses'],
                'most_common_action': stats['actions'].most_common(1)[0] if stats['actions'] else ('none', 0)
            })
            
            analytics['device_usage_stats'][device] = {
                'total_uses': stats['total_uses'],
                'actions': dict(stats['actions']),
                'last_used': stats['last_used'].isoformat() if stats['last_used'] else None
            }
        
        # Sort by usage
        analytics['most_used_devices'].sort(key=lambda x: x['total_uses'], reverse=True)
        
        # Time distribution
        for entry in history:
            timestamp = datetime.fromisoformat(entry['timestamp'])
            time_cat = self._categorize_time(timestamp)
            analytics['time_distribution'][time_cat] += 1
        
        # Learning insights
        if patterns:
            most_confident_pattern = max(patterns, key=lambda p: p.confidence)
            analytics['learning_insights'].append(
                f"Your most consistent behavior: {most_confident_pattern.description}"
            )
        
        if device_stats:
            most_used = max(device_stats.items(), key=lambda x: x[1]['total_uses'])
            analytics['learning_insights'].append(
                f"Your most frequently controlled device: {most_used[0]} ({most_used[1]['total_uses']} times)"
            )
        
        # Cache the results
        self._analytics_cache[user_id] = analytics
        self._cache_expiry[user_id] = datetime.now() + timedelta(minutes=15)
        
        return analytics
    
    def get_history(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get user's history (enhanced version)"""
        history = self._history.get(user_id, [])
        return history[-limit:] if limit else history
    
    def clear_history(self, user_id: str) -> None:
        """Clear user's history and learning data"""
        if user_id in self._history:
            del self._history[user_id]
        if user_id in self._behavior_patterns:
            del self._behavior_patterns[user_id]
        if user_id in self._user_preferences:
            del self._user_preferences[user_id]
        if user_id in self._device_usage_stats:
            del self._device_usage_stats[user_id]
        if user_id in self._active_suggestions:
            del self._active_suggestions[user_id]
        if user_id in self._analytics_cache:
            del self._analytics_cache[user_id]
        if user_id in self._cache_expiry:
            del self._cache_expiry[user_id]
        
        logging.info(f"Cleared all data for user {user_id}")


# Example usage
if __name__ == "__main__":
    # Create enhanced memory agent
    memory_agent = EnhancedMemoryAgent()
    
    # Simulate some user interactions
    user_id = "test_user"
    
    # Simulate morning routine
    memory_agent.add_entry(
        user_id, 
        InteractionType.DEVICE_COMMAND.value,
        {"device": "light.living_room", "action": "turn_on", "brightness": 80}
    )
    
    memory_agent.add_entry(
        user_id,
        InteractionType.DEVICE_COMMAND.value, 
        {"device": "thermostat.main", "action": "set_temperature", "temperature": 22}
    )
    
    # Get analytics
    analytics = memory_agent.get_user_analytics(user_id)
    print("User Analytics:")
    for key, value in analytics.items():
        print(f"  {key}: {value}")