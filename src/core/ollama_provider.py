"""
Ollama Provider - HTTP-based integration with local Ollama service.

This is a concrete implementation of the LLMProvider interface for Ollama.
It handles HTTP communication, error handling, and response parsing.

No automation logic. No domain context. Pure infrastructure.
"""
import logging
import requests
from typing import Dict, Any, Optional
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""
    
    @abstractmethod
    def query(self, prompt: str, expect_json: bool = False) -> Optional[Dict[str, Any] | str]:
        """
        Send a query to the LLM.
        
        Args:
            prompt: The prompt to send
            expect_json: If True, attempt to parse response as JSON
            
        Returns:
            Parsed response (dict if expect_json=True, str otherwise) or None on failure
        """
        pass
    
    @abstractmethod
    def test_connection(self) -> bool:
        """
        Test connectivity to the LLM provider.
        
        Returns:
            True if connection successful, False otherwise
        """
        pass
    
    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Return the name of this provider."""
        pass


class OllamaProvider(LLMProvider):
    """Ollama HTTP API provider implementation."""
    
    def __init__(self, host: str, model: str, timeout: int = 30):
        """
        Initialize Ollama provider.
        
        Args:
            host: Ollama API host (e.g., http://localhost:11434)
            model: Model name (e.g., llama3.2:latest)
            timeout: Request timeout in seconds
        """
        self.host = host.rstrip('/')
        self.model = model
        self.timeout = timeout
        self.endpoint = f"{self.host}/api/generate"
        
        logger.info(f"[OLLAMA] Initialized provider: {model} @ {host}")
    
    @property
    def provider_name(self) -> str:
        return "Ollama"
    
    def query(self, prompt: str, expect_json: bool = False) -> Optional[Dict[str, Any] | str]:
        """
        Send a query to Ollama.
        
        Args:
            prompt: The prompt to send
            expect_json: If True, instruct model to return JSON
            
        Returns:
            Response text or parsed JSON dict, or None on failure
        """
        if not prompt or not prompt.strip():
            logger.warning("[OLLAMA] Empty prompt provided")
            return None
        
        # Add JSON instruction if requested
        full_prompt = prompt
        if expect_json:
            full_prompt += "\n\nIMPORTANT: Respond with valid JSON only. No markdown, no explanations."
        
        # Prepare request
        payload = {
            "model": self.model,
            "prompt": full_prompt,
            "stream": False
        }
        
        try:
            logger.debug(f"[OLLAMA] Sending request to {self.endpoint}")
            
            response = requests.post(
                self.endpoint,
                json=payload,
                timeout=self.timeout
            )
            
            # Check HTTP status
            if response.status_code != 200:
                logger.error(f"[OLLAMA] HTTP {response.status_code}: {response.text[:200]}")
                return None
            
            # Parse response
            data = response.json()
            
            # Extract response text
            response_text = data.get("response", "")
            
            # Guard against empty responses
            if not response_text or not response_text.strip():
                logger.warning("[OLLAMA] Received empty response from model")
                return None
            
            response_text = response_text.strip()
            logger.debug(f"[OLLAMA] Received response: {len(response_text)} chars")
            
            # Return as-is if not expecting JSON
            if not expect_json:
                return response_text
            
            # Otherwise, caller will parse JSON separately
            return response_text
            
        except requests.exceptions.ConnectionError:
            logger.error("[OLLAMA] Connection refused - is Ollama service running?")
            return None
        except requests.exceptions.Timeout:
            logger.error(f"[OLLAMA] Request timeout after {self.timeout}s")
            return None
        except requests.exceptions.RequestException as e:
            logger.error(f"[OLLAMA] Request failed: {e}")
            return None
        except ValueError as e:
            logger.error(f"[OLLAMA] Invalid JSON response: {e}")
            return None
        except Exception as e:
            logger.error(f"[OLLAMA] Unexpected error: {e}")
            return None
    
    def test_connection(self) -> bool:
        """
        Test Ollama connectivity with a simple query.
        
        Returns:
            True if connection successful
        """
        logger.info("[OLLAMA] Testing connection...")
        
        result = self.query(
            prompt='Respond with exactly: {"status": "ok"}',
            expect_json=True
        )
        
        if result:
            logger.info("[OLLAMA] ✅ Connection test passed")
            return True
        else:
            logger.error("[OLLAMA] ❌ Connection test failed")
            return False
