"""
Llama Cloud Provider - Remote LLM transport for Phase 1.5.

Identical interface to OllamaProvider but uses HTTP requests to call
cloud-hosted Llama-3 APIs (Groq, Together, etc).

Strictly advisory-only. Part of Phase 1 Infrastructure.
"""
import logging
import requests
import json
from typing import Optional, Dict, Any
from .ollama_provider import LLMProvider

logger = logging.getLogger(__name__)


class LlamaCloudProvider(LLMProvider):
    """
    Provider for cloud-hosted Llama-3 models.
    Supports OpenAI-compatible chat completion endpoints.
    """
    
    def __init__(
        self,
        api_key: str,
        model: str,
        base_url: str = "https://api.groq.com/openai/v1/chat/completions",
        timeout: int = 30
    ):
        """
        Initialize Cloud Llama provider.
        
        Args:
            api_key: API key for the cloud service.
            model: Model name (e.g. 'llama3-70b-8192').
            base_url: API endpoint URL.
            timeout: Request timeout in seconds.
        """
        self.api_key = api_key
        self.model = model
        self.base_url = base_url
        self.timeout = timeout
        
        if not api_key:
            logger.warning("[LLAMA_CLOUD] Missing API key - provider will fail queries")

    def query(self, prompt: str, expect_json: bool = False) -> Optional[str]:
        """
        Query the cloud LLM.
        
        Args:
            prompt: Full prompt string.
            expect_json: If True, requests JSON-mode output.
        
        Returns:
            Raw text response or None on failure.
        """
        if not self.api_key:
            logger.error("[LLAMA_CLOUD] Cannot query: API key missing")
            return None

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        # Construct OpenAI-compatible payload
        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.1 # Low temperature for consistency
        }
        
        if expect_json:
            payload["response_format"] = {"type": "json_object"}

        try:
            logger.debug(f"[LLAMA_CLOUD] Querying cloud model: {self.model}")
            response = requests.post(
                self.base_url,
                headers=headers,
                json=payload,
                timeout=self.timeout
            )
            
            # Fail safe on HTTP errors
            if response.status_code != 200:
                logger.error(f"[LLAMA_CLOUD] API returned error {response.status_code}: {response.text}")
                return None
            
            data = response.json()
            
            # Extract content from OpenAI-style response
            # choices[0].message.content
            content = data.get("choices", [{}])[0].get("message", {}).get("content")
            
            if content is None:
                logger.warning("[LLAMA_CLOUD] Unexpected API response structure: missing content")
                return None
                
            return str(content)

        except requests.exceptions.Timeout:
            logger.error(f"[LLAMA_CLOUD] Request timed out after {self.timeout}s")
            return None
        except requests.exceptions.RequestException as e:
            logger.error(f"[LLAMA_CLOUD] Network error: {e}")
            return None
        except (ValueError, KeyError, IndexError) as e:
            logger.error(f"[LLAMA_CLOUD] Failed to parse API response: {e}")
            return None

    def test_connection(self) -> bool:
        """
        Simple connection test using a minimal query.
        """
        logger.info(f"[LLAMA_CLOUD] Testing connection to {self.base_url}")
        result = self.query("Say ok", expect_json=False)
        return result is not None

    @property
    def provider_name(self) -> str:
        return "llama_cloud"
