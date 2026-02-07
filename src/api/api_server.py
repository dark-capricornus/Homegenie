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

# Load environment variables from .env if present
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("✅ Loaded environment from .env")
except ImportError:
    print("⚠️ python-dotenv not installed, skipping .env load")


try:
    from fastapi import FastAPI, HTTPException, Query, BackgroundTasks, Request
    from fastapi.responses import JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn
except ImportError:
    print("FastAPI not found. Installing required packages...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn", "python-multipart"])
    from fastapi import FastAPI, HTTPException, Query, BackgroundTasks, Request
    from fastapi.responses import JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn

from src.core.context_store import ContextStore
from src.agents.sensor_agent import SensorAgent
from src.agents.executor_agent import ExecutorAgent
from src.agents.enhanced_memory_agent import EnhancedMemoryAgent
from src.agents.planner_agent import PlannerAgent
from src.agents.scheduler_agent import SchedulerAgent

from src.core.feature_flags import flags
from dataclasses import asdict
from src.core.settings_v2 import settings_v2
from src.core import db_async as db_v2


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
executor_agent = ExecutorAgent(broker_host=mqtt_broker_host, context_store=context_store)
logger.info(f"🔧 Created executor agent with MQTT broker: {mqtt_broker_host} and context_store")

user_prefs = UserPreferences()
memory_agent = EnhancedMemoryAgent(context_store=context_store)
planner_agent = PlannerAgent(context_store=context_store, memory_fetcher=memory_agent.get_history)
scheduler = Scheduler(context_store)
scheduler_agent = SchedulerAgent(loop=asyncio.get_event_loop(), executor=None)
sensor_agent = None  # Will be initialized in lifespan
voice_agent = None  # Will be initialized in lifespan



