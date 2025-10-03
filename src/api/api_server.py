"""
FastAPI Home Automation Server

REST API server that provides web endpoints for the home automation system.
Integrates ContextStore, SensorAgent, ExecutorAgent, and adds planning/scheduling layers.
"""

import asyncio
import json
import logging
import os
from datetime import datetime
from typing import Dict, Any, List, Optional
from contextlib import asynccontextmanager

try:
    from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
    from fastapi.responses import JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn
except ImportError:
    print("FastAPI not found. Installing required packages...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn", "python-multipart"])
    from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
    from fastapi.responses import JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn

from src.core.context_store import ContextStore
from src.agents.sensor_agent import SensorAgent
from src.agents.executor_agent import ExecutorAgent
# from src.agents.voice_agent import VoiceAgent  # Temporarily disabled for Docker
from src.agents.enhanced_memory_agent import EnhancedMemoryAgent


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class UserPreferences:
    """Manages user preferences storage."""
    
    def __init__(self):
        self._prefs: Dict[str, Dict[str, Any]] = {}
    
    def set_preference(self, user_id: str, key: str, value: Any) -> None:
        """Set a user preference."""
        if user_id not in self._prefs:
            self._prefs[user_id] = {}
        self._prefs[user_id][key] = value
        logger.info(f"Set preference for {user_id}: {key} = {value}")
    
    def get_preferences(self, user_id: str) -> Dict[str, Any]:
        """Get all preferences for a user."""
        return self._prefs.get(user_id, {})
    
    def get_preference(self, user_id: str, key: str, default: Any = None) -> Any:
        """Get a specific preference for a user."""
        return self._prefs.get(user_id, {}).get(key, default)


class MemoryAgent:
    """Manages user interaction history and memory."""
    
    def __init__(self):
        self._history: Dict[str, List[Dict[str, Any]]] = {}
    
    def add_entry(self, user_id: str, entry_type: str, data: Dict[str, Any]) -> None:
        """Add an entry to user's history."""
        if user_id not in self._history:
            self._history[user_id] = []
        
        entry = {
            "timestamp": datetime.now().isoformat(),
            "type": entry_type,
            "data": data
        }
        
        self._history[user_id].append(entry)
        
        # Keep history limited to last 100 entries per user
        if len(self._history[user_id]) > 100:
            self._history[user_id].pop(0)
        
        logger.debug(f"Added {entry_type} entry for user {user_id}")
    
    def get_history(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get user's history."""
        history = self._history.get(user_id, [])
        return history[-limit:] if limit else history
    
    def clear_history(self, user_id: str) -> None:
        """Clear user's history."""
        if user_id in self._history:
            del self._history[user_id]
        logger.info(f"Cleared history for user {user_id}")


class Planner:
    """Plans device actions based on user goals."""
    
    def __init__(self, context_store: ContextStore, user_prefs: UserPreferences):
        self.context_store = context_store
        self.user_prefs = user_prefs
    
    async def plan_goal(self, user_id: str, goal: str) -> List[Dict[str, Any]]:
        """
        Plan a sequence of device actions to achieve a goal.
        
        Args:
            user_id: User identifier
            goal: Natural language goal description
            
        Returns:
            List of device tasks to execute
        """
        logger.info(f"Planning goal for {user_id}: {goal}")
        
        # Get user preferences
        prefs = self.user_prefs.get_preferences(user_id)
        preferred_brightness = prefs.get("default_brightness", 75)
        preferred_temp = prefs.get("default_temperature", 22.0)
        
        # Simple goal parsing (in production, you'd use NLP)
        goal_lower = goal.lower()
        tasks = []
        
        if "goodnight" in goal_lower or "sleep" in goal_lower:
            tasks = [
                {"device": "light.bedroom", "action": "set_brightness", "value": 10},
                {"device": "light.living_room", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 20.0},
                {"device": "lock.front_door", "action": "lock", "value": True}
            ]
        elif "good morning" in goal_lower or "wake up" in goal_lower:
            tasks = [
                {"device": "light.bedroom", "action": "set_brightness", "value": preferred_brightness},
                {"device": "thermostat.main", "action": "set_temperature", "value": preferred_temp},
                {"device": "switch.coffee_maker", "action": "turn_on", "value": True}
            ]
        elif "movie" in goal_lower or "watch" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "set_brightness", "value": 20},
                {"device": "light.kitchen", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 21.0}
            ]
        elif "party" in goal_lower or "entertainment" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "set_color", "value": "#FF6B6B"},
                {"device": "light.kitchen", "action": "set_color", "value": "#4ECDC4"},
                {"device": "fan.living_room", "action": "set_speed", "value": 2}
            ]
        elif "away" in goal_lower or "leaving" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "turn_off", "value": False},
                {"device": "light.bedroom", "action": "turn_off", "value": False},
                {"device": "light.kitchen", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 18.0},
                {"device": "lock.front_door", "action": "lock", "value": True}
            ]
        elif "bright" in goal_lower or "lights on" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "set_brightness", "value": preferred_brightness},
                {"device": "light.bedroom", "action": "set_brightness", "value": preferred_brightness},
                {"device": "light.kitchen", "action": "set_brightness", "value": preferred_brightness}
            ]
        else:
            # Generic goal - try to extract device and action
            if "light" in goal_lower:
                if "on" in goal_lower:
                    tasks = [{"device": "light.living_room", "action": "turn_on", "value": True}]
                elif "off" in goal_lower:
                    tasks = [{"device": "light.living_room", "action": "turn_off", "value": False}]
            elif "temperature" in goal_lower or "temp" in goal_lower:
                tasks = [{"device": "thermostat.main", "action": "set_temperature", "value": preferred_temp}]
            else:
                # Fallback for unknown goals
                tasks = [{"device": "light.living_room", "action": "turn_on", "value": True, "reason": f"Unknown goal: {goal}"}]
        
        logger.info(f"Planned {len(tasks)} tasks for goal: {goal}")
        return tasks


