# -*- coding: utf-8 -*-
"""Simplified API-based model implementation using only OpenRouter."""

from typing import Any
from loguru import logger
from .model_interface import ModelInterface
from .utils import cached_query_openrouter


# Define API model prefixes
API_MODEL_PREFIXES = (
    "api/",
    "openai/",
    "anthropic/",
    "qwen/",
    "meta/",
    "google/",
    "x-ai/",
    "deepseek/",
    "o3",
)


class APIModel(ModelInterface):
    """Simplified API model using only OpenRouter"""

    def __init__(self, model_name: str):
        self._model_name = model_name
        logger.info(f"Initialized API model: {model_name}")

    def inference(self, prompt: str, **kwargs: Any) -> str:
        """Generate response using OpenRouter"""
        response = cached_query_openrouter(prompt, self._model_name)
        if response is None:
            logger.error(f"OpenRouter API returned None for model {self._model_name}")
            return ""

        result = response["result"]
        reasoning = response.get("reasoning", "No reasoning found")
        return f"<think>\n{reasoning}</think>\n{result}"

    @classmethod
    def is_api_model(cls, model_name: str) -> bool:
        """Check if a model name corresponds to an API model"""
        return any(model_name.startswith(prefix) for prefix in API_MODEL_PREFIXES)