async def start_proactivity_loop():
    """Background task to check for proactive suggestions."""
    logger.info("🧠 Proactivity loop started")
    while True:
        try:
            # Check for suggestions for known users (mock list for now or iterate active users)
            # In a real app we'd iterate over all active users in DB
            users = ["test_user", "default_user"] 
            
            for user_id in users:
                suggestions = memory_agent.get_proactive_suggestions(user_id)
                for suggestion in suggestions:
                    # If high confidence, we could auto-execute or just log
                    if suggestion['confidence'] > 0.85:
                        logger.info(f"💡 High confidence suggestion for {user_id}: {suggestion['title']}")
                        # Setup for auto-execution could go here
                        
            await asyncio.sleep(60) # check every minute
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Error in proactivity loop: {e}")
            await asyncio.sleep(60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - startup and shutdown."""
    # Startup
    logger.info("🚀 Starting Home Automation API Server...")
    # Log feature flags and key settings (mask secrets)
    try:
        flags_dict = asdict(flags)
    except Exception:
        # Fallback if flags is not a dataclass instance
        flags_dict = {k: getattr(flags, k) for k in dir(flags) if k.isupper()}

    def _mask_postgres(url: str | None) -> str | None:
        if not url:
            return None
        try:
            if '://' in url and '@' in url:
                proto, rest = url.split('://', 1)
                creds, after = rest.split('@', 1)
                return f"{proto}://<redacted>@{after}"
            return url
        except Exception:
            return '<invalid-postgres-url>'

    settings_summary = {
        'API_HOST': getattr(settings_v2, 'API_HOST', None),
        'API_PORT': getattr(settings_v2, 'API_PORT', None),
        'POSTGRES_URL': _mask_postgres(getattr(settings_v2, 'POSTGRES_URL', None)),
        'ENABLE_POSTGRES_MIGRATION': getattr(settings_v2, 'ENABLE_POSTGRES_MIGRATION', False)
    }

    enabled_flags = [k for k, v in flags_dict.items() if v]
    logger.info(f"Feature flags enabled: {enabled_flags}")
    logger.info(f"Settings summary: {settings_summary}")
    # Initialize optional Postgres DB (if configured) so it's ready as single source of truth
    if getattr(settings_v2, "POSTGRES_URL", None):
        try:
            await db_v2.init_db()
            logger.info("✅ Postgres DB initialized")

            try:
                stored_devices = await db_v2.list_devices()
                hydrated = 0

                for device_id, device_data in stored_devices.items():
                    state = device_data.get("state")
                    if not isinstance(state, dict):
                        logger.warning(f"⚠️ Skipping {device_id}: invalid or missing state")
                        continue

                    await context_store.async_update_observed_state(device_id, state)
                    hydrated += 1

                if hydrated == 0:
                    logger.warning(f"⚠️ Hydrated 0 devices. DB Query Result Keys: {list(stored_devices.keys())}")
                else:
                    logger.info(f"✅ Hydrated ContextStore with {hydrated} devices from DB")

            except Exception as e:
                logger.exception(f"❌ Failed to hydrate ContextStore from DB: {e}")
        except Exception as e:
            logger.error(f"❌ Postgres DB connection failed: {e}")
    
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
    
    # Start sensor monitoring in background task
    sensor_task = asyncio.create_task(start_sensor_monitoring())
    
    # Start proactivity loop
    proactivity_task = asyncio.create_task(start_proactivity_loop())

    # Start scheduler agent and wire executor
    try:
        async def _job_executor(job_row):
            # job_row.data expected to contain a `task` dict for ExecutorAgent
            try:
                logger.info(f"_job_executor invoked for job {getattr(job_row, 'id', '?')}; executor_agent id={id(executor_agent)} has_execute={hasattr(executor_agent, 'execute')}")
                task = (job_row.data or {}).get('task')
                if task:
                    # ensure executor_agent is connected
                    if not executor_agent._connected:
                        await executor_agent.connect()
                    await executor_agent.execute(task)
            except Exception as e:
                logger.error(f"Error executing scheduled job {getattr(job_row, 'id', '?')}: {e}")

        scheduler_agent.executor = _job_executor
        # Log executor identity for debugging (helps tests that patch executor_agent)
        try:
            logger.info(f"Scheduler executor assigned. executor_agent id={id(executor_agent)} has_execute={hasattr(executor_agent, 'execute')}")
        except Exception:
            pass
        await scheduler_agent.start()
    except Exception as e:
        logger.warning(f"Could not start scheduler_agent: {e}")

    # Start periodic context snapshot task if persistence enabled
    snapshot_task = None
    timeout_checker_task = None
    try:
        from src.core import db_async as db_v2
        interval = int(getattr(settings_v2, 'CONTEXT_SNAPSHOT_INTERVAL_SECONDS', os.getenv('CONTEXT_SNAPSHOT_INTERVAL_SECONDS', '0')) or 0)
        if settings_v2.ENABLE_POSTGRES_MIGRATION and settings_v2.POSTGRES_URL and interval > 0:
            async def _snapshot_loop():
                while True:
                    try:
                        await db_v2.save_context_snapshot(context_store)
                    except Exception as e:
                        logger.warning(f"Failed to save context snapshot: {e}")
                    await asyncio.sleep(interval)

            snapshot_task = asyncio.create_task(_snapshot_loop())
    except Exception as e:
        logger.debug(f"Snapshot task not started: {e}")
    
    # Start timeout checker for two-phase state reconciliation
    async def _timeout_checker_loop():
        """Background task to mark timed-out commands as failed"""
        while True:
            try:
                await context_store.async_check_timeouts()
                await asyncio.sleep(1.0)  # Check every second
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Timeout checker error: {e}")
                await asyncio.sleep(1.0)
    
    timeout_checker_task = asyncio.create_task(_timeout_checker_loop())
    logger.info("✅ Two-phase state timeout checker started")
    
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
    # Stop scheduler agent
    try:
        await scheduler_agent.stop()
    except Exception:
        pass

    
    # Cancel proactivity task
    if 'proactivity_task' in locals() and proactivity_task:
        proactivity_task.cancel()
        try:
            await proactivity_task
        except asyncio.CancelledError:
            pass
            
    # Cancel snapshot task
    if 'snapshot_task' in locals() and snapshot_task:
        snapshot_task.cancel()
        try:
            await snapshot_task
        except asyncio.CancelledError:
            pass
    
    # Cancel timeout checker task
    if 'timeout_checker_task' in locals() and timeout_checker_task:
        timeout_checker_task.cancel()
        try:
            await timeout_checker_task
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


class ScheduleRequest(BaseModel):
    name: Optional[str] = "unnamed"
    cron: Optional[str] = None
    next_run: Optional[str] = None  # ISO timestamp
    delay_seconds: Optional[int] = None
    data: Optional[Dict[str, Any]] = {}


class ScheduleResponse(BaseModel):
    id: int
    name: str
    cron: Optional[str]
    next_run: Optional[str]
    enabled: bool
    data: Dict[str, Any]



class CommandRequest(BaseModel):
    action: str
    value: Optional[Any] = None
    params: Optional[Dict[str, Any]] = {}


# API Endpoints

@app.post("/devices/{device_id}/command")
async def send_device_command(
    device_id: str,
    command: CommandRequest
):
    """
    Send a command to a specific device.
    
    This endpoint validates the device exists (in config or as a fallback)
    and dispatches the command via the appropriate protocol (MQTT/HTTP).
    It returns immediately upon dispatch (fire-and-forget).
    """
    try:
        task = {
            "device": device_id,
            "action": command.action,
            "value": command.value
        }
        # Merge extra params if present
        if command.params:
            task.update(command.params)
            
        success = await executor_agent.execute(task)
        
        if success:
             return {"status": "accepted", "device_id": device_id, "message": "Command dispatched"}
        else:
             raise HTTPException(status_code=500, detail="Failed to dispatch command")
             
    except Exception as e:
        logger.error(f"Command execution error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


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
        # Sanitize input: trim whitespace and newlines
        goal = goal.strip()
        
        if not goal:
            raise HTTPException(status_code=400, detail="Goal cannot be empty")
        
        logger.info(f"Processing goal for user {user_id}: {goal}")
        
        # Log the goal request
        await memory_agent.add_entry(user_id, "goal_request", {
            "goal": goal,
            "timestamp": start_time.isoformat()
        })
        
        # Step 1: Plan the goal
        planned_tasks = await planner_agent.plan(goal, user_id)
        
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
        await memory_agent.add_entry(user_id, "goal_execution", {
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
        
    except HTTPException:
        # Re-raise HTTP exceptions (like 400 for empty goal)
        raise
    except Exception as e:
        logger.error(f"Goal processing failed: {e}", exc_info=True)
        try:
            await memory_agent.add_entry(user_id, "goal_error", {
                "goal": goal if 'goal' in locals() else "unknown",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            pass  # Don't fail if logging fails
        raise HTTPException(status_code=500, detail=f"Goal processing failed: {str(e)}")


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
        await memory_agent.add_entry(user_id, "preference_change", {
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
        logger.info(f"🔍 /state called. StoreID={id(context_store)} Items={len(state_dump.get('states', {}))}")
        
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


# Voice Agent Endpoints - REMOVED for clarity and stability
# (Voice claims removed as per audit requirements)


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
                tasks = await planner_agent.plan(goal, user_id)
                
                if tasks:
                    # Execute the tasks
                    results = []
                    for task in tasks:
                        result = await executor_agent.execute(task)
                        results.append(result)
                    
                    # Dismiss the suggestion after execution
                    memory_agent.dismiss_suggestion(user_id, request.suggestion_id)
                    
                    # Log the interaction
                    await memory_agent.add_entry(
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
        logger.info(f"API /devices/control called: device={request.device_id} action={request.action} user={request.user_id}")
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
        
        # Persist intended state to DB before publishing (executor will also persist)
        try:
            from src.core import db_async as db_v2
            # derive device id
            # (executor will also persist; we avoid double-calculation here)
        except Exception:
            pass

        # Execute directly (ExecutorAgent will persist the intended state before publish)
        result = await executor_agent.execute(device_task)
        
        # Log the interaction
        await memory_agent.add_entry(
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



@app.post("/devices/{device_id}/command", response_model=DeviceControlResponse)
async def device_command(device_id: str, request: DeviceCommandRequest):
    """Per-device command endpoint that mirrors /devices/control but is easier for clients.

    Accepts JSON body with action, optional parameters, and optional user_id.
    """
    start_time = datetime.now()
    try:
        logger.info(f"API /devices/{device_id}/command called: action={request.action} user={request.user_id}")
        # ensure the device_id in URL and body match (or prefer URL)
        request_device_id = request.device_id or device_id
        request.device_id = request_device_id

        # Reuse existing control_device logic
        return await control_device(request)
    except Exception as e:
        logger.error(f"Error in /devices/{device_id}/command: {e}")
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        return DeviceControlResponse(
            success=False,
            device_id=device_id,
            action=request.action if request else "",
            result={"error": str(e)},
            timestamp=start_time.isoformat(),
            execution_time_ms=execution_time
        )


@app.post("/devices/{device_id}/toggle")
async def toggle_device(device_id: str, user_id: str = Query("api_user")):
    """Toggle a device's state (on/off)."""
    try:
        # Try to read current state from DB first (single source of truth)
        action = 'turn_on'
        try:
            from src.core import db_async as db_v2
            await db_v2.init_db()
            db_dev = await db_v2.get_device_by_device_id(device_id)
            if db_dev and hasattr(db_dev, 'current_state') and isinstance(getattr(db_dev, 'current_state', None), dict):
                current_power = getattr(db_dev, 'current_state', {}).get('state', 'off')
                if current_power in ['on', 'true', True]:
                    action = 'turn_off'
                else:
                    action = 'turn_on'
        except Exception:
            # Fallback to context store if DB not available
            current_state = context_store.get_state(f"home/{device_id.replace('.', '/')}/state")
            if current_state and isinstance(current_state, dict):
                current_power = current_state.get('state', 'off')
                if current_power in ['on', 'true', True]:
                    action = 'turn_off'
                else:
                    action = 'turn_on'
        
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
        # Prefer DB-backed device list as single source of truth
        try:
            from src.core import db_async as db_v2
            await db_v2.init_db()
            devices = await db_v2.list_devices()
            logger.info(f"📊 DB query returned {len(devices)} devices")
            if devices:  # Only use DB if it has devices
                return {
                    "devices": devices,
                    "total_devices": len(devices),
                    "retrieved_at": datetime.now().isoformat()
                }
            else:
                logger.info("📊 DB is empty, falling back to ContextStore")
                raise Exception("DB empty, use ContextStore fallback")
        except Exception as e:
            logger.info(f"📊 Using ContextStore fallback (reason: {str(e)[:50]})")
            # Fallback to ContextStore
            all_topics = await context_store.async_get_topics()
            logger.info(f"📋 Available topics in context store (ID:{id(context_store)}): {all_topics}")
            
            devices = {}
            
            # New format: devices/{device_id}/observed
            for key in all_topics:
                if key.startswith("devices/") and key.endswith("/observed"):
                    # Extract device_id from key: devices/temperature.living_room/observed -> temperature.living_room
                    device_id = key.replace("devices/", "").replace("/observed", "")
                    state = await context_store.async_get_state(key)
                    
                    # Parse device_id: temperature.living_room -> type=temperature, name=living_room
                    parts = device_id.split('.')
                    if len(parts) >= 2:
                        device_type = parts[0]
                        device_name = '.'.join(parts[1:])  # Handle multi-part names
                        
                        devices[device_id] = {
                            "device_id": device_id,
                            "type": device_type,
                            "name": device_name,
                            "state": state,
                            "last_updated": state.get('last_seen') or state.get('timestamp') if isinstance(state, dict) else None
                        }
            
            # Legacy fallback: home/{type}/{location}/state format
            if not devices:
                for key in all_topics:
                    # Parse device info from key (e.g., "home/light/living_room/state")
                    parts = key.split('/')
                    if len(parts) >= 4 and parts[0] == 'home' and parts[-1] == 'state':
                        device_type = parts[1]
                        device_name = parts[2]
                        device_id = f"{device_type}.{device_name}"
                        state = await context_store.async_get_state(key)
                        
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
        # Prefer DB-backed device status
        try:
            from src.core import db_async as db_v2
            await db_v2.init_db()
            db_dev = await db_v2.get_device_by_device_id(device_id)
            if not db_dev:
                raise HTTPException(status_code=404, detail=f"Device {device_id} not found")

            return {
                "device_id": getattr(db_dev, 'device_id', device_id),
                "type": getattr(db_dev, 'device_type', None),
                "name": getattr(db_dev, 'name', None),
                "state": getattr(db_dev, 'current_state', None),
                "state_key": f"home/{getattr(db_dev, 'device_type', '')}/{getattr(db_dev, 'name', '')}/state",
                "retrieved_at": datetime.now().isoformat()
            }
        except HTTPException:
            raise
        except Exception:
            # Fallback to ContextStore
            parts = device_id.split('.')
            if len(parts) != 2:
                raise HTTPException(status_code=400, detail="Device ID must be in format 'type.name'")

            device_type, device_name = parts
            
            # Try legacy topic key first
            state_key = f"home/{device_type}/{device_name}/state"
            state = context_store.get_state(state_key)
            
            # If not found, try the new persistent observed key format
            if state is None:
                obs_key = f"devices/{device_id}/observed"
                obs_state = context_store.get_state(obs_key)
                if obs_state:
                    state = obs_state
                    state_key = obs_key

            if state is None:
                raise HTTPException(status_code=404, detail=f"Device {device_id} not found")

            # Handle the case where state is a dict wrapper or raw value
            if isinstance(state, dict):
                # If wrapped in "state" key or similar, extract or return full
                # The ContextStore usually stores the full payload from sensor
                pass

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
                await memory_agent.add_entry(
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
                    await memory_agent.add_entry(
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


@app.post("/schedules", response_model=Dict[str, Any])
async def create_schedule(request: ScheduleRequest):
    """Create and persist a schedule job. Returns created job id and details."""
    try:
        job = {
            "name": request.name,
            "cron": request.cron,
            "next_run": request.next_run,
            "data": request.data or {}
        }
        # If delay_seconds provided, include in payload data for SchedulerAgent
        if request.delay_seconds:
            job.setdefault("data", {})["delay_seconds"] = int(request.delay_seconds)

        job_id = await scheduler_agent.schedule_job(job)
        return {"id": job_id, "status": "created"}
    except Exception as e:
        logger.error(f"Error creating schedule: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating schedule: {e}")


@app.get("/schedules")
async def list_schedules(user_id: Optional[str] = Query(None, description="Filter schedules by user_id")):
    """List persisted schedules. Optionally filter by user_id present in job.data.

    By default, only enabled schedules are returned so DELETE (disable) removes
    them from the active list.
    """
    try:
        rows = await scheduler_agent.list_jobs(user_id=user_id)
        out = []
        for r in rows:
            # Only include enabled jobs in the active list
            if getattr(r, "enabled", True) is not True:
                continue
            try:
                # Use Pydantic v2 API for model serialization where available
                if hasattr(r, 'model_dump'):
                    out.append(r.model_dump())
                else:
                    out.append(r.__dict__ if hasattr(r, '__dict__') else {k: getattr(r, k) for k in dir(r) if not k.startswith("_")})
            except Exception:
                out.append({k: getattr(r, k) for k in dir(r) if not k.startswith("_")})
        return {"schedules": out, "total": len(out)}
    except Exception as e:
        logger.error(f"Error listing schedules: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing schedules: {e}")


@app.delete("/schedules/{job_id}")
async def delete_schedule(job_id: int):
    """Cancel and disable a persisted schedule job."""
    try:
        success = await scheduler_agent.cancel_job(int(job_id))
        return {"id": job_id, "cancelled": bool(success)}
    except Exception as e:
        logger.error(f"Error deleting schedule {job_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting schedule: {e}")


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


# Conditionally include v2 migration router (feature-flagged)
try:
    if flags.ENABLE_POSTGRES_MIGRATION:
        from src.api.migration_v2 import router as migration_router

        app.include_router(migration_router)
        logger.info("✅ Postgres migration endpoints enabled (v2)")
except Exception as exc:  # pragma: no cover - safe fail
    logger.warning(f"Could not include migration_v2 router: {exc}")