class Scheduler:
    """Schedules and optimizes planned tasks."""
    
    def __init__(self, context_store: ContextStore):
        self.context_store = context_store
    
    async def schedule_tasks(self, tasks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Schedule and optimize task execution order.
        
        Args:
            tasks: List of planned tasks
            
        Returns:
            Optimized and scheduled task list
        """
        logger.info(f"Scheduling {len(tasks)} tasks")
        
        if not tasks:
            return []
        
        # Get current device states to optimize
        current_states = await self.context_store.async_dump()
        
        # Filter out redundant tasks
        optimized_tasks = []
        
        for task in tasks:
            device = task.get("device", "")
            action = task.get("action", "")
            value = task.get("value")
            
            # Check current state to avoid redundant commands
            device_type, location = device.split('.') if '.' in device else (device, "unknown")
            state_topic = f"home/{device_type}/{location}/state"
            current_state = current_states.get("states", {}).get(state_topic, {})
            
            should_execute = True
            
            if current_state:
                # Skip if device is already in desired state
                if action == "turn_on" and current_state.get("state") == "on":
                    should_execute = False
                elif action == "turn_off" and current_state.get("state") == "off":
                    should_execute = False
                elif action == "set_brightness" and current_state.get("brightness") == value:
                    should_execute = False
                elif action == "set_temperature" and current_state.get("target") == value:
                    should_execute = False
            
            if should_execute:
                # Add scheduling metadata
                task_with_metadata = task.copy()
                task_with_metadata.update({
                    "scheduled_at": datetime.now().isoformat(),
                    "priority": self._calculate_priority(task),
                    "estimated_duration": self._estimate_duration(task)
                })
                optimized_tasks.append(task_with_metadata)
            else:
                logger.debug(f"Skipped redundant task: {device} {action}")
        
        # Sort by priority and execution efficiency
        optimized_tasks.sort(key=lambda t: t.get("priority", 5))
        
        logger.info(f"Scheduled {len(optimized_tasks)} tasks (filtered {len(tasks) - len(optimized_tasks)} redundant)")
        return optimized_tasks
    
    def _calculate_priority(self, task: Dict[str, Any]) -> int:
        """Calculate task priority (lower number = higher priority)."""
        action = task.get("action", "")
        device = task.get("device", "")
        
        # Security/safety tasks get highest priority
        if "lock" in device or action in ["lock", "unlock"]:
            return 1
        
        # Lighting tasks get medium priority
        if "light" in device:
            return 2
        
        # Climate control gets medium-low priority
        if "thermostat" in device or "fan" in device:
            return 3
        
        # Everything else gets low priority
        return 5
    
    def _estimate_duration(self, task: Dict[str, Any]) -> float:
        """Estimate task execution duration in seconds."""
        device_type = task.get("device", "").split('.')[0] if '.' in task.get("device", "") else "unknown"
        
        durations = {
            "light": 0.5,
            "switch": 0.2,
            "thermostat": 1.0,
            "lock": 0.8,
            "fan": 0.6
        }
        
        return durations.get(device_type, 0.5)


# Global instances
context_store = ContextStore()
logger.info(f"🏗️ Created global context store with ID: {id(context_store)}")

# Use localhost for MQTT broker when running outside Docker
mqtt_broker_host = os.getenv("MQTT_BROKER_HOST", "localhost")
executor_agent = ExecutorAgent(broker_host=mqtt_broker_host)
logger.info(f"🔧 Created executor agent with MQTT broker: {mqtt_broker_host}")

user_prefs = UserPreferences()
memory_agent = EnhancedMemoryAgent(context_store=context_store)
planner = Planner(context_store, user_prefs)
scheduler = Scheduler(context_store)
sensor_agent = None  # Will be initialized in lifespan
voice_agent = None  # Will be initialized in lifespan


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - startup and shutdown."""
    # Startup
    logger.info("🚀 Starting Home Automation API Server...")
    
    # Initialize sensor agent in background
    global sensor_agent, voice_agent
    
    # Get MQTT configuration from environment or default
    mqtt_host = os.getenv('HOMEGENIE_MQTT_HOST', os.getenv('MQTT_BROKER_HOST', 'localhost'))
    mqtt_port = int(os.getenv('HOMEGENIE_MQTT_PORT', os.getenv('MQTT_BROKER_PORT', 1883)))
    
    sensor_agent = SensorAgent(
        broker_host=mqtt_host,
        broker_port=mqtt_port,
        topic_pattern="home/+/+/state",
        context_store=context_store
    )
    
    # Initialize voice agent with goal processor
    try:
        def voice_goal_processor(goal: str) -> Dict[str, Any]:
            """Wrapper for voice agent goal processing"""
            try:
                # Use a default user for voice commands
                result = asyncio.create_task(planner.plan_goal("voice_user", goal))
                # Note: This is a simplified approach - in production you'd handle async properly
                return {"success": True, "message": f"Voice command processed: {goal}"}
            except Exception as e:
                return {"success": False, "message": str(e)}
        
        # voice_agent = VoiceAgent(
        #     goal_processor=voice_goal_processor,
        #     enable_tts=True,
        #     enable_wake_word=False,  # Can be enabled later
        #     recognition_method="google"
        # )
        voice_agent = None  # Temporarily disabled for Docker compatibility
        logger.info("✅ Voice Agent disabled for Docker compatibility")
    except Exception as e:
        logger.warning(f"Voice Agent initialization failed (optional): {e}")
        voice_agent = None
    
    # Start sensor monitoring in background task
    sensor_task = asyncio.create_task(start_sensor_monitoring())
    
    logger.info("✅ Home Automation API Server started")
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down Home Automation API Server...")
    if sensor_agent:
        sensor_agent.stop()
    
    if voice_agent:
        voice_agent.stop_listening()
    
    # Cancel sensor task
    sensor_task.cancel()
    try:
        await sensor_task
    except asyncio.CancelledError:
        pass
    
    logger.info("✅ Home Automation API Server stopped")


async def start_sensor_monitoring():
    """Start sensor monitoring in background."""
    try:
        if sensor_agent:
            await sensor_agent.start()
    except Exception as e:
        logger.error(f"Sensor monitoring error: {e}")


# Create FastAPI app
app = FastAPI(
    title="Home Automation API",
    description="REST API for smart home automation system",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware to allow browser requests from any origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=False,  # Must be False when allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models for request/response
class GoalResponse(BaseModel):
    message: str
    tasks_planned: int
    tasks_scheduled: int
    tasks_executed: int
    execution_time: float


class PreferenceResponse(BaseModel):
    user_id: str
    preferences: Dict[str, Any]


class StateResponse(BaseModel):
    timestamp: str
    states: Dict[str, Any]
    total_devices: int


class HistoryResponse(BaseModel):
    user_id: str
    entries: List[Dict[str, Any]]
    total_entries: int


# API Endpoints

@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "message": "Home Automation API Server",
        "version": "1.0.0",
        "endpoints": [
            "POST /goal/{user_id}?goal=<goal>",
            "POST /prefs/{user_id}?key=<k>&value=<v>",
            "GET /prefs/{user_id}",
            "GET /state",
            "GET /history/{user_id}"
        ]
    }


@app.post("/goal/{user_id}", response_model=GoalResponse)
async def process_goal(
    user_id: str,
    background_tasks: BackgroundTasks,
    goal: str = Query(..., description="Natural language goal description")
):
    """
    Process a user goal through Planner → Scheduler → Executor pipeline.
    
    Examples:
    - "goodnight" → Turn off lights, lock doors, set sleep temperature
    - "good morning" → Turn on lights, set comfortable temperature
    - "movie time" → Dim lights for entertainment
    """
    start_time = datetime.now()
    
    try:
        logger.info(f"Processing goal for user {user_id}: {goal}")
        
        # Log the goal request
        memory_agent.add_entry(user_id, "goal_request", {
            "goal": goal,
            "timestamp": start_time.isoformat()
        })
        
        # Step 1: Plan the goal
        planned_tasks = await planner.plan_goal(user_id, goal)
        
        # Step 2: Schedule the tasks
        scheduled_tasks = await scheduler.schedule_tasks(planned_tasks)
        
        # Step 3: Execute the tasks
        executed_count = 0
        execution_results = []
        
        for task in scheduled_tasks:
            try:
                success = await executor_agent.execute(task)
                if success:
                    executed_count += 1
                execution_results.append({
                    "task": task,
                    "success": success
                })
            except Exception as e:
                logger.error(f"Task execution failed: {e}")
                execution_results.append({
                    "task": task,
                    "success": False,
                    "error": str(e)
                })
        
        execution_time = (datetime.now() - start_time).total_seconds()
        
        # Log the execution results
        memory_agent.add_entry(user_id, "goal_execution", {
            "goal": goal,
            "tasks_planned": len(planned_tasks),
            "tasks_scheduled": len(scheduled_tasks),
            "tasks_executed": executed_count,
            "execution_time": execution_time,
            "results": execution_results
        })
        
        logger.info(f"Goal processed: {executed_count}/{len(scheduled_tasks)} tasks executed in {execution_time:.2f}s")
        
        return GoalResponse(
            message=f"Goal '{goal}' processed successfully",
            tasks_planned=len(planned_tasks),
            tasks_scheduled=len(scheduled_tasks),
            tasks_executed=executed_count,
            execution_time=execution_time
        )
        
    except Exception as e:
        logger.error(f"Goal processing failed: {e}")
        memory_agent.add_entry(user_id, "goal_error", {
            "goal": goal,
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        })
        raise HTTPException(status_code=500, detail=f"Goal processing failed: {e}")


@app.post("/prefs/{user_id}", response_model=PreferenceResponse)
async def set_preference(
    user_id: str,
    key: str = Query(..., description="Preference key"),
    value: str = Query(..., description="Preference value")
):
    """
    Set a user preference.
    
    Examples:
    - /prefs/john?key=default_brightness&value=75
    - /prefs/jane?key=default_temperature&value=22.5
    - /prefs/bob?key=sleep_time&value=23:00
    """
    try:
        # Convert string value to appropriate type
        converted_value = value
        try:
            # Try to convert to number
            if '.' in value:
                converted_value = float(value)
            else:
                converted_value = int(value)
        except ValueError:
            # Try to convert to boolean
            if value.lower() in ['true', 'false']:
                converted_value = value.lower() == 'true'
            # Otherwise keep as string
        
        user_prefs.set_preference(user_id, key, converted_value)
        
        # Log preference change
        memory_agent.add_entry(user_id, "preference_change", {
            "key": key,
            "value": converted_value,
            "timestamp": datetime.now().isoformat()
        })
        
        return PreferenceResponse(
            user_id=user_id,
            preferences=user_prefs.get_preferences(user_id)
        )
        
    except Exception as e:
        logger.error(f"Failed to set preference: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to set preference: {e}")


@app.get("/prefs/{user_id}", response_model=PreferenceResponse)
async def get_preferences(user_id: str):
    """Get all preferences for a user."""
    try:
        preferences = user_prefs.get_preferences(user_id)
        
        return PreferenceResponse(
            user_id=user_id,
            preferences=preferences
        )
        
    except Exception as e:
        logger.error(f"Failed to get preferences: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get preferences: {e}")


@app.get("/state", response_model=StateResponse)
async def get_system_state():
    """Get current system state from ContextStore."""
    try:
        state_dump = await context_store.async_dump()
        
        return StateResponse(
            timestamp=datetime.now().isoformat(),
            states=state_dump.get("states", {}),
            total_devices=state_dump.get("total_topics", 0)
        )
        
    except Exception as e:
        logger.error(f"Failed to get system state: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get system state: {e}")


@app.get("/history/{user_id}", response_model=HistoryResponse)
async def get_user_history(
    user_id: str,
    limit: int = Query(50, description="Maximum number of history entries to return")
):
    """Get user interaction history from MemoryAgent."""
    try:
        history = memory_agent.get_history(user_id, limit)
        
        return HistoryResponse(
            user_id=user_id,
            entries=history,
            total_entries=len(history)
        )
        
    except Exception as e:
        logger.error(f"Failed to get user history: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user history: {e}")


# Additional utility endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "components": {
            "context_store": len(context_store) > 0,
            "executor_agent": True,
            "sensor_agent": sensor_agent.is_running() if sensor_agent else False
        }
    }


