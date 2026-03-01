"""
LLM Client - Generic interface for Large Language Model APIs

Supports:
- Ollama (local open-source models)
- Configurable via environment variables
- Strict JSON response parsing
- Timeout, retry, and error handling

This is infrastructure-only. No automation logic or device context.
"""
import os
import json
import logging
from typing import Dict, Any, Optional
from dataclasses import dataclass
from dotenv import load_dotenv

from .ollama_provider import LLMProvider, OllamaProvider
from .llama_cloud_provider import LlamaCloudProvider

load_dotenv(override=True)
logger = logging.getLogger(__name__)


@dataclass
class LLMConfig:
    """Configuration for LLM client."""
    provider: str = "ollama"
    
    # Ollama (Local)
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.2:latest"
    
    # Llama Cloud
    llama_cloud_api_key: Optional[str] = None
    llama_cloud_model: str = "llama-3.3-70b-versatile"
    llama_cloud_base_url: str = "https://api.groq.com/openai/v1/chat/completions"
    
    timeout: int = 30


class LLMClient:
    """Generic LLM client with provider abstraction."""
    
    def __init__(self, config: Optional[LLMConfig] = None):
        """
        Initialize LLM client.
        
        Args:
            config: LLMConfig object. If None, loads from environment.
        """
        if config is None:
            config = self._load_config_from_env()
        
        self.config = config
        self.enabled = False
        self.init_error: Optional[str] = None
        self.provider: Optional[LLMProvider] = None
        
        # Normalize and validate provider
        provider = config.provider.lower().strip()
        if provider not in ["ollama", "llama_cloud"]:
            self.init_error = f"Invalid LLM provider: only 'ollama' or 'llama_cloud' supported (got '{config.provider}')"
            logger.error(self.init_error)
            return
        
        # Initialize provider
        try:
            if provider == "ollama":
                self.provider = OllamaProvider(
                    host=config.ollama_host,
                    model=config.ollama_model,
                    timeout=config.timeout
                )
            elif provider == "llama_cloud":
                self.provider = LlamaCloudProvider(
                    api_key=config.llama_cloud_api_key or "",
                    model=config.llama_cloud_model,
                    base_url=config.llama_cloud_base_url,
                    timeout=config.timeout
                )
            
            self.enabled = True
            logger.info(f"✅ LLM client initialized: {self.provider.provider_name} ({self.provider.model if hasattr(self.provider, 'model') else ''})")
        except Exception as e:
            self.init_error = f"Failed to initialize {provider} provider: {e}"
            logger.error(self.init_error)
            self.enabled = False
    
    def _load_config_from_env(self) -> LLMConfig:
        """Load configuration from environment variables."""
        return LLMConfig(
            provider=os.getenv("LLM_PROVIDER", "ollama"),
            ollama_host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
            ollama_model=os.getenv("OLLAMA_MODEL", "llama3.2:latest"),
            llama_cloud_api_key=os.getenv("LLAMA_CLOUD_API_KEY"),
            llama_cloud_model=os.getenv("LLAMA_CLOUD_MODEL", "llama-3.3-70b-versatile"),
            llama_cloud_base_url=os.getenv("LLAMA_CLOUD_BASE_URL", "https://api.groq.com/openai/v1/chat/completions"),
            timeout=int(os.getenv("LLM_TIMEOUT", "30"))
        )
    
    def query(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        json_mode: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Send a query to the LLM and get a response.
        
        Args:
            prompt: User prompt
            system_prompt: Optional system instructions
            json_mode: If True, enforce JSON-only response
        
        Returns:
            Parsed JSON response or None on failure
        """
        if not self.enabled:
            logger.debug(f"LLM client disabled: {self.init_error}")
            return None
        
        # Construct full prompt
        full_prompt = prompt
        if system_prompt:
            full_prompt = f"{system_prompt}\n\n{prompt}"
        
        # Query provider
        response = self.provider.query(full_prompt, expect_json=json_mode)
        
        if response is None:
            return None
        
        # Parse JSON if requested
        if json_mode:
            if isinstance(response, dict):
                return response
            return self._parse_json_response(response)
        else:
            return {"text": response}
    
    def _parse_json_response(self, text: str) -> Optional[Dict[str, Any]]:
        """
        Parse JSON from LLM response, handling common formatting issues.
        
        Args:
            text: Raw response text
        
        Returns:
            Parsed JSON dict or None
        """
        # Remove markdown code blocks if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()
        
        # Try to parse
        try:
            data = json.loads(text)
            logger.debug(f"Successfully parsed JSON response: {type(data)}")
            return data
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON: {e}")
            logger.debug(f"Raw text: {text[:200]}")
            return None
    
    def test_connection(self) -> bool:
        """
        Test LLM connectivity with a simple query.
        
        Returns:
            True if connection successful
        """
        if not self.enabled:
            logger.warning(f"LLM client is disabled: {self.init_error}")
            return False
        
        logger.info("Testing LLM connection...")
        
        result = self.query(
            prompt='Respond with: {"status": "ok", "message": "Connection successful"}',
            json_mode=True
        )
        
        if result and result.get("status") == "ok":
            logger.info("✅ LLM connection test passed")
            return True
        else:
            logger.error("❌ LLM connection test failed")
            return False


def test_llm_client():
    """
    Minimal test function for LLM client.
    
    Tests:
    - Model connectivity
    - JSON response parsing
    - Error handling
    """
    print("=== LLM Client Test ===\n")
    
    # Initialize client
    client = LLMClient()
    
    if not client.enabled:
        print(f"❌ LLM client is disabled: {client.init_error}")
        return False
    
    print(f"✅ Client initialized: {client.provider.provider_name} ({client.config.ollama_model})\n")
    
    # Test 1: Connection test
    print("Test 1: Connection test")
    if not client.test_connection():
        print("❌ Connection test failed\n")
        return False
    print()
    
    # Test 2: Simple JSON query
    print("Test 2: JSON response parsing")
    result = client.query(
        prompt="Generate a JSON object with fields: name (string), count (number), active (boolean)",
        json_mode=True
    )
    
    if result and isinstance(result, dict):
        print(f"✅ Received valid JSON: {result}\n")
    else:
        print("❌ Failed to get valid JSON response\n")
        return False
    
    # Test 3: Text mode
    print("Test 3: Text mode (non-JSON)")
    result = client.query(
        prompt="Say hello in one word",
        json_mode=False
    )
    
    if result and "text" in result:
        print(f"✅ Received text response: {result['text']}\n")
    else:
        print("❌ Failed to get text response\n")
        return False
    
    print("=== All tests passed ===")
    return True


if __name__ == "__main__":
    # Run tests if executed directly
    test_llm_client()