@app.delete("/history/{user_id}")
async def clear_user_history(user_id: str):
    """Clear user's interaction history."""
    try:
        memory_agent.clear_history(user_id)
        return {"message": f"History cleared for user {user_id}"}
    except Exception as e:
        logger.error(f"Failed to clear history: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to clear history: {e}")


# Voice Agent Endpoints

class VoiceCommandRequest(BaseModel):
    """Request model for voice commands."""
    command: str
    user_id: Optional[str] = "voice_user"


class VoiceResponse(BaseModel):
    """Response model for voice commands."""
    success: bool
    command: str
    processed_goal: str
    response: str
    timestamp: str
    confidence: float


@app.post("/voice/command", response_model=VoiceResponse)
async def process_voice_command(request: VoiceCommandRequest):
    """Process a voice command through text input."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        # Process the command
        result = voice_agent.process_single_command(request.command)
        
        return VoiceResponse(
            success=True,
            command=result.raw_text,
            processed_goal=result.processed_goal,
            response=result.response or "Command processed",
            timestamp=result.timestamp.isoformat(),
            confidence=result.confidence
        )
    except Exception as e:
        logger.error(f"Error processing voice command: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing voice command: {e}")


@app.post("/voice/start-listening")
async def start_voice_listening():
    """Start continuous voice listening."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        voice_agent.start_listening()
        return {"message": "Voice listening started", "status": "listening"}
    except Exception as e:
        logger.error(f"Error starting voice listening: {e}")
        raise HTTPException(status_code=500, detail=f"Error starting voice listening: {e}")


@app.post("/voice/stop-listening")
async def stop_voice_listening():
    """Stop continuous voice listening."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        voice_agent.stop_listening()
        return {"message": "Voice listening stopped", "status": "stopped"}
    except Exception as e:
        logger.error(f"Error stopping voice listening: {e}")
        raise HTTPException(status_code=500, detail=f"Error stopping voice listening: {e}")


@app.get("/voice/status")
async def get_voice_status():
    """Get voice agent status and statistics."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        stats = voice_agent.get_voice_stats()
        return {
            "voice_agent_available": True,
            "stats": stats
        }
    except Exception as e:
        logger.error(f"Error getting voice status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting voice status: {e}")


@app.get("/voice/history")
async def get_voice_history(limit: int = Query(10, ge=1, le=100)):
    """Get voice command history."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        history = voice_agent.get_command_history(limit)
        return {
            "history": history,
            "total_commands": len(history)
        }
    except Exception as e:
        logger.error(f"Error getting voice history: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting voice history: {e}")


@app.post("/voice/speak")
async def speak_text(text: str):
    """Make the voice agent speak text (text-to-speech)."""
    if not voice_agent:
        raise HTTPException(status_code=503, detail="Voice Agent not available")
    
    try:
        voice_agent.speak(text)
        return {"message": f"Speaking: {text}", "text": text}
    except Exception as e:
        logger.error(f"Error speaking text: {e}")
        raise HTTPException(status_code=500, detail=f"Error speaking text: {e}")


# Behavioral Learning Endpoints

@app.get("/learning/patterns/{user_id}")
async def get_behavior_patterns(user_id: str):
    """Get detected behavior patterns for a user."""
    try:
        patterns = memory_agent.get_behavior_patterns(user_id)
        return {
            "user_id": user_id,
            "patterns": patterns,
            "total_patterns": len(patterns)
        }
    except Exception as e:
        logger.error(f"Error getting behavior patterns for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting behavior patterns: {e}")


@app.get("/learning/suggestions/{user_id}")
async def get_proactive_suggestions(user_id: str):
    """Get proactive suggestions for a user based on learned behavior."""
    try:
        suggestions = memory_agent.get_proactive_suggestions(user_id)
        return {
            "user_id": user_id,
            "suggestions": suggestions,
            "total_suggestions": len(suggestions)
        }
    except Exception as e:
        logger.error(f"Error getting suggestions for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting suggestions: {e}")


@app.post("/learning/suggestions/{user_id}/dismiss/{suggestion_id}")
async def dismiss_suggestion(user_id: str, suggestion_id: str):
    """Dismiss a proactive suggestion."""
    try:
        success = memory_agent.dismiss_suggestion(user_id, suggestion_id)
        if success:
            return {"message": f"Suggestion {suggestion_id} dismissed", "success": True}
        else:
            return {"message": f"Suggestion {suggestion_id} not found", "success": False}
    except Exception as e:
        logger.error(f"Error dismissing suggestion {suggestion_id} for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error dismissing suggestion: {e}")


@app.get("/learning/analytics/{user_id}")
async def get_user_analytics(user_id: str):
    """Get comprehensive behavioral analytics for a user."""
    try:
        analytics = memory_agent.get_user_analytics(user_id)
        return {
            "user_id": user_id,
            "analytics": analytics,
            "generated_at": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting analytics for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting analytics: {e}")


class SuggestionActionRequest(BaseModel):
    """Request model for executing a suggestion action."""
    suggestion_id: str
    execute_action: bool = True


@app.post("/learning/suggestions/{user_id}/execute")
async def execute_suggestion_action(user_id: str, request: SuggestionActionRequest):
    """Execute the action from a proactive suggestion."""
    try:
        # Get the suggestion
        suggestions = memory_agent.get_proactive_suggestions(user_id)
        suggestion = next((s for s in suggestions if s['suggestion_id'] == request.suggestion_id), None)
        
        if not suggestion:
            raise HTTPException(status_code=404, detail="Suggestion not found")
        
        if request.execute_action:
            # Execute the suggested action
            action = suggestion['action']
            
            if action['type'] == 'device_command':
                # Create a goal from the suggestion
                device = action.get('device', '')
                action_type = action.get('action', 'toggle')
                goal = f"{action_type} {device}"
                
                # Process through planner
                tasks = await planner.plan_goal(user_id, goal)
                
                if tasks:
                    # Execute the tasks
                    results = []
                    for task in tasks:
                        result = await executor_agent.execute(task)
                        results.append(result)
                    
                    # Dismiss the suggestion after execution
                    memory_agent.dismiss_suggestion(user_id, request.suggestion_id)
                    
                    # Log the interaction
                    memory_agent.add_entry(
                        user_id,
                        "suggestion_executed",
                        {
                            "suggestion_id": request.suggestion_id,
                            "action": action,
                            "results": results
                        }
                    )
                    
                    return {
                        "message": f"Suggestion executed successfully",
                        "suggestion_id": request.suggestion_id,
                        "results": results,
                        "success": True
                    }
                else:
                    return {
                        "message": "No tasks generated from suggestion",
                        "suggestion_id": request.suggestion_id,
                        "success": False
                    }
            else:
                return {
                    "message": f"Action type {action['type']} not supported yet",
                    "suggestion_id": request.suggestion_id,
                    "success": False
                }
        else:
            # Just dismiss without executing
            memory_agent.dismiss_suggestion(user_id, request.suggestion_id)
            return {
                "message": f"Suggestion {request.suggestion_id} dismissed without execution",
                "suggestion_id": request.suggestion_id,
                "success": True
            }
            
    except Exception as e:
        logger.error(f"Error executing suggestion for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error executing suggestion: {e}")


@app.get("/learning/insights/{user_id}")
async def get_learning_insights(user_id: str):
    """Get AI-generated insights about user behavior."""
    try:
        analytics = memory_agent.get_user_analytics(user_id)
        patterns = memory_agent.get_behavior_patterns(user_id)
        
        # Generate insights
        insights = []
        
        # Device usage insights
        most_used = analytics.get('most_used_devices', [])
        if most_used:
            top_device = most_used[0]
            insights.append({
                "type": "device_usage",
                "title": "Most Used Device",
                "description": f"You interact with {top_device['device']} most frequently ({top_device['total_uses']} times)",
                "recommendation": f"Consider setting up automation rules for {top_device['device']} to save time"
            })
        
        # Time pattern insights
        time_dist = analytics.get('time_distribution', {})
        if time_dist:
            peak_time = max(time_dist.items(), key=lambda x: x[1])
            insights.append({
                "type": "time_pattern",
                "title": "Peak Activity Time", 
                "description": f"You're most active during {peak_time[0]} ({peak_time[1]} interactions)",
                "recommendation": f"Consider scheduling routine tasks during {peak_time[0]} for efficiency"
            })
        
        # Pattern-based insights
        high_confidence_patterns = [p for p in patterns if p.get('confidence', 0) > 0.8]
        if high_confidence_patterns:
            pattern = high_confidence_patterns[0]
            insights.append({
                "type": "behavior_pattern",
                "title": "Strong Routine Detected",
                "description": pattern['description'],
                "recommendation": "This routine could be automated to happen automatically"
            })
        
        return {
            "user_id": user_id,
            "insights": insights,
            "total_insights": len(insights),
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting insights for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting insights: {e}")


# Direct Device Control Endpoints

class DeviceCommandRequest(BaseModel):
    """Request model for direct device commands."""
    device_id: str
    action: str
    parameters: Optional[Dict[str, Any]] = {}
    user_id: Optional[str] = "api_user"


class DeviceControlResponse(BaseModel):
    """Response model for device control operations."""
    success: bool
    device_id: str
    action: str
    result: Dict[str, Any]
    timestamp: str
    execution_time_ms: float


@app.post("/devices/control", response_model=DeviceControlResponse)
async def control_device(request: DeviceCommandRequest):
    """Direct device control endpoint - bypasses goal planning."""
    start_time = datetime.now()
    
    try:
        # Ensure executor is connected
        if not executor_agent._connected:
            await executor_agent.connect()
        
        # Create device task
        device_task = {
            "device": request.device_id,
            "action": request.action
        }
        if request.parameters:
            device_task.update(request.parameters)
        
        # Execute directly
        result = await executor_agent.execute(device_task)
        
        # Log the interaction
        memory_agent.add_entry(
            request.user_id or "api_user",
            "device_command",
            {
                "device": request.device_id,
                "action": request.action,
                "parameters": request.parameters,
                "source": "direct_api"
            }
        )
        
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        
        return DeviceControlResponse(
            success=result,
            device_id=request.device_id,
            action=request.action,
            result={"executed": result, "task": device_task},
            timestamp=start_time.isoformat(),
            execution_time_ms=execution_time
        )
        
    except Exception as e:
        logger.error(f"Error controlling device {request.device_id}: {e}")
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        
        return DeviceControlResponse(
            success=False,
            device_id=request.device_id,
            action=request.action,
            result={"error": str(e)},
            timestamp=start_time.isoformat(),
            execution_time_ms=execution_time
        )


@app.post("/devices/{device_id}/toggle")
async def toggle_device(device_id: str, user_id: str = Query("api_user")):
    """Toggle a device's state (on/off)."""
    try:
        # Get current state to determine toggle action
        current_state = context_store.get_state(f"home/{device_id.replace('.', '/')}/state")
        
        # Determine toggle action based on current state
        if current_state and isinstance(current_state, dict):
            current_power = current_state.get('state', 'off')
            if current_power in ['on', 'true', True]:
                action = 'turn_off'
            else:
                action = 'turn_on'
        else:
            action = 'turn_on'  # Default to turn on if state unknown
        
        # Execute toggle
        request = DeviceCommandRequest(
            device_id=device_id,
            action=action,
            user_id=user_id
        )
        
        return await control_device(request)
        
    except Exception as e:
        logger.error(f"Error toggling device {device_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error toggling device: {e}")


@app.post("/devices/{device_id}/set")
async def set_device_parameter(
    device_id: str, 
    parameter: str, 
    value: Any,
    user_id: str = Query("api_user")
):
    """Set a specific parameter on a device."""
    try:
        request = DeviceCommandRequest(
            device_id=device_id,
            action="set",
            parameters={parameter: value},
            user_id=user_id
        )
        
        return await control_device(request)
        
    except Exception as e:
        logger.error(f"Error setting {parameter} on device {device_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error setting device parameter: {e}")


@app.get("/devices")
async def list_devices():
    """List all known devices and their current states."""
    try:
        # Get all device states from context store
        all_topics = await context_store.async_get_topics()
        logger.info(f"📋 Available topics in context store (ID:{id(context_store)}): {all_topics}")
        
        devices = {}
        for key in all_topics:
            state = await context_store.async_get_state(key)
            # Parse device info from key (e.g., "home/light/living_room/state")
            parts = key.split('/')
            if len(parts) >= 4 and parts[-1] == 'state':
                device_type = parts[1]
                device_name = parts[2]
                device_id = f"{device_type}.{device_name}"
                
                devices[device_id] = {
                    "device_id": device_id,
                    "type": device_type,
                    "name": device_name,
                    "state": state,
                    "last_updated": state.get('timestamp') if isinstance(state, dict) else None
                }
        
        return {
            "devices": devices,
            "total_devices": len(devices),
            "retrieved_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error listing devices: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing devices: {e}")


@app.get("/devices/{device_id}")
async def get_device_status(device_id: str):
    """Get detailed status of a specific device."""
    try:
        # Convert device_id to state key
        parts = device_id.split('.')
        if len(parts) != 2:
            raise HTTPException(status_code=400, detail="Device ID must be in format 'type.name'")
        
        device_type, device_name = parts
        state_key = f"home/{device_type}/{device_name}/state"
        
        # Get device state
        state = context_store.get_state(state_key)
        
        if state is None:
            raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
        
        return {
            "device_id": device_id,
            "type": device_type,
            "name": device_name,
            "state": state,
            "state_key": state_key,
            "retrieved_at": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting device status for {device_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting device status: {e}")


class BatchDeviceRequest(BaseModel):
    """Request model for batch device operations."""
    commands: List[DeviceCommandRequest]
    execute_parallel: bool = True
    user_id: Optional[str] = "api_user"


@app.post("/devices/batch")
async def batch_device_control(request: BatchDeviceRequest):
    """Execute multiple device commands in batch."""
    start_time = datetime.now()
    
    try:
        # Ensure executor is connected
        if not executor_agent._connected:
            await executor_agent.connect()
        
        results = []
        
        if request.execute_parallel:
            # Execute commands in parallel
            tasks = []
            for cmd in request.commands:
                task_dict = {
                    "device": cmd.device_id,
                    "action": cmd.action
                }
                if cmd.parameters:
                    task_dict.update(cmd.parameters)
                tasks.append(executor_agent.execute(task_dict))
            
            # Wait for all tasks to complete
            task_results = await asyncio.gather(*tasks, return_exceptions=True)
            
            for i, (cmd, result) in enumerate(zip(request.commands, task_results)):
                if isinstance(result, Exception):
                    results.append({
                        "device_id": cmd.device_id,
                        "action": cmd.action,
                        "success": False,
                        "error": str(result)
                    })
                else:
                    results.append({
                        "device_id": cmd.device_id,
                        "action": cmd.action,
                        "success": result,
                        "result": result
                    })
                
                # Log each command
                memory_agent.add_entry(
                    request.user_id or "api_user",
                    "device_command",
                    {
                        "device": cmd.device_id,
                        "action": cmd.action,
                        "parameters": cmd.parameters,
                        "source": "batch_api",
                        "batch_index": i
                    }
                )
        else:
            # Execute commands sequentially
            for i, cmd in enumerate(request.commands):
                try:
                    task_dict = {
                        "device": cmd.device_id,
                        "action": cmd.action
                    }
                    if cmd.parameters:
                        task_dict.update(cmd.parameters)
                    
                    result = await executor_agent.execute(task_dict)
                    results.append({
                        "device_id": cmd.device_id,
                        "action": cmd.action,
                        "success": result,
                        "result": result
                    })
                    
                    # Log the command
                    memory_agent.add_entry(
                        request.user_id or "api_user",
                        "device_command",
                        {
                            "device": cmd.device_id,
                            "action": cmd.action,
                            "parameters": cmd.parameters,
                            "source": "batch_api",
                            "batch_index": i
                        }
                    )
                    
                except Exception as e:
                    results.append({
                        "device_id": cmd.device_id,
                        "action": cmd.action,
                        "success": False,
                        "error": str(e)
                    })
        
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        successful_commands = sum(1 for r in results if r.get('success', False))
        
        return {
            "success": True,
            "total_commands": len(request.commands),
            "successful_commands": successful_commands,
            "failed_commands": len(request.commands) - successful_commands,
            "execution_mode": "parallel" if request.execute_parallel else "sequential",
            "results": results,
            "execution_time_ms": execution_time,
            "timestamp": start_time.isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error in batch device control: {e}")
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        raise HTTPException(status_code=500, detail=f"Error in batch control: {e}")


if __name__ == "__main__":
    print("🏠 HOME AUTOMATION API SERVER")
    print("="*40)
    print("Starting FastAPI server...")
    print("API Documentation: http://localhost:8000/docs")
    print("Alternative docs: http://localhost:8000/redoc")
    print()
    
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